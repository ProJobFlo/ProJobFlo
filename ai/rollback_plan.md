# ProJobFlo Rollback Plan

Use this when a production release creates a customer-impacting issue.

## Rollback Decision

Rollback immediately for:

- Login is broken for confirmed users.
- App shell does not load.
- Quote/customer/job/payment data appears missing or cross-linked.
- Proposal approval is broken or partially saving records.
- Payments duplicate or totals become incorrect.
- Scheduling cannot load or corrupts job state.

Consider a hotfix instead of rollback for:

- Isolated copy issue.
- Cosmetic UI regression.
- Non-critical empty state or polish issue.
- Feedback submission failure with mailto fallback still available.

## Required Information

Before acting, record:

- Current production commit hash.
- Last known-good commit hash.
- Time the issue started.
- Affected user/account.
- Affected customer/quote/job/payment IDs if known.
- Exact screen/workflow.
- Any Supabase or browser diagnostic logs.

## Frontend Rollback

Preferred path:

1. Identify the last known-good commit.
2. Revert the bad commit or redeploy the known-good commit.
3. Push the rollback only after confirming the target commit.
4. Wait for GitHub Pages deployment.
5. Open:
   - `https://www.projobflo.com`
   - `https://www.projobflo.com/app.html`
   - a disposable `approve.html` link
6. Run the minimum smoke test:
   - login
   - Quote Builder load
   - save quote
   - Scheduling load
   - Money Tracker load
   - Customer Database load
   - proposal approval confirmation/load

Do not rollback database records automatically as part of frontend rollback.

## Supabase RPC / SQL Rollback

Only change database functions after identifying the exact failure.

For `approve_proposal_transaction`:

1. Export the current function definition.
2. Export affected `quotes` and `proposal_signatures` rows.
3. If the previous RPC version is known-good, redeploy that function body.
4. If the RPC is unavailable but frontend fallback is still present, temporarily accept fallback only for controlled beta and document the risk.
5. Verify:
   - invalid token cannot approve
   - already-signed token returns safely
   - expired token cannot approve
   - valid disposable proposal signs once

Do not drop production tables or delete production rows as a rollback shortcut.

## Edge Function Rollback

For `super-processor` or `send-signature-email`:

1. Check function logs.
2. Confirm whether the frontend request payload changed.
3. Redeploy the previous known-good function version if email delivery is broken.
4. Confirm proposal links use `https://www.projobflo.com/approve.html`.
5. Send one disposable proposal email.
6. Confirm no sensitive request payloads are logged.

## Data Repair After Rollback

If bad data was created:

1. Export affected rows first.
2. Identify records by `user_id`, quote ID, job ID, payment ID, estimate number, and timestamps.
3. Repair the smallest possible set of rows.
4. Do not edit derived Money Tracker totals; fix the underlying payment rows.
5. Do not remove storage objects until confirming no metadata references them.
6. Document every repair with before/after values.

## Communication

For controlled beta:

- Tell affected contractors that ProJobFlo is being reverted to the previous stable version.
- Mention whether any data entry needs to be repeated.
- Avoid technical details unless asked.
- Never ask for passwords, signatures, or exported raw backups over email.

## Rollback Completion Criteria

Rollback is complete when:

- The production app loads.
- Login works.
- Existing customer/quote/job/payment data loads.
- Proposal approval loads and signed proposals show confirmation.
- Minimum smoke test passes.
- Supabase logs show no repeated production errors.
- Affected contractors are notified if needed.
