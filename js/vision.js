import { analyzePixels, identifyMorph, morphScore } from "./engine.js";
import { buildCatalog } from "./library.js";

const MODEL_ID = "Xenova/clip-vit-base-patch32";
const LIB_URL = "https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.7.2";

let clip = null;
let loadPromise = null;
const galleryEmbeds = new Map();

function fileName(path = "") {
  return String(path).split("/").pop() || "model";
}

function formatProgress(info) {
  if (!info || !info.status) return "CLIP 딥러닝 모델을 준비하는 중…";
  if (info.status === "initiate") return "모델 파일을 확인하는 중…";
  if (info.status === "download") return `${fileName(info.file)} 받기 시작…`;
  if (info.status === "progress") {
    const pct =
      typeof info.progress === "number"
        ? Math.round(info.progress)
        : Math.round(((info.loaded || 0) / (info.total || 1)) * 100);
    return `CLIP 모델 받는 중 ${Math.max(0, Math.min(100, pct))}% · 기기에만 저장됩니다`;
  }
  if (info.status === "ready" || info.status === "done") return "모델을 불러왔습니다…";
  return "딥러닝 모델을 준비하는 중…";
}

function toVector(tensor) {
  const data = tensor?.data ?? tensor;
  return Float32Array.from(data);
}

function tensorToEmbed(output) {
  if (output?.image_embeds) return toVector(output.image_embeds);
  const hidden = output?.last_hidden_state;
  if (!hidden?.data || !hidden.dims) throw new Error("CLIP 출력에 임베딩이 없습니다");
  const dims = hidden.dims;
  const data = hidden.data;
  const depth = dims[dims.length - 1];
  const tokens = data.length / depth;
  const out = new Float32Array(depth);
  for (let i = 0; i < tokens; i++) {
    for (let j = 0; j < depth; j++) out[j] += data[i * depth + j];
  }
  for (let j = 0; j < depth; j++) out[j] /= tokens;
  return out;
}

function cosine(a, b) {
  let dot = 0;
  let na = 0;
  let nb = 0;
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return dot / (Math.sqrt(na) * Math.sqrt(nb) + 1e-8);
}

async function loadLibrary() {
  return import(LIB_URL);
}

async function toRawImage(hf, source) {
  const { RawImage } = hf;
  if (typeof source === "string") {
    return RawImage.read(new URL(source, location.href).href);
  }

  const w = source.naturalWidth || source.width;
  const h = source.naturalHeight || source.height;
  const side = Math.min(w, h);
  const sx = (w - side) / 2;
  const sy = (h - side) / 2;
  const out = 256;
  const canvas = document.createElement("canvas");
  canvas.width = out;
  canvas.height = out;
  const ctx = canvas.getContext("2d");
  ctx.drawImage(source, sx, sy, side, side, 0, 0, out, out);

  if (typeof RawImage.fromCanvas === "function") {
    return RawImage.fromCanvas(canvas);
  }

  const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", 0.92));
  const url = URL.createObjectURL(blob);
  try {
    return await RawImage.read(url);
  } finally {
    URL.revokeObjectURL(url);
  }
}

async function ensureClip(onStatus) {
  if (clip) return clip;
  if (loadPromise) return loadPromise;

  loadPromise = (async () => {
    onStatus?.(formatProgress({ status: "initiate" }));
    const hf = await loadLibrary();
    hf.env.allowLocalModels = false;
    hf.env.useBrowserCache = true;
    if (hf.env.backends?.onnx?.wasm) {
      hf.env.backends.onnx.wasm.numThreads = 1;
    }

    const processor = await hf.AutoProcessor.from_pretrained(MODEL_ID, {
      progress_callback: (info) => onStatus?.(formatProgress(info)),
    });
    const model = await hf.CLIPVisionModelWithProjection.from_pretrained(MODEL_ID, {
      dtype: "q8",
      device: "wasm",
      progress_callback: (info) => onStatus?.(formatProgress(info)),
    });

    clip = { hf, processor, model };
    return clip;
  })();

  try {
    return await loadPromise;
  } catch (err) {
    loadPromise = null;
    throw err;
  }
}

async function embed(source, onStatus) {
  const session = await ensureClip(onStatus);
  const raw = await toRawImage(session.hf, source);
  const inputs = await session.processor(raw);
  const output = await session.model(inputs);
  return tensorToEmbed(output);
}

export function forgetCustomEmbed(photoId) {
  galleryEmbeds.delete("custom:" + photoId);
}

async function embedGallery(onStatus) {
  const { morphs, photos } = await buildCatalog();
  const jobs = [];
  for (const morph of morphs) {
    if (morph.image && !morph.custom && !galleryEmbeds.has(morph.id)) {
      jobs.push({ key: morph.id, image: morph.image, label: morph.nameKo });
    }
  }
  for (const photo of photos) {
    const key = "custom:" + photo.id;
    if (!galleryEmbeds.has(key) && photo.image) {
      jobs.push({ key, image: photo.image, label: photo.name });
    }
  }
  for (let i = 0; i < jobs.length; i++) {
    const job = jobs[i];
    onStatus?.(`도감 사진 학습 중 ${i + 1}/${jobs.length} · ${job.label}`);
    galleryEmbeds.set(job.key, await embed(job.image, onStatus));
  }
  return morphs;
}

function packResult(scored, source, extra = {}) {
  scored.sort((a, b) => b.score - a.score);
  const list = scored.slice(0, 4);
  const total = list.reduce((sum, x) => sum + Math.max(x.score, 0.001), 0);
  list.forEach((x) => {
    x.confidence = Math.round((Math.max(x.score, 0) / total) * 100);
  });
  const gap = (list[0]?.score || 0) - (list[1]?.score || 0);
  return {
    top: list[0],
    alternatives: list.slice(1),
    all: list,
    source,
    lowConfidence: source === "clip" ? gap < 0.012 || (list[0]?.clip || 0) < 0.18 : extra.lowConfidence,
    ...extra,
  };
}

export function warmupVision(onStatus) {
  return ensureClip(onStatus).then(() => embedGallery(onStatus)).catch((err) => {
    console.warn("CLIP warmup failed", err);
    return null;
  });
}

function bestClip(morph, query) {
  const keys = [];
  if (!morph.custom) keys.push(morph.id);
  for (const extra of morph.extraIds || []) keys.push(extra);
  let best = 0;
  for (const key of keys) {
    const gallery = galleryEmbeds.get(key);
    if (!gallery) continue;
    best = Math.max(best, cosine(query, gallery));
  }
  return best;
}

export async function identifyImage(image, { onStatus } = {}) {
  const feat = analyzePixels(image);

  try {
    onStatus?.("CLIP 딥러닝 모델을 준비하는 중…");
    const catalog = await embedGallery(onStatus);
    onStatus?.("올린 사진을 도감·내 참고 사진과 비교하는 중…");
    const query = await embed(image, onStatus);

    const scored = catalog.map((m) => {
      const clipSim = bestClip(m, query);
      const colorSim = m.signature ? morphScore(feat, m) : 0;
      const extraN = (m.extraIds || []).length;
      return {
        morph: m,
        clip: clipSim,
        color: colorSim,
        score: clipSim * 0.82 + colorSim * 0.18,
        extraN,
      };
    });

    return packResult(scored, "clip");
  } catch (err) {
    console.warn("CLIP identify failed, using color fallback", err);
    return {
      ...identifyMorph(feat),
      source: "color",
      error: err?.message || String(err),
    };
  }
}

export { analyzePixels };
