# CREHOONI

크레스티드게코(*Correlophus ciliatus*) 모프를 **사진으로 식별**하고, 두 부모의 **교배 결과를 예측**하고,
**모프 도감**을 찾아보는 앱입니다.

Flutter 하나로 **iOS · Android · Web**을 모두 빌드합니다. 웹은 GitHub Pages로 자동 배포되고,
데이터·인증·스토리지는 Supabase를 씁니다.

이전 바닐라 JS 웹 버전은 [`legacy-web/`](legacy-web/)에 그대로 보관해 두었습니다.

---

## 화면 구성

| 탭 | 하는 일 |
| --- | --- |
| **모프 식별** | 사진을 올리면 색·패턴 분석 + CLIP 딥러닝 비교로 모프를 추정하고, 퀄리티 점수와 예상 시세까지 보여 줍니다. 참고 사진을 도감에 기여할 수도 있습니다. |
| **교배 AI** | 부모 두 마리를 고르면 확정 유전자는 멘델 비율로, 패턴은 다지성 근사치로 자손 확률을 계산합니다. 한국어로 자유롭게 물어보는 채팅도 있습니다. |
| **모프 도감** | 내장 18종과 공유된 참고 사진을 분류별로 모아 봅니다. |

### 유전 규칙

내장 로직은 공개된 크레스티드게코 유전 규칙을 따릅니다.

- **릴리 화이트** — 불완전 우성. 슈퍼폼(유전자 2개)은 **치사**라 릴리 × 릴리 교배에 경고를 띄웁니다.
- **아잔틱 · 팬텀** — 열성. 비주얼이 나오려면 유전자가 2개 필요합니다.
- **카푸치노** — 불완전 우성. 슈퍼 카푸(멜라니스틱)는 기형 위험이 있어 경고합니다.
- **할리퀸 · 핀스트라이프 · 달마시안 등 패턴** — 다지성이라 확률은 **대략치**입니다.

---

## 빠르게 실행하기

```sh
flutter pub get

# Supabase 없이도 실행됩니다 (내장 도감 18종 · 오프라인 색·패턴 분석)
flutter run

# 웹으로 실행
flutter run -d chrome
```

Supabase까지 붙이려면 키를 `--dart-define`으로 넘깁니다.

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhb...
```

> 키를 넘기지 않으면 앱은 **오프라인 모드**로 실행됩니다. 내장 도감·교배 계산·색 기반 식별은
> 모두 동작하고, 참고 사진 공유와 CLIP 비교만 꺼집니다.

### 키를 매번 입력하지 않기

`--dart-define-from-file`을 쓰면 편합니다. [`env.example.json`](env.example.json)을 복사해서 채우세요.
`env.json`은 **커밋되지 않습니다** (`.gitignore`에 이미 있습니다).

```sh
cp env.example.json env.json   # 값을 채운 뒤
flutter run --dart-define-from-file=env.json
```

---

## Supabase 설정

`supabase/` 폴더에 마이그레이션과 엣지 함수가 들어 있습니다.

```
supabase/
├── migrations/
│   ├── 20260814000001_reference_photos.sql   # 테이블 · RLS · pgvector
│   ├── 20260814000002_storage_bucket.sql     # 스토리지 버킷 · 정책
│   └── 20260814000003_match_morphs.sql       # 유사도 검색 RPC
├── functions/clip-embed/index.ts             # CLIP 임베딩 · 유사도 검색
└── scripts/seed_catalog_embeddings.mjs       # 내장 18종 임베딩 시딩
```

### 1. 마이그레이션 적용

```sh
supabase link --project-ref <project-ref>
supabase db push
```

대시보드의 SQL Editor에 `supabase/migrations/` 파일을 순서대로 붙여 넣어도 됩니다.

### 2. 익명 로그인 켜기

**Dashboard → Authentication → Sign In / Providers → Anonymous sign-ins** 를 활성화합니다.

참고 사진을 올릴 때 `auth.uid()`가 필요합니다. 회원가입 화면 없이 기기마다 고유 ID를 발급해
**본인이 올린 사진만 삭제**할 수 있게 RLS로 제한합니다.

이 스위치가 꺼져 있으면 앱은 실행되고 도감·교배·색 기반 식별까지 정상 동작하지만, 로그에
`anonymous_provider_disabled`가 찍히고 참고 사진 추가만 막힙니다.

### 3. (선택) CLIP 딥러닝 비교 켜기

이 단계를 건너뛰어도 앱은 **기기에서 색·패턴만으로** 모프를 추정합니다. 정확도를 올리고 싶을 때
켜면 됩니다.

```sh
# Hugging Face 추론 토큰 등록
supabase secrets set HF_TOKEN=hf_xxxxx

# 엣지 함수 배포
supabase functions deploy clip-embed

# 내장 18종 참고 사진 임베딩 시딩 (한 번만)
SUPABASE_URL=https://xxxx.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=eyJhb... \
node supabase/scripts/seed_catalog_embeddings.mjs
```

시딩을 하지 않으면 비교 대상이 없어 CLIP 경로가 자동으로 꺼집니다.

`clip-embed` 함수가 지원하는 동작:

| action | 하는 일 |
| --- | --- |
| `identify` | 올린 사진을 임베딩해 모프별 유사도를 반환 |
| `index` | 새로 올라온 참고 사진 하나를 임베딩해 저장 |
| `backfill` | 임베딩이 없는 참고 사진들을 일괄 처리 |
| `catalog` | 내장 도감 사진 임베딩 시딩 (service role 필요) |

---

## 웹 배포 (GitHub Pages)

`main`에 푸시하면 [`.github/workflows/pages.yml`](.github/workflows/pages.yml)이
포맷 검사 → 정적 분석 → 테스트 → 웹 빌드 → Pages 배포까지 자동으로 수행합니다.

**한 번만 해 둘 설정:**

1. **Settings → Pages → Source**를 `GitHub Actions`로 변경
2. **Settings → Secrets and variables → Actions**에 리포지터리 시크릿 추가
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`

시크릿을 넣지 않아도 배포는 되지만, 배포된 웹은 오프라인 모드로 동작합니다.

> anon key는 클라이언트에 노출되어도 되는 공개 키입니다. 실제 데이터를 지키는 것은 RLS 정책입니다.
> **service role key는 절대 앱이나 시크릿에 넣지 마세요** — 시딩 스크립트에서 로컬로만 씁니다.

base href는 리포지터리 이름(`/cremorph/`)으로 자동 설정됩니다.

---

## 모바일 빌드

```sh
# iOS
flutter build ipa --dart-define-from-file=env.json

# Android
flutter build appbundle --dart-define-from-file=env.json
```

Android 빌드 전 `cmdline-tools`가 필요합니다.

```sh
sdkmanager --install "cmdline-tools;latest"
flutter doctor --android-licenses
```

릴리스 빌드는 지금 **디버그 키로 서명**됩니다. Play 스토어에 올리기 전에 업로드 키를 만들고
`android/key.properties`를 추가한 뒤 `android/app/build.gradle.kts`의 `signingConfig`를 바꿔 주세요.
iOS는 Xcode에서 팀·프로비저닝 프로파일을 지정해야 `flutter build ipa`가 서명까지 마칩니다.

---

## 코드 구조

```
lib/
├── main.dart                       앱 진입점 · Supabase 초기화
├── core/
│   ├── theme.dart                  css/app.css의 디자인 토큰을 그대로 옮긴 테마
│   └── config.dart                 빌드 시점에 주입되는 Supabase 설정
├── data/
│   ├── morph_catalog.dart           내장 18종 · 유전자/패턴 메타데이터
│   ├── models/                      Morph · ImageFeatures · Breeding · ReferencePhoto
│   ├── supabase_service.dart        연결 · 익명 세션
│   └── reference_photo_repository.dart  공유 도감 읽기/쓰기 · 카탈로그 병합
├── domain/
│   ├── genetics.dart                Punnett · 표현형 · 패턴 예측
│   ├── morph_nlp.dart               한국어 질문 파싱
│   ├── image_analysis.dart          160×160 색·패턴 분석
│   ├── morph_scoring.dart           유사도 점수 · 순위 계산
│   ├── quality.dart                 퀄리티 등급 · 시세 추정
│   └── identification_service.dart  오프라인 + CLIP 하이브리드 식별
├── state/providers.dart             Riverpod 상태
└── ui/
    ├── app_shell.dart               탭 · 헤더 · 배경
    ├── identify/ · breed/ · gallery/
    └── widgets/                     공용 컴포넌트
```

### 웹 버전에서 무엇이 어떻게 옮겨졌는지

| 이전 (`legacy-web/`) | 지금 |
| --- | --- |
| `js/morphs.js` | `lib/data/morph_catalog.dart` |
| `js/engine.js` 유전 로직 | `lib/domain/genetics.dart` |
| `js/engine.js` 한국어 NLP | `lib/domain/morph_nlp.dart` |
| `js/engine.js` `analyzePixels` | `lib/domain/image_analysis.dart` |
| `js/engine.js` 퀄리티·시세 | `lib/domain/quality.dart` |
| `js/vision.js` 브라우저 CLIP (WASM, 80MB) | `supabase/functions/clip-embed` + pgvector |
| `js/library.js` IndexedDB | Supabase Postgres + Storage |
| `js/github-store.js` GitHub 토큰 | Supabase 익명 인증 + RLS |
| `css/app.css` | `lib/core/theme.dart` + `lib/ui/widgets/` |
| `server.py` 로컬 API | 불필요 (Supabase가 대체) |

**모바일에서 CLIP을 어떻게 처리했는지:** 기존 웹 버전은 브라우저에서 CLIP ViT-B/32를 WASM으로
돌렸습니다. 폰에서 80MB 모델을 내려받게 하는 건 현실적이지 않아, 하이브리드로 바꿨습니다.

1. **항상** 기기에서 색·패턴 분석을 돌립니다 (오프라인, 즉시, 기존 폴백 로직과 동일).
2. 서버가 켜져 있으면 CLIP 임베딩 유사도를 받아 **0.82 : 0.18** 비율로 재정렬합니다.

2단계는 순수한 업그레이드라서, 실패하더라도 1단계 결과가 그대로 남습니다.

---

## 개발 명령어

```sh
flutter analyze                                  # 정적 분석
flutter test                                     # 단위 테스트
dart format lib test                             # 포맷
flutter build web --release --base-href="/cremorph/"
```

테스트는 두 층으로 나뉩니다.

- **도메인 로직** — 유전 계산(324가지 교배 조합의 확률 합이 100%인지 포함), 한국어 파싱,
  픽셀 분석, 유사도 점수, 카탈로그 병합.
- **화면** (`test/app_shell_test.dart`) — 폰·와이드 두 레이아웃에서 세 탭이 모두 그려지는지,
  교배 예측·채팅 답변·도감 필터·상세 시트가 실제로 동작하는지.

---

## 한계

- 퀄리티 점수와 시세는 **사진 상태**에 크게 좌우됩니다. 참고용 지표로만 보세요.
- 패턴(할리퀸·핀·달마) 확률은 다지성이라 멘델 비율이 아닌 **근사치**입니다.
- 사진 속 개체의 **건강·성별은 판정하지 않습니다**.
- 식별용으로 올린 사진은 기기에만 남습니다. 참고 사진으로 직접 등록할 때만 공유됩니다.
- 웹 첫 로딩은 CanvasKit 런타임과 한글 폰트(Pretendard 3종 · 약 4.5MB) 때문에 가볍지 않습니다.
  한 번 받으면 캐시되지만, 첫 화면이 뜰 때까지 잠깐 로딩 화면이 보입니다.
