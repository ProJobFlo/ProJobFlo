# ProJobFlo Orchestration Notes

## Purpose

This document explains how the current repository pieces work together and how future AI or engineering work should approach the codebase.

## Repository Entry Points

- `index.html`: public marketing/beta landing page.
- `app.html`: main contractor application.
- `approve.html`: customer-facing proposal approval page.
- `manifest.json`: web app manifest for installability/PWA presentation.
- `app- backup.html`: older app snapshot, should be treated as reference only until ownership is clarified.

## Runtime Flow

### Public Visitor Flow

1. User lands on `index.html`.
2. User reads product/beta content.
3. User can click `Open Prototype`, which links to `/app.html`.
4. User can email for beta access.

### Contractor App Flow

1. Contractor opens `app.html`.
2. App initializes local settings, templates, rooms, signature pad, and dashboard render.
3. App checks Supabase Auth for an existing session.
4. If logged in, app loads cloud customers, quotes, jobs, payments, and user settings.
5. Contractor creates a quote, saves/sends it, captures signature, schedules jobs, and records payments.

### Proposal Approval Flow

1. Contractor generates or sends an approval link from `app.html`.
2. Customer opens `approve.html?token=...`.
3. `approve.html` loads the quote by `signature_token`.
4. Customer reviews line items/photos and signs.
5. Page inserts into `proposal_signatures`.
6. Page updates the quote to signed/sold.
7. Page invokes a notification function to notify the contractor.

## Supabase Touchpoints

Current frontend usage implies these tables/buckets/functions:

- Auth users.
- `customers`
- `quotes`
- `jobs`
- `payments`
- `user_settings`
- `proposal_signatures`
- Storage bucket `job-photos`
- Storage bucket `contractor-logos`
- Public storage bucket/path for ProJobFlo logo assets.
- Edge Function or function invocation for proposal/signed-contract email.
- Edge Function `send-signature-email` referenced by `approve.html`.

The repo does not currently include SQL schema, RLS policies, storage bucket policy documentation, or Edge Function source.

## State Ownership

Current state is split across:

- In-memory arrays in `app.html`.
- Supabase tables.
- Supabase Storage.
- localStorage.

This split is the main orchestration risk. Long-term, Supabase should become the durable source of truth for user/business data, while localStorage should be limited to harmless UI preferences or cache.

## AI Work Rules

When using AI assistance on this repo:

- Do not redesign while fixing bugs.
- Keep changes narrowly scoped.
- Prefer small patches that can be manually reviewed.
- Never mix app fixes with marketing copy changes unless requested.
- Do not edit `app- backup.html` unless explicitly asked.
- Keep `approve.html` and `app.html` token/status behavior aligned.
- Before changing persistence, identify the source of truth and affected tables.
- After any app change, run at minimum:
  - static syntax/load check
  - clean browser load
  - quote save smoke test
  - schedule smoke test
  - payment smoke test

## Recommended Future Structure

Do not start this refactor until launch blockers are fixed. When approved, split the app into:

- `/src/state/`
- `/src/supabase/`
- `/src/quotes/`
- `/src/schedule/`
- `/src/payments/`
- `/src/customers/`
- `/src/settings/`
- `/src/pdf/`
- `/src/approval/`

The short-term goal is stability, not architecture cleanup.

