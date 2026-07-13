# Proposal Approval Transaction Safety

Reliability Sprint Phase 2
Audit date: 2026-07-12

## Current Risks

The current customer approval flow in `approve.html` loads a quote by `signature_token`, validates printed name/signature locally, inserts into `proposal_signatures`, updates `quotes`, and then invokes `send-signature-email`.

Failure scenarios reviewed:

| Scenario | Current Risk | Phase 2 Handling |
|---|---|---|
| Signature saved but quote status not updated | High: the old client flow inserted signature before quote update. | RPC performs insert and quote update in one Postgres transaction. Legacy fallback remains only until RPC deployment. |
| Quote updated but signature missing | High if client order is reversed; avoided in old flow but still possible with partial client rewrites. | RPC inserts signature and updates quote atomically. |
| Double-click Accept Proposal | Medium/high: old button remained clickable during the request. | Client now sets `approvalSubmitting`, disables inputs/button/canvas, and shows loading state immediately. |
| Refresh during approval | Medium: old partial saves could leave confusing state. | RPC either commits the accepted state or commits nothing. Refresh shows confirmation after success. |
| Browser retry after timeout | High: old retry could insert another signature. | RPC locks the quote row and returns `already_signed` after the first success. |
| Two browser tabs approve simultaneously | High: old flow could duplicate signatures. | RPC uses `select ... for update` on the quote row. Second tab waits, then returns `already_signed`. |
| Expired proposal approval | Medium: old client blocked expired proposals, but server did not enforce. | RPC checks `expires_at` before writing. |
| Already-signed proposal approval | Medium: old load showed confirmation, but submit path had no server idempotency. | RPC returns the existing signed quote without inserting another signature. |
| Network interruption after request reaches Supabase | High: old client could leave unknown partial state. | RPC result is atomic. Retrying is safe because signed quotes return `already_signed`. |
| Contractor notification failure | Medium: old UI could withhold confirmation after the proposal was already accepted. | Notification is now non-blocking and runs after successful acceptance. |

## Recommended Architecture

Use a Supabase Postgres RPC named `approve_proposal_transaction` as the canonical approval endpoint.

The RPC:

1. Accepts `signature_token`, printed customer name, and signature image.
2. Normalizes the token, printed name, and signature image.
3. Locks the matching quote row with `for update`.
4. Rejects missing token/name/signature, invalid signature image format, invalid token, expired token, or already-signed quote.
5. Inserts one `proposal_signatures` row guarded by a unique `quote_id` index.
6. Updates the quote to:
   - `status = 'Sold'`
   - `signature_status = 'Signed'`
   - `signed_at`
   - `signed_customer_name`
   - `signature_image`
   - matching fields inside `quote_data`
7. Adds one `Quote Accepted` activity to `quote_data.jobActivityTimeline` if one does not already exist.
8. Returns the updated quote JSON.

The SQL also creates these required indexes:

- `quotes_signature_token_unique_idx` on `quotes(signature_token)` where the token is not null.
- `proposal_signatures_quote_id_unique_idx` on `proposal_signatures(quote_id)`.

These indexes are part of the reliability contract. The token index makes proposal lookup fast and guarantees one token cannot point to multiple quotes. The signature index prevents duplicate stored signatures even if a future client path bypasses the RPC.

Security posture:

- The RPC is `security definer` so it can perform the approval transaction despite customer approval links running outside the authenticated contractor session.
- `search_path` is pinned to `public, pg_temp`.
- Execute is revoked from the broad `public` pseudo-role and granted only to `anon` and `authenticated`.
- The function never accepts a quote ID. The signature token is the only quote selector.

## Production Review Findings

| Area | Finding | Change |
|---|---|---|
| Transaction safety | The original RPC was already one Postgres transaction, but database constraints did not enforce one token/one signature. | Added required unique indexes for `signature_token` and `proposal_signatures.quote_id`. |
| Idempotency | Already-signed quotes returned safely, but duplicate signature rows were still possible through non-RPC paths. | Added unique signature index and `on conflict (quote_id) do nothing` with an explicit conflict response. |
| Concurrency | `select ... for update` serialized approvals for the same quote. | Kept row lock and added DB-level uniqueness as a second layer. |
| Performance | Token lookup needed an index for launch-scale proposal links. | Added partial unique token index. |
| RLS compatibility | Customer approval pages may not have contractor-authenticated table policies. | Kept `security definer`; documented that token possession is the approval authority. |
| Security definer | Search path should be pinned and broad default execute should be removed. | Set `search_path = public, pg_temp`; added `revoke all ... from public` before explicit grants. |
| SQL injection | Inputs are passed as bound RPC arguments and never concatenated into SQL. | No dynamic SQL added. |
| Error handling | Missing token/name/signature were handled; malformed or oversized approval payloads were not. | Added token/name/signature length caps and simple data URL image format validation. |
| Return values | Already-signed response lacked top-level `signed_at`. | Added `signed_at` to already-signed response for consistent retry handling. |
| Maintainability | Repeated `trim(...)` calls created small consistency risk. | Normalized inputs once into local variables. |

`approve.html` now calls the RPC first. If the RPC has not been deployed yet, the page falls back to the previous client-side flow with better button locking and messaging. This preserves the current approval page while Hayden deploys the RPC.

## SQL/RPC Code

The deployable SQL is stored in:

- `ai/approve_proposal_transaction.sql`

Keep this file in sync with any Supabase SQL Editor changes.

## Client Changes

`approve.html` now:

- Disables Accept Proposal immediately after click.
- Prevents duplicate submissions with `approvalSubmitting`.
- Disables printed-name input, clear button, and signature canvas while saving.
- Shows a loading message.
- Calls `approve_proposal_transaction` first.
- Handles `already_signed` by rendering the confirmation screen.
- Handles `expired` without saving anything.
- Shows a clear failure message when approval is not saved.
- Treats contractor notification as non-blocking after successful approval.
- Keeps the legacy flow as a temporary fallback only when the RPC is missing.

## Deployment Steps

1. Open Supabase SQL Editor for the ProJobFlo project.
2. Run this duplicate-token preflight:
   ```sql
   select signature_token, count(*)
   from public.quotes
   where signature_token is not null
   group by signature_token
   having count(*) > 1;
   ```
   Expected: zero rows. Stop and investigate before deploying if any rows return.
3. Run this duplicate-signature preflight:
   ```sql
   select quote_id, count(*)
   from public.proposal_signatures
   group by quote_id
   having count(*) > 1;
   ```
   Expected: zero rows. Stop and investigate before deploying if any rows return.
4. Confirm `quotes.quote_data` is `jsonb`:
   ```sql
   select data_type
   from information_schema.columns
   where table_schema = 'public'
     and table_name = 'quotes'
     and column_name = 'quote_data';
   ```
   Expected: `jsonb`.
5. Run the contents of `ai/approve_proposal_transaction.sql`.
6. Confirm the function exists and is `security definer`:
   ```sql
   select
     n.nspname as schema,
     p.proname as function_name,
     pg_get_function_identity_arguments(p.oid) as arguments,
     p.prosecdef as security_definer
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'approve_proposal_transaction';
   ```
7. Confirm grants exist for `anon` and `authenticated`.
8. Confirm the required indexes exist:
   ```sql
   select indexname
   from pg_indexes
   where schemaname = 'public'
     and indexname in (
       'quotes_signature_token_unique_idx',
       'proposal_signatures_quote_id_unique_idx'
     );
   ```
9. Deploy `approve.html`.
10. Run the approval validation plan below against a new smoke-test proposal link.

## Rollback Steps

1. Revert `approve.html` to the previous deployed version if the client fails.
2. Optionally remove the RPC:
   ```sql
   drop function if exists public.approve_proposal_transaction(text, text, text);
   ```
3. Re-run the proposal approval smoke test.
4. Inspect `proposal_signatures` and `quotes` for any partial records created during the incident.

## Validation Plan

- First approval succeeds.
- Refresh after approval shows Signed confirmation.
- Double-click Accept Proposal creates only one signature and one Quote Accepted activity.
- Retry after timeout returns `already_signed`.
- A second tab cannot approve again.
- Already-signed proposal opens confirmation directly.
- Expired proposal cannot be signed.
- Forced failed approval leaves quote unchanged.
- No duplicate activities appear in `quote_data.jobActivityTimeline`.
- Contractor notification failure does not hide successful approval confirmation.
- No app-specific console errors.

## Remaining Limitations

- True atomicity requires the RPC to be deployed. Until then, `approve.html` uses the legacy fallback only when the RPC is missing.
- The notification Edge Function is intentionally outside the approval transaction. Approval should remain valid even if email notification fails.
- The SQL intentionally fails deployment if historical duplicate proposal tokens or duplicate signature rows exist. Clean those records before deploying.
- The RPC does not clean up historical duplicate signatures that may already exist.
