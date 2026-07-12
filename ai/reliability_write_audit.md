# ProJobFlo Reliability Write Audit

Audit date: 2026-07-12

Scope: Reliability Sprint Phase 1, Critical Write Audit. This audit reviewed critical create, update, and delete workflows in `app.html` and the customer approval write path in `approve.html`.

Reliability rule used:

1. Validate input.
2. Attempt cloud write.
3. Confirm cloud success.
4. Update local state/UI.
5. Show success message.

If a cloud write fails, local state should remain unchanged or roll back, no success message should appear, and secondary timeline records should not be created from a failed parent action.

## Audited Workflows

| Workflow | Function(s) | Current Write Order | Risk | Problem Found | Recommended Fix |
|---|---|---|---|---|---|
| Customer create from Quote Builder | `saveCurrentCustomerToCloud`, `loadCustomersFromCloud` | Validate/login, insert customer, show success, reload customers | Low | Local customer list updates only after cloud reload. | No code change. |
| Quote save with customer upsert | `saveCurrentQuoteToCloud` | Upsert customer, upsert quote, then reload/update local IDs | Medium | Customer upsert can succeed while quote upsert fails; no client-side transaction. Local `currentCloudCustomerId` previously advanced before quote success. | Fixed local ID ordering. Future: server RPC transaction for customer+quote save. |
| Quote status actions | `updateQuoteStatusCloud`, `markSold`, `markLost`, `snoozeQuote` | Previously mutated local quote before cloud update | High | Failed cloud update could leave local status/follow-up changes visible until refresh. | Fixed: build proposed quote/quote data, save cloud, then mutate local and render. |
| Contractor quote acceptance | `acceptQuote`, `saveCurrentQuoteToCloud`, `saveAcceptedQuoteAsSold`, `appendJobActivity` | Save quote as Sold, then update local accepted state, then append activity | Low | Parent quote save is cloud-first. Activity can fail after quote acceptance succeeds. | No code change. Future: optional batched quote+activity write. |
| Customer approval/signature | `approve.html acceptProposal` | Insert signature, update quote status, notify contractor, update local confirmation | High | Signature insert can succeed while quote update fails; no transaction. Duplicate signature insert possible on double submit without schema constraint. | Future: Supabase RPC/Edge Function transaction or idempotent approval endpoint. |
| Schedule job create | `scheduleSelectedQuote` | Validate, insert job, then push local job, then append activity and show success | Medium | Parent job insert is cloud-first. Activity save can fail after job is scheduled. Duplicate jobs possible on rapid retry without idempotency key/constraint. | No code change in Phase 1. Future: idempotency key or unique quote/date scheduling constraint. |
| Schedule job update | `updateScheduledJob`, `saveScheduledJobCloud` | Build proposed job, save cloud, mutate local, append activity, render | Low | Already cloud-first from prior hardening. | No code change. |
| Job delete | `deleteScheduledJob` | Confirm, delete cloud, remove local, render | Low | Cloud-backed delete is cloud-first. Local-only jobs can still be removed locally. | No code change. |
| Job status In Progress | `markJobInProgress`, `saveScheduledJobCloud`, `appendJobActivity` | Previously mutated job/quote before cloud update and always showed success | High | Failed cloud save could leave job shown as In Progress and show success. | Fixed: proposed job is saved first; local status/activity/success only after save. |
| Job status Complete | `markJobComplete`, `saveScheduledJobCloud`, `appendJobActivity` | Previously mutated job/quote before cloud update and always showed success | High | Failed cloud save could leave job shown as Complete and show success. | Fixed: proposed job is saved first; local status/activity/success only after save. |
| Payments | `recordPayment`, `addPayment`, `loadPaymentsFromCloud` | Validate/login, insert payment with UUID, push local payment, append activity, render | Medium | Parent payment insert is cloud-first. Activity can fail after payment succeeds. Duplicate payments are possible if the user retries after an uncertain network result. | No code change in Phase 1. Future: idempotency token/unique client request key. |
| Project Photo Timeline upload | `handleJobTimelineUpload`, `uploadPhotoToCloud`, `persistProjectPhotoTimeline` | Upload blob, persist metadata in quote JSON, then render | High | Timeline arrays were mutated locally before quote metadata save. Blob upload can still succeed while metadata fails. | Fixed local mutation ordering and cloned arrays. Future: cleanup orphaned blobs when metadata save fails. |
| Activity Timeline manual/automatic entries | `appendJobActivity`, `persistJobActivityTimeline` | Build entry, persist quote JSON, then render | High | `persistJobActivityTimeline` mutated local quote data before cloud save. | Fixed: save proposed quote data first, then update local activity data. |
| Job Progress checklist | `toggleJobProgressItem`, `persistJobProgressChecklist` | Build proposed progress, save quote JSON, mutate local quote data | Low | Already cloud-first and reopens Job File after failure without preserving false UI state. | No code change. |
| Company/settings data | `saveUserSettings`, `saveCompanySettings`, `uploadContractorLogo` | Previously mutated `userSettings` before cloud upsert; company settings showed success regardless of save result | High | Failed settings save could appear saved locally and show false success. Logo URL could appear active after settings metadata failed. | Fixed: save proposed settings first, then mutate local settings and show success. Logo UI updates only after settings save succeeds. |
| Customer deletion | `deleteCustomer` | Confirm, delete cloud, remove local, render, show success | Low | Cloud-backed delete is cloud-first. Related records are not cascaded by client. | No code change. Future: documented cascade/archive policy. |
| Room photo upload | `addRoomPhotos`, `uploadPhotoToCloud`, quote autosave | Push local preview, upload blob, later autosave quote metadata | Medium | Local room photo preview appears before upload/metadata persistence. Refresh can lose unsaved local previews. | No Phase 1 code change. Future: explicit pending/upload failed states and metadata-first reconciliation. |
| Room/photo deletion | `removeRoomPhoto` | Remove local photo only | Medium | Does not delete storage object or persist deletion immediately unless later quote save succeeds. | Future: cloud metadata update and storage delete with failure rollback. |
| Feedback | `submitFeedback` | Insert feedback if table exists, otherwise mailto fallback | Low | Non-critical beta feedback path. | No code change. |

## Issues Fixed

1. `updateQuoteStatusCloud()` now returns explicit success/failure and does not mutate local quote status or quote data until the cloud update succeeds.
2. `quoteProjectTimeline()` now clones timeline arrays before edits so proposed photo changes cannot mutate existing local quote state.
3. `persistProjectPhotoTimeline()` now builds proposed quote data, saves it, then updates local photo timeline only after success.
4. `persistJobActivityTimeline()` now builds proposed quote data, saves it, then updates local activity data only after success.
5. `markJobInProgress()` now saves a proposed job status before mutating local job/quote state or appending the Job Started activity.
6. `markJobComplete()` now saves a proposed job status before mutating local job/quote state or appending the Job Completed activity.
7. `saveCurrentQuoteToCloud()` no longer advances `currentCloudCustomerId` until the quote write succeeds.
8. `saveUserSettings()` now returns `true`/`false`, saves proposed settings before mutating `userSettings`, and does not show false success on failure.
9. `saveCompanySettings()` now shows success only after `saveUserSettings()` succeeds.
10. `uploadContractorLogo()` now updates local logo state/UI only after the logo URL is saved to `user_settings`.

## Ranked Reliability Risks

1. High: `approve.html` customer approval is a multi-table write without a transaction; signature insert can succeed while quote update fails.
2. High: Payment retries can create duplicate payments after uncertain network failures because there is no idempotency key or unique client request constraint.
3. High: Schedule retries can create duplicate jobs because job creation has no idempotency key or uniqueness constraint.
4. Medium: Quote save can create/update a customer but fail quote save because customer+quote writes are not transactional.
5. Medium: Photo blob upload can succeed while quote metadata persistence fails, leaving orphaned storage objects.
6. Medium: Room photo upload/delete remains local-first and depends on later quote persistence.
7. Medium: Customer deletion does not cascade/archive related quotes, jobs, payments, signatures, or storage objects in the client.
8. Medium: Activity events after successful parent actions can fail separately, leaving parent data correct but timeline history incomplete.
9. Low: Manual follow-up state changes are local-only unless included in a later quote save/status update.
10. Low: Local-only settings such as crews and some trade defaults remain device-local by design.

## Items Requiring Schema Changes Or Future Work

- Add an idempotent approval endpoint or Supabase RPC for proposal signature + quote status update.
- Add idempotency keys for payments and scheduled jobs.
- Add a server-side transactional customer+quote save.
- Add storage cleanup for photo/logo uploads when metadata persistence fails.
- Define cascade/archive behavior for customer deletion.
- Persist room photo deletes with storage object removal and rollback on failure.
- Move device-local settings that matter across devices into cloud-backed settings.

## Validation Notes

- The Phase 1 code fixes are order-of-operations changes only.
- No Supabase schema changes were made.
- No calculations were changed.
- No UI redesign or feature additions were made.
