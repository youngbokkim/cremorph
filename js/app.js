import { MORPHS, getMorph } from "./morphs.js";
import {
  analyzePixels,
  identifyMorph,
  gradeQuality,
  estimatePrice,
  formatWon,
  breed,
  morphToProfile,
  answerQuestion,
} from "./engine.js";

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

  const load = (f) => {
    if (!f || !f.type.startsWith("image/")) return;
    const url = URL.createObjectURL(f);
    const img = new Image();
    img.onload = () => {
      preview.src = url;
      preview.hidden = false;
      drop.classList.add("has-img");
      onReady(img, url);
    };
    img.src = url;
  };

  file.addEventListener("change", () => load(file.files[0]));
  drop.addEventListener("dragover", (e) => {
    e.preventDefault();
  });
  drop.addEventListener("drop", (e) => {
    e.preventDefault();
    load(e.dataTransfer.files[0]);
  });
}

function wait(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

let idImage = null;
let valImage = null;

bindDrop("id-drop", "id-file", "id-preview", (img) => {
  idImage = img;
  $("id-run").disabled = false;
});
bindDrop("val-drop", "val-file", "val-preview", (img) => {
  valImage = img;
  $("val-run").disabled = false;
});

function morphHero(morph, kicker, extra = "") {
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
        </div>
        ${extra}
      </div>
    </article>`;
}

function renderIdentify(feat) {
  const id = identifyMorph(feat);
  const morph = id.top.morph;
  const q = gradeQuality(feat, morph);
  const price = estimatePrice(morph, q);
  const warn = id.lowConfidence
    ? `<div class="warn">후보 점수가 낮습니다. 게코가 작게 찍혔거나 조명이 강해 다른 모프일 수 있습니다.</div>`
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
    ${warn}
    ${morphHero(morph, "가장 가까운 모프")}
    <div>
      <div class="kicker" style="margin-bottom:8px">다른 가능성</div>
      <div class="alt-list">${alts}</div>
    </div>
    <div class="quality">
      <div class="stamp ${q.rank}">${q.label}<br>${q.score}</div>
      <div>
        <div class="price">${formatWon(price.min)} – ${formatWon(price.max)}
          <small>추정 시세 · 중간값 ${formatWon(price.mid)} · ${price.note}</small>
        </div>
      </div>
    </div>`;
}

$("id-run").addEventListener("click", async () => {
  if (!idImage) return;
  $("id-wait").classList.add("show");
  $("id-run").disabled = true;
  await wait(900);
  const feat = analyzePixels(idImage);
  renderIdentify(feat);
  $("id-wait").classList.remove("show");
  $("id-run").disabled = false;
});

function fillSelects() {
  const html = MORPHS.map((m) => `<option value="${m.id}">${m.nameKo} · ${m.nameEn}</option>`).join("");
  $("parent-a").innerHTML = html;
  $("parent-b").innerHTML = html;
  $("parent-a").value = "lilly-white";
  $("parent-b").value = "axanthic";
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
  const ma = getMorph($("parent-a").value);
  const mb = getMorph($("parent-b").value);
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
    addMsg(
      "bot",
      `${morphHero(m, "모프 정보")}<p style="margin-top:10px">시세 구간 ${formatWon(m.price.min)} – ${formatWon(m.price.max)}. 다른 모프와 섞은 결과가 필요하면 이름을 하나 더 적어 주세요.</p>`
    );
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

$("gallery-grid").innerHTML = MORPHS.map(
  (m) => `
  <article class="g-card" data-id="${m.id}">
    <img src="${m.image}" alt="${m.nameKo}" />
    <div class="pad">
      <div class="en">${m.nameEn}</div>
      <h3>${m.nameKo}</h3>
      <p>${m.look}</p>
    </div>
  </article>`
).join("");

$("gallery-grid").addEventListener("click", (e) => {
  const card = e.target.closest(".g-card");
  if (!card) return;
  const m = getMorph(card.dataset.id);
  $("modal-card").innerHTML = `
    <img src="${m.image}" alt="${m.nameKo}" />
    <div class="pad">
      <div class="kicker">${m.inheritanceKo}</div>
      <h3>${m.nameKo}</h3>
      <div class="en">${m.nameEn}</div>
      <p style="margin:12px 0;line-height:1.6">${m.description}</p>
      <div class="badge-row">
        <span class="badge">${m.look}</span>
        <span class="badge">${formatWon(m.price.min)} – ${formatWon(m.price.max)}</span>
      </div>
      <button class="btn ghost" id="close-modal" style="margin-top:16px">닫기</button>
    </div>`;
  $("modal").classList.add("open");
});

$("modal").addEventListener("click", (e) => {
  if (e.target.id === "modal" || e.target.id === "close-modal") $("modal").classList.remove("open");
});

$("val-run").addEventListener("click", async () => {
  if (!valImage) return;
  $("val-wait").classList.add("show");
  $("val-run").disabled = true;
  await wait(1000);
  const feat = analyzePixels(valImage);
  const id = identifyMorph(feat);
  const morph = id.top.morph;
  const q = gradeQuality(feat, morph);
  const price = estimatePrice(morph, q);
  const reasons = q.reasons.map((r) => `<li>${r}</li>`).join("");
  $("val-result").innerHTML = `
    ${morphHero(morph, "추정 모프 기준 감정")}
    <div class="quality">
      <div class="stamp ${q.rank}">${q.label}<br>${q.score}점</div>
      <div>
        <div class="price">${formatWon(price.mid)}
          <small>추정 구간 ${formatWon(price.min)} – ${formatWon(price.max)}</small>
        </div>
      </div>
    </div>
    <ul class="reasons">${reasons}</ul>
    <p class="sub" style="margin-top:12px">${price.note} 등급 기준: 78+ 매우 좋음 · 62+ 좋음 · 44+ 보통 · 그 아래 안좋음.</p>
  `;
  $("val-wait").classList.remove("show");
  $("val-run").disabled = false;
});
