import { MORPHS, getMorph, normalize } from "./morphs.js";
import { analyzePixels } from "./engine.js";

const DB_NAME = "crehooni-library";
const STORE = "photos";
const DB_VERSION = 1;

function openDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE)) {
        db.createObjectStore(STORE, { keyPath: "id" });
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

function txDone(tx) {
  return new Promise((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
    tx.onabort = () => reject(tx.error || new Error("aborted"));
  });
}

export function matchMorphByName(name) {
  const n = normalize(name);
  if (!n) return null;
  for (const m of MORPHS) {
    const keys = [m.nameKo, m.nameEn, ...(m.aliases || [])].map(normalize);
    if (keys.includes(n)) return m;
  }
  return null;
}

export function userMorphId(name) {
  const linked = matchMorphByName(name);
  if (linked) return linked.id;
  return "user-" + normalize(name).replace(/[^a-z0-9가-힣]/gi, "").slice(0, 40);
}

function makeUserMorph(name, image, signature) {
  const id = userMorphId(name);
  const linked = matchMorphByName(name);
  if (linked) return { ...linked };
  return {
    id,
    nameKo: name.trim(),
    nameEn: "Custom",
    category: "custom",
    inheritance: "unknown",
    inheritanceKo: "내가 추가한 참고 사진",
    description: "사용자가 도감에 올린 참고 개체입니다. 모프 분석 때 이 사진과도 비교합니다.",
    look: "사용자 추가",
    image,
    aliases: [name.trim()],
    genes: {},
    traits: {},
    custom: true,
    signature: signature || null,
  };
}

export async function listCustomPhotos() {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const req = db.transaction(STORE, "readonly").objectStore(STORE).getAll();
    req.onsuccess = () => resolve(req.result || []);
    req.onerror = () => reject(req.error);
  });
}

export async function addCustomPhoto({ name, image, signature }) {
  const photo = {
    id: crypto.randomUUID(),
    name: name.trim(),
    morphId: matchMorphByName(name)?.id || userMorphId(name),
    image,
    signature: signature || null,
    addedAt: Date.now(),
  };
  const db = await openDb();
  const tx = db.transaction(STORE, "readwrite");
  tx.objectStore(STORE).put(photo);
  await txDone(tx);
  return photo;
}

export async function deleteCustomPhoto(id) {
  const db = await openDb();
  const tx = db.transaction(STORE, "readwrite");
  tx.objectStore(STORE).delete(id);
  await txDone(tx);
}

export async function buildCatalog() {
  const photos = await listCustomPhotos();
  const byId = new Map(
    MORPHS.filter((m) => m.category !== "het").map((m) => [
      m.id,
      { ...m, extraIds: [], extraImages: [] },
    ])
  );

  for (const p of photos) {
    const linked = matchMorphByName(p.name);
    const id = linked ? linked.id : userMorphId(p.name);
    if (!byId.has(id)) {
      byId.set(id, { ...makeUserMorph(p.name, p.image, p.signature), extraIds: [], extraImages: [] });
    }
    const morph = byId.get(id);
    morph.extraIds.push("custom:" + p.id);
    morph.extraImages.push(p.image);
    if (!morph.image) morph.image = p.image;
    if (morph.custom) morph.image = p.image;
    if (p.signature && morph.custom) morph.signature = p.signature;
  }

  return { morphs: [...byId.values()], photos };
}

export function getCatalogMorph(catalog, id) {
  return catalog.find((m) => m.id === id) || getMorph(id);
}

export function fileToDataUrl(file, maxSize = 720) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(file);
    img.onload = () => {
      const scale = Math.min(1, maxSize / Math.max(img.width, img.height));
      const w = Math.round(img.width * scale);
      const h = Math.round(img.height * scale);
      const canvas = document.createElement("canvas");
      canvas.width = w;
      canvas.height = h;
      canvas.getContext("2d").drawImage(img, 0, 0, w, h);
      URL.revokeObjectURL(url);
      resolve({ dataUrl: canvas.toDataURL("image/jpeg", 0.84), img });
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("이미지를 읽지 못했습니다"));
    };
    img.src = url;
  });
}

export function signatureFromImage(img) {
  return analyzePixels(img);
}

export { makeUserMorph };
