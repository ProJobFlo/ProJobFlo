# ProJobFlo v1.0 Beta Release Checklist

This checklist decides whether ProJobFlo is ready for the first 5 controlled free beta contractors.

## Release Gate

Invite the first 5 contractors only when all "Must Pass" items pass or are explicitly accepted as controlled-beta risks.

## Must Pass

Authentication:

- [ ] Confirmed beta user can log in.
- [ ] Session restores after refresh.
- [ ] Logout works.
- [ ] Auth errors show clear user-facing messages.

Quote Builder:

- [ ] Customer fields are readable on desktop and mobile.
- [ ] Quote save persists as intended after refresh.
- [ ] Quote status flow is correct: Draft when explicitly draft, Unsold after Save Quote, Sold after acceptance.
- [ ] Quote Preview looks professional and totals match Live Numbers.
- [ ] Generate PDF works.
- [ ] Send Proposal works or fails with a clear message.

Proposal Approval:

- [ ] Approval page opens from deployed-domain email link.
- [ ] Printed name without signature is blocked.
- [ ] Real signature plus printed name approves.
- [ ] Already-signed proposal opens confirmation and hides signature form.
- [ ] Expired proposal cannot be signed.
- [ ] `approve_proposal_transaction` is deployed and validated, or fallback risk is explicitly accepted.
- [ ] No duplicate signature/activity is created by retry/double-click.

Scheduling:

- [ ] Sold quote can be scheduled.
- [ ] Scheduled job persists after refresh.
- [ ] Schedule edit persists after refresh.
- [ ] Schedule delete persists after refresh.
- [ ] Add to Calendar generates valid `.ics`.
- [ ] Google Calendar and Maps links generate.

Job Command Center:

- [ ] Job File opens from Scheduling.
- [ ] Contact actions work.
- [ ] Money snapshot matches Money Tracker.
- [ ] Photo Timeline renders.
- [ ] Activity Timeline renders newest first.
- [ ] Job Progress checklist persists.

Money Tracker:

- [ ] Deposit payment persists.
- [ ] Final payment persists.
- [ ] Outstanding balance matches payment rows.
- [ ] Total collected matches payment rows.
- [ ] Failed payment save does not alter local totals.

Customer Database:

- [ ] Customer profile opens.
- [ ] Customer history shows related quotes/jobs/payments.
- [ ] Customer deletion does not hide records locally if cloud delete fails.

Mobile:

- [ ] Mobile bottom nav does not wrap.
- [ ] Dashboard, Quote, Schedule, Money, Customers, and More are reachable.
- [ ] No horizontal overflow on iPhone-sized viewport.
- [ ] Feedback does not block bottom navigation.

Operations:

- [ ] `git diff --check` passes.
- [ ] `app.html` script parses.
- [ ] `approve.html` script parses.
- [ ] Settings shows the expected app version.
- [ ] Settings Health Check runs without exposing sensitive data.
- [ ] Support Report copies and includes app version, user ID, safe diagnostics, and health status.
- [ ] Production smoke test passes.
- [ ] Rollback commit is known.
- [ ] Supabase access is confirmed.
- [ ] Edge Function logs are checked after smoke test.

## Accepted Controlled-Beta Risks

These can be accepted for the first 5 free beta users if Hayden is ready to monitor manually:

- No external error monitoring service.
- Application health and support reports are client-side only.
- No automated browser regression suite.
- Some preferences/setup state still uses browser local storage.
- Photo storage and quote metadata can require manual recovery if one side saves and the other fails.
- Estimate numbering is not yet server-transactional.
- Customer deletion/cascade policy still needs a paid-beta hardening pass.

## No-Go Conditions

Do not invite beta users if any of these are true:

- A save shows success but disappears after refresh.
- Proposal approval can partially save signature/status.
- Payments can duplicate on repeated submit.
- Money Tracker totals are wrong for known fixture data.
- Data from one user appears under another user.
- Mobile navigation blocks critical buttons.
- There is no clear rollback path.

## First 5 Contractor Rollout Plan

1. Invite one internal/test contractor first.
2. Run one quote-to-paid-job workflow with that account.
3. Invite two friendly contractors who can tolerate close support.
4. Monitor daily for one week.
5. Invite the remaining two only after no Critical or High issues are open.

## Support Triage Questions

Ask:

- What screen were you on?
- What customer or estimate number?
- What were you trying to do?
- What message did ProJobFlo show?
- Did the data remain after refresh?
- Are you on desktop, iPhone, or Android?

Do not ask for:

- password
- signature image
- Supabase token
- raw exported backup by email

## Before Paid Beta

Required before paid beta:

- Deploy and validate approval RPC in production.
- Decide whether to remove approval legacy fallback.
- Add external error monitoring or a server-side diagnostic log.
- Harden estimate numbering server-side.
- Define customer/job/photo deletion archive policy.
- Add automated smoke tests for quote, approval, scheduling, payment, photo, and mobile navigation.
