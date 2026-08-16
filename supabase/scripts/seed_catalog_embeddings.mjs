#!/usr/bin/env node
/**
 * Seeds `public.morph_embeddings` with CLIP embeddings of the 18 bundled morph
 * photos in `assets/morphs/`.
 *
 * Until this has run, `match_morphs()` has no catalog rows to compare an upload
 * against and identification stays on the on-device colour path.
 *
 * Usage:
 *   SUPABASE_URL=https://xxxx.supabase.co \
 *   SUPABASE_SERVICE_ROLE_KEY=eyJhb... \
 *   node supabase/scripts/seed_catalog_embeddings.mjs
 *
 * Re-running is safe: rows are upserted by morph_id.
 */

import { readdir, readFile } from 'node:fs/promises';
import { basename, extname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = fileURLToPath(new URL('.', import.meta.url));
const morphsDir = join(here, '..', '..', 'assets', 'morphs');

const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !serviceKey) {
  console.error(
    'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must both be set.\n' +
      'Find them in Supabase dashboard → Project Settings → API.',
  );
  process.exit(1);
}

const endpoint = `${url.replace(/\/$/, '')}/functions/v1/clip-embed`;

const files = (await readdir(morphsDir))
  .filter((f) => ['.jpg', '.jpeg', '.png'].includes(extname(f).toLowerCase()))
  .sort();

if (files.length === 0) {
  console.error(`No images found in ${morphsDir}`);
  process.exit(1);
}

console.log(`Seeding ${files.length} catalog embeddings via ${endpoint}\n`);

let ok = 0;
const failures = [];

for (const file of files) {
  const morphId = basename(file, extname(file));
  const bytes = await readFile(join(morphsDir, file));

  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        action: 'catalog',
        morphId,
        sourcePath: `assets/morphs/${file}`,
        imageBase64: bytes.toString('base64'),
      }),
    });

    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error ?? response.statusText);

    ok += 1;
    console.log(`  ok   ${morphId.padEnd(20)} dim=${payload.dim}`);
  } catch (err) {
    failures.push({ morphId, reason: String(err) });
    console.log(`  FAIL ${morphId.padEnd(20)} ${err}`);
  }
}

console.log(`\n${ok}/${files.length} embedded.`);
if (failures.length > 0) {
  console.error('\nFailures:');
  for (const f of failures) console.error(`  ${f.morphId}: ${f.reason}`);
  process.exit(1);
}
