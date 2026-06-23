# ProJobFlo Project Audit

Audit date: 2026-06-22
Repository reviewed: `https://github.com/ProJobFlo/ProJobFlo`
Local path reviewed: `C:\Users\Jen\Documents\Codex\2026-06-18\okay-i\ProJobFlo`

## Scope

This audit reviewed the current static repository:

- `index.html`
- `app.html`
- `app- backup.html`
- `approve.html`
- `manifest.json`
- `CNAME`
- `README.md`
- repository screenshots

No existing application files were modified.

## Architecture Summary

ProJobFlo is currently a static web app. The production-facing repo contains:

- A marketing landing page in `index.html`.
- The main contractor app in `app.html`.
- A customer proposal approval page in `approve.html`.
- A previous app copy in `app- backup.html`.
- A web app manifest in `manifest.json`.
- Static screenshots used for product presentation.

The main app is a single large HTML file with embedded CSS and JavaScript. It uses Supabase for auth, tables, storage, and email-related functions. It also uses localStorage for some settings and backup-style persistence.

## Complete or Mostly Complete Features

- Marketing landing page with beta positioning, product value proposition, feature cards, workflow, pricing section, story section, testimonials, and CTA.
- Main contractor app shell with tabs for Dashboard, Quote, Follow-Ups, Schedule, Money Tracker, Settings, Customers, and Profit Mode.
- Supabase Auth integration for signup, login, logout, password reset, session restore, and protected cloud actions.
- Quote builder with customer/company fields, rooms, measurements, line items, tax, waste, deposits, and live quote preview.
- Trade setup and trade filtering for visible templates and preset fields.
- Preset rates saved locally.
- Crew management saved locally.
- Room photo capture/upload flow with Supabase Storage support.
- PDF proposal generation using jsPDF.
- Customer database, customer search, and customer detail rendering.
- Follow-up queue and follow-up message helpers.
- Scheduling calendar with multi-day jobs, crew, duration, status, and notes.
- Google Calendar URL generation for jobs.
- Money Tracker UI with deposit/final/outstanding/payment history sections.
- Supabase payment insert and payment load functions in `app.html`.
- Profit Mode with internal cost, revenue, gross profit, and margin.
- Proposal approval page in `approve.html` that loads by signature token, displays proposal details, captures customer signature, inserts a proposal signature, updates quote status, and attempts contractor notification.
- Company settings and contractor logo upload flow.

## Incomplete or Risky Areas

- The repository has no build system, test runner, package manifest, linting, or automated syntax validation.
- `README.md` is still GitHub profile boilerplate and does not explain setup, deployment, Supabase schema, or operating instructions.
- Supabase schema is not documented in the repo.
- Edge Functions referenced from the frontend are not included in this repo.
- `app.html` is over 4,000 lines and mixes UI, business logic, persistence, rendering, and third-party integration in one file.
- `app- backup.html` appears to be an older copy, but there is no explanation of whether it should remain, be archived, or be removed.
- localStorage and Supabase both store important state, creating multiple sources of truth.
- Local settings like crews, presets, and trade setup are device-local instead of cloud-backed.
- Manual `saveAll()`, `loadAll()`, and `clearAll()` functions exist but are not clearly exposed as normal product workflows.
- There is no documented deployment flow for GitHub Pages or the custom domain.

## Known Bugs and Defects

High-priority defects are documented in `ai/known_bugs.md`. Summary:

- `app.html` currently contains a JavaScript syntax error in `autoSaveCurrentQuoteDraft()`:
  - `status: status: getAutoSaveQuoteStatus(),`
- `app.html` currently contains a JavaScript syntax error in `renderMoneyTracker()`:
  - duplicate `const depReq` inside the same block.
- `renderMoneyTracker()` also references `paid` in the deposit list block without defining it.
- `manifest.json` is invalid JSON because the icon object is missing a comma after the `src` property.
- Money Tracker formulas appear to conflate deposit owed and final balance owed.
- Some cloud writes update local UI state before confirming Supabase success.
- Job status and quote status can diverge.
- `saveJobsToCloud()` does not include enough stable relational identifiers.
- Photo delete appears local-only and may not delete Supabase Storage objects.
- `removeRoomPhoto()` filters by `p.id`, but photo objects may not have stable IDs.
- Company settings may not fully apply unless a logo exists because important logic is nested inside the logo check.

## Data Loss Risks

- In-memory quote/job/payment changes can be lost on refresh if cloud save fails.
- Failed payment/job cloud writes can still appear in the UI until refresh.
- Device-local settings can disappear if browser storage is cleared.
- User settings split across localStorage and Supabase can drift across devices.
- Signed photo URLs can expire; stored quote payloads should prefer cloud paths over temporary URLs.
- Customer deletion does not visibly cascade to quotes, jobs, payments, signatures, or storage assets.
- Estimate number advancement is not transaction-safe and can duplicate across tabs/devices.

## Launch Blockers

1. Fix current JavaScript syntax errors in `app.html`.
2. Fix invalid `manifest.json`.
3. Add a minimal syntax/load validation process before deploy.
4. Verify quote creation, proposal send, approval, schedule, payment, refresh, and reload persistence in a clean account.
5. Correct Money Tracker payment math before relying on it for customer balances.
6. Clarify Supabase schema, RLS policies, storage buckets, and Edge Functions.

## Suggested Immediate Focus

- Stabilize runtime first.
- Add repo documentation next.
- Then harden data integrity and payment/status logic.
- Defer redesign and new features until core workflows survive refresh and cross-device usage.

