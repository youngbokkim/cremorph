/**
 * CLIP image embedding + morph similarity search.
 *
 * This is the server half of the hybrid identification strategy. The Flutter app
 * always computes an on-device colour signature, which is enough to rank morphs
 * offline. When this function is deployed the app additionally gets a real CLIP
 * ViT-B/32 embedding — the same model the original browser version ran in WASM —
 * without a phone downloading 80MB of weights.
 *
 * Actions
 *   identify  { image: base64 }                  -> ranked morph similarities
 *   index     { photoId: uuid }                  -> stores an embedding for one
 *                                                   community reference photo
 *   backfill  { limit?: number }                 -> indexes pending photos
 *   catalog   { morphId, imageBase64 }           -> seeds a catalog embedding
 *                                                   (service role key required)
 *
 * Required secrets:
 *   HF_TOKEN  Hugging Face access token with inference permission.
 *             supabase secrets set HF_TOKEN=hf_xxx
 */

import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';

const MODEL_ID = 'openai/clip-vit-base-patch32';
const HF_ENDPOINT =
  `https://router.huggingface.co/hf-inference/models/${MODEL_ID}`;
const EMBEDDING_DIM = 512;
const BUCKET = 'reference-photos';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

function fail(message: string, status = 400): Response {
  return json({ error: message }, status);
}

/**
 * Averages token embeddings into a single vector when the provider returns a
 * sequence rather than a pooled vector, mirroring `tensorToEmbed()` in the
 * original `js/vision.js`.
 */
function pool(raw: unknown): number[] {
  if (!Array.isArray(raw)) {
    throw new Error('임베딩 응답 형식을 이해할 수 없습니다');
  }

  // Already a flat vector.
  if (typeof raw[0] === 'number') {
    const flat = raw as number[];
    if (flat.length !== EMBEDDING_DIM) {
      throw new Error(`임베딩 차원이 ${flat.length}입니다 (${EMBEDDING_DIM} 필요)`);
    }
    return flat;
  }

  // [batch][dim] or [batch][tokens][dim].
  const first = raw[0];
  if (Array.isArray(first) && typeof first[0] === 'number') {
    return pool(first);
  }
  if (Array.isArray(first)) {
    const tokens = first as number[][];
    const depth = tokens[0].length;
    const out = new Array<number>(depth).fill(0);
    for (const token of tokens) {
      for (let i = 0; i < depth; i++) out[i] += token[i];
    }
    return out.map((v) => v / tokens.length);
  }
  throw new Error('임베딩 응답 형식을 이해할 수 없습니다');
}

/** L2-normalises so cosine similarity reduces to a dot product. */
function normalise(vector: number[]): number[] {
  let norm = 0;
  for (const v of vector) norm += v * v;
  norm = Math.sqrt(norm) || 1;
  return vector.map((v) => v / norm);
}

async function embedImage(bytes: Uint8Array): Promise<number[]> {
  const token = Deno.env.get('HF_TOKEN');
  if (!token) {
    throw new Error(
      'HF_TOKEN 시크릿이 설정되지 않았습니다. `supabase secrets set HF_TOKEN=...`',
    );
  }

  const response = await fetch(HF_ENDPOINT, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/octet-stream',
      // Cold starts on the shared inference tier can take ~20s; waiting beats
      // failing the user's first identification.
      'X-Wait-For-Model': 'true',
    },
    body: bytes,
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`CLIP 추론 실패 (${response.status}): ${detail.slice(0, 200)}`);
  }

  return normalise(pool(await response.json()));
}

function decodeBase64(input: string): Uint8Array {
  // Accept both bare base64 and `data:image/jpeg;base64,...` payloads.
  const comma = input.indexOf(',');
  const payload = input.startsWith('data:') && comma !== -1
    ? input.slice(comma + 1)
    : input;
  const binary = atob(payload);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

async function downloadPhoto(
  client: SupabaseClient,
  storagePath: string,
): Promise<Uint8Array> {
  const { data, error } = await client.storage.from(BUCKET).download(storagePath);
  if (error || !data) {
    throw new Error(`사진을 내려받지 못했습니다: ${error?.message ?? storagePath}`);
  }
  return new Uint8Array(await data.arrayBuffer());
}

/** Client bound to the caller's JWT, so RLS still applies. */
function callerClient(req: Request): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    {
      global: {
        headers: { Authorization: req.headers.get('Authorization') ?? '' },
      },
      auth: { persistSession: false },
    },
  );
}

/** Client that bypasses RLS, for writing embeddings the user cannot write. */
function adminClient(): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );
}

async function handleIdentify(req: Request, body: Record<string, unknown>) {
  const image = body.image;
  if (typeof image !== 'string' || image.length === 0) {
    return fail('image(base64) 값이 필요합니다');
  }

  const embedding = await embedImage(decodeBase64(image));
  const matchCount = typeof body.matchCount === 'number' ? body.matchCount : 12;

  const { data, error } = await callerClient(req).rpc('match_morphs', {
    query_embedding: embedding,
    match_count: matchCount,
  });
  if (error) return fail(`유사도 검색 실패: ${error.message}`, 500);

  return json({ matches: data ?? [] });
}

async function handleIndex(body: Record<string, unknown>) {
  const photoId = body.photoId;
  if (typeof photoId !== 'string') return fail('photoId 값이 필요합니다');

  const admin = adminClient();
  const { data: photo, error } = await admin
    .from('reference_photos')
    .select('id, storage_path')
    .eq('id', photoId)
    .single();
  if (error || !photo) return fail('참고 사진을 찾을 수 없습니다', 404);

  const embedding = await embedImage(
    await downloadPhoto(admin, photo.storage_path),
  );
  const { error: updateError } = await admin
    .from('reference_photos')
    .update({ embedding })
    .eq('id', photo.id);
  if (updateError) return fail(`임베딩 저장 실패: ${updateError.message}`, 500);

  return json({ indexed: photo.id });
}

async function handleBackfill(body: Record<string, unknown>) {
  const limit = typeof body.limit === 'number' ? Math.min(body.limit, 25) : 10;
  const admin = adminClient();

  const { data: pending, error } = await admin
    .from('reference_photos')
    .select('id, storage_path')
    .is('embedding', null)
    .order('created_at')
    .limit(limit);
  if (error) return fail(`대기 목록 조회 실패: ${error.message}`, 500);

  const indexed: string[] = [];
  const failed: { id: string; reason: string }[] = [];
  for (const photo of pending ?? []) {
    try {
      const embedding = await embedImage(
        await downloadPhoto(admin, photo.storage_path),
      );
      await admin
        .from('reference_photos')
        .update({ embedding })
        .eq('id', photo.id);
      indexed.push(photo.id);
    } catch (err) {
      failed.push({ id: photo.id, reason: String(err) });
    }
  }
  return json({ indexed, failed, remaining: (pending ?? []).length - indexed.length });
}

async function handleCatalog(body: Record<string, unknown>) {
  const { morphId, imageBase64, sourcePath } = body;
  if (typeof morphId !== 'string' || typeof imageBase64 !== 'string') {
    return fail('morphId와 imageBase64 값이 필요합니다');
  }

  const embedding = await embedImage(decodeBase64(imageBase64));
  const { error } = await adminClient().from('morph_embeddings').upsert({
    morph_id: morphId,
    embedding,
    source_path: typeof sourcePath === 'string' ? sourcePath : morphId,
    updated_at: new Date().toISOString(),
  });
  if (error) return fail(`카탈로그 임베딩 저장 실패: ${error.message}`, 500);

  return json({ morphId, dim: embedding.length });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') return fail('POST만 지원합니다', 405);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return fail('JSON 본문을 읽을 수 없습니다');
  }

  const action = typeof body.action === 'string' ? body.action : 'identify';

  try {
    switch (action) {
      case 'identify':
        return await handleIdentify(req, body);
      case 'index':
        return await handleIndex(body);
      case 'backfill':
        return await handleBackfill(body);
      case 'catalog':
        return await handleCatalog(body);
      default:
        return fail(`알 수 없는 action: ${action}`);
    }
  } catch (err) {
    console.error(action, err);
    return fail(err instanceof Error ? err.message : String(err), 500);
  }
});
