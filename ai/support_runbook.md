# ProJobFlo Support Runbook

Use this when supporting controlled v1.0 Beta contractors.

## Support Goals

When something breaks, collect enough safe information to know:

- what failed
- where it failed
- which user experienced it
- which safe record IDs were involved
- how severe it is
- how to reproduce it

Do not collect passwords, signatures, proposal contents, photo data, tokens, or raw customer contact details in diagnostic reports.

## First Response

Ask the contractor:

1. What were you trying to do?
2. What screen were you on?
3. What message did ProJobFlo show?
4. Did the information remain after refresh?
5. What approximate time did it happen?
6. Are you on desktop, iPhone, or Android?

Use customer name or estimate number conversationally to locate the issue, but do not ask them to paste sensitive contact details into support reports.

## Safe Support Report

Ask the contractor to:

1. Open Settings.
2. Go to Application Health & Support.
3. Click Run Health Check.
4. Click Copy Support Report.
5. Paste the report into the support conversation.

The report is designed to include:

- app version
- user ID
- browser/platform
- current screen
- health statuses
- safe reference IDs
- recent sanitized diagnostics
- release readiness score

The report is designed to exclude:

- email addresses
- phone numbers
- passwords
- JWTs
- signature/proposal tokens
- customer signatures
- proposal contents
- photos/base64 data
- customer addresses

## Severity

Critical:

- Data appears under the wrong user.
- Quote, payment, job, customer, or signed approval is lost or corrupted.
- Money Tracker totals are materially wrong.
- Proposal approval partially saves.

High:

- Save shows success but data disappears after refresh.
- Payments duplicate.
- Jobs duplicate or cannot be edited/deleted.
- Proposal emails or approval links fail for multiple users.
- Photo upload succeeds but timeline metadata disappears.

Medium:

- One workflow fails with a clear error and no data loss.
- Health check returns warning.
- Feedback falls back to email draft.

Low:

- UI polish, text, or isolated browser issue.

## Triage Map

Quote save issue:

- Ask for estimate number and approximate time.
- Check support report diagnostics for `quote-save`, `quote-upsert`, or `quote-status-update`.
- Inspect `quotes` and linked `customers` in Supabase.

Schedule issue:

- Check diagnostics for `schedule-job-create`, `schedule-job-update`, or `schedule-job-delete`.
- Inspect `jobs` by user, quote ID, customer ID, start date, and status.

Payment issue:

- Check diagnostics for `payment-save` or `payments-load`.
- Inspect `payments` rows.
- Do not edit derived Money Tracker totals directly.

Proposal approval issue:

- Check diagnostics for `proposal-approval-submit`, `legacy-signature-insert`, `legacy-quote-approval-update`, or `contractor-signature-notification`.
- Inspect `quotes` and `proposal_signatures`.
- Confirm whether `approve_proposal_transaction` is deployed and responding.

Photo issue:

- Check diagnostics for `photo-upload` or `project-photo-timeline-save`.
- Inspect `job-photos` bucket object path and `quotes.quote_data` timeline metadata.

Settings/logo issue:

- Check diagnostics for `settings-save` or `logo-upload`.
- Inspect `user_settings` and `contractor-logos`.

## Reproduction Notes

Record:

- workflow
- app version
- browser/platform
- account user ID
- quote/job/customer/payment safe IDs
- exact steps
- expected result
- actual result
- refresh behavior
- health status

## Escalation

Escalate immediately if:

- any Critical issue is reported
- there is cross-user data exposure
- payment totals are wrong after refresh
- proposal approval creates partial state
- rollback may be needed

Use `ai/rollback_plan.md` if a production release is suspected.

## Support Boundaries

Do not:

- ask for passwords
- ask for raw signatures
- ask for JWTs or Supabase tokens
- ask for screenshots of full proposal/customer details unless necessary
- ask for raw local backups over email
- run broad delete/update SQL without exporting affected rows first

Do:

- use safe support reports
- export rows before manual repair
- keep repair scope minimal
- document before/after values for any data repair
