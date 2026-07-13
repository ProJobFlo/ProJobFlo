# Photo Storage Integrity

Audit date: 2026-07-13

Scope: Reliability Sprint Phase 4, room photos in Quote Builder and Project Photo Timeline photos in the Job Command Center.

## Current Architecture

Storage bucket:

- `job-photos`

Allowed cloud object namespace:

- `{authenticated_user_id}/rooms/{room_id_or_timeline_stage}/{generated_file_name}`

The client must not delete objects outside the authenticated user's `user_id/rooms/` prefix.

## Metadata Models

Room photos are stored inside `quotes.quote_data.roomPhotos` and loaded into `roomPhotos` while editing a quote.

Project Photo Timeline photos are stored inside `quotes.quote_data.projectPhotoTimeline` grouped by stage:

- `estimate`
- `before-demo`
- `installation-progress`
- `finished-project`

Cloud-backed photo metadata should retain:

- `id`
- `cloudPath`
- `fileName`
- `category`
- `caption` when available
- `customerId`
- `quoteId`
- `jobId`
- `timelineStage` or room ID context
- `uploadedAt`
- `source`

Legacy photos may lack `id` or `cloudPath`. The app must not infer a destructive storage path from a signed URL, blob URL, filename, caption, or user-visible image URL.

## Upload Flow

Room photos:

1. Validate login and online state.
2. Upload the image to `job-photos`.
3. Add local metadata to the active quote.
4. Queue quote autosave.

Remaining risk: room-photo upload can still leave an orphan if upload succeeds and the later quote autosave fails.

Project Photo Timeline photos:

1. Validate login and online state.
2. Upload the image to `job-photos`.
3. Build proposed timeline metadata.
4. Save `quotes.quote_data.projectPhotoTimeline`.
5. Only then render the updated Job File.

If Project Photo Timeline metadata save fails, the app now attempts to delete the newly uploaded storage objects to reduce orphan risk.

## Delete Flow

Room photos:

1. Identify the exact room photo by stable `id`, `cloudPath`, or existing metadata identity.
2. Confirm with the user.
3. If cloud-backed and `cloudPath` exists, delete the `job-photos` object.
4. Save updated `quotes.quote_data.roomPhotos`.
5. Only after successful cloud operations update local state and UI.

Project Photo Timeline photos:

1. Identify the exact stage and photo.
2. Reject legacy room-photo echoes displayed in the timeline.
3. Confirm with the user.
4. If `cloudPath` exists, delete the `job-photos` object.
5. Save updated `quotes.quote_data.projectPhotoTimeline`.
6. Update the Job File and close or advance the lightbox safely.

Legacy/local-only photos without `cloudPath`:

- The app does not guess a storage object.
- The app can remove metadata/local state only.
- The user is told that the photo has no saved cloud path.

## Failure Handling

If Storage deletion fails:

- Metadata is not removed.
- Local UI state is not changed.
- The photo remains visible.
- A clear error toast is shown.

If metadata save fails after Storage deletion:

- The app does not show success.
- Local UI state remains at the last known persisted state.
- A warning/error tells the operator that storage cleanup may need review.
- A safe diagnostic is recorded without tokens, signatures, customer payloads, or photo data.

## Security Requirements

The client delete helper allowlists:

- bucket: `job-photos`
- path prefix: `{currentUser.id}/rooms/`

It rejects:

- empty paths
- paths starting with `/`
- paths containing `..`
- paths containing backslashes
- buckets other than `job-photos`
- paths outside the authenticated user's namespace

Supabase Storage policies should also enforce owner-only delete access. Client-side checks are defense-in-depth, not a replacement for RLS/Storage policies.

## Orphan Cleanup Strategy

Do not automatically mass-delete production storage.

Dry-run process:

1. Export affected `quotes.id`, `quotes.user_id`, and `quotes.quote_data`.
2. Build a set of all `cloudPath` values found in `quote_data.roomPhotos` and `quote_data.projectPhotoTimeline`.
3. List storage objects under each user's `job-photos/{user_id}/rooms/` prefix.
4. Compare storage paths to metadata paths.
5. Flag storage objects with no metadata reference as possible orphans.
6. Flag metadata paths with no storage object as possible broken references.
7. Manually review by user, quote, timestamp, and project context.
8. Keep a retention window, recommended 30 days for beta, before destructive cleanup.
9. Export affected rows and object lists before cleanup.

Rollback limitation:

- Deleting a storage object cannot be undone from the app. Recovery depends on Supabase storage backups or an external backup.

## Remaining Limitations

1. Room-photo upload still relies on later quote autosave, so upload success plus autosave failure can leave an orphan.
2. Existing legacy photos without `cloudPath` cannot have their original storage object deleted automatically.
3. Photo metadata lives inside quote JSON, so concurrent edits across tabs can still race.
4. There is no server-side photo metadata table or transaction tying storage delete and metadata update together.
5. Storage policy correctness must be confirmed in the Supabase dashboard.
