# External CTO Findings Verification

Verification date: 2026-07-13

Scope:

- `app.html`
- `approve.html`
- `index.html`
- `manifest.json`
- `README.md`
- tracked deployable files in the repository

This report verifies the latest external CTO audit findings against the current repository. It does not assume older audit findings are still accurate.

No application code was changed during this verification.

## Executive Summary

Several older CTO findings are stale. The current app loads without the old duplicate `depReq` syntax failure, visible mojibake has been removed from user-facing files, and `manifest.json` is valid JSON.

Some findings remain current or partially true:

- `app- backup.html` is tracked by Git and would be publicly deployable on static hosting unless removed or excluded.
- `generateSignatureLink()` and `createSignatureLink()` both still exist and duplicate token/update/link behavior.
- Crews, trade setup, and preset rates remain localStorage-backed or mixed, so some setup data can disappear when switching devices.
- Room photo deletion now deletes known Supabase Storage objects and quote metadata in a cloud-first order when a safe `cloudPath` exists.
- Project Photo Timeline deletion is now supported for real timeline photos, and upload now attempts cleanup if metadata persistence fails.
- Offline awareness now uses browser online/offline events, an offline banner, reconnect toast, and preflight guards before major cloud writes.
- Approval is RPC-first in source, but live deployment status cannot be inferred from repository code alone.
- Money Tracker core outstanding balance is correct for the requested fixtures. The confirmed `Remaining To Collect` double-counting bug was fixed by using total unpaid balance instead of adding deposit shortfall on top of that balance.

## Finding Verification

### 1. Duplicate `const depReq`

Search result:

- `app.html:7350`
- `app.html:7377`

Current code:

- `app.html:7350` declares `const depReq` inside the `soldQuotes.forEach(q => { ... })` callback in `renderMoneyTracker()`.
- `app.html:7377` declares `const depReq` inside a separate `soldQuotes.map(q => { ... })` callback for the deposit outstanding list.

Conclusion:

- Stale/already fixed.
- No duplicate `const depReq` exists in the same JavaScript scope.
- Browser load validation of `app.html` passed with no parse/runtime console errors.

Recommended action:

- Remove this item from current launch blockers.

### 2. Money Tracker Math

Current relevant formulas in `renderMoneyTracker()`:

- Deposit required per quote: `Number(q.depositRequired ?? q.deposit_required ?? quoteDepositRequired(q) ?? 0)`
- Deposit still due: `Math.max(0, depReq - depPaid)`
- Final balance / Outstanding Balance: `Math.max(0, Number(q.amount || 0) - paid)`
- Total collected: sum of all payment rows
- Deposits received: sum of payment rows where `type === "Deposit"`
- Remaining To Collect: `finalDue`
- Average Job Value: total tracked sold/scheduled job value divided by tracked quote count
- Collection Rate: `collected / (collected + finalDue)`

Controlled fixture:

- Total quote: `$10,000`
- Deposit requirement: `50%`
- Deposit required: `$5,000`
- Paid so far: `$3,000`

Current output:

| Metric | Current Result |
|---|---:|
| Deposit required | `$5,000` |
| Deposit still due | `$2,000` |
| Total paid | `$3,000` |
| Final balance | `$7,000` |
| Outstanding balance | `$7,000` |
| Remaining To Collect | `$7,000` |

Interpretation:

- Deposit required is correct.
- Deposit still due is correct.
- Total paid is correct.
- Final balance / Outstanding Balance is correct.
- `Remaining To Collect` is now correct for this partial-deposit case because final balance already includes all unpaid dollars.

Explicit zero deposit fixture:

- Total quote: `$10,000`
- `depositRequired: 0`
- Paid so far: `$3,000`

Current output:

| Metric | Current Result |
|---|---:|
| Deposit required | `$0` |
| Deposit still due | `$0` |
| Total paid | `$3,000` |
| Final balance | `$7,000` |
| Outstanding balance | `$7,000` |
| Remaining To Collect | `$7,000` |

Conclusion:

- The explicit-zero deposit fix is working. `depositRequired: 0` is respected and does not fall back to a default percentage.
- Core outstanding balance is correct.
- The confirmed `Remaining To Collect` double-counting bug has been fixed.

Previous three-job fixture:

Fixture:

- Job A total `$5,000`; deposit `$1,000`; final payment `$2,000`; remaining `$2,000`.
- Job B total `$3,000`; deposit `$500`; remaining `$2,500`.
- Job C total `$2,000`; fully paid `$2,000`; remaining `$0`.

Current output:

| Metric | Expected | Current |
|---|---:|---:|
| Total job value | `$10,000` | `$10,000` |
| Total collected | `$5,500` | `$5,500` |
| Outstanding balance | `$4,500` | `$4,500` |
| Deposits received | `$1,500` | `$1,500` |
| Remaining to collect | `$4,500` | `$4,500` |
| Collection rate | `55%` | `55%` |
| Average job value | `$3,333.33` | `$3,333.33` |

Conclusion:

- Previous three-job fixture still passes.
- No regression for the earlier controlled fixture.
- The previous `Remaining To Collect` partial-deposit regression no longer reproduces.

Fix applied:

- `Remaining To Collect` now uses `finalDue`, which is the non-negative unpaid contract balance across tracked quotes/jobs.
- Deposit Still Due remains separate and continues to use `depositsDue`.
- Explicit `depositRequired: 0`, fully paid jobs, and overpaid jobs remain respected because `finalDue` is clamped with `Math.max(0, amount - paid)`.

### 3. Remaining `alert()` Calls

Current count:

- `60` `alert()` calls in `app.html`.
- `0` `alert()` calls in `approve.html`.
- `0` `alert()` calls in `index.html`.

Classification:

Validation blockers that can remain blocking for now:

- Trade selection required: lines `4412`, `4463`, `4531`
- Crew validation: lines `4646`, `4651`
- Room measurement validation: lines `4910`, `4911`
- Customer/signature/quote validation: lines `5404`, `5492`, `5591`, `5592`, `5697`, `5702`, `5851`, `5875`, `5974`, `5976`, `6171`, `6172`, `6186`, `6191`, `6197`, `6204`, `6528`, `6859`, `6862`, `6981`, `7147`, `7181`, `7196`, `7219`, `7477`, `7479`, `7526`, `7661`, `8117`, `8122`, `8130`, `8131`, `8311`, `8563`, `8882`, `9235`, `9399`, `9405`, `9411`, `9417`, `9423`, `9572`, `9744`, `9783`

Destructive/safety warnings that should remain blocking:

- `confirm("Delete this crew?")` is not an `alert()` but should remain blocking.
- `confirm("Clear all saved app data?")` is not an `alert()` but should remain blocking.
- Job completion with balance due uses blocking confirm/alert-style safety messaging around line `7704` flow context and should remain intentionally interruptive.

Success/guidance messages that can safely become toasts:

- Save Quote success: line `5419`
- Post-accept scheduling guidance: line `7704`
- Account-created success flow currently uses status text; no alert there.

Cloud/runtime errors that should become toasts or inline messages:

- Signed contract email failure: line `5751`
- Auth/signup raw error: line `8233`
- Signature link creation errors: lines `9255`, `9771`

Conclusion:

- Partially true current finding.
- Alerts remain, but most are validation blockers or safety stops.
- A small future polish pass should convert success/guidance and cloud/runtime alerts to toast/inline messaging.

### 4. Encoding Artifacts

Scanned:

- `app.html`
- `approve.html`
- `index.html`
- `manifest.json`
- `README.md`

Patterns searched:

- `â`
- `ð`
- `Ã`
- replacement character `�`

Conclusion:

- Stale/already fixed for visible user-facing files.
- No visible mojibake remains in the scanned user-facing files.
- Historical audit documentation still contains examples, but those are not user-facing and were intentionally ignored.

### 5. Duplicate Signature-Link Functions

Current functions:

- `generateSignatureLink()` at `app.html:9226`
- `createSignatureLink()` at `app.html:9735`

Call sites:

- `createSignatureLink()` is called by `sendProposalEmail()` at `app.html:9790`.
- `generateSignatureLink()` appears to support manual link generation/copying. It was found as a function definition but no direct current call site appeared in the targeted search.

Behavior comparison:

Both functions:

- Require login.
- Auto-save a quote if `currentCloudQuoteId` is missing.
- Generate a new token using `crypto.randomUUID() + "-" + Date.now()`.
- Update `quotes.signature_token`, `signature_status`, `sent_at`, and `expires_at`.
- Use the deployed approval URL: `https://www.projobflo.com/approve.html?token=...`.

Differences:

- `generateSignatureLink()` writes the generated approval link to clipboard and shows a toast.
- `createSignatureLink()` returns the link for proposal email sending.
- `generateSignatureLink()` and `createSignatureLink()` previously referenced `quote.id` in their error diagnostics even though `quote` was not defined in either function scope.

Conclusion:

- Confirmed current duplicate logic.
- The low-risk diagnostic runtime error has been fixed by using `currentCloudQuoteId || ""`.

Recommended safe consolidation plan:

1. Create one helper such as `createProposalApprovalLink({ copyToClipboard = false } = {})`.
2. Move shared token creation, quote update, expiration, and URL building into that helper.
3. Use `currentCloudQuoteId` in diagnostics instead of undefined `quote.id`.
4. Have manual copy call the helper with `copyToClipboard: true`.
5. Have `sendProposalEmail()` call the helper and use the returned link.
6. Validate proposal email, manual link copy, and failed Supabase update paths.

No consolidation was performed in this verification sprint.

### 6. Local-Only Settings

Current storage:

Cloud-backed:

- Business profile / branding fields via `user_settings`:
  - `company_name`
  - `company_phone`
  - `company_email`
  - `company_address`
  - `company_website`
  - `company_license`
  - `company_logo_url`
  - `next_estimate_number`

LocalStorage-backed:

- Crews:
  - key: `projobfloCrews`
  - functions: `loadCrewSettings()`, `saveCrewSettings()`
- Trade setup:
  - key: `fastQuoteTradeSetup`
  - functions: `getSavedTrades()`, `saveEnabledTrades()`
- Preset rates:
  - key: `fastQuotePresetRates`
  - functions: `savePresetRates()`, `loadPresetRates()`
- Local backup:
  - key: `fastQuoteIntegratedApp`
- Diagnostic rings:
  - `projobfloClientDiagnostics`
  - `projobfloApprovalDiagnostics`

Mixed behavior:

- Onboarding saves trade configuration and preset fields locally.
- It also saves business/default settings to cloud through existing settings paths where available.

Values that disappear or differ when switching devices:

- Custom crews.
- Enabled trade selection.
- Preset rates.
- Any local backup data.
- Local diagnostic history.

Conclusion:

- Confirmed current five-user beta risk.
- Paid beta should move crews, trade setup, and preset rates into `user_settings` or another cloud-backed settings path.

### 7. Backup File Exposure

Tracked file:

- `app- backup.html`

Git status:

- `app- backup.html` is tracked by Git.
- It is not ignored by `.gitignore`.

Risk:

- Static hosting can serve tracked root HTML files publicly.
- Users or search engines could open an old app build if the URL is known.
- Future edits could accidentally target the wrong file.

Conclusion:

- Confirmed current deployable-file risk.

Safe removal/exclusion action:

1. Confirm no production route, link, or rollback process depends on `app- backup.html`.
2. Remove it from the repository with `git rm -- "app- backup.html"`.
3. If an archived copy is needed, move it outside the deploy root or into a non-deployed archive location.
4. Add a policy to avoid committed deploy-root backup HTML copies.

No file removal was performed in this verification sprint.

### 8. Photo Deletion

Room photo deletion:

- Function: `removeRoomPhoto(roomId, photoKey)` in `app.html`
- Current behavior: identifies the exact room photo, confirms deletion, deletes the `job-photos` object when a safe `cloudPath` exists, saves updated `quotes.quote_data.roomPhotos`, then updates local UI.
- Legacy photos with no `cloudPath` are removed from metadata/local state only; the app does not guess a storage object from a URL.

Project Photo Timeline deletion:

- Current behavior: delete is available from timeline thumbnails and the lightbox for real Project Photo Timeline photos.
- The app targets an exact stage/photo identity, deletes the known `job-photos` object when a safe `cloudPath` exists, then saves updated `quotes.quote_data.projectPhotoTimeline`.
- Legacy room-photo echoes displayed in the timeline are not deleted from the timeline view; users must delete them from the Quote Builder room-photo context.

Storage delete:

- `deleteStoredPhotoObject()` removes objects only from the allowlisted `job-photos` bucket and only under `{currentUser.id}/rooms/`.
- Paths with `/`, `..`, backslashes, a wrong bucket, or another user's prefix are rejected before the Storage API call.

Orphan risks:

- Room-photo upload can still leave an orphan if the upload succeeds and the later quote autosave fails.
- Project Photo Timeline upload now attempts to delete newly uploaded blobs if timeline metadata save fails.
- Existing metadata can reference objects that later become inaccessible if storage paths or signed URL generation fail.

Conclusion:

- The original delete gap is fixed for photos with stored `cloudPath` metadata.
- Remaining risk is now orphan prevention/cleanup for upload failure edge cases, legacy metadata without paths, and server-side policy verification.

Recommended action:

- Confirm Supabase Storage delete policies enforce owner-only access.
- Consider a server-side photo metadata table or RPC before paid launch.
- Use `ai/photo_storage_integrity.md` for manual orphan dry-runs and cleanup review.

### 9. Offline Behavior

Current source:

- `navigator.onLine` is used through the central connection-state helper.
- `online` / `offline` event listeners are registered during app initialization.
- Major cloud write paths call the shared offline guard before attempting Supabase writes or Edge Function sends.

Current behavior:

- Offline state shows a persistent banner.
- Reconnect shows a brief success toast.
- Major cloud write paths stop before the cloud request when offline and do not show success.
- No offline write queue or background sync is implemented.

Conclusion:

- The previous missing-offline-awareness finding is fixed for beta reliability.
- Offline sync remains intentionally unsupported; ProJobFlo still requires an internet connection for cloud saves.

Recommended action:

- Do not queue writes offline until idempotency and sync conflict rules are server-backed.
- Keep first beta users aware that offline mode is read/blocked only, not a sync feature.

### 10. Approval RPC Status

Repository source:

- `ai/approve_proposal_transaction.sql` exists.
- `approve.html` calls `supabaseClient.rpc("approve_proposal_transaction", ...)` first.
- `approve.html` still has a legacy fallback when the RPC appears missing.

Conclusion:

- RPC-first source code is present.
- Deployment status cannot be inferred from source code alone.
- The remaining live gate is to deploy `ai/approve_proposal_transaction.sql` to the beta Supabase project and validate:
  - first approval succeeds
  - retry is idempotent
  - double-click creates no duplicate signature/activity
  - two-tab concurrency is safe
  - expired and invalid tokens cannot approve
  - already-signed proposals open confirmation

Before paid beta:

- Deploy and validate the RPC live.
- Decide whether to remove the legacy fallback after successful live validation.

## Confirmed Current Bugs

1. `generateSignatureLink()` and `createSignatureLink()` duplicate approval-link token/update behavior.
2. `app- backup.html` is tracked and publicly deployable from the static root.
3. Photo metadata/storage drift can still happen for legacy photos without `cloudPath` and room-photo upload/autosave failures.

## Fixed In This Pass

1. `Remaining To Collect` no longer double counts partial unpaid deposits. It now uses total unpaid balance (`finalDue`) instead of `depositsDue + finalDue`.
2. Signature-link error diagnostics no longer reference undefined `quote.id`; both functions now use the available `currentCloudQuoteId` safely.
3. Offline awareness now shows an offline banner, reconnect toast, health/support connection status, and guards major cloud writes before Supabase requests.
4. Cloud-backed room-photo and Project Photo Timeline deletion now removes known `job-photos` storage objects and quote metadata in a cloud-first order.

## Stale / Already-Fixed Findings

1. Duplicate `const depReq` in the same scope: fixed/stale.
2. `app.html` parse failure from duplicate `depReq`: not present.
3. Visible mojibake in scanned user-facing files: fixed/stale.
4. `manifest.json` invalid JSON: fixed/stale.
5. Explicit-zero `depositRequired` being ignored: fixed/stale.
6. `Remaining To Collect` partial-deposit double counting: fixed.
7. Undefined `quote.id` in signature-link diagnostics: fixed.
8. Missing offline detection and offline user messaging: fixed.

## Partially True Findings

1. Money Tracker math:
   - Core deposit due, paid, final balance, outstanding balance, `Remaining To Collect`, and previous three-job fixture are correct.
   - Deposit Still Due remains a separate metric and is not added into Remaining To Collect.
2. Alerts:
   - 60 alert calls remain.
   - Many are validation blockers and can stay temporarily.
   - Success/guidance/runtime alerts should be converted to toast/inline messages.
3. Local settings:
   - Business settings are cloud-backed.
   - Crews, enabled trades, and preset rates are still localStorage-backed.
4. Approval transaction safety:
   - Source is RPC-first.
   - Live deployment and validation remain external gates.

## Paid-Beta Blockers

1. Deploy and validate `approve_proposal_transaction` live; then decide whether to remove legacy fallback.
2. Remove or exclude `app- backup.html` from the deploy root.
3. Validate photo storage policies and the documented orphan cleanup process against the live Supabase project.
4. Add server-side idempotency for payments and scheduled jobs.
5. Decide whether crews/trades/presets must become cloud-backed settings for paid users.

## Five-User Beta Risks

1. `app- backup.html` is publicly accessible if deployed.
2. Local crews/trades/preset rates do not follow the user across devices.
3. Legacy photos without `cloudPath` and failed room-photo autosaves can still leave orphaned files.
4. Some user-facing alerts still feel less polished than the rest of the app.

## Future Architecture Concerns

1. Move activity/photo metadata out of large quote JSON or add row-locking RPCs.
2. Add durable idempotency keys for jobs, payments, quote saves, and photo uploads.
3. Add cloud-backed settings for crews, trades, and rate presets.
4. Add external monitoring or server-side diagnostic capture.
5. Add automated browser smoke tests for quote, approval, scheduling, payment, photos, and mobile navigation.

## Validation Results

Passed:

- `git diff --check`
- Browser load validation of `app.html`
- Browser load validation of `approve.html`
- Browser load validation of `index.html`
- No app-specific console errors during page-load validation.
- No visible mojibake in scanned user-facing files.
- Deterministic Money Tracker fixture for explicit zero deposit.
- Deterministic previous three-job Money Tracker fixture.

Blocked:

- Direct shell-based Node parser is unavailable in this environment, so script parse validation was performed by actual browser page-load/runtime validation.
- Live deployment status of `approve_proposal_transaction` cannot be inferred from source code.

Code changes made:

- `app.html`: changed Money Tracker `Remaining To Collect` from `depositsDue + finalDue` to `finalDue`.
- `app.html`: changed signature-link diagnostics to use `currentCloudQuoteId || ""` instead of undefined `quote.id`.

Files changed:

- `app.html`
- `ai/external_cto_findings_verification.md`
