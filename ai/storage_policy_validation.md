# Storage Policy Deployment And Validation

Date: 2026-07-13

SQL artifact:

- `ai/storage_policy_deployment.sql`

Do not modify `app.html` for this deployment. The policy script is designed to preserve current app behavior.

## Deployment Goal

Harden Supabase Storage policies for:

- `job-photos`
- `contractor-logos`

The deployment should:

- preserve valid `job-photos/{user_id}/rooms/...` uploads/deletes
- preserve valid `contractor-logos/{user_id}/company-logo-...` uploads
- reject traversal-shaped and traversal-normalized paths
- reject invalid `contractor-logos/{user_id}/rooms/...` paths
- enforce owner namespace checks
- require no application changes

## Pre-Deployment Dashboard Steps

1. Open the live beta Supabase project.
2. Go to Storage.
3. Inspect both buckets:
   - `job-photos`
   - `contractor-logos`
4. Confirm both buckets exist.
5. Manually remove this known disposable validation artifact if it still exists:
   - bucket: `contractor-logos`
   - path: `787d547e-51dc-42e8-9874-90557a0a73c6/rooms/photo-delete-smoke-20260712-233006-be31261c-policy/wrong-bucket.png`
6. Go to SQL Editor.
7. Open `ai/storage_policy_deployment.sql`.
8. Run Section 1 only first.

## Preflight SQL

Run the policy inventory query:

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

Expected:

- Existing Storage policies are visible.
- No automatic action is taken.

Run the ProJobFlo policy filter:

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

Expected:

- Any current broad policies are visible for manual review.
- Do not drop unknown policies automatically.

Check for invalid contractor-logo paths:

```sql
select
  bucket_id,
  name,
  owner,
  created_at,
  updated_at
from storage.objects
where bucket_id = 'contractor-logos'
  and (storage.foldername(name))[2] = 'rooms'
order by created_at desc;
```

Expected:

- Zero rows after manual cleanup.
- If rows appear, review and remove only known invalid test artifacts.

Check for invalid job photo paths:

```sql
select
  bucket_id,
  name,
  owner,
  created_at,
  updated_at
from storage.objects
where bucket_id = 'job-photos'
  and not (
    name <> ''
    and name not like '/%'
    and name not like '%//%'
    and name not like '%..%'
    and position(chr(92) in name) = 0
    and storage.filename(name) <> ''
    and (storage.foldername(name))[2] = 'rooms'
    and coalesce(array_length(storage.foldername(name), 1), 0) >= 3
  )
order by created_at desc;
```

Expected:

- Zero rows, or manually reviewed legacy rows.
- Do not delete production customer objects without review.

Check for invalid contractor logo paths:

```sql
select
  bucket_id,
  name,
  owner,
  created_at,
  updated_at
from storage.objects
where bucket_id = 'contractor-logos'
  and not (
    name <> ''
    and name not like '/%'
    and name not like '%//%'
    and name not like '%..%'
    and position(chr(92) in name) = 0
    and storage.filename(name) <> ''
    and coalesce(array_length(storage.foldername(name), 1), 0) = 1
    and storage.filename(name) like 'company-logo-%'
  )
order by created_at desc;
```

Expected:

- Zero rows, or manually reviewed legacy rows.

## Deployment Steps

1. Confirm preflight results are understood.
2. Confirm no production workflow writes outside:
   - `job-photos/{user_id}/rooms/...`
   - `contractor-logos/{user_id}/company-logo-...`
3. In SQL Editor, run Section 2 from `ai/storage_policy_deployment.sql`.
4. Confirm the transaction completes without error.
5. Run Section 3 validation SQL.

## Post-Deployment Validation SQL

Confirm policies exist:

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
  and policyname in (
    'projobflo_job_photos_select_own',
    'projobflo_job_photos_insert_own',
    'projobflo_job_photos_update_own',
    'projobflo_job_photos_delete_own',
    'projobflo_contractor_logos_select_own',
    'projobflo_contractor_logos_insert_own',
    'projobflo_contractor_logos_update_own',
    'projobflo_contractor_logos_delete_own',
    'projobflo_restrict_photo_logo_select_shape',
    'projobflo_restrict_photo_logo_insert_shape',
    'projobflo_restrict_photo_logo_update_shape',
    'projobflo_restrict_photo_logo_delete_shape'
  )
order by policyname;
```

Expected:

- 12 rows.
- Four restrictive shape policies.
- Eight bucket-specific owner policies.

Confirm count:

```sql
select count(*) as projobflo_storage_policy_count
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname like 'projobflo_%';
```

Expected:

- At least 12 rows.
- If more than 12 rows exist, review older `projobflo_%` policy names.

## Live Storage Validation Commands

Use a confirmed test account and disposable files only.

Expected PASS:

1. Upload a tiny image to:
   - `job-photos/{user_id}/rooms/policy-validation/pass-job-photo.png`
2. Create a signed URL for that object.
3. Delete that object.
4. Upload a tiny image to:
   - `contractor-logos/{user_id}/company-logo-policy-validation.png`
5. Confirm the logo object URL still renders according to current bucket behavior.
6. Delete that disposable logo if policy allows owner delete for canonical logo paths.

Expected REJECT:

1. `job-photos/{other_user_id}/rooms/policy-validation/reject.png`
2. `job-photos/{user_id}/not-rooms/policy-validation/reject.png`
3. `job-photos/{user_id}/rooms/../policy-validation/reject.png`
4. `job-photos/{user_id}/rooms/policy-validation\\reject.png`
5. `contractor-logos/{user_id}/rooms/policy-validation/reject.png`
6. `contractor-logos/{user_id}/../company-logo-policy-validation.png`
7. Any delete outside the authenticated user's namespace.

Record:

- timestamp
- user ID used
- object paths created
- object paths rejected
- cleanup result

## App Smoke Test After Deployment

Run these against the app after policy deployment:

1. Log in with confirmed beta test account.
2. Create or open a disposable quote.
3. Upload a room photo.
4. Refresh and confirm it still appears.
5. Delete the room photo.
6. Refresh and confirm metadata and Storage object are gone.
7. Open a scheduled disposable job.
8. Upload one Project Photo Timeline image.
9. Refresh and confirm it appears.
10. Delete it from the thumbnail or lightbox.
11. Refresh and confirm metadata and Storage object are gone.
12. Upload a contractor logo from Settings.
13. Confirm proposal/PDF logo rendering still works.
14. Confirm no app-specific console errors.

## Rollback Steps

Rollback should remove only the new ProJobFlo hardening policies unless Hayden also intentionally changed old policies.

Run the rollback block from Section 4 in:

- `ai/storage_policy_deployment.sql`

Then:

1. Restore prior broad policies from the pre-deployment dashboard backup if needed.
2. Re-test room photo upload.
3. Re-test Project Photo Timeline upload.
4. Re-test contractor logo upload.
5. Document why rollback was needed.

Do not roll back by editing app code unless a separate application bug is proven.

## Notes

- Policies may not see the pre-normalized HTTP request path if Supabase normalizes `..` before RLS evaluation.
- The deployed policy still rejects the normalized result because it enforces the final object shape.
- Public logo URLs remain part of current app behavior.
- This deployment does not implement orphan cleanup. It only prevents unsafe future object paths.
