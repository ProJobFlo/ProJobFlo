-- ProJobFlo Supabase Storage Policy Deployment
-- Production Security Sprint: Storage Policy Hardening
-- Date: 2026-07-13
--
-- Purpose:
-- - Preserve current app.html Storage assumptions.
-- - Allow valid job photos at:         job-photos/{auth.uid()}/rooms/{folder}/{file}
-- - Allow valid contractor logos at:   contractor-logos/{auth.uid()}/company-logo-{timestamp}.{ext}
-- - Reject traversal-shaped or normalized traversal-result paths.
-- - Reject invalid contractor-logos paths such as {auth.uid()}/rooms/...
-- - Enforce owner namespace checks at the Storage policy layer.
--
-- IMPORTANT:
-- - Do not run the rollback section unless reverting this deployment.
-- - Review existing policies before deployment.
-- - Manually remove known invalid contractor-logos test artifact before deployment if still present:
--   contractor-logos/787d547e-51dc-42e8-9874-90557a0a73c6/rooms/photo-delete-smoke-20260712-233006-be31261c-policy/wrong-bucket.png

-- =========================================================
-- SECTION 1: PREFLIGHT / CURRENT POLICY REVIEW
-- =========================================================

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

-- Existing non-canonical objects that should be manually reviewed before deploying.
-- Expected after cleanup: zero rows for contractor-logos paths under /rooms/.
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

-- Existing job photo paths outside the expected app namespace.
-- Expected: zero rows, or manually reviewed legacy rows.
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

-- Existing contractor logo paths outside the expected app namespace.
-- Expected: zero rows, or manually reviewed legacy rows.
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

-- =========================================================
-- SECTION 2: DEPLOY HARDENED POLICIES
-- =========================================================

begin;

-- Replace prior ProJobFlo hardening policies only.
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

-- Bucket-specific owner policies: job-photos.
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

-- Bucket-specific owner policies: contractor-logos.
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

-- Restrictive path validation policies.
-- These are ANDed with permissive policies and protect these two buckets even if older broad policies still exist.
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

-- =========================================================
-- SECTION 3: POST-DEPLOY VALIDATION SQL
-- =========================================================

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

-- Expected: 12 rows.
select count(*) as projobflo_storage_policy_count
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname like 'projobflo_%';

-- Expected: zero rows after manual cleanup.
select
  bucket_id,
  name,
  created_at,
  updated_at
from storage.objects
where bucket_id = 'contractor-logos'
  and (storage.foldername(name))[2] = 'rooms'
order by created_at desc;

-- Expected: zero rows, unless manually reviewed legacy objects remain.
select
  bucket_id,
  name,
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

-- Expected: zero rows, unless manually reviewed legacy objects remain.
select
  bucket_id,
  name,
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

-- =========================================================
-- SECTION 4: ROLLBACK SQL
-- =========================================================
-- Run this section only if the deployment breaks valid app uploads/deletes.
-- Rollback removes the ProJobFlo hardening policies created above.
-- Restore previous broad policies from the dashboard backup if necessary.

/*
begin;

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

commit;
*/
