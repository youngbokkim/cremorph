-- CREHOONI reference photo library.
--
-- Replaces the previous "GitHub repo as a database" approach, where every
-- contributor needed a personal access token with write scope on the repo.
-- Contributions are now owned by an (anonymous) Supabase user and protected by
-- row level security.

create extension if not exists "vector" with schema extensions;

-- Community-contributed reference photos used to improve morph identification.
create table if not exists public.reference_photos (
  id uuid primary key default gen_random_uuid(),

  -- Free-text morph name exactly as the contributor typed it.
  display_name text not null check (
    length(trim(display_name)) between 1 and 60
  ),

  -- Resolved morph id: a built-in catalog id such as 'lilly-white', or a
  -- 'user-<slug>' id when the name is not recognised. Kept denormalised because
  -- the catalog itself lives in the client bundle, not the database.
  morph_id text not null check (length(morph_id) between 1 and 64),

  -- Object path inside the 'reference-photos' storage bucket.
  storage_path text not null unique,

  -- Colour fingerprint from ImageAnalysis, so the offline scorer can use
  -- community photos without downloading them first.
  signature jsonb,

  -- CLIP ViT-B/32 image embedding. Null until the photo has been indexed by the
  -- clip-embed edge function; identification falls back to `signature` then.
  embedding extensions.vector(512),

  -- Lets the client see indexing status without transferring the vector itself.
  has_embedding boolean generated always as (embedding is not null) stored,

  created_by uuid not null default auth.uid() references auth.users (id)
    on delete cascade,
  created_at timestamptz not null default now()
);

comment on table public.reference_photos is
  'Community reference photos that feed morph identification.';

create index if not exists reference_photos_morph_id_idx
  on public.reference_photos (morph_id);

create index if not exists reference_photos_created_at_idx
  on public.reference_photos (created_at desc);

create index if not exists reference_photos_created_by_idx
  on public.reference_photos (created_by);

-- Cosine-distance index for similarity search. `lists` is deliberately small:
-- the table is expected to hold thousands, not millions, of rows.
create index if not exists reference_photos_embedding_idx
  on public.reference_photos
  using ivfflat (embedding extensions.vector_cosine_ops)
  with (lists = 100);

-- CLIP embeddings for the 18 bundled catalog photos. Seeded once by
-- `supabase/scripts/seed_catalog_embeddings.mjs`; without these rows the
-- identification endpoint has nothing to compare an upload against.
create table if not exists public.morph_embeddings (
  morph_id text primary key,
  embedding extensions.vector(512) not null,
  source_path text not null,
  updated_at timestamptz not null default now()
);

comment on table public.morph_embeddings is
  'CLIP embeddings of the bundled catalog reference photos.';

alter table public.reference_photos enable row level security;
alter table public.morph_embeddings enable row level security;

-- The library is a shared public resource: anyone, signed in or not, may read
-- it. This is what makes the gallery work before the user has done anything.
drop policy if exists "reference photos are publicly readable"
  on public.reference_photos;
create policy "reference photos are publicly readable"
  on public.reference_photos
  for select
  to anon, authenticated
  using (true);

-- Contributors must be signed in (anonymous sign-in counts) and can only
-- attribute a row to themselves.
drop policy if exists "users insert their own reference photos"
  on public.reference_photos;
create policy "users insert their own reference photos"
  on public.reference_photos
  for insert
  to authenticated
  with check (created_by = auth.uid());

drop policy if exists "users update their own reference photos"
  on public.reference_photos;
create policy "users update their own reference photos"
  on public.reference_photos
  for update
  to authenticated
  using (created_by = auth.uid())
  with check (created_by = auth.uid());

drop policy if exists "users delete their own reference photos"
  on public.reference_photos;
create policy "users delete their own reference photos"
  on public.reference_photos
  for delete
  to authenticated
  using (created_by = auth.uid());

-- Catalog embeddings are readable by everyone but only writable with the
-- service role key, which bypasses RLS entirely — so no write policy exists.
drop policy if exists "catalog embeddings are publicly readable"
  on public.morph_embeddings;
create policy "catalog embeddings are publicly readable"
  on public.morph_embeddings
  for select
  to anon, authenticated
  using (true);
