# ProJobFlo Roadmap

## Phase 0: Stabilize the Current Repo

Goal: make the current static app load reliably and preserve core data.

- Fix current JavaScript syntax errors in `app.html`.
- Fix invalid JSON in `manifest.json`.
- Add a minimal smoke-test checklist to every deployment.
- Document Supabase tables, storage buckets, and functions.
- Confirm `approve.html` works with real signature tokens.
- Confirm `app.html` and `approve.html` agree on quote status and signature fields.

## Phase 1: Core Workflow Reliability

Goal: make quote to payment reliable enough for beta users.

- Correct Money Tracker formulas for deposit owed and final balance owed.
- Prevent UI from showing unsaved payments/jobs as if cloud save succeeded.
- Ensure jobs always save with `quote_id` and `customer_id`.
- Ensure payments always save with a valid `quote_id`.
- Ensure quote status and job status stay synchronized.
- Add clear saved/saving/error indicators.
- Verify refresh persistence for quotes, jobs, payments, and settings.

## Phase 2: Data Model and Cloud Sync

Goal: make Supabase the durable source of truth.

- Move trade setup, crews, and preset rates into Supabase user settings or dedicated tables.
- Document or add migrations for:
  - customers
  - quotes
  - jobs
  - payments
  - user_settings
  - proposal_signatures
- Document RLS policies.
- Decide delete/cascade behavior.
- Add customer dedupe/merge strategy.
- Make estimate number advancement transaction-safe.

## Phase 3: Approval and Email Hardening

Goal: make proposal send/sign workflows production-safe.

- Consolidate duplicate signature link functions.
- Verify token expiration behavior.
- Ensure proposal accepted notification has retry/error handling.
- Include Edge Function source or deployment instructions in repo.
- Confirm contractor and customer email templates.
- Verify signed proposal audit trail.

## Phase 4: Product Polish

Goal: improve trust and usability without changing the core workflow.

- Improve README and onboarding docs.
- Add beta user instructions.
- Add issue templates or bug report format.
- Improve loading/empty/error states.
- Clean up mojibake/encoding artifacts visible in text.
- Make generated PDFs professional and legible.
- Review mobile usability for field use.

## Phase 5: Maintainability

Goal: reduce regression risk.

- Split `app.html` into modules after stability is achieved.
- Add automated checks.
- Add Playwright smoke tests.
- Add fixture data for quote/schedule/payment flows.
- Add a release checklist.
- Archive or remove `app- backup.html` after deciding its purpose.

## 30-Day Suggested Plan

### Week 1

- Fix runtime blockers.
- Validate app load, auth, cloud load, and approval page.
- Correct manifest JSON.
- Add repo documentation and setup notes.

### Week 2

- Fix Money Tracker math.
- Harden payment save/load behavior.
- Harden schedule/job save/load behavior.
- Verify quote/job/payment persistence after refresh.

### Week 3

- Fix status lifecycle.
- Document Supabase schema and RLS.
- Move critical local settings toward cloud-backed storage.
- Test approval link lifecycle end to end.

### Week 4

- Beta QA pass.
- Fix highest-risk data-loss bugs.
- Prepare deployment checklist.
- Prepare beta support and feedback workflow.

