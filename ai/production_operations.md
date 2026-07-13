# ProJobFlo Production Operations

Use this runbook for the v1.0 Beta release candidate and the first controlled contractor beta.

## Current Production Shape

- Frontend: static `index.html`, `app.html`, and `approve.html`.
- Hosting: GitHub Pages / custom domain `https://www.projobflo.com`.
- Backend: Supabase Auth, Postgres tables, Storage buckets, Edge Functions, and the `approve_proposal_transaction` RPC.
- Client persistence: authenticated cloud data is primary; several setup/preferences values still use browser `localStorage`.
- Release process: git commit, push production branch, verify deployed pages, run production smoke test.

## Supabase Inventory

Tables currently used:

- `customers`: customer CRM records.
- `quotes`: quote payloads, status, totals, signature token fields, approval fields, timeline/photo/checklist JSON.
- `jobs`: schedule records linked to quotes/customers.
- `payments`: deposit and final payment records.
- `proposal_signatures`: customer approval signatures.
- `feedback`: optional in-app feedback table when available.
- `user_settings`: company profile, logo URL, default settings, onboarding completion.

Storage buckets currently used:

- `job-photos`: room photos and Project Photo Timeline uploads.
- `contractor-logos`: contractor logo uploads.
- `Logos`: public ProJobFlo brand/logo assets.

Edge Functions / RPC:

- `super-processor`: proposal and signed contract email delivery.
- `send-signature-email`: contractor notification after customer approval.
- `approve_proposal_transaction`: transactional customer proposal approval.

## Monitoring

### What Is Available Now

- Browser console diagnostics for client errors.
- Supabase Auth logs.
- Supabase API logs.
- Supabase Edge Function logs.
- Supabase table/storage inspection.
- Browser-local sanitized diagnostic rings:
  - `localStorage.projobfloClientDiagnostics`
  - `localStorage.projobfloApprovalDiagnostics`

The browser-local diagnostic logs are intentionally small and sanitized. They keep the last 25 entries only and include:

- timestamp
- workflow name
- current user ID when available
- safe record IDs such as quote/job/customer/payment IDs
- table, bucket, RPC, or Edge Function names
- sanitized error message

They must not include:

- customer email or phone
- passwords
- Supabase access or refresh tokens
- proposal signature tokens
- signature image data URLs
- raw proposal payloads
- photo blobs

### Daily Beta Monitoring

During the first 5-user beta, check once per business day:

1. Supabase Auth: failed login spikes or disabled users.
2. Edge Functions: failures for `super-processor` and `send-signature-email`.
3. Database: recent writes to `quotes`, `jobs`, `payments`, and `proposal_signatures`.
4. Storage: upload failures or unusually large files in `job-photos`.
5. Feedback table/email: contractor-reported blockers.
6. Manual support notes: any reports of missing quotes, duplicate payments, failed approvals, or photo loss.

### When A Contractor Reports A Problem

Ask for:

1. Account email.
2. Customer name or estimate number.
3. Approximate time of the action.
4. Screen where it happened.
5. Screenshot of the user-facing message if available.
6. The sanitized diagnostic log from browser local storage if the issue is reproducible.

Do not ask contractors to send passwords, signatures, Supabase tokens, or raw exported app backups by email.

## Incident Levels

Critical:

- A quote, payment, approval, job, customer, or photo is lost or saved under the wrong user.
- Proposal approval produces a partial signature/status state.
- Money Tracker totals become materially wrong.
- Auth exposes or mixes user data.

High:

- Proposal email delivery fails for multiple users.
- Scheduling save/edit/delete fails repeatedly.
- Photo upload succeeds but metadata does not persist.
- Customer or quote save shows success when refresh loses data.

Medium:

- A single non-critical save fails with a clear error.
- UI gets stuck in a loading state but refresh recovers.
- Feedback submission falls back to mailto.

Low:

- Cosmetic issues, copy issues, or isolated browser quirks without data risk.

## Backup And Recovery

### Before Inviting Beta Users

1. Confirm Supabase point-in-time recovery or daily backups are enabled for the project tier.
2. Export schema definitions for all app tables and the approval RPC.
3. Record the current production commit hash.
4. Confirm Supabase dashboard access for Hayden.
5. Confirm the last known-good deployment URL loads.

### Manual Recovery Principles

- Never delete or overwrite production records during triage without exporting the affected rows first.
- Prefer correcting one clearly identified row over broad update scripts.
- Use customer/user IDs, quote IDs, estimate numbers, and timestamps to identify affected data.
- For partial approval states, inspect both `quotes` and `proposal_signatures` before changing anything.
- For payment disputes, inspect `payments` rows first; do not edit Money Tracker totals directly because they are derived.
- For photo issues, inspect both `quotes.quote_data` metadata and `job-photos` storage object paths.

### Recovery Playbooks

Quote missing after save:

1. Search `quotes` by `user_id`, `estimate_number`, and timestamp.
2. Inspect `quote_data` and `customer_id`.
3. Search matching `customers`.
4. If the quote exists but the app does not show it, check status and quote/customer ID mapping.
5. If no row exists, treat as unsaved and ask contractor to recreate from available proposal/PDF/email.

Duplicate quote:

1. Identify duplicate rows by `user_id`, `estimate_number`, `created_at`, and similar `quote_data`.
2. Confirm which quote has jobs, payments, signatures, photos, or activity.
3. Keep the record with downstream links.
4. Archive or manually remove the duplicate only after export and review.

Partial proposal approval:

1. Inspect `quotes.status`, `quotes.signature_status`, `signed_at`, `signed_customer_name`, and `signature_image`.
2. Inspect `proposal_signatures` for the quote.
3. Prefer rerunning the deployed `approve_proposal_transaction` with the original valid token only if the token is still valid and the proposal is not already signed.
4. If manual repair is needed, export both rows first and document the repair.

Payment issue:

1. Inspect `payments` rows for duplicate amount/type/date/quote ID.
2. Confirm Money Tracker values derive from rows.
3. Do not manually change derived totals.
4. If a duplicate payment exists, export rows and remove only the duplicate after confirmation.

Scheduled job issue:

1. Inspect `jobs` by `quote_id`, `customer_id`, `start_date`, and status.
2. Confirm the quote still exists and remains `Sold` for sales/history.
3. Repair job status/date only after confirming the desired state with the contractor.

Photo issue:

1. Inspect `job-photos` storage for uploaded object path.
2. Inspect the quote's Project Photo Timeline metadata in `quote_data`.
3. If object exists but metadata is missing, add metadata only after confirming customer/quote/job/stage.
4. If metadata exists but signed URL fails, inspect bucket permissions and object path.

Settings/logo issue:

1. Inspect `user_settings` for the contractor.
2. Inspect `contractor-logos` object path.
3. Do not set a logo URL unless the storage object exists and is readable by the app.

## Release Operations

For every production release:

1. Review `git status`.
2. Run `git diff --check`.
3. Parse `app.html` and `approve.html` scripts.
4. Run the production smoke-test checklist.
5. Confirm no sensitive data is logged in newly changed error paths.
6. Commit with a release-focused message.
7. Push only after approval.
8. Verify deployed `index.html`, `app.html`, and `approve.html`.
9. Record commit hash, deploy time, and smoke-test result.

## Security Operations

- Keep the Supabase anon key public only; never add service role keys to frontend files.
- The approval RPC should use token-based quote lookup and should not accept a quote ID as authority.
- RLS should restrict authenticated table access to `user_id = auth.uid()`.
- Public proposal approval should expose only the intended proposal-token flow.
- Storage policies should prevent one contractor from reading another contractor's photos/logos.
- Edge Function logs should not print full request bodies with emails, signatures, or quote payloads.

## Remaining Production Risks

1. Full observability is still manual. There is no external error monitoring service yet.
2. Some important data is stored inside `quotes.quote_data`; recovery requires careful JSON inspection.
3. Customer deletion does not have a documented server-side cascade/archival policy.
4. Estimate number generation is not server-transactional.
5. Photo metadata and storage objects can still become mismatched if upload succeeds but metadata save fails.
6. Proposal approval legacy fallback should remain only until the RPC is deployed and validated, then be reconsidered before paid beta.
7. There is no automated end-to-end regression suite.
