import { MORPHS, getMorph } from "./morphs.js?v=8";
import { breed, morphToProfile, answerQuestion } from "./engine.js?v=8";
import { identifyImage, warmupVision, forgetCustomEmbed } from "./vision.js?v=8";
import {
  addCustomPhoto,
  deleteCustomPhoto,
  fileToDataUrl,
  signatureFromImage,
  buildCatalog,
  matchMorphByName,
  migrateLocalPhotosToServer,
} from "./library.js?v=8";
import { hasLocalApi, getGithubToken, setGithubToken } from "./github-store.js?v=8";

const $ = (id) => document.getElementById(id);

function switchTab(name) {
  document.querySelectorAll(".tab").forEach((t) => t.classList.toggle("active", t.dataset.tab === name));
  document.querySelectorAll(".panel").forEach((p) => p.classList.toggle("active", p.id === name));
}
window.cremorphTab = switchTab;

$("tabs").addEventListener("click", (e) => {
  const btn = e.target.closest(".tab");
  if (btn) switchTab(btn.dataset.tab);
});
document.querySelectorAll(".tab").forEach((btn) => {
  btn.addEventListener("click", () => switchTab(btn.dataset.tab));
});

function bindDrop(dropId, fileId, previewId, onReady) {
  const drop = $(dropId);
  const file = $(fileId);
  const preview = $(previewId);
  if (!drop || !file) return;

  const load = (f) => {
    if (!f || !f.type.startsWith("image/")) return;
    const url = URL.createObjectURL(f);
    const img = new Image();
    img.onload = () => {
      preview.src = url;
      preview.hidden = false;
      drop.classList.add("has-img");
      onReady(img, url, f);
    };
    img.src = url;
  };

  file.addEventListener("change", () => load(file.files[0]));
  drop.addEventListener("dragover", (e) => e.preventDefault());
  drop.addEventListener("drop", (e) => {
    e.preventDefault();
    load(e.dataTransfer.files[0]);
  });
}

let idImage = null;
let identifying = false;
let libFile = null;

bindDrop("id-drop", "id-file", "id-preview", (img) => {
  idImage = img;
  $("id-run").disabled = false;
  warmupVision((msg) => {
    if (identifying) return;
    $("id-wait-text").textContent = msg;
    $("id-wait").classList.add("show");
  }).finally(() => {
    if (!identifying) $("id-wait").classList.remove("show");
  });
});

bindDrop("lib-drop", "lib-file", "lib-preview", (img, _url, file) => {
  libFile = file;
  $("lib-add").disabled = !$("lib-name").value.trim();
});

$("lib-name").addEventListener("input", () => {
  $("lib-add").disabled = !libFile || !$("lib-name").value.trim();
});

function morphHero(morph, kicker, extra = "") {
  const extraN = (morph.extraIds || []).length;
  const extraBadge = extraN ? `<span class="badge">공유 참고 ${extraN}장</span>` : "";
  return `
    <article class="morph-hero">
      <img src="${morph.image}" alt="${morph.nameKo}" />
      <div class="meta">
        <div class="kicker">${kicker}</div>
        <h3>${morph.nameKo}</h3>
        <div class="en">${morph.nameEn}</div>
        <p>${morph.description}</p>
        <div class="badge-row">
          <span class="badge">${morph.inheritanceKo}</span>
          <span class="badge">${morph.look}</span>
          ${extraBadge}
        </div>
        ${extra}
      </div>
    </article>`;
}

function renderIdentify(id) {
  const morph = id.top.morph;
  const method =
    id.source === "clip"
      ? `<p class="method-note">CLIP으로 기본 도감과 공유된 참고 사진을 함께 비교했습니다.</p>`
      : `<p class="method-note">모델 로드에 실패해 색 통계로 추정했습니다. ${id.error ? `원인: ${id.error}` : ""}</p>`;
  const warn = id.lowConfidence
    ? `<div class="warn">후보 점수가 낮습니다. 참고 사진을 더 넣으면 구분력이 좋아집니다.</div>`
    : "";
  const extras =
    morph.extraImages?.length
      ? `<div class="kicker" style="margin:12px 0 8px">이 모프의 공유 참고 사진</div>
         <div class="thumb-row">${morph.extraImages.map((src) => `<img src="${src}" alt="" />`).join("")}</div>`
      : "";
  const alts = id.all
    .map(
      (x) => `
      <div class="alt">
        <img src="${x.morph.image}" alt="${x.morph.nameKo}" />
        <div>
          <strong>${x.morph.nameKo}</strong>
          <div class="bar"><i style="width:${x.confidence}%"></i></div>
        </div>
        <span>${x.confidence}%</span>
      </div>`
    )
    .join("");

  $("id-result").innerHTML = `
    ${method}
    ${warn}
    ${morphHero(morph, "가장 가까운 모프")}
    ${extras}
    <div>
      <div class="kicker" style="margin-bottom:8px">다른 가능성</div>
      <div class="alt-list">${alts}</div>
    </div>`;
}

$("id-run").addEventListener("click", async () => {
  if (!idImage) return;
  identifying = true;
  $("id-wait").classList.add("show");
  $("id-run").disabled = true;
  $("id-wait-text").textContent = "CLIP으로 도감·공유 참고 사진과 비교하는 중…";
  try {
    const id = await identifyImage(idImage, {
      onStatus: (msg) => {
        $("id-wait-text").textContent = msg;
      },
    });
    renderIdentify(id);
  } catch (err) {
    $("id-result").innerHTML = `<div class="warn">분석에 실패했습니다. 다른 사진으로 다시 시도해 주세요.</div>`;
    console.warn(err);
  }
  identifying = false;
  $("id-wait").classList.remove("show");
  $("id-run").disabled = false;
});

function fillSelects(catalogMorphs = MORPHS) {
  const html = catalogMorphs
    .filter((m) => m.category !== "het")
    .map((m) => `<option value="${m.id}">${m.nameKo}${m.custom ? " (공유)" : ""} · ${m.nameEn}</option>`)
    .join("");
  $("parent-a").innerHTML = html;
  $("parent-b").innerHTML = html;
  if ([...$("parent-a").options].some((o) => o.value === "lilly-white")) $("parent-a").value = "lilly-white";
  if ([...$("parent-b").options].some((o) => o.value === "axanthic")) $("parent-b").value = "axanthic";
}
fillSelects();

function applyHet(profile, het) {
  if (het === "axanthic" && (profile.genes.axanthic || 0) < 1) profile.genes.axanthic = 1;
  if (het === "phantom" && (profile.genes.phantom || 0) < 1) profile.genes.phantom = 1;
  return profile;
}

function renderBreed(result) {
  const warns = result.warnings
    .map((w) => `<div class="${w.level === "danger" ? "danger-box" : "warn"}"><strong>${w.title}</strong><br>${w.text}</div>`)
    .join("");
  const genes = result.geneResults
    .map(
      (r) => `
      <div class="off-card">
        <img src="${r.imagePath}" alt="${r.name}" />
        <div>
          <h4>${r.name}${r.lethal ? " ⚠️" : ""}</h4>
          <p>${r.detail || "확정 유전자 조합"}</p>
        </div>
        <div class="pct">${r.percent}%</div>
      </div>`
    )
    .join("");
  const patterns =
    result.patternResults.length === 0
      ? ""
      : `<div class="kicker" style="margin:16px 0 8px">패턴 · 발색 예측 (다지성, 대략)</div>` +
        result.patternResults
          .map(
            (r) => `
          <div class="off-card">
            <img src="${r.imagePath}" alt="${r.name}" />
            <div>
              <h4>${r.name}</h4>
              <p>${r.note || "선발 교배 형질이라 비율은 참고치입니다."}</p>
            </div>
            <div class="pct">${r.percent}%</div>
          </div>`
          )
          .join("");

  return `
    ${warns}
    <p class="sub">${result.summary}</p>
    <div class="kicker">유전자 자손</div>
    <div class="offspring">${genes}</div>
    ${patterns}`;
}

function currentProfiles() {
  const a = applyHet(morphToProfile($("parent-a").value), $("het-a").value);
  const b = applyHet(morphToProfile($("parent-b").value), $("het-b").value);
  const ma = getMorph($("parent-a").value) || { nameKo: $("parent-a").selectedOptions[0]?.text || "부모 A" };
  const mb = getMorph($("parent-b").value) || { nameKo: $("parent-b").selectedOptions[0]?.text || "부모 B" };
  a.label = ma.nameKo + ($("het-a").value ? ` + ${$("het-a").selectedOptions[0].text}` : "");
  b.label = mb.nameKo + ($("het-b").value ? ` + ${$("het-b").selectedOptions[0].text}` : "");
  return { a, b };
}

$("breed-run").addEventListener("click", () => {
  const { a, b } = currentProfiles();
  $("breed-out").innerHTML = renderBreed(breed(a, b));
});

const SUGGEST = [
  "릴리화이트랑 아잔틱 섞으면?",
  "카푸치노 x 릴리 화이트",
  "할리퀸이랑 핀스트라이프",
  "릴리끼리 교배하면?",
  "할로윈이랑 크림시클",
  "팬텀이랑 릴리화이트",
];

$("chips").innerHTML = SUGGEST.map((s) => `<button type="button" class="chip">${s}</button>`).join("");

function addMsg(role, html) {
  const el = document.createElement("div");
  el.className = `bubble ${role}`;
  el.innerHTML = html;
  $("messages").appendChild(el);
  $("messages").scrollTop = $("messages").scrollHeight;
}

addMsg(
  "bot",
  "안녕하세요. 크레스티드게코 교배 AI입니다. 모프 두 개를 말하면 자손이 무슨 모프로, 몇 %로 나오는지와 참고 사진을 보여 드립니다. 릴리끼리 교배처럼 위험한 조합은 따로 경고합니다."
);

function handleAsk(text) {
  addMsg("me", text);
  const ans = answerQuestion(text);
  if (ans.type === "breed") {
    const names = ans.morphs.map((m) => m.nameKo).join(" × ");
    addMsg("bot", `<strong>${names}</strong><div style="margin-top:10px">${renderBreed(ans.result)}</div>`);
  } else if (ans.type === "info") {
    const m = ans.morph;
    addMsg("bot", `${morphHero(m, "모프 정보")}<p style="margin-top:10px">다른 모프와 섞은 결과가 필요하면 이름을 하나 더 적어 주세요.</p>`);
  } else {
    addMsg("bot", ans.message || "모프 이름을 인식하지 못했습니다. 도감에 있는 이름(릴리 화이트, 아잔틱, 카푸치노, 할리퀸 등)으로 물어봐 주세요.");
  }
}

$("chips").addEventListener("click", (e) => {
  const chip = e.target.closest(".chip");
  if (chip) handleAsk(chip.textContent);
});

$("ask-form").addEventListener("submit", (e) => {
  e.preventDefault();
  const v = $("ask-input").value.trim();
  if (!v) return;
  $("ask-input").value = "";
  handleAsk(v);
});

let catalogCache = MORPHS.map((m) => ({ ...m, extraIds: [], extraImages: [] }));

async function refreshLibrary() {
  const { morphs, photos } = await buildCatalog();
  catalogCache = morphs;
  fillSelects(morphs);
  renderGallery(morphs, photos);
  renderLibList(photos);
}

function renderLibList(photos) {
  const el = $("lib-list");
  if (!photos.length) {
    el.innerHTML = `<p class="sub" style="margin-top:12px">아직 추가한 참고 사진이 없습니다.</p>`;
    return;
  }
  el.innerHTML = photos
    .map((p) => {
      const linked = matchMorphByName(p.name);
      const tag = linked ? linked.nameKo : "새 모프";
      const where = p.localOnly ? "이 브라우저에만 저장됨" : "공유 도감";
      return `
        <article class="lib-item">
          <img src="${p.image}" alt="${p.name}" />
          <div>
            <strong>${p.name}</strong>
            <span>${tag} · ${where}</span>
          </div>
          <button type="button" class="btn ghost tiny" data-del="${p.id}">삭제</button>
        </article>`;
    })
    .join("");
}

function renderGallery(morphs, photos) {
  const builtIn = morphs
    .filter((m) => !m.custom)
    .map(
      (m) => `
  <article class="g-card" data-id="${m.id}">
    <img src="${m.image}" alt="${m.nameKo}" />
    <div class="pad">
      <div class="en">${m.nameEn}${m.extraIds?.length ? ` · 공유 ${m.extraIds.length}` : ""}</div>
      <h3>${m.nameKo}</h3>
      <p>${m.look}</p>
    </div>
  </article>`
    )
    .join("");

  const mine = photos
    .map(
      (p) => `
  <article class="g-card custom" data-photo="${p.id}">
    <img src="${p.image}" alt="${p.name}" />
    <div class="pad">
      <div class="en">${p.localOnly ? "이 브라우저만" : "공유 참고"}</div>
      <h3>${p.name}</h3>
      <p>모프 분석 비교용 참고 사진</p>
    </div>
  </article>`
    )
    .join("");

  $("gallery-grid").innerHTML = builtIn + mine;
}

$("gallery-grid").addEventListener("click", (e) => {
  const card = e.target.closest(".g-card");
  if (!card) return;
  if (card.dataset.photo) {
    const m = catalogCache.find((x) => (x.extraIds || []).includes("custom:" + card.dataset.photo));
    const title = m?.nameKo || "공유 참고 사진";
    $("modal-card").innerHTML = `
      <img src="${card.querySelector("img").src}" alt="${title}" />
      <div class="pad">
        <div class="kicker">공유된 참고 사진</div>
        <h3>${title}</h3>
        <p style="margin:12px 0;line-height:1.6">이 사진은 모든 방문자의 모프 분석 때 도감과 함께 비교됩니다.</p>
        <button class="btn ghost" id="close-modal" style="margin-top:16px">닫기</button>
      </div>`;
    $("modal").classList.add("open");
    return;
  }
  const m = catalogCache.find((x) => x.id === card.dataset.id) || getMorph(card.dataset.id);
  if (!m) return;
  const extraImgs = (m.extraImages || []).map((src) => `<img src="${src}" alt="" />`).join("");
  $("modal-card").innerHTML = `
    <img src="${m.image}" alt="${m.nameKo}" />
    <div class="pad">
      <div class="kicker">${m.inheritanceKo}</div>
      <h3>${m.nameKo}</h3>
      <div class="en">${m.nameEn}</div>
      <p style="margin:12px 0;line-height:1.6">${m.description}</p>
      <div class="badge-row">
        <span class="badge">${m.look}</span>
      </div>
      ${extraImgs ? `<div class="kicker" style="margin:14px 0 8px">공유 참고 사진</div><div class="thumb-row">${extraImgs}</div>` : ""}
      <button class="btn ghost" id="close-modal" style="margin-top:16px">닫기</button>
    </div>`;
  $("modal").classList.add("open");
});

$("modal").addEventListener("click", (e) => {
  if (e.target.id === "modal" || e.target.id === "close-modal") $("modal").classList.remove("open");
});

$("lib-add").addEventListener("click", async () => {
  const name = $("lib-name").value.trim();
  if (!libFile || !name) return;
  $("lib-add").disabled = true;
  $("lib-status").textContent = "공유 도감에 올리는 중… 배포까지 1~2분 걸릴 수 있습니다.";
  try {
    const { dataUrl, img } = await fileToDataUrl(libFile);
    const signature = signatureFromImage(img);
    const saved = await addCustomPhoto({ name, image: dataUrl, signature });
    await refreshLibrary();
    warmupVision(() => {});
    const linked = matchMorphByName(name);
    if (saved.localOnly) {
      $("lib-status").textContent = `「${name}」을 이 브라우저에만 저장했습니다. 모든 사람과 공유하려면 아래 GitHub 토큰을 저장하거나 start.bat 서버를 켜 주세요.`;
    } else {
      $("lib-status").textContent = linked
        ? `「${linked.nameKo}」 참고 사진을 공유 도감에 올렸습니다. 잠시 후 모든 방문자가 봅니다.`
        : `「${name}」을 새 참고 모프로 공유 도감에 올렸습니다. 잠시 후 모든 방문자가 봅니다.`;
    }
    libFile = null;
    $("lib-file").value = "";
    $("lib-name").value = "";
    $("lib-preview").hidden = true;
    $("lib-drop").classList.remove("has-img");
  } catch (err) {
    console.warn(err);
    $("lib-status").textContent = err?.message
      ? `추가에 실패했습니다. ${err.message}`
      : "추가에 실패했습니다. 다른 사진으로 다시 시도해 주세요.";
    $("lib-add").disabled = false;
  }
});

$("lib-list").addEventListener("click", async (e) => {
  const btn = e.target.closest("[data-del]");
  if (!btn) return;
  const id = btn.dataset.del;
  try {
    await deleteCustomPhoto(id);
    forgetCustomEmbed(id);
    await refreshLibrary();
  } catch (err) {
    $("lib-status").textContent = err?.message || "삭제하지 못했습니다.";
  }
});

async function setupShare() {
  const local = await hasLocalApi();
  const setup = $("share-setup");
  if (local) {
    setup.hidden = true;
    $("lib-share-hint").textContent =
      "사진을 올리면 이 서버를 통해 GitHub 공유 도감에 들어가고, 모든 방문자의 모프 분석에 쓰입니다. 기존 모프 이름이면 그 모프의 추가 예시로 붙습니다.";
    return;
  }
  setup.hidden = false;
  $("gh-token-status").textContent = getGithubToken()
    ? "토큰이 이 기기에 저장되어 있습니다. 추가한 사진이 공유 도감에 올라갑니다."
    : "토큰이 없으면 이 브라우저에만 저장됩니다.";
}

$("gh-token-save").addEventListener("click", async () => {
  const value = $("gh-token").value.trim();
  setGithubToken(value);
  $("gh-token").value = "";
  $("gh-token-status").textContent = value
    ? "저장했습니다. 이제 올리는 사진이 공유됩니다."
    : "토큰을 지웠습니다.";
  if (!value) return;
  const moved = await migrateLocalPhotosToServer();
  if (moved) {
    $("gh-token-status").textContent += ` 기존 사진 ${moved}장을 공유 도감으로 옮겼습니다.`;
    await refreshLibrary();
  }
});

(async () => {
  try {
    await setupShare();
    const moved = await migrateLocalPhotosToServer();
    await refreshLibrary();
    if (moved) {
      $("lib-status").textContent = `이 브라우저에만 있던 사진 ${moved}장을 공유 도감으로 옮겼습니다.`;
    }
  } catch (err) {
    console.warn("library load failed", err);
  }
})();
