# ProJobFlo Test Checklist

## Preflight

- Confirm `app.html` has no JavaScript syntax errors.
- Confirm `approve.html` has no JavaScript syntax errors.
- Confirm `manifest.json` is valid JSON.
- Open browser console and confirm no app startup exceptions.
- Confirm Supabase URL and publishable key are expected for the environment.
- Confirm required Supabase tables, buckets, RLS policies, and functions exist.

## Landing Page

- Open `index.html`.
- Verify logo loads.
- Verify beta CTA links open email.
- Verify `Open Prototype` opens `/app.html`.
- Check mobile layout.
- Check for visible encoding artifacts.

## Auth

- Sign up new user.
- Log in existing user.
- Refresh while logged in.
- Confirm session restores.
- Log out.
- Confirm protected cloud actions require login.
- Reset password flow sends email.

## Quote Builder

- Start new quote.
- Enter company details.
- Enter customer details.
- Select each template.
- Add room by room type.
- Add quick room.
- Change feet/inches measurements.
- Add/edit/delete line items.
- Toggle taxable line items.
- Change waste percentage.
- Change tax location/rate.
- Change deposit percentage.
- Verify measured sqft, order sqft, subtotal, tax, total, and deposit update.
- Save unsold quote.
- Refresh and confirm quote reloads.

## Photos

- Add room photo while logged out.
- Add room photo while logged in.
- Confirm cloud upload succeeds.
- Open saved quote and confirm photo rehydrates.
- Remove photo and verify UI behavior.
- Generate PDF with photos.

## Proposal and Signature

- Generate signature link.
- Send proposal email.
- Open `approve.html?token=...`.
- Verify proposal details load.
- Verify line items render.
- Verify photos render.
- Sign as customer.
- Confirm `proposal_signatures` row is created.
- Confirm quote updates to Signed/Sold.
- Confirm contractor notification path succeeds.
- Test expired proposal.
- Test invalid token.
- Test missing token.

## Schedule

- Mark quote sold.
- Schedule sold quote.
- Select date, crew, duration, status, and notes.
- Refresh and confirm job persists.
- Edit scheduled job.
- Delete scheduled job.
- Mark job in progress.
- Mark job complete.
- Verify quote status and job status remain consistent.
- Test multi-day job rendering.
- Open Google Calendar link.

## Money Tracker

- Record deposit.
- Refresh and confirm deposit persists.
- Record final payment.
- Refresh and confirm final payment persists.
- Verify deposits due.
- Verify final balances due.
- Verify total collected.
- Verify total outstanding.
- Verify payment history shows correct customer.
- Test payment after schedule workflow.
- Test duplicate deposit prevention if intended.

## Customers

- Load cloud customers.
- Search by name.
- Search by phone.
- Search by email.
- Search by address.
- Open customer detail.
- Confirm quote history.
- Confirm scheduled jobs.
- Delete customer.
- Verify related data behavior is expected and documented.

## Settings

- Save company settings.
- Refresh and confirm settings load.
- Upload logo.
- Generate PDF with logo.
- Save preset rates.
- Refresh and confirm preset rates load.
- Add crew.
- Delete crew.
- Refresh and confirm crew list behavior.
- Change trade types.
- Refresh and confirm trade visibility.

## Profit Mode

- Enter cost rates.
- Verify revenue, cost, profit, and margin.
- Confirm profit information is not shown in customer-facing proposal.

## Persistence and Data Loss

- Create quote, refresh before save, document behavior.
- Create quote, save, refresh, confirm persistence.
- Simulate cloud save failure if possible.
- Test two browser tabs.
- Test two devices on same account.
- Clear localStorage and confirm cloud data still loads.
- Confirm device-local settings behavior is documented.

## Release Smoke Test

- Landing page loads.
- App page loads.
- Login works.
- Quote save works.
- Proposal link works.
- Customer approval works.
- Schedule save works.
- Payment save/load works.
- Refresh restores cloud data.
- No console errors in normal workflow.

