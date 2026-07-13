# ProJobFlo Deployment Checklist

Use this checklist for every v1.0 Beta production deployment.

## 1. Preflight

- [ ] Confirm the intended repo and branch.
- [ ] Confirm `git status` contains only intentional changes.
- [ ] Review `git diff` for unintended business logic, calculation, persistence, or schema changes.
- [ ] Confirm no service role keys, passwords, signature images, access tokens, or refresh tokens are present in the diff.
- [ ] Confirm `ai/project_audit.md`, reliability docs, and current release notes have no conflicting blocker.
- [ ] Confirm the Supabase project is the live beta project.
- [ ] Confirm Hayden can access Supabase dashboard before deployment.

## 2. Local Validation

- [ ] Run `git diff --check`.
- [ ] Parse scripts from `app.html`.
- [ ] Parse scripts from `approve.html`.
- [ ] Open `index.html` locally or on a local static server.
- [ ] Open `app.html` locally or on a local static server.
- [ ] Open `approve.html` locally or on a local static server.
- [ ] Confirm no app-specific console errors during initial load.

## 3. Supabase Validation

- [ ] Confirm tables exist: `customers`, `quotes`, `jobs`, `payments`, `proposal_signatures`, `feedback`, `user_settings`.
- [ ] Confirm buckets exist: `job-photos`, `contractor-logos`, `Logos`.
- [ ] Confirm Edge Functions are deployed: `super-processor`, `send-signature-email`.
- [ ] Confirm RPC exists: `approve_proposal_transaction`.
- [ ] Confirm proposal approval RPC grants match `ai/reliability_approval_transaction.md`.
- [ ] Confirm RLS policies prevent cross-user authenticated reads/writes.
- [ ] Confirm auth redirect URLs include `https://www.projobflo.com`.

## 4. Deploy

- [ ] Commit the approved release changes.
- [ ] Push to the production branch only after approval.
- [ ] Wait for GitHub Pages deployment to finish.
- [ ] Open `https://www.projobflo.com`.
- [ ] Open `https://www.projobflo.com/app.html`.
- [ ] Open a valid disposable `https://www.projobflo.com/approve.html?token=...` link.

## 5. Production Smoke Test

Run `ai/production_smoke_test_checklist.md`.

Minimum required pass before inviting contractors:

- [ ] Login/session restore works.
- [ ] Create customer works.
- [ ] Save quote persists after refresh.
- [ ] Send proposal produces a deployed-domain approval link.
- [ ] Customer approval works and refresh shows confirmation.
- [ ] Sold quote schedules correctly.
- [ ] Schedule edit/delete persists after refresh.
- [ ] Deposit and final payment persist.
- [ ] Money Tracker totals are correct.
- [ ] Customer history shows related quote/job/payment data.
- [ ] Job Command Center opens.
- [ ] Photo Timeline upload persists.
- [ ] Activity Timeline note persists.
- [ ] Mobile navigation reaches every major screen.
- [ ] No app-specific console errors.

## 6. Post-Deploy Checks

- [ ] Check Supabase Auth logs for unexpected failures.
- [ ] Check Edge Function logs for email failures.
- [ ] Check recent table writes for the smoke-test account.
- [ ] Confirm no duplicate smoke-test quotes/jobs/payments/activities were created.
- [ ] Record production commit hash.
- [ ] Record deployment time.
- [ ] Record smoke-test account used.
- [ ] Record smoke-test result.

## 7. Go / No-Go

Go for 5-user free beta only if:

- [ ] No Critical or High data-integrity failures are open.
- [ ] Proposal approval RPC is deployed and validated, or fallback risk is explicitly accepted for controlled beta.
- [ ] The release can be rolled back quickly.
- [ ] Hayden has the smoke-test checklist and support/recovery runbooks.
- [ ] The first beta contractors are warned this is a controlled v1.0 Beta.

No-go if:

- [ ] Any save path shows success but loses data after refresh.
- [ ] Proposal approval can partially save signature/status.
- [ ] Payments can duplicate or alter totals incorrectly.
- [ ] Contractor data can appear under another account.
- [ ] Production cannot be rolled back to a known-good commit.
