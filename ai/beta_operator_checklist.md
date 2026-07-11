# ProJobFlo v1.0 Beta Operator Checklist

Use this checklist before inviting or supporting the first controlled beta contractors.

## Supabase tables used

- `customers`: contractor-owned customer records.
- `quotes`: quote records, quote payload JSON, signature tokens, status, totals, and proposal approval fields.
- `jobs`: scheduled jobs linked to quotes/customers.
- `payments`: deposit and final payment records.
- `proposal_signatures`: customer approval signatures from `approve.html`.
- `feedback`: in-app beta feedback submissions when the table exists.
- `user_settings`: company profile, logo URL, and estimate-number settings.

## Storage buckets used

- `job-photos`: room photos and Project Photo Timeline uploads. Requires authenticated upload/read access through signed URLs.
- `contractor-logos`: contractor logo uploads. Requires authenticated upload/read access.
- `Logos`: public ProJobFlo brand assets used by the app and landing page.

## RLS expectations

- Authenticated contractors can read/write only rows where `user_id = auth.uid()`.
- `proposal_signatures` must allow inserting signatures for a valid quote approval token flow.
- `approve.html` must be able to read a quote by `signature_token` and update that quote to `Sold`/`Signed` after customer approval.
- Storage policies should prevent users from reading or writing another contractor's private photos/logos.
- Public logo assets in `Logos` should remain readable without login.

## Required Edge Functions

- `super-processor`: sends proposal emails with the generated approval link.
- `send-signature-email`: notifies the contractor after a customer signs from `approve.html`.

## Required auth settings

- Email/password auth enabled.
- Confirmed beta users should be able to log in before testing.
- If email confirmation is enabled, confirm test users manually or verify confirmation emails are deliverable.
- Site URL and redirect URLs should include `https://www.projobflo.com`.

## Deployment steps

1. Confirm `git status` is clean except for intentional release changes.
2. Run the production smoke-test checklist in `ai/production_smoke_test_checklist.md`.
3. Commit release changes.
4. Push to the GitHub Pages production branch.
5. Open `https://www.projobflo.com` and `https://www.projobflo.com/app.html`.
6. Verify browser console has no errors on landing, login, Quote Builder, Scheduling, and customer approval pages.
7. Complete one logged-in quote-to-schedule smoke test on production.

## Rollback steps

1. Identify the last known-good commit.
2. Revert the bad commit or redeploy the last known-good commit.
3. Confirm `index.html`, `app.html`, and `approve.html` load on production.
4. Run login, quote load, scheduling load, and customer approval link checks.
5. Record the incident, affected users, and any data repair needed.
