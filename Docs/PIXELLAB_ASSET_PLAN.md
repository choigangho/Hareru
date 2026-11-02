# Hareru × PixelLab 에셋 제작 마스터 플랜 (`PIXELLAB_ASSET_PLAN.md`)

> **문서 목적**: API 토큰을 소모하지 않고 [PixelLab 공식 웹 툴](https://www.pixellab.ai/)에서 직접 에셋을 생성·편집한 뒤, 로컬 폴더에 넣어 Claude Code(또는 개발 파이프라인)에 전달하기 위한 **구체적인 툴 사용법 · 해상도 규격 · 스토리 기반 에셋 제작 체크리스트**입니다.
> **관련 문서**: [`STORY_BIBLE.md`](STORY_BIBLE.md) · [`GAME_DESIGN.md`](GAME_DESIGN.md)
> **최종 업데이트**: 2026-11-02

---

## 1. PixelLab 공식 웹 툴 분석 (처음 쓰는 분을 위한 핵심 요약)

[PixelLab 공식 문서(Ways to Use PixelLab)](https://www.pixellab.ai/docs/ways-to-use-pixellab) 기준으로, API/MCP 토큰을 쓰지 않고 웹 브라우저에서 직접 작업할 때 사용하는 핵심 도구는 아래 **4가지**입니다.

| 웹 도구 이름 | 용도 및 특징 | Hareru에서 쓸 곳 |
| :--- | :--- | :--- |
| **① Characters 페이지** (`Instant Character Creator`) | 텍스트 프롬프트나 레퍼런스 이미지로 **4방향/8방향 회전(Rotation)** 및 **걷기(Walk)·대기(Idle) 애니메이션**을 원클릭 생성 후 스프라이트 시트(PNG)로 다운로드 | 미제작된 **카자마 린(`courier_rin`)** 스프라이트 제작, 주인공/주임 연구원 추가 감정 모션, 과거 회상용 어린 시절 캐릭터 |
| **② PixelLab Pixelorama** (`In-browser Editor`) | 데스크톱 웹 브라우저에서 바로 열리는 오픈소스 픽셀 에디터 + PixelLab AI 통합 환경. **Style Reference(화풍 고정)**, **Inpainting(부분 수정)**, **Create Isometric Tile**, **Create UI Elements** 등 모든 고급 옵션 사용 가능 | **가장 핵심 작업 공간!** 연구소 시설, 렉스코드(QR) 간판, 《애프터썬》 캠코더 소품, 픽셀 UI 프레임 제작 및 손보정 |
| **③ Simple Web Creator** (`Create Page`) | 브라우저에서 빠르게 단일 이미지를 뽑는 경량 생성기 (`BitForge`: 소형 스프라이트/스타일 참조 특화, `PixFlux`: 중대형 장면에 특화) | 캐릭터 대화 초상화(64×64), 스토리 해금 컷신(픽셀 캠코더 화면), 아이템 아이콘 초안 |
| **④ Create Isometric Tile & UI Elements** (Pixelorama 내부 메뉴) | [아이소메트릭 타일 생성기](https://www.pixellab.ai/docs/tools/create-isometric-tile)(32×32 권장, Thick/Thin/Block/Reference 형태 고정) 및 UI 컴포넌트 생성기 | 연구소 2~5단계 바닥/벽 타일셋, `NJL-OS` 고급 픽셀 UI 프레임·버튼·모자이크 배지 |

### 💡 왜 API 대신 "웹에서 직접 생성 → 로컬 전달" 방식이 유리한가?
1. **실시간 눈대중 확인 & 부분 수정(Inpainting)**: 웹 에디터(Pixelorama)에서는 주임 연구원의 안경 1px이나 QR 간판의 도트 모양이 어색할 때 그 부분만 마스킹해서 **Inpaint v3**로 즉시 다시 뽑을 수 있어 실패 크레딧 낭비가 거의 없습니다.
2. **기존 에셋 화풍 100% 고정 (`Style Reference` & `Init Image`)**: 이미 앱에 들어가 있는 `Sources/Hareru/Resources/Art/`의 에셋을 **Style Reference**와 **Target Palette(색상 팔레트 강제)**에 올려두고 뽑으면, 새로 뽑는 에셋도 기존 연구소 화풍과 완벽하게 통일됩니다.
3. **Claude Code 토큰 절약**: 웹에서 완성된 PNG만 `Docs/Art/...` 폴더에 넣어두고 *"새로 넣은 PNG를 앱 번들에 연결해 줘"*라고만 지시하면 코드 작업에만 토큰을 쓸 수 있습니다.

---

## 2. Hareru 전용 PixelLab 설정 표준 (건드리지 말아야 할 황금 규격)

현재 Hareru 코드베이스(`OfficePixelArt.swift`, `PixelFrame.swift`)와 바로 맞물리도록 PixelLab에서 생성할 때 아래 수치를 고정하세요.

- **컬러 팔레트 원칙**:
  - 베이스: 바랜 청록(Desaturated Teal) · 슬레이트 그레이 · 오프화이트 · 딥 네이비(`#141824` 계열)
  - 포인트 컬러: **호박색(Amber Gold)** 1개 + 뉴럴링크/렉스코드 전용 **시안 글리치(Cyan `#00F0FF`)**
  - PixelLab의 `Color -> Target Palette` 옵션에 기존 `Docs/Art/Characters/sprites/chief_researcher_idle_se.png` 또는 `Docs/Art/Environment/v2/` 이미지를 넣으면 색감이 자동으로 맞춰집니다.
- **해상도 규격**:
  - **캐릭터 스프라이트**: `48×48 px` (투명 배경, 발끝이 하단 중앙에 오도록 정렬, `Low top-down` 또는 `Isometric` 뷰 선택 → 남동`SE` / 북서`NW` 방향)
  - **캐릭터 대화 초상화 (Portrait)**: `64×64 px` (또는 표정 변화를 담은 4프레임 시트)
  - **연구소 시설 (1칸짜리)**: 가로 최대 `64 px`, 세로 최대 `72 px` (바닥 아이소메트릭 마름모 비율 2:1 준수)
  - **아이소메트릭 바닥 타일**: `64×38 px` (또는 PixelLab 기본 `32×32` 생성 후 기존 `cast_env_v2.py` 스크립트로 규격 맞춤)
  - **UI 프레임 (9-slice용)**: `24×24 px` 또는 `32×32 px` 모서리 대칭 타일 (`1px = 화면 2pt`)

---

## 3. 스토리 기반 에셋 제작 리스트 & 프롬프트 가이드 (우선순위순)

### Phase 1: 세계관 핵심 연출 에셋 (가장 먼저 만들면 임팩트가 큰 것들)

#### ① 창밖 『렉스코드(QR 매트릭스) 간판 ↔ 복원된 한자 간판』 세트
- **스토리 역할**: 2094년 세상의 문자가 직사각형·정사각형 QR 같은 매트릭스 코드로 대체되었다가, 한자를 복원하면 따뜻한 네온 한자 간판으로 바뀌는 핵심 시각 장치.
- **제작 방법 (Pixelorama → Create S-M Image / Inpaint)**:
  1. 먼저 기존 `Docs/Art/Environment/v2/assets/`에 있는 간판(`sign_bookstore`, `sign_cafe`, `sign_building`)을 **Init Image**로 불러옵니다.
  2. 간판 안쪽 글자 영역만 마스킹한 뒤 **Inpaint**로 *"futuristic monochrome cyan and black rectangular QR matrix code pattern, cyberpunk barcode glyph, pixel art"*를 입력해 **복원 전(렉스코드 상태) 간판 PNG**를 만듭니다.
  3. 이렇게 하면 간판 외곽 프레임은 100% 똑같고 안쪽만 **QR 매트릭스 → 한자 네온**으로 픽셀 모자이크 전환되는 기가 막힌 연출이 가능해집니다!
- **파일명 규칙**: `sign_bookstore_qr.png` ↔ `sign_bookstore_kanji.png`

#### ② 《애프터썬》 & 《빙과》 스토리 핵심 소품 (기억 복원 오브젝트)
- **스토리 역할**: 주인공과 주임 연구원의 어린 시절 기억, 카자마 린 아버지의 서점 유언, 마스터 겐의 레시피 노트를 해금하는 연구소 내 특수 오브젝트 및 이벤트 아이콘.
- **제작할 에셋 목록 (`32×32` 아이콘 및 `64×72` 이하 시설 소품)**:
  1. `prop_camcorder_dv.png`: 낡은 미니 DV 캠코더와 테이프 (주임 연구원 아버지의 여름 휴가 영상 재생기 — **《애프터썬》 핵심 소품**)
  2. `prop_handwritten_resume.png`: 주인공의 첫날 짐 상자 속에 들어있는 **자필 종이 이력서와 모자이크된 한자 쪽지** (A안 입소 명분 핵심 아이템)
  3. `prop_faded_diary.png`: 카자마 린 아버지의 낡은 서점 일기장 (**《빙과》 『もう、あけるな』 에피소드 해금 아이템**)
  4. `prop_recipe_notebook.png`: 마스터 겐 아내의 찻집 레시피 노트
- **프롬프트 예시**:
  > *"isometric pixel art prop, vintage mini DV camcorder resting on a stack of old videotapes, muted teal and warm amber accents, dark outline, transparent background, 48x48"*

#### ③ 미제작 캐릭터: 카자마 린 (`courier_rin`) 4프레임 스프라이트 & 초상화
- **스토리 역할**: 현재 [`Docs/Art/Cast/README.md`](Art/Cast/README.md)에서 유일하게 시트가 비어 있는 2단계 주역(폐허 서점 스쿠터 배달원, 《빙과》 모티프 주인공).
- **제작 방법 (Characters 페이지 또는 Pixelorama)**:
  - **Style Reference**: `chief_researcher_idle_se.png` 또는 `citizen_mio_idle_se.png` 업로드.
  - **프롬프트**: *"chibi isometric pixel art character, energetic female scooter courier with short windswept hair, amber goggles on forehead, weathered courier jacket, carrying old paper book satchel, 48x48"*
  - **방향/모션**: `South-East` Idle 1장, Walk 2장 + `North-West` Idle 1장 (총 4장).

---

### Phase 2: 캐릭터 초상화 표정 차분(감정선 연출) & 《Cytus II》 글리치 에셋

#### ① 주임 연구원 & 주요 인물 표정 변화 초상화 (`64×64 px`)
- 《애프터썬》 특유의 **'겉으로는 웃고 있지만 눈가에 스치는 설명하기 어려운 우울감'**을 표현하기 위해, 기본 표정(`portraits/`)을 PixelLab **Inpaint**로 눈매와 입매만 살짝 바꿔 4가지 표정으로 확장합니다.
  - `chief_portrait_neutral.png` (기본 차분함)
  - `chief_portrait_excited.png` (좋아하는 한자 어원이 나왔을 때 안경이 반짝이는 덕후 텐션)
  - `chief_portrait_melancholy.png` (아버지와 어린 시절 기억을 떠올릴 때 시선을 내린 쓸쓸한 미소)
  - `chief_portrait_glitch.png` (제4의 벽을 넘어 플레이어를 똑바로 응시하는 정면 시선)

#### ② 《Cytus II》 스타일 컷신 / 기억 파편 프레임 (`128×128` 또는 `160×90 px`)
- 학습 중 글리치 오류가 발생하며 3초간 스쳐 지나가는 저해상도 픽셀 컷신 3~4장:
  1. **컷신 1 (여름날의 손바닥)**: 어린 아이의 손바닥 위에 어른의 손가락이 한자 `晴`을 적어주는 픽셀 일러스트 (노을빛 + 캠코더 REC 타임코드 프레임).
  2. **컷신 2 (시술실의 우체통)**: 차가운 청록색 NeuroLex 기억 소거 시술실 복도 끝, 빨간 구식 우체통에 종이 봉투를 넣는 주인공의 뒷모습.
  3. **컷신 3 (꺼진 서점 앞)**: 비 내리는 밤, `렉스코드(QR)`로 바뀌어버린 서점 간판 아래에서 울고 있는 어린 린.

---

### Phase 3: 앱 전체 고급 픽셀 UI (`NJL-OS`) 에셋 키트

Liquid Glass를 걷어내고 단어장·통계·설정 전체를 **동적 픽셀 단말기**로 바꾸기 위해 필요한 UI 에셋입니다 (Pixelorama의 `Create UI Elements` 활용).

| 에셋 분류 | 파일명(예시) | 규격 | 설명 및 동적 연출 결합 방식 |
| :--- | :--- | :--- | :--- |
| **단어 카드 프레임** | `ui_card_frame_9slice.png` | `48×48` (9-slice) | 바랜 종이 질감과 단말기 금속 베젤이 결합된 픽셀 카드 틀. 코드에서 OKLCH 하늘 색조를 테두리 하이라이트에 실시간 곱셈(Multiply/Screen) 블렌딩 |
| **평가 버튼 4종** | `ui_btn_eval_normal/pressed.png` | `32×16` (9-slice) | 눌렀을 때 도트 베젤이 2px 아래로 물리적으로 들어가는 2프레임 버튼 |
| **집중 모드 토글** | `ui_toggle_exam_mode.png` | `32×16` | 수험생용 **『시험 대비 집중 모드』**를 켜고 끄는 아날로그 레버/스위치 스프라이트 |
| **글리치/제4의벽 아이콘** | `ui_icon_memory_leak.png` | `16×16` / `24×24` | 통계 탭의 손상된 잔디 칸이나 미확인 스토리 보관함(`Archive Queue`)에 깜빡이는 호박색/시안색 경고 픽셀 아이콘 |

---

## 4. 작업 전달 워크플로우 (사용자 → Claude Code / 에이전트)

1. **PixelLab 웹에서 생성 & 다운로드**: 위 규격대로 만든 PNG 파일들을 로컬의 임시 폴더(예: `Docs/Art/Inbox/`)에 그냥 모아둡니다.
2. **배경 제거 및 격자 정렬은 코드에 맡기기**: 만약 PixelLab에서 뽑은 이미지에 단색 배경이 섞여 있거나 여백이 안 맞아도 일일이 손으로 자를 필요 없이, 기존에 만들어 둔 파이프라인(`Docs/Art/Cast/cast_env_v2.py` 등)처럼 에이전트에게 *"Inbox에 넣은 에셋들 여백 맞추고 번들에 등록해 줘"*라고 시키면 토큰을 거의 쓰지 않고 자동 처리됩니다.
3. **모션·글리치·픽셀 모자이크는 100% 코드(Shader/Canvas)로 구현**:
   - QR 픽셀 모자이크가 10초 동안 글자로 풀리는 연출이나 《Cytus II》 스타일 화면 노이즈는 에셋을 여러 장 뽑을 필요 없이, **SwiftUI/SpriteKit 셰이더와 동적 애니메이션 코드로 구현**해야 용량도 작고 60fps로 훨씬 고급스럽게 움직입니다.
