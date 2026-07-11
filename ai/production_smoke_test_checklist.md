# ProJobFlo v1.0 Beta Production Smoke-Test Checklist

Run this on the deployed site before inviting beta contractors.

## Account and login

- [ ] Sign up with a new user or log in with a confirmed beta test account.
- [ ] Refresh after login and confirm the session restores.
- [ ] Confirm the app shows the correct logged-in email.

## Customer and quote persistence

- [ ] Create a new customer with name, phone, email, address, and notes.
- [ ] Create a quote with at least one room and one line item.
- [ ] Save the quote as `Unsold`.
- [ ] Refresh the app.
- [ ] Confirm the customer still appears.
- [ ] Confirm the quote still appears with the correct status and total.

## Proposal and customer approval

- [ ] Generate the proposal preview and confirm line items/totals match Live Numbers.
- [ ] Send proposal email to a reachable test email.
- [ ] Open the approval link from the email.
- [ ] Confirm `approve.html` loads the correct customer, quote total, line items, and photos if present.
- [ ] Sign with a real stroke and printed name.
- [ ] Submit approval.
- [ ] Confirm the quote reloads as `Sold` in the contractor app.
- [ ] Confirm contractor signature notification succeeds or fails with a clear message.

## Scheduling

- [ ] Schedule the sold quote.
- [ ] Refresh the app.
- [ ] Confirm the scheduled job still appears.
- [ ] Edit scheduled date, duration, crew, and notes.
- [ ] Refresh the app.
- [ ] Confirm schedule edits persisted.
- [ ] Generate Add to Calendar `.ics`.
- [ ] Open Google Calendar URL.
- [ ] Open Google Maps URL.
- [ ] Delete the scheduled job.
- [ ] Refresh the app.
- [ ] Confirm the deleted job does not reappear.

## Payments and money tracking

- [ ] Record a deposit.
- [ ] Refresh the app.
- [ ] Confirm the payment still exists.
- [ ] Record a final payment.
- [ ] Refresh the app.
- [ ] Confirm Money Tracker totals match expected paid, balance due, deposits due, and completed revenue.

## Customer history

- [ ] Open Customer Database.
- [ ] Confirm the customer history shows quote, sold status, schedule/payment history where applicable.
- [ ] Confirm no unrelated customer data appears.

## Job File, photos, and activity

- [ ] Open a scheduled job's Job File.
- [ ] Confirm money snapshot matches Money Tracker for the job.
- [ ] Upload one Estimate Photo.
- [ ] Upload one Installation Progress photo.
- [ ] Add a manual Activity Timeline note.
- [ ] Refresh the app.
- [ ] Reopen the same Job File.
- [ ] Confirm photos remain in the correct timeline stages.
- [ ] Confirm the manual note persists.
- [ ] Confirm automatic activities appear newest first.

## Mobile navigation

- [ ] On an iPhone-sized viewport, confirm bottom nav does not wrap.
- [ ] Open Dashboard, Quote, Schedule, Money, Customers, and More.
- [ ] From More, open Follow-Ups, Settings, Profit Mode, Feedback, and Logout if visible.
- [ ] Confirm no horizontal scrolling.
- [ ] Confirm Feedback does not overlap the mobile nav.

## Final checks

- [ ] No console errors on landing page.
- [ ] No console errors on app load.
- [ ] No console errors during quote save, proposal send, approval, scheduling, payment, photo upload, or mobile navigation.
- [ ] No user-facing prototype, sample app, or mojibake text appears.
