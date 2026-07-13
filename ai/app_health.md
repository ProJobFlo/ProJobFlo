# ProJobFlo Application Health

Production Readiness Sprint Phase 2

## Purpose

The application health system is a lightweight support and release-readiness tool. It is not a customer-facing feature and it does not repair data automatically.

It answers:

- Is the user authenticated?
- Can the app reach Supabase?
- Can the app read the database?
- Can the app see required storage buckets?
- Is the approval RPC reachable?
- Are required Edge Function names configured in the client?
- Is browser-local configuration available?
- Is the browser currently online or offline?

## Where It Lives

The health tools are available in `app.html` under:

- Settings
- Application Health & Support

The central release version is:

- `APP_VERSION`

Future release version changes should update this constant only.

## Health Statuses

Each subsystem returns one of:

- `PASS`: subsystem responded as expected.
- `WARNING`: subsystem is configured or partially available, but should be reviewed.
- `FAIL`: subsystem failed a safe probe.

Overall health is:

- `FAIL` if any required check fails.
- `WARNING` if no checks fail but at least one warning exists.
- `PASS` only when all checks pass.

## Current Checks

| Subsystem | Check | Notes |
|---|---|---|
| Local configuration | Confirms Supabase URL and publishable key constants exist. | Does not validate secrets. The publishable key is expected to be public. |
| Connection | Reads the browser online/offline state. | Reports `PASS` when online and `WARNING` when offline. It does not attempt repair or background sync. |
| Browser local storage | Writes and removes a harmless temporary key. | Does not read customer backups. |
| Supabase authentication | Calls `supabaseClient.auth.getSession()`. | Anonymous state is a warning for user-data testing. |
| Database connectivity | Reads `customers.id` with `limit(1)`. | Requires the logged-in user's normal RLS path. |
| Storage connectivity | Calls `storage.listBuckets()` and checks required bucket names. | If bucket listing is restricted, this may fail even if uploads work. Treat as an operations signal. |
| RPC availability | Calls `approve_proposal_transaction` with a known invalid token and minimal dummy signature data URL. | A safe invalid-token response means the RPC exists. No proposal can be approved by this probe. |
| Edge Function configuration | Confirms required function names are configured in the client. | Reports `WARNING`/configured-unverified because the health check does not invoke email functions to avoid side effects. |

Required buckets:

- `job-photos`
- `contractor-logos`
- `Logos`

Required Edge Functions:

- `super-processor`
- `send-signature-email`

Required RPC:

- `approve_proposal_transaction`

## Diagnostic Report

The diagnostic report includes:

- app name/version
- release commit if embedded
- generated timestamp
- current screen
- current user ID
- browser user agent and platform
- browser connection status
- configured trade labels
- company configured flag
- outstanding operation-lock items
- health check results
- release readiness score
- recent sanitized diagnostics

The report must never include:

- passwords
- JWTs
- Supabase access or refresh tokens
- proposal signature tokens
- emails
- phone numbers
- signatures
- proposal contents
- photo data
- customer addresses

## Support Package

The support package wraps the diagnostic report with:

- support package version
- workflow name
- allowlisted reference IDs
- safe diagnostic report

Reference IDs are allowlisted through the same safe diagnostic context rules used by client diagnostics.

## Release Readiness Score

The score is calculated in the app from these categories:

- Reliability
- Documentation
- Monitoring
- Deployment
- Rollback
- Testing
- Known Risks

The score is a support signal, not an automatic release approval. A high score does not override no-go conditions in `ai/v1_beta_release_checklist.md`.

## Known Limitations

- There is no external monitoring service yet.
- Health checks are client-side only.
- Supabase probes use client-side timeouts so one unavailable subsystem does not block the whole report.
- Edge Functions are not invoked because that could send emails or cause side effects.
- Storage bucket listing can be blocked by Supabase permissions even when object-level upload/read policies work.
- Health checks do not prove RLS correctness across users.
- Health checks do not replace the production smoke test.

## Validation Plan

Before release:

1. Run `git diff --check`.
2. Parse `app.html` scripts.
3. Log in with a confirmed beta test account.
4. Open Settings.
5. Confirm version displays.
6. Run Health Check.
7. Confirm health output contains no sensitive data.
8. Copy Support Report.
9. Confirm report contains safe IDs, health statuses, browser/platform, version, and recent diagnostics only.
10. Confirm no customer emails, phone numbers, proposal tokens, signatures, proposal text, or photo data appear.
