# Reliability Sprint Phase 3: Idempotency & Duplicate Prevention

Audit date: 2026-07-12

Scope: create, update, upload, and delete workflows that can be repeated by double-clicks, browser retries, refreshes, or multiple tabs.

Reliability target:

1. Repeated clicks should not start duplicate writes while the first write is pending.
2. Retry after an uncertain response should reuse the same client-generated ID where practical.
3. Successful cloud writes should not create duplicate local records.
4. Remaining multi-tab/browser-retry risks should be documented for server-side constraints or RPCs.

## Summary

Phase 3 added a shared client-side operation lock in `app.html`, stable pending IDs for first-save quote/customer/payment retries, local de-duping for activity entries and payment pushes, and loading/disabled states where practical.

No calculations, business formulas, Supabase schema, or product workflows were changed.

## Workflows Audited

| Workflow | Duplicate Risk | Fix Implemented | Remaining Risk | Recommendation |
|---|---|---|---|---|
| Create Quote / Save Quote | Rapid clicks or direct repeated calls before `currentCloudQuoteId` exists could generate different quote/customer IDs. A timeout after customer upsert but before quote save could duplicate customer on retry. | Added `save-current-quote` and `save-current-quote-cloud` operation locks. Added `pendingQuoteCustomerId` and `pendingQuoteId` so retries reuse the same IDs until a successful quote save clears them. | Multiple browser tabs can still save separate quotes because there is no server idempotency key for the quote draft. | Add a `client_request_id` or quote draft id with a unique `(user_id, client_request_id)` constraint, or move customer+quote save into a transaction RPC. |
| Save Customer | Standalone Save Customer used `insert`, so repeated saves could create duplicate customers. | Changed to stable-ID `upsert` using `currentCloudCustomerId` or `pendingStandaloneCustomerId`. Added `save-current-customer` operation lock. | Cross-tab duplicate customer creation remains possible without a uniqueness policy for customer identity. | Consider normalized customer identity constraints or a server-side customer upsert RPC keyed by user/email/phone/address rules. |
| Schedule Job | Rapid repeated clicks could create duplicate jobs for the same quote/date. | Added a `schedule-job-<quote>-<date>` operation lock and existing button loading state. | Cross-tab retry after a timeout can still create duplicate jobs because job creation has no idempotency key or unique scheduling constraint. | Add a server idempotency key or unique partial constraint/RPC for intended one-job-per-quote scheduling. |
| Record Payment | Retry after uncertain network response could insert a second payment with a new UUID. Duplicate local pushes were possible if the same payment id was returned twice. | Added per-payment operation lock, stable pending UUID by payment fingerprint, `upsert` by payment id, and local replacement by payment id before push. | Cross-tab/manual retry can still create a second payment with a different UUID. Payment activity can still fail after the parent payment succeeds. | Add `client_request_id` to payments with a unique constraint, or record payment + activity in one RPC. |
| Upload Room Photos | Re-selecting/double-uploading the same files while upload was pending could add duplicate local photo cards. Room photo deletes relied on missing photo IDs for older local photos. | Added per-room/file operation lock and assigned stable local photo IDs for new room photos. | Existing historical photos without IDs still cannot be reliably deleted by ID. Blob upload can succeed while quote metadata autosave later fails. | Add explicit photo metadata records or a cloud photo manifest update path with rollback/orphan cleanup. |
| Project Photo Timeline Upload | Repeated drop/click while upload was pending could upload and persist duplicate photos. | Added per-job/stage/file operation lock. Existing cloud-first metadata ordering from Phase 1 remains. | Cross-tab uploads of the same file can still create duplicate storage objects and metadata because storage paths are random. | Add persistent photo metadata table with a client upload id or content fingerprint. |
| Manual Activity Notes | Double-clicking Add Job Note could append duplicate manual notes. Parent action retries could append repeated identical automatic entries. | Added `manual-job-note-<job>-<note>` operation lock. `appendJobActivity()` now skips an entry when the same activity type, description, quote, and job already exist. | Two tabs adding the exact same note at the same time can still race because the timeline is stored inside quote JSON. | Move activity timeline to a table with unique client event IDs, or add an activity append RPC that locks the quote row. |
| Quote Acceptance (contractor app) | Repeated Accept Quote clicks could save twice and record duplicate acceptance deposits. | Added `accept-current-quote` operation lock and button loading. Acceptance deposit now uses a stable pending payment UUID and checks for the existing acceptance deposit before creating another. | Acceptance + deposit + activity are still separate writes; partial activity/payment failure can leave the quote accepted but the secondary record missing. | Add a contractor-side acceptance RPC if this workflow becomes high volume. |
| Quote Acceptance (customer approval page) | Double-clicks and retries could create duplicate signatures or partial signature/quote writes. | Phase 2 already added `approvalSubmitting`, loading/disabled states, RPC-first approval, and documented unique indexes/RPC transaction. | True atomicity requires deployment of `approve_proposal_transaction`. Legacy fallback remains temporarily. | Deploy and validate the RPC, then remove legacy fallback before paid beta. |
| Company Settings | Repeated Save Settings clicks could send overlapping upserts and show confusing state. | Added `save-user-settings` operation lock and Save Company Settings button loading. Existing cloud-first mutation ordering remains. | Last writer wins across tabs/devices. | Acceptable for beta; future settings versioning could detect stale overwrites. |
| Logo Upload | Repeated logo selections could upload multiple logo files and race metadata saves. | Added `upload-contractor-logo` operation lock. Existing Phase 1 cloud-first metadata behavior remains. | A storage upload can succeed while settings metadata save fails, leaving an orphaned logo object. | Add cleanup of orphaned logo objects when settings save fails. |
| Customer Delete | Repeated delete clicks could send multiple delete requests or remove local state inconsistently. | Added `delete-customer-<id>` operation lock. Existing cloud-first delete remains. | Customer delete does not cascade/archive related quotes, jobs, payments, signatures, or storage assets. | Define server-side archive/cascade policy before paid beta. |
| Job Delete | Repeated delete clicks could send duplicate delete requests or hide a job locally after a failed cloud delete. | Added `delete-job-<id>` operation lock. Existing cloud-first delete remains. | Cross-tab delete/edit race remains possible. | Acceptable for small beta; add server-side version checks for paid launch if needed. |

## Fixes Implemented

1. Added `pendingOperations`, `beginOperation()`, and `endOperation()` helpers.
2. Added stable pending IDs:
   - `pendingStandaloneCustomerId`
   - `pendingQuoteCustomerId`
   - `pendingQuoteId`
   - `pendingPaymentIds`
3. Added operation locks to:
   - Save Quote
   - Save Customer
   - Schedule Job
   - Record Payment
   - Room photo upload
   - Project Photo Timeline upload
   - Manual Job Note
   - Contractor-side Accept Quote
   - Company Settings
   - Contractor Logo upload
   - Customer Delete
   - Job Delete
4. Changed standalone customer save from insert to stable-ID upsert.
5. Changed payment save to stable-ID upsert and local replace-by-id.
6. Added local activity de-duping in `appendJobActivity()`.
7. Added UUIDs to newly added room photos so delete actions can target new photos reliably.
8. Added contractor-side acceptance deposit de-duping.

## Remaining Risks Requiring Server Work

1. Jobs need a server-side idempotency key or unique scheduling constraint.
2. Payments need a durable `client_request_id` unique constraint.
3. Customer+quote save should eventually be a single transaction RPC.
4. Activity timeline should eventually move out of quote JSON or use a row-locking append RPC.
5. Project photos need durable metadata records and orphan cleanup.
6. Customer deletion needs an archive/cascade policy.
7. Proposal approval legacy fallback should be removed after the RPC is live and validated.

## Validation Plan

- Run syntax/app-load validation.
- Confirm operation locks reject duplicate in-flight calls.
- Confirm quote/customer first-save retries reuse pending IDs.
- Confirm payment retries reuse pending UUIDs and replace local payment by ID.
- Confirm duplicate manual activity entries are skipped.
- Confirm delete locks release after cancel/failure.
- Confirm no calculations changed.
