-- Storage bucket for community reference photos.
--
-- Objects are laid out as `<user id>/<uuid>.jpg`. Putting the owner's id in the
-- first path segment lets the delete policy be a simple prefix check, which is
-- the pattern Supabase's own storage examples use.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'reference-photos',
  'reference-photos',
  true,
  5242880, -- 5 MB; uploads are downscaled to 720px client-side first
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "reference photos are publicly viewable" on storage.objects;
create policy "reference photos are publicly viewable"
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'reference-photos');

-- The uploader must own the folder they are writing into.
drop policy if exists "users upload into their own folder" on storage.objects;
create policy "users upload into their own folder"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'reference-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users delete from their own folder" on storage.objects;
create policy "users delete from their own folder"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'reference-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
