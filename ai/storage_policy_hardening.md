# Supabase Storage Policy Hardening

Production Security Sprint
Review date: 2026-07-13

Scope:

- `job-photos`
- `contractor-logos`

No application code was changed. This document generates SQL and deployment guidance only.

## Current Policy Review

Exact Storage policy definitions are not exposed through the authenticated client. Attempts to query `pg_policies`, `information_schema.policies`, and `storage.objects` through PostgREST returned schema-cache errors because those system/storage schemas are not available through the public REST surface.

Current live behavior was reviewed through authenticated Storage API probes using the beta test account.

Observed user ID:

- `787d547e-51dc-42e8-9874-90557a0a73c6`

Observed behavior:

| Probe | Result | Interpretation |
|---|---|---|
| Upload/delete `job-photos/{user_id}/rooms/...` | Passed | Normal app photo path works. |
| Upload `job-photos/not-{user_id}/rooms/...` | Rejected | Current policy appears to enforce first path segment ownership for `job-photos`. |
| Upload traversal-style `job-photos/{user_id}/rooms/../...` | Accepted after path normalization | Current live behavior permits traversal-shaped request keys. Supabase normalized the final object name, but policy should not rely on this. |
| List `job-photos/{user_id}` | Allowed | Needed for owner-managed photo visibility and support checks. |
| List `job-photos/not-{user_id}` | Empty | No cross-user listing observed. |
| Upload `contractor-logos/{user_id}/rooms/...` | Accepted | Current policy is too broad for the logo bucket. App only needs `{user_id}/company-logo-...`. |
| Delete the wrong-bucket `contractor-logos/{user_id}/rooms/...` test object as authenticated user | Did not remove object | Current policy appears inconsistent: upload allowed an invalid logo path but delete did not remove it. Manual cleanup is required. |
| List `contractor-logos/{user_id}` | Allowed | Existing real logo objects and the invalid `rooms` prefix were visible to the owner. |

Remaining manual cleanup from validation:

- Bucket: `contractor-logos`
- Path: `787d547e-51dc-42e8-9874-90557a0a73c6/rooms/photo-delete-smoke-20260712-233006-be31261c-policy/wrong-bucket.png`

## App Assumptions To Preserve

`app.html` currently writes:

- Room photos and Project Photo Timeline photos:
  - Bucket: `job-photos`
  - Path: `{currentUser.id}/rooms/{room_id_or_timeline_stage}/{generated_file_name}`
- Contractor logos:
  - Bucket: `contractor-logos`
  - Path: `{currentUser.id}/company-logo-{timestamp}.{ext}`

`app.html` currently rejects destructive photo deletes unless:

- bucket is exactly `job-photos`
- path starts with `{currentUser.id}/rooms/`
- path does not start with `/`
- path does not contain `..`
- path does not contain backslashes

Storage policies should enforce the same assumptions server-side.

## Findings

### 1. Current Storage RLS Policies

Blocked from exact client-side introspection. Review exact policy names and definitions in Supabase SQL Editor with:

```sql
select
  policyname,
  cmd,
  permissive,
  roles,
  qual,
  with_check
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
order by policyname;
```

### 2. Traversal-Style Keys

Traversal-style keys should be rejected by policy as defense-in-depth.

Important nuance: Supabase may normalize path traversal before the object row is evaluated by RLS. Therefore, policies should enforce a strict final object shape, not merely check for `..`.

For `job-photos`, the final object shape must be:

```text
{auth.uid()}/rooms/{room_or_timeline_folder}/{file_name}
```

For `contractor-logos`, the final object shape must be:

```text
{auth.uid()}/company-logo-{file_name}
```

### 3. Object Names

Object names should be canonical and bucket-specific.

Recommended generic rejects:

- empty object name
- leading `/`
- backslash
- `..`
- double slash
- missing file name

### 4. Bucket-Specific Prefixes

Yes, bucket-specific prefixes should be enforced.

- `job-photos`: require first folder `auth.uid()` and second folder `rooms`.
- `contractor-logos`: require first folder `auth.uid()`, no second folder, and file name starts with `company-logo-`.

### 5. Upload Outside Namespace

Live `job-photos` wrong-user upload was rejected.

Live `contractor-logos` accepted a path under the authenticated user's namespace but outside the app's expected logo prefix. This should be tightened.

### 6. Delete Another User Namespace

No cross-user delete was observed or needed. Policies should explicitly restrict delete to the authenticated user's allowed namespace.

### 7. Signed URLs

`job-photos` uses signed URLs for private project photos. That is appropriate if select/list policies are owner-only.

`contractor-logos` uses `getPublicUrl()`, so logos are effectively public if the bucket is public. That matches current app behavior because proposals/PDFs need to render the logo without a signed URL workflow. If private logos become required, that would need an app change and is out of scope for this sprint.

### 8. Match With `app.html`

The recommended `job-photos` rules match the current upload/delete path assumptions in `app.html`.

The recommended `contractor-logos` rules match the current logo upload path in `app.html` and would block the invalid `contractor-logos/{user_id}/rooms/...` path found during validation.

## Recommended Policy SQL

Run this only after reviewing existing Storage policies. The restrictive policies below are designed to harden the two ProJobFlo buckets even if older broad permissive policies still exist, because restrictive policies are ANDed with permissive policies.

The permissive policies below provide the intended allow rules for these buckets. Existing broad permissive policies should still be removed after review to reduce confusion.

```sql
begin;

-- Existing hardening policies can be replaced safely.
drop policy if exists "projobflo_job_photos_select_own" on storage.objects;
drop policy if exists "projobflo_job_photos_insert_own" on storage.objects;
drop policy if exists "projobflo_job_photos_update_own" on storage.objects;
drop policy if exists "projobflo_job_photos_delete_own" on storage.objects;

drop policy if exists "projobflo_contractor_logos_select_own" on storage.objects;
drop policy if exists "projobflo_contractor_logos_insert_own" on storage.objects;
drop policy if exists "projobflo_contractor_logos_update_own" on storage.objects;
drop policy if exists "projobflo_contractor_logos_delete_own" on storage.objects;

drop policy if exists "projobflo_restrict_photo_logo_select_shape" on storage.objects;
drop policy if exists "projobflo_restrict_photo_logo_insert_shape" on storage.objects;
drop policy if exists "projobflo_restrict_photo_logo_update_shape" on storage.objects;
drop policy if exists "projobflo_restrict_photo_logo_delete_shape" on storage.objects;

-- Permissive owner policies for job photos.
create policy "projobflo_job_photos_select_own"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'job-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'rooms'
);

create policy "projobflo_job_photos_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'job-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'rooms'
);

create policy "projobflo_job_photos_update_own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'job-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'rooms'
)
with check (
  bucket_id = 'job-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'rooms'
);

create policy "projobflo_job_photos_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'job-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'rooms'
);

-- Permissive owner policies for contractor logos.
create policy "projobflo_contractor_logos_select_own"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'contractor-logos'
  and (storage.foldername(name))[1] = auth.uid()::text
  and coalesce(array_length(storage.foldername(name), 1), 0) = 1
  and storage.filename(name) like 'company-logo-%'
);

create policy "projobflo_contractor_logos_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'contractor-logos'
  and (storage.foldername(name))[1] = auth.uid()::text
  and coalesce(array_length(storage.foldername(name), 1), 0) = 1
  and storage.filename(name) like 'company-logo-%'
);

create policy "projobflo_contractor_logos_update_own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'contractor-logos'
  and (storage.foldername(name))[1] = auth.uid()::text
  and coalesce(array_length(storage.foldername(name), 1), 0) = 1
  and storage.filename(name) like 'company-logo-%'
)
with check (
  bucket_id = 'contractor-logos'
  and (storage.foldername(name))[1] = auth.uid()::text
  and coalesce(array_length(storage.foldername(name), 1), 0) = 1
  and storage.filename(name) like 'company-logo-%'
);

create policy "projobflo_contractor_logos_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'contractor-logos'
  and (storage.foldername(name))[1] = auth.uid()::text
  and coalesce(array_length(storage.foldername(name), 1), 0) = 1
  and storage.filename(name) like 'company-logo-%'
);

-- Restrictive shape policies for both buckets.
-- These harden bucket paths even if older broad permissive policies still exist.
create policy "projobflo_restrict_photo_logo_select_shape"
on storage.objects
as restrictive
for select
to authenticated
using (
  bucket_id not in ('job-photos', 'contractor-logos')
  or (
    bucket_id = 'job-photos'
    and name <> ''
    and name not like '/%'
    and name not like '%//%'
    and name not like '%..%'
    and position(chr(92) in name) = 0
    and storage.filename(name) <> ''
    and (storage.foldername(name))[1] = auth.uid()::text
    and (storage.foldername(name))[2] = 'rooms'
    and coalesce(array_length(storage.foldername(name), 1), 0) >= 3
  )
  or (
    bucket_id = 'contractor-logos'
    and name <> ''
    and name not like '/%'
    and name not like '%//%'
    and name not like '%..%'
    and position(chr(92) in name) = 0
    and storage.filename(name) <> ''
    and (storage.foldername(name))[1] = auth.uid()::text
    and coalesce(array_length(storage.foldername(name), 1), 0) = 1
    and storage.filename(name) like 'company-logo-%'
  )
);

create policy "projobflo_restrict_photo_logo_insert_shape"
on storage.objects
as restrictive
for insert
to authenticated
with check (
  bucket_id not in ('job-photos', 'contractor-logos')
  or (
    bucket_id = 'job-photos'
    and name <> ''
    and name not like '/%'
    and name not like '%//%'
    and name not like '%..%'
    and position(chr(92) in name) = 0
    and storage.filename(name) <> ''
    and (storage.foldername(name))[1] = auth.uid()::text
    and (storage.foldername(name))[2] = 'rooms'
    and coalesce(array_length(storage.foldername(name), 1), 0) >= 3
  )
  or (
    bucket_id = 'contractor-logos'
    and name <> ''
    and name not like '/%'
    and name not like '%//%'
    and name not like '%..%'
    and position(chr(92) in name) = 0
    and storage.filename(name) <> ''
    and (storage.foldername(name))[1] = auth.uid()::text
    and coalesce(array_length(storage.foldername(name), 1), 0) = 1
    and storage.filename(name) like 'company-logo-%'
  )
);

create policy "projobflo_restrict_photo_logo_update_shape"
on storage.objects
as restrictive
for update
to authenticated
using (
  bucket_id not in ('job-photos', 'contractor-logos')
  or (
    bucket_id = 'job-photos'
    and name <> ''
    and name not like '/%'
    and name not like '%//%'
    and name not like '%..%'
    and position(chr(92) in name) = 0
    and storage.filename(name) <> ''
    and (storage.foldername(name))[1] = auth.uid()::text
    and (storage.foldername(name))[2] = 'rooms'
    and coalesce(array_length(storage.foldername(name), 1), 0) >= 3
  )
  or (
    bucket_id = 'contractor-logos'
    and name <> ''
    and name not like '/%'
    and name not like '%//%'
    and name not like '%..%'
    and position(chr(92) in name) = 0
    and storage.filename(name) <> ''
    and (storage.foldername(name))[1] = auth.uid()::text
    and coalesce(array_length(storage.foldername(name), 1), 0) = 1
    and storage.filename(name) like 'company-logo-%'
  )
)
with check (
  bucket_id not in ('job-photos', 'contractor-logos')
  or (
    bucket_id = 'job-photos'
    and name <> ''
    and name not like '/%'
    and name not like '%//%'
    and name not like '%..%'
    and position(chr(92) in name) = 0
    and storage.filename(name) <> ''
    and (storage.foldername(name))[1] = auth.uid()::text
    and (storage.foldername(name))[2] = 'rooms'
    and coalesce(array_length(storage.foldername(name), 1), 0) >= 3
  )
  or (
    bucket_id = 'contractor-logos'
    and name <> ''
    and name not like '/%'
    and name not like '%//%'
    and name not like '%..%'
    and position(chr(92) in name) = 0
    and storage.filename(name) <> ''
    and (storage.foldername(name))[1] = auth.uid()::text
    and coalesce(array_length(storage.foldername(name), 1), 0) = 1
    and storage.filename(name) like 'company-logo-%'
  )
);

create policy "projobflo_restrict_photo_logo_delete_shape"
on storage.objects
as restrictive
for delete
to authenticated
using (
  bucket_id not in ('job-photos', 'contractor-logos')
  or (
    bucket_id = 'job-photos'
    and name <> ''
    and name not like '/%'
    and name not like '%//%'
    and name not like '%..%'
    and position(chr(92) in name) = 0
    and storage.filename(name) <> ''
    and (storage.foldername(name))[1] = auth.uid()::text
    and (storage.foldername(name))[2] = 'rooms'
    and coalesce(array_length(storage.foldername(name), 1), 0) >= 3
  )
  or (
    bucket_id = 'contractor-logos'
    and name <> ''
    and name not like '/%'
    and name not like '%//%'
    and name not like '%..%'
    and position(chr(92) in name) = 0
    and storage.filename(name) <> ''
    and (storage.foldername(name))[1] = auth.uid()::text
    and coalesce(array_length(storage.foldername(name), 1), 0) = 1
    and storage.filename(name) like 'company-logo-%'
  )
);

commit;
```

## Existing Broad Policy Review SQL

Run this before deployment. If broad policies already grant access to `job-photos` or `contractor-logos`, leave the restrictive policies above in place and remove or narrow the broad policies after manual review.

```sql
select
  policyname,
  cmd,
  permissive,
  roles,
  qual,
  with_check
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and (
    qual ilike '%job-photos%'
    or qual ilike '%contractor-logos%'
    or with_check ilike '%job-photos%'
    or with_check ilike '%contractor-logos%'
  )
order by policyname;
```

Do not automatically drop unknown policies. For each old policy, confirm what it protects and whether it is still needed.

## Migration Order

1. Back up or screenshot current Storage policies from the Supabase dashboard.
2. Run the exact policy review SQL above.
3. Confirm no production process writes outside these app paths:
   - `job-photos/{user_id}/rooms/...`
   - `contractor-logos/{user_id}/company-logo-...`
4. Manually remove the validation artifact in `contractor-logos`:
   - `787d547e-51dc-42e8-9874-90557a0a73c6/rooms/photo-delete-smoke-20260712-233006-be31261c-policy/wrong-bucket.png`
5. Run the recommended policy SQL.
6. Re-run the policy review SQL and confirm new policies exist.
7. Run the validation checklist below.
8. Only after validation, remove or narrow old broad policies that are no longer needed.

## Rollback Procedure

Rollback should restore the previous policy set, not delete user data.

1. Capture any Storage errors reported by the app.
2. In Supabase SQL Editor, drop the new hardening policies:
   ```sql
   drop policy if exists "projobflo_job_photos_select_own" on storage.objects;
   drop policy if exists "projobflo_job_photos_insert_own" on storage.objects;
   drop policy if exists "projobflo_job_photos_update_own" on storage.objects;
   drop policy if exists "projobflo_job_photos_delete_own" on storage.objects;

   drop policy if exists "projobflo_contractor_logos_select_own" on storage.objects;
   drop policy if exists "projobflo_contractor_logos_insert_own" on storage.objects;
   drop policy if exists "projobflo_contractor_logos_update_own" on storage.objects;
   drop policy if exists "projobflo_contractor_logos_delete_own" on storage.objects;

   drop policy if exists "projobflo_restrict_photo_logo_select_shape" on storage.objects;
   drop policy if exists "projobflo_restrict_photo_logo_insert_shape" on storage.objects;
   drop policy if exists "projobflo_restrict_photo_logo_update_shape" on storage.objects;
   drop policy if exists "projobflo_restrict_photo_logo_delete_shape" on storage.objects;
   ```
3. Restore the prior policies from the captured dashboard copy if needed.
4. Run a photo upload/delete smoke test.
5. Do not roll back by changing app code unless a separate app bug is proven.

## Validation Checklist

Run with a confirmed test account and disposable objects only.

Expected PASS:

1. Upload to `job-photos/{user_id}/rooms/{test_folder}/{file}` succeeds.
2. Create signed URL for that `job-photos` object succeeds.
3. Delete that `job-photos` object succeeds.
4. Upload to `contractor-logos/{user_id}/company-logo-{timestamp}.png` succeeds.
5. Public logo URL still works if the bucket remains public.
6. Delete/update own contractor logo succeeds only for canonical logo paths.

Expected REJECT:

1. Upload to `job-photos/{other_user_id}/rooms/...`.
2. Upload to `job-photos/{user_id}/not-rooms/...`.
3. Upload to `job-photos/{user_id}/rooms/../...`.
4. Upload to `job-photos/{user_id}/rooms/...` with a backslash in the path.
5. Upload to `contractor-logos/{user_id}/rooms/...`.
6. Upload to `contractor-logos/{user_id}/../company-logo-test.png`.
7. Delete any `job-photos` or `contractor-logos` object outside the authenticated user's allowed namespace.

App smoke tests after policy deployment:

1. Room photo upload works.
2. Room photo delete removes metadata and Storage object.
3. Project Photo Timeline upload works.
4. Project Photo Timeline delete removes metadata and Storage object.
5. Contractor logo upload works.
6. Existing proposal/PDF logo rendering still works.
7. No app-specific console errors.

## Remaining Limitations

1. Exact current policy definitions require Supabase SQL Editor/dashboard access.
2. Public logo URLs remain public by current app design.
3. Policies cannot reliably inspect the pre-normalized HTTP request path if Supabase normalizes before RLS. Strict final object shape is the practical control.
4. These policies do not solve orphaned photo metadata; they only prevent unsafe object access patterns.
5. If old broad permissive policies remain, the restrictive policies should still harden these buckets for authenticated users, but old policies should be removed or narrowed for clarity.
