-- Similarity search used by morph identification.

-- Best cosine similarity per morph, considering both the bundled catalog photos
-- and every community reference photo attached to that morph.
--
-- The web version did this in the browser: embed all catalog images with CLIP,
-- then take `Math.max(cosine(query, gallery))` per morph. Doing it in Postgres
-- means a phone never downloads an 80MB model or the whole photo library.
create or replace function public.match_morphs(
  query_embedding extensions.vector(512),
  match_count integer default 12
)
returns table (
  morph_id text,
  similarity double precision,
  photo_count integer,
  is_community boolean
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  with catalog_hits as (
    select
      m.morph_id,
      -- pgvector's `<=>` is cosine distance, so 1 - distance is similarity.
      1 - (m.embedding <=> query_embedding) as similarity,
      0 as photo_count,
      false as is_community
    from public.morph_embeddings m
  ),
  community_hits as (
    select
      p.morph_id,
      max(1 - (p.embedding <=> query_embedding)) as similarity,
      count(*)::integer as photo_count,
      true as is_community
    from public.reference_photos p
    where p.embedding is not null
    group by p.morph_id
  ),
  combined as (
    select * from catalog_hits
    union all
    select * from community_hits
  )
  select
    c.morph_id,
    max(c.similarity) as similarity,
    coalesce(sum(c.photo_count), 0)::integer as photo_count,
    bool_and(c.is_community) as is_community
  from combined c
  group by c.morph_id
  order by similarity desc
  limit greatest(match_count, 1);
$$;

comment on function public.match_morphs is
  'Ranks morphs by best CLIP cosine similarity to a query embedding.';

grant execute on function public.match_morphs(extensions.vector, integer)
  to anon, authenticated;

-- Reference photos still awaiting a CLIP embedding. The clip-embed function
-- walks this to backfill, so a photo contributed while the function was down
-- gets indexed on the next run.
create or replace view public.unindexed_reference_photos
with (security_invoker = true)
as
  select id, morph_id, storage_path, created_at
  from public.reference_photos
  where embedding is null
  order by created_at;

comment on view public.unindexed_reference_photos is
  'Reference photos that have no CLIP embedding yet.';
