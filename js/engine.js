import { MORPHS, GENE_META, TRAIT_META, getMorph, allAliases, normalize } from "./morphs.js";

const GENE_KEYS = Object.keys(GENE_META);
const TRAIT_KEYS = Object.keys(TRAIT_META);

export function emptyProfile() {
  const genes = {};
  for (const k of GENE_KEYS) genes[k] = 0;
  const traits = {};
  for (const k of TRAIT_KEYS) traits[k] = 0;
  return { genes, traits, label: "노멀" };
}

export function morphToProfile(morphLike) {
  const base = emptyProfile();
  const morph = typeof morphLike === "string" ? getMorph(morphLike) : morphLike;
  if (!morph) return base;
  Object.assign(base.genes, morph.genes || {});
  Object.assign(base.traits, morph.traits || {});
  base.label = morph.nameKo;
  base.id = morph.id;
  return base;
}

function punnett(copiesA, copiesB) {
  const pair = (n) => (n <= 0 ? [0, 0] : n === 1 ? [1, 0] : [1, 1]);
  const A = pair(copiesA);
  const B = pair(copiesB);
  const counts = { 0: 0, 1: 0, 2: 0 };
  for (const a of A) for (const b of B) counts[a + b] += 1;
  return [0, 1, 2]
    .filter((k) => counts[k] > 0)
    .map((k) => ({ copies: k, p: counts[k] / 4 }));
}

function combineLoci(locusMap) {
  let combos = [{ genes: {}, p: 1 }];
  for (const [locus, outcomes] of Object.entries(locusMap)) {
    const next = [];
    for (const c of combos) {
      for (const o of outcomes) {
        next.push({ genes: { ...c.genes, [locus]: o.copies }, p: c.p * o.p });
      }
    }
    combos = next;
  }
  return combos;
}

function phenotypeName(genes, traits = {}) {
  const warnings = [];
  if ((genes.lillyWhite || 0) === 2) {
    return {
      name: "슈퍼 릴리 화이트",
      lethal: true,
      caution: false,
      image: "lilly-white",
      detail: "치사 유전자. 부화해도 대부분 며칠 내 폐사합니다. 릴리끼리 교배는 하지 마세요.",
      warnings: ["lethal"],
    };
  }
  if ((genes.cappuccino || 0) === 2) {
    warnings.push("super-cap");
  }

  const parts = [];
  const lw = genes.lillyWhite || 0;
  const ax = genes.axanthic || 0;
  const ph = genes.phantom || 0;
  const cap = genes.cappuccino || 0;

  if (lw === 1 && cap === 1 && ax === 2) parts.push("프라푸치노 아잔틱");
  else if (lw === 1 && cap === 1 && ph === 2) parts.push("팬텀 프라푸치노");
  else if (lw === 1 && cap === 1) parts.push("프라푸치노");
  else if (lw === 1 && ax === 2) parts.push("릴리 아잔틱");
  else if (lw === 1 && ph === 2) parts.push("팬텀 릴리");
  else if (cap === 2) parts.push("슈퍼 카푸치노");
  else if (cap === 1 && ph === 2) parts.push("팬텀 카푸치노");
  else if (cap === 1 && ax === 2) parts.push("카푸치노 아잔틱");
  else if (lw === 1) parts.push("릴리 화이트");
  else if (cap === 1) parts.push("카푸치노");
  else if (ax === 2) parts.push("아잔틱");
  else if (ph === 2) parts.push("팬텀");

  if (traits.halloween > 0.55) parts.push("할로윈");
  else if (traits.tricolor > 0.55) parts.push("트라이컬러");
  else if (traits.creamsicle > 0.55) parts.push("크림시클");
  else if (traits.extreme > 0.7 || traits.harlequin > 0.85) parts.push("익스트림 할리퀸");
  else if (traits.harlequin > 0.45) parts.push("할리퀸");
  else if (traits.flame > 0.5) parts.push("플레임");
  if (traits.pinstripe > 0.5) parts.push("핀스트라이프");
  if (traits.dalmatian > 0.85) parts.push("슈퍼 달마시안");
  else if (traits.dalmatian > 0.4) parts.push("달마시안");
  if (traits.tiger > 0.5 && traits.halloween < 0.55) parts.push("타이거");

  if (ax === 1) parts.push("100% het 아잔틱");
  if (ph === 1) parts.push("100% het 팬텀");

  const name = parts.length ? [...new Set(parts)].join(" · ") : "노멀 (유전자 비발현)";
  return {
    name,
    lethal: false,
    caution: cap === 2,
    image: pickImage(genes, traits, parts),
    detail: cap === 2 ? "슈퍼 카푸치노(멜라니스틱)는 콧구멍·척추 기형 위험이 큽니다." : "",
    warnings,
  };
}

function pickImage(genes, traits, parts) {
  const joined = parts.join(" ");
  if (joined.includes("프라푸치노")) return "frappuccino";
  if (joined.includes("릴리 아잔틱")) return "lilly-axanthic";
  if (joined.includes("슈퍼 카푸")) return "cappuccino";
  if ((genes.lillyWhite || 0) === 1) return "lilly-white";
  if ((genes.cappuccino || 0) >= 1) return "cappuccino";
  if ((genes.axanthic || 0) === 2) return "axanthic";
  if ((genes.phantom || 0) === 2) return "phantom";
  if (traits.halloween > 0.55) return "halloween";
  if (traits.tricolor > 0.55) return "tricolor";
  if (traits.creamsicle > 0.55) return "creamsicle";
  if (traits.dalmatian > 0.85) return "super-dalmatian";
  if (traits.dalmatian > 0.4) return "dalmatian";
  if (traits.pinstripe > 0.5) return "pinstripe";
  if (traits.extreme > 0.7) return "extreme-harlequin";
  if (traits.harlequin > 0.45) return "harlequin";
  if (traits.flame > 0.5) return "flame";
  if (traits.tiger > 0.5) return "tiger";
  return "normal";
}

function imagePath(id) {
  const m = getMorph(id) || MORPHS.find((x) => x.id === id);
  if (m) return m.image;
  return `assets/morphs/${id}.jpg`;
}

function patternForecast(a, b) {
  const rows = [];
  const push = (name, p, image, note) => {
    if (p <= 0.02) return;
    rows.push({ name, percent: Math.round(p * 1000) / 10, image, note });
  };

  const avg = (k) => ((a.traits[k] || 0) + (b.traits[k] || 0)) / 2;
  const any = (k) => (a.traits[k] || 0) > 0.2 || (b.traits[k] || 0) > 0.2;
  const both = (k) => (a.traits[k] || 0) > 0.35 && (b.traits[k] || 0) > 0.35;

  if (any("harlequin") || any("extreme") || any("flame")) {
    if (both("extreme") || avg("extreme") > 0.7) {
      push("익스트림 할리퀸", 0.45, "extreme-harlequin", "양쪽 커버리지가 높아 고퀄 패턴 확률이 큽니다.");
      push("할리퀸", 0.4, "harlequin", "");
      push("플레임 / 약한 패턴", 0.15, "flame", "다지성이라 약하게 빠지는 개체도 나옵니다.");
    } else if (both("harlequin") || avg("harlequin") > 0.5) {
      push("할리퀸", 0.55, "harlequin", "다지성 — 정확한 멘델 비율은 아닙니다.");
      push("익스트림 할리퀸", 0.18, "extreme-harlequin", "운 좋게 커버리지가 더 쌓인 경우");
      push("플레임", 0.2, "flame", "");
      push("약한 패턴 / 노멀", 0.07, "normal", "");
    } else if (any("flame") || any("harlequin")) {
      push("플레임 또는 약한 할리퀸", 0.5, "flame", "한쪽만 패턴을 가진 경우의 대략치");
      push("할리퀸", 0.22, "harlequin", "");
      push("무늬 거의 없음", 0.28, "normal", "");
    }
  }

  if (any("pinstripe")) {
    push("핀스트라이프", both("pinstripe") ? 0.82 : 0.52, "pinstripe", "핀은 한 쪽만 있어도 절반 가까이 나오는 편입니다.");
  }
  if (any("dalmatian")) {
    const superish = avg("dalmatian") > 0.8;
    push(superish ? "슈퍼 달마시안" : "달마시안", both("dalmatian") ? 0.78 : 0.48, superish ? "super-dalmatian" : "dalmatian", "점 밀도는 선발로 강해집니다.");
  }
  if (any("halloween")) {
    push("할로윈 (블랙+오렌지)", both("halloween") ? 0.7 : 0.35, "halloween", "노랑·크림이 섞이면 할로윈으로 안 칩니다.");
  }
  if (any("creamsicle")) {
    push("크림시클", both("creamsicle") ? 0.62 : 0.32, "creamsicle", "오렌지 발색은 개체 차가 큽니다.");
  }
  if (any("tricolor")) {
    push("트라이컬러", both("tricolor") ? 0.5 : 0.25, "tricolor", "세 색이 동시에 선명해야 트라이로 봅니다.");
  }
  if (any("tiger")) {
    push("타이거 / 브린들", both("tiger") ? 0.65 : 0.4, "tiger", "");
  }

  rows.sort((x, y) => y.percent - x.percent);
  return rows;
}

export function breed(profileA, profileB) {
  const warnings = [];
  const locusMap = {};
  for (const k of GENE_KEYS) {
    const ca = profileA.genes[k] || 0;
    const cb = profileB.genes[k] || 0;
    if (ca > 0 || cb > 0) locusMap[k] = punnett(ca, cb);
  }

  if ((profileA.genes.lillyWhite || 0) >= 1 && (profileB.genes.lillyWhite || 0) >= 1) {
    warnings.push({
      level: "danger",
      title: "릴리 화이트 × 릴리 화이트",
      text: "슈퍼 릴리 화이트가 25% 나옵니다. 치사 조합이라 브리더들은 이 교배를 하지 않습니다.",
    });
  }
  if ((profileA.genes.cappuccino || 0) >= 1 && (profileB.genes.cappuccino || 0) >= 1) {
    warnings.push({
      level: "warn",
      title: "카푸치노 × 카푸치노",
      text: "슈퍼 카푸치노(멜라니스틱)가 25%입니다. 호흡기·척추 기형 보고가 있어 권장하지 않습니다.",
    });
  }

  const geneResults = [];
  if (Object.keys(locusMap).length === 0) {
    geneResults.push({
      percent: 100,
      ...phenotypeName({ lillyWhite: 0, axanthic: 0, phantom: 0, cappuccino: 0 }, {}),
    });
  } else {
    const combos = combineLoci(locusMap);
    const merged = new Map();
    for (const c of combos) {
      const ph = phenotypeName(c.genes, {});
      const prev = merged.get(ph.name);
      if (prev) prev.percent += c.p * 100;
      else merged.set(ph.name, { ...ph, percent: c.p * 100, genes: c.genes });
    }
    for (const row of merged.values()) {
      row.percent = Math.round(row.percent * 10) / 10;
      geneResults.push(row);
    }
    geneResults.sort((a, b) => b.percent - a.percent);
  }

  const patternResults = patternForecast(profileA, profileB);

  return {
    parentA: profileA.label,
    parentB: profileB.label,
    warnings,
    geneResults: geneResults.map((r) => ({ ...r, imagePath: imagePath(r.image) })),
    patternResults: patternResults.map((r) => ({ ...r, imagePath: imagePath(r.image) })),
    summary: buildSummary(profileA, profileB, geneResults, warnings),
  };
}

function buildSummary(a, b, genes, warnings) {
  const top = genes[0];
  let s = `${a.label} × ${b.label} 교배입니다. `;
  if (top) s += `가장 많이 나오는 표현형은 「${top.name}」약 ${top.percent}%입니다. `;
  if (warnings.length) s += warnings.map((w) => w.text).join(" ");
  else s += "확정 유전자는 멘델 비율로, 할리퀸·핀·달마 같은 패턴은 다지성이라 확률은 대략치입니다.";
  return s;
}

function aliasHitCount(text, morph) {
  const compact = normalize(text);
  let hits = 0;
  for (const a of morph.aliases || []) {
    const alias = normalize(a);
    if (alias.length < 2) continue;
    let idx = compact.indexOf(alias);
    while (idx !== -1) {
      hits += 1;
      idx = compact.indexOf(alias, idx + alias.length);
    }
  }
  return hits;
}

export function findMorphsInText(text) {
  const compact = normalize(text);
  const found = [];
  const used = new Array(compact.length).fill(false);
  for (const { alias, morph } of allAliases()) {
    if (alias.length < 2) continue;
    let idx = compact.indexOf(alias);
    while (idx !== -1) {
      const overlap = used.slice(idx, idx + alias.length).some(Boolean);
      if (!overlap) {
        for (let i = idx; i < idx + alias.length; i++) used[i] = true;
        if (!found.some((f) => f.id === morph.id)) found.push(morph);
      }
      idx = compact.indexOf(alias, idx + 1);
    }
  }
  return found;
}

export function answerQuestion(text) {
  const raw = text.trim();
  if (!raw) return { type: "help" };
  const morphs = findMorphsInText(raw);
  const breedCue = /섞|교배|믹스|mix|×|\bx\b|이랑|랑|와 |붙이|메이팅|브리딩|확률|나오면|끼리/.test(raw);
  const selfCross = /끼리|같은모프|두마리/.test(normalize(raw)) || (morphs.length === 1 && aliasHitCount(raw, morphs[0]) >= 2);

  if (morphs.length >= 2) {
    const result = breed(morphToProfile(morphs[0]), morphToProfile(morphs[1]));
    return { type: "breed", morphs, result };
  }
  if (morphs.length === 1 && (selfCross || (breedCue && /끼리/.test(raw)))) {
    const result = breed(morphToProfile(morphs[0]), morphToProfile(morphs[0]));
    return { type: "breed", morphs: [morphs[0], morphs[0]], result };
  }
  if (morphs.length === 1) {
    return { type: "info", morph: morphs[0] };
  }
  return {
    type: "help",
    message:
      "모프 이름을 두 개 넣어 보세요. 예: 「릴리화이트랑 아잔틱 섞으면?」「카푸치노 x 릴리」「할리퀸이랑 핀스트라이프」",
  };
}

function rgbToHsl(r, g, b) {
  r /= 255;
  g /= 255;
  b /= 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  let h = 0;
  const l = (max + min) / 2;
  const d = max - min;
  const s = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1));
  if (d !== 0) {
    if (max === r) h = ((g - b) / d) % 6;
    else if (max === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    h *= 60;
    if (h < 0) h += 360;
  }
  return { h, s, l };
}

export function analyzePixels(image) {
  const size = 160;
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d", { willReadFrequently: true });
  ctx.drawImage(image, 0, 0, size, size);
  const { data } = ctx.getImageData(0, 0, size, size);

  let white = 0,
    orange = 0,
    yellow = 0,
    dark = 0,
    gray = 0,
    brown = 0,
    satSum = 0,
    lSum = 0,
    lSq = 0,
    n = 0;
  const lum = [];

  const margin = 18;
  for (let y = margin; y < size - margin; y++) {
    for (let x = margin; x < size - margin; x++) {
      const i = (y * size + x) * 4;
      const r = data[i],
        g = data[i + 1],
        b = data[i + 2];
      const { h, s, l } = rgbToHsl(r, g, b);
      n += 1;
      satSum += s;
      lSum += l;
      lSq += l * l;
      lum.push(l);
      if (l < 0.16) dark += 1;
      if (s < 0.18 && l > 0.2 && l < 0.75) gray += 1;
      if (l > 0.72 && s < 0.35) white += 1;
      else if (l > 0.62 && s >= 0.2 && h >= 30 && h <= 70) white += 0.6;
      if (s > 0.28 && l > 0.22 && l < 0.75) {
        if (h < 28 || h > 345) orange += 0.5;
        if (h >= 18 && h < 42) orange += 1;
        if (h >= 42 && h < 72) yellow += 1;
        if (h >= 18 && h < 50 && l < 0.45) brown += 1;
        if (h >= 20 && h < 55 && s < 0.55 && l < 0.5) brown += 0.6;
      }
    }
  }

  let spots = 0;
  for (let y = margin + 1; y < size - margin - 1; y += 2) {
    for (let x = margin + 1; x < size - margin - 1; x += 2) {
      const i = (y * size + x) * 4;
      const { l } = rgbToHsl(data[i], data[i + 1], data[i + 2]);
      if (l > 0.22) continue;
      let lightN = 0;
      const nbs = [
        [0, 2],
        [0, -2],
        [2, 0],
        [-2, 0],
      ];
      for (const [dx, dy] of nbs) {
        const j = ((y + dy) * size + (x + dx)) * 4;
        const nl = rgbToHsl(data[j], data[j + 1], data[j + 2]).l;
        if (nl > 0.42) lightN += 1;
      }
      if (lightN >= 3) spots += 1;
    }
  }

  const meanL = lSum / n;
  const variance = lSq / n - meanL * meanL;
  const contrast = Math.sqrt(Math.max(variance, 0));
  const spotScore = Math.min(1, spots / 90);

  let sharp = 0;
  for (let y = 1; y < size - 1; y += 3) {
    for (let x = 1; x < size - 1; x += 3) {
      const c = data[(y * size + x) * 4];
      const lft = data[(y * size + x - 1) * 4];
      sharp += Math.abs(c - lft);
    }
  }
  sharp = Math.min(1, sharp / 180000);

  const feat = {
    white: white / n,
    orange: orange / n,
    yellow: yellow / n,
    dark: dark / n,
    gray: gray / n,
    brown: brown / n,
    spots: spotScore,
    sat: satSum / n,
    contrast,
    meanL,
    sharp,
  };
  return feat;
}

function morphScore(feat, morph) {
  const s = morph.signature;
  if (!s) return 0;
  const dist =
    (feat.white - s.white) ** 2 * 1.4 +
    (feat.orange - s.orange) ** 2 * 1.3 +
    (feat.yellow - s.yellow) ** 2 * 1.2 +
    (feat.dark - s.dark) ** 2 * 1.1 +
    (feat.gray - s.gray) ** 2 * 1.5 +
    (feat.brown - s.brown) ** 2 +
    (feat.spots - s.spots) ** 2 * 1.6 +
    (feat.sat - s.sat) ** 2;
  return Math.max(0, 1 - Math.sqrt(dist) * 1.15);
}

export function identifyMorph(feat) {
  const scored = MORPHS.filter((m) => m.category !== "het").map((m) => ({
    morph: m,
    score: morphScore(feat, m),
  }));
  scored.sort((a, b) => b.score - a.score);
  const max = scored[0]?.score || 0.01;
  const list = scored.slice(0, 4).map((x) => ({
    ...x,
    confidence: Math.round((x.score / (scored[0].score + scored[1].score + 0.08)) * 100),
  }));
  const total = list.reduce((s, x) => s + x.score, 0);
  list.forEach((x) => {
    x.confidence = Math.round((x.score / total) * 100);
  });
  const geckoLikeness = Math.min(
    1,
    feat.brown * 1.2 + feat.orange * 0.8 + feat.yellow * 0.6 + feat.white * 0.5 + (1 - Math.abs(feat.meanL - 0.42))
  );
  return { top: list[0], alternatives: list.slice(1), all: list, geckoLikeness, lowConfidence: max < 0.42 };
}

export function gradeQuality(feat, morph) {
  let score = 40;
  score += feat.contrast * 90;
  score += feat.sat * 35;
  score += feat.sharp * 25;
  if (morph?.id === "dalmatian" || morph?.id === "super-dalmatian") score += feat.spots * 30;
  if (morph?.id === "harlequin" || morph?.id === "extreme-harlequin") score += feat.white * 25;
  if (morph?.id === "lilly-white" || morph?.id === "frappuccino") score += feat.white * 20;
  if (feat.meanL < 0.12 || feat.meanL > 0.88) score -= 18;
  if (feat.sharp < 0.15) score -= 12;
  score = Math.max(8, Math.min(98, Math.round(score)));

  let label, rank;
  if (score >= 78) {
    label = "매우 좋음";
    rank = "s";
  } else if (score >= 62) {
    label = "좋음";
    rank = "a";
  } else if (score >= 44) {
    label = "보통";
    rank = "b";
  } else {
    label = "안좋음";
    rank = "c";
  }

  const reasons = [];
  if (feat.contrast > 0.16) reasons.push("명암 대비가 또렷합니다");
  else reasons.push("대비가 약한 편입니다");
  if (feat.sat > 0.35) reasons.push("발색이 선명합니다");
  else if (feat.sat < 0.2) reasons.push("채도가 낮아 발색이 밋밋합니다");
  if (feat.sharp > 0.35) reasons.push("피부 텍스처가 선명하게 찍혔습니다");
  if (feat.spots > 0.4) reasons.push("달마시안 점 표현이 분명합니다");
  if (feat.white > 0.3) reasons.push("크림/화이트 커버리지가 넓습니다");

  return { score, label, rank, reasons };
}

const QUALITY_MULT = { s: [1.8, 3.2], a: [1.15, 1.85], b: [0.75, 1.15], c: [0.4, 0.7] };

export function estimatePrice(morph, quality) {
  const base = morph?.price || { min: 80000, max: 250000 };
  const [loM, hiM] = QUALITY_MULT[quality.rank] || QUALITY_MULT.b;
  const min = Math.round((base.min * loM) / 10000) * 10000;
  const max = Math.round((base.max * hiM) / 10000) * 10000;
  const mid = Math.round((min + max) / 2 / 10000) * 10000;
  return { min, max, mid, note: "2026년 한국 분양 시장 대략 시세. 베이비/성체, 성별, 혈통, 브리더에 따라 크게 달라집니다." };
}

export function formatWon(n) {
  return n.toLocaleString("ko-KR") + "원";
}

export { imagePath, MORPHS, getMorph };
