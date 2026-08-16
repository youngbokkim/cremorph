import { MORPHS, getMorph, normalize } from "./morphs.js?v=8";
import { analyzePixels } from "./engine.js?v=8";
import {
  githubUploadPhoto,
  githubDeletePhoto,
  hasLocalApi,
  getGithubToken,
  GH_OWNER,
  GH_REPO,
  GH_BRANCH,
} from "./github-store.js?v=8";

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
    inheritanceKo: "공유된 참고 사진",
    description: "서버 도감에 올라간 참고 개체입니다. 모프 분석 때 이 사진과도 비교합니다.",
    look: "공유 참고",
    image,
    aliases: [name.trim()],
    genes: {},
    traits: {},
    custom: true,
    signature: signature || null,
  };
}

function withImage(photo) {
  return { ...photo, image: photo.image || photo.file };
}

async function listIndexedPhotos() {
  try {
    const db = await openDb();
    return new Promise((resolve, reject) => {
      const req = db.transaction(STORE, "readonly").objectStore(STORE).getAll();
      req.onsuccess = () => resolve(req.result || []);
      req.onerror = () => reject(req.error);
    });
  } catch {
    return [];
  }
}

async function saveIndexedPhoto(photo) {
  const db = await openDb();
  const tx = db.transaction(STORE, "readwrite");
  tx.objectStore(STORE).put(photo);
  await txDone(tx);
}

async function deleteIndexedPhoto(id) {
  const db = await openDb();
  const tx = db.transaction(STORE, "readwrite");
  tx.objectStore(STORE).delete(id);
  await txDone(tx);
}

export async function loadSharedPhotos() {
  const rawBase = `https://raw.githubusercontent.com/${GH_OWNER}/${GH_REPO}/${GH_BRANCH}`;
  const localFirst = /^(localhost|127\.0\.0\.1)$/i.test(location.hostname) || (await hasLocalApi());
  const urls = localFirst
    ? [`data/library.json?t=${Date.now()}`, `${rawBase}/data/library.json?t=${Date.now()}`]
    : [`${rawBase}/data/library.json?t=${Date.now()}`, `data/library.json?t=${Date.now()}`];

  for (const url of urls) {
    try {
      const res = await fetch(url, { cache: "no-store" });
      if (!res.ok) continue;
      const data = await res.json();
      const fromRaw = url.startsWith("https://raw.githubusercontent.com");
      return (data.photos || []).map((p) => {
        const file = p.file || p.image;
        const image =
          file && !String(file).startsWith("data:") && !String(file).startsWith("http")
            ? fromRaw
              ? `${rawBase}/${file}`
              : file
            : file;
        return { ...p, file, image };
      });
    } catch {
      /* try next source */
    }
  }
  return [];
}

export async function listCustomPhotos() {
  const shared = await loadSharedPhotos();
  const local = (await listIndexedPhotos()).map(withImage);
  const byId = new Map();
  for (const p of local) byId.set(p.id, { ...p, localOnly: !p.file });
  for (const p of shared) byId.set(p.id, { ...p, shared: true, localOnly: false });
  return [...byId.values()];
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

  if (await hasLocalApi()) {
    const res = await fetch("/api/photos", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(photo),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || "서버에 올리지 못했습니다");
    return withImage({ ...data, shared: true });
  }

  if (getGithubToken()) {
    return withImage(await githubUploadPhoto(photo));
  }

  await saveIndexedPhoto(photo);
  return { ...photo, localOnly: true };
}

export async function deleteCustomPhoto(id) {
  const photos = await listCustomPhotos();
  const photo = photos.find((p) => p.id === id);
  if (await hasLocalApi()) {
    const res = await fetch(`/api/photos/${id}`, { method: "DELETE" });
    if (!res.ok) throw new Error("서버에서 삭제하지 못했습니다");
  } else if (photo && !photo.localOnly) {
    if (!getGithubToken()) throw new Error("공유 사진을 지우려면 GitHub 토큰이 필요합니다");
    await githubDeletePhoto(photo);
  }
  await deleteIndexedPhoto(id);
}

export async function migrateLocalPhotosToServer() {
  if (!(await hasLocalApi()) && !getGithubToken()) return 0;
  const local = (await listIndexedPhotos()).filter((p) => p.image && String(p.image).startsWith("data:"));
  let moved = 0;
  for (const p of local) {
    try {
      if (await hasLocalApi()) {
        const res = await fetch("/api/photos", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(p),
        });
        if (!res.ok) continue;
      } else {
        await githubUploadPhoto(p);
      }
      await deleteIndexedPhoto(p.id);
      moved += 1;
    } catch (err) {
      console.warn("migrate failed", p.id, err);
    }
  }
  return moved;
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
