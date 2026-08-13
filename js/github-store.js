export const GH_OWNER = "youngbokkim";
export const GH_REPO = "cremorph";
export const GH_BRANCH = "main";
export const LIBRARY_PATH = "data/library.json";
export const TOKEN_KEY = "cremorph_github_token";

function apiBase() {
  return `https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/contents`;
}

export function getGithubToken() {
  return (localStorage.getItem(TOKEN_KEY) || "").trim();
}

export function setGithubToken(token) {
  const value = String(token || "").trim();
  if (value) localStorage.setItem(TOKEN_KEY, value);
  else localStorage.removeItem(TOKEN_KEY);
}

export async function hasLocalApi() {
  try {
    const res = await fetch("/api/status", { cache: "no-store" });
    if (!res.ok) return false;
    const data = await res.json();
    return Boolean(data && data.ok && data.mode === "local-api");
  } catch {
    return false;
  }
}

function decodeGithubJson(content) {
  const binary = atob(String(content || "").replace(/\n/g, ""));
  try {
    return JSON.parse(decodeURIComponent(escape(binary)));
  } catch {
    return JSON.parse(binary);
  }
}

async function githubHeaders(token) {
  return {
    Accept: "application/vnd.github+json",
    Authorization: `Bearer ${token}`,
    "X-GitHub-Api-Version": "2022-11-28",
    "Content-Type": "application/json",
  };
}

async function getFile(path, token) {
  const res = await fetch(`${apiBase()}/${path}?ref=${GH_BRANCH}`, {
    headers: await githubHeaders(token),
  });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error("GitHub에서 파일을 읽지 못했습니다");
  return res.json();
}

async function putFile(path, contentB64, message, sha, token) {
  const body = {
    message,
    content: contentB64,
    branch: GH_BRANCH,
  };
  if (sha) body.sha = sha;
  const res = await fetch(`${apiBase()}/${path}`, {
    method: "PUT",
    headers: await githubHeaders(token),
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.message || "GitHub에 올리지 못했습니다");
  }
  return res.json();
}

async function deleteFile(path, sha, message, token) {
  const res = await fetch(`${apiBase()}/${path}`, {
    method: "DELETE",
    headers: await githubHeaders(token),
    body: JSON.stringify({ message, sha, branch: GH_BRANCH }),
  });
  if (!res.ok && res.status !== 404) throw new Error("GitHub에서 삭제하지 못했습니다");
}

export async function githubUploadPhoto({ id, name, morphId, image, signature, addedAt }) {
  const token = getGithubToken();
  if (!token) throw new Error("NO_TOKEN");
  const file = `assets/shared/${id}.jpg`;
  const jpegB64 = String(image).split(",")[1];
  if (!jpegB64) throw new Error("이미지 데이터가 없습니다");
  try {
    await putFile(file, jpegB64, `Add shared morph photo: ${name}`, null, token);
  } catch (err) {
    const existing = await getFile(file, token);
    if (!existing?.sha) throw err;
    await putFile(file, jpegB64, `Add shared morph photo: ${name}`, existing.sha, token);
  }

  const current = await getFile(LIBRARY_PATH, token);
  let library = { photos: [] };
  if (current?.content) {
    library = decodeGithubJson(current.content);
    if (!Array.isArray(library.photos)) library.photos = [];
  }
  library.photos = library.photos.filter((p) => p.id !== id);
  library.photos.push({
    id,
    name,
    morphId,
    file,
    signature: signature || null,
    addedAt: addedAt || Date.now(),
  });
  const jsonB64 = btoa(unescape(encodeURIComponent(JSON.stringify(library, null, 2))));
  await putFile(LIBRARY_PATH, jsonB64, `Update shared morph library: ${name}`, current?.sha, token);
  return { id, name, morphId, file, image: file, signature, addedAt: addedAt || Date.now(), shared: true };
}

export async function githubDeletePhoto(photo) {
  const token = getGithubToken();
  if (!token) throw new Error("NO_TOKEN");
  const file = photo.file || `assets/shared/${photo.id}.jpg`;
  const currentFile = await getFile(file, token);
  if (currentFile?.sha) await deleteFile(file, currentFile.sha, `Remove shared morph photo: ${photo.name || photo.id}`, token);

  const current = await getFile(LIBRARY_PATH, token);
  if (!current?.content) return;
  const library = decodeGithubJson(current.content);
  library.photos = (library.photos || []).filter((p) => p.id !== photo.id);
  const jsonB64 = btoa(unescape(encodeURIComponent(JSON.stringify(library, null, 2))));
  await putFile(LIBRARY_PATH, jsonB64, `Update shared morph library after delete`, current.sha, token);
}
