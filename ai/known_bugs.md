# ProJobFlo Known Bugs

## Critical

### `app.html` Has an Autosave Syntax Error

Location: `autoSaveCurrentQuoteDraft()`

Current code includes:

```js
status: status: getAutoSaveQuoteStatus(),
```

Expected shape:

```js
status: getAutoSaveQuoteStatus(),
```

Impact: can prevent `app.html` JavaScript from parsing and stop the app from loading.

### `app.html` Has a Money Tracker Syntax Error

Location: `renderMoneyTracker()`

The deposit outstanding block declares `const depReq` twice in the same scope and then uses `paid` without defining it in that block.

Impact: can prevent `app.html` JavaScript from parsing and stop the app from loading.

### `manifest.json` Is Invalid JSON

The icon object is missing a comma after the `src` property:

```json
"src": "https://..."
"sizes": "512x512"
```

Impact: browser install/PWA metadata can fail.

## High

### Money Tracker Deposit Math Appears Incorrect

Deposit owed should likely be:

```js
max(0, depositRequired - depositPaid)
```

Current logic appears to use final-balance-style calculations in the deposit section.

Impact: users may collect or report the wrong deposit amount.

### Final Balance Math May Understate Amounts Due

Current final balance logic uses `Math.max(paid, depReq)`, which treats required deposit as if it has been paid.

Impact: outstanding balance can be understated.

### Local UI Can Show Cloud-Unsaved Records

Jobs and payments are pushed into local arrays before cloud save is confirmed.

Impact: failed writes appear saved until refresh, then disappear.

### Quote and Job Status Can Diverge

Some job status changes leave quote status as `Scheduled`.

Impact: dashboard, money tracker, customer history, and schedule can disagree.

### `saveJobsToCloud()` Does Not Include Full Relational Data

The manual jobs save path does not clearly upsert with stable job IDs, quote IDs, and customer IDs.

Impact: duplicate or disconnected job records.

## Medium

### Company Settings May Not Apply Without Logo

Some company-setting application logic appears nested inside the company logo conditional.

Impact: users without logos may not get company settings or estimate number setup applied correctly.

### Photo Deletion Is Local-Only

Photo removal updates local state, but does not appear to delete Supabase Storage objects.

Impact: orphan files and stale storage.

### Photo Objects May Lack Stable IDs

`removeRoomPhoto()` filters by `p.id`, but photo objects are not clearly assigned stable IDs when created.

Impact: remove photo may not work reliably.

### Duplicate Signature-Link Logic

Both `generateSignatureLink()` and `createSignatureLink()` exist.

Impact: logic can drift between manual copy and email proposal paths.

### README Is Boilerplate

The repo does not explain what ProJobFlo is, how to run it, or how Supabase should be configured.

Impact: maintenance and onboarding are harder.

## Low

### Encoding Artifacts

Several user-visible strings show mojibake characters such as `â€”`, `âœ“`, and similar sequences.

Impact: unpolished text in the UI and marketing page.

### `app- backup.html` Purpose Is Unclear

It is not clear whether the backup file is needed, historical, or accidentally deployed.

Impact: future changes may be made to the wrong file.

