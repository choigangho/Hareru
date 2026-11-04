# 연구소 시작 인원 2명 — 캐릭터 에셋

## v2 — Pixellab (2026-11-02) — ❌ 채택 안 함, 기록만 남김

> 사용자 판단 (2026-11-02): 톤이 안 맞고 실사 비율이라 v1보다 못함. **앱은 v1 스프라이트(아래 `sprites/`, 3등신·바랜 색감)로 되돌림.**
> 주임 연구원은 더 귀엽고 예쁜 방향으로 다시 만들 예정. 이 정도 완성도를 Pixellab으로 내려면 유료 플랜이 필요하다는 판단.
> 남은 것: 원본 `pixellab/`, 미리보기 `previews/*_pixellab_x6.png`, 변환 스크립트 `tools/pixellab_import.py`(재사용 가능),
> 그리고 코드의 가변 걷기 프레임 로딩(`walk_se_a`부터 있는 만큼 — 2프레임 v1도 그대로 동작).

Pixellab MCP `create_character`(mode `v3`, 48×48, low top-down, 8방향)로 다시 만듦. 걷기는 `animate_character` 템플릿 `walking-6-frames`(남동 1방향, 6프레임).
출연진 9인도 같은 설정·같은 프롬프트 꼬리말로 만들어 화풍·비율을 맞춤 → `Docs/05_Art/Cast/README.md`.

- 공통 프롬프트 꼬리말: `near-future decaying research institute, muted faded teal grey and off-white palette, single amber accent, no logos`
- `pixellab/characters.json` — 이름 → Pixellab character id (11명 전원). 다시 받거나 방향·애니메이션을 더 만들 때 씀.
- `pixellab/<name>/` — Pixellab 원본 (8방향 `rotations/`, `animations/walk/south-east/frame_00N.png`).
- `tools/pixellab_import.py` — 원본 받기 → 앱 규격으로 저장: `<name>_idle_se`(남동) · `_idle_nw`(북서) · `_walk_se_a`~`_f`(걷기 6프레임). 같은 묶음은 같은 만큼만 내려 가장 낮은 발이 48행에 닿게 정렬(걷기 흔들림 보존).
  `python3 tools/pixellab_import.py pixellab/characters.json <raw_dir> Sources/Hareru/Resources/Art/Characters <previews_dir> [name ...]`
- `previews/preview_<name>_pixellab_x6.png` — 서기(남동) · 걷기 6프레임 · 뒷모습(북서), 6배 확대.
- 코드: `OfficePixelArt.characterFrames`가 `walk_se_a`부터 있는 만큼 걷기 프레임을 읽음 (2프레임 옛 에셋도 그대로 동작).

| 인물 | 프롬프트 요점 |
| :--- | :--- |
| `chief_researcher` (주임 연구원) | 남색 단발 · 동그란 안경 · 팔꿈치 덧댄 낡은 오프화이트 가운 · 검은 터틀넥 · **호박색 포스트잇**이 빽빽한 종이 사전 |
| `newcomer` (플레이어) | 성별 중립 · 갈색 부스스한 머리 · 약간 큰 새 가운 · 귀 뒤 청록 뉴럴링크 포트 · **호박색 연수생 ID** |

### 생성 기록 (Pixellab 체험판, 40 생성 중)
- 캐릭터 v3 48px: 2 생성 × 11명 = 22. 걷기 템플릿: 1 생성 × 10명 = 10.
- ✅ `courier_rin` 도보 버전 재생성 완료 (2026-11-02, id `c2ee258d-8aaa-4e58-b44f-e1145abe9bc9`): "standing on foot, no vehicle, no scooter"로 v3 8방향 재생성 후 `Sources/Hareru/Resources/Art/Characters/courier_rin_idle_se.png` · `courier_rin_idle_nw.png` 반영 완료 (남동 6프레임 걷기 모션만 1 생성으로 추가 대기).
- ⚠️ `announcer_ai`(이전 id `aa0afd95-6d56-4632-b5c1-24d31263fda7`): 무료 등급 대기열에서 서버 측 `Generation failed` 처리됨(크레딧 자동 환불) → 앱에는 v1 스프라이트(2프레임) 유지, 재시도 시 `create_character` v3(2 생성) 필요.
- ✅ 스토리 핵심 소품 5종 (`Docs/05_Art/Environment/v2/assets/`, 2026-11-02 Pixflux 아이소메트릭 생성 완료):
  - `prop_camcorder_dv.png` (48×48): 《애프터썬》 미니 DV 캠코더와 비디오테이프
  - `sign_lexcode_qr.png` (48×64): 2094년 『렉스코드(QR 매트릭스 문자)』 거리 간판
  - `prop_handwritten_resume.png` (48×48): 주인공의 첫날 짐 상자와 자필 종이 이력서·모자이크 쪽지
  - `prop_faded_diary.png` (48×48): 카자마 린 아버지의 낡은 서점 일기장과 만년필
  - `prop_recipe_notebook.png` (48×48): 마스터 겐 아내의 구식 찻집 레시피 노트와 찻잔
- 초상화(`portraits/`)는 이번에 갱신하지 않음 — 기존 Higgsfield 초안 유지. Pixellab로 바꾸려면 Pro Flash 64×64 1장당 5 생성.
- 알려진 점: 걷기 템플릿은 남동보다 약간 정면(남) 쪽으로 돌아 보이는 프레임이 있음. 체험판은 동시 작업 1개만 허용 (현재 잔여 크레딧 `1.90` 생성).

---

## v1 — Higgsfield 초안 (2026-11-01, 현재 앱 버전)

Higgsfield(Nano Banana 2, `nano_banana_flash`)로 만든 **AI 초안**을 손 보정해 앱에 넣음 (2026-11-01) — 번들 사본은 `Sources/Hareru/Resources/Art/Characters`, 여기 `sprites/`는 같은 보정본. 사무실 장면에서는 캐릭터 픽셀을 방 픽셀의 절반 크기로 그림 (GAME_DESIGN §9.2 4차).

| 인물 | 화면 표기 | 디자인 요점 |
| :--- | :--- | :--- |
| `chief_researcher` | **주임 연구원 (主任研究員)** | 남색 단발 · 동그란 안경 · 팔꿈치를 덧댄 낡은 흰 가운 · 검은 터틀넥 · 포스트잇이 빽빽한 종이 사전 · 만년필. 혼자 연구소를 지켜 온 사람. |
| `newcomer` | **신입 연구원 (주인공 = 플레이어)** | 성별 중립 · 갈색 부스스한 머리 · 아직 큰 새 가운 · 귀 뒤 청록색 뉴럴링크 포트(뉴럴링크 세대) · 연수생 ID · 첫날 짐 상자. |

근미래 쇠퇴 분위기는 색과 소품으로: 바랜 청록·회색·오프화이트 위주 + 인물별 호박색 포인트 1개, 덧댄 가운·옛 사원증(주임) vs 빳빳한 새 가운·뉴럴링크(신입).

## 파일

- `source/concept_v1.png` — 두 인물 설정화 (1264×848, 마젠타 배경). 대화 초상화의 원본.
- `source/sprite_sheet_v1.png` — 위 설정화를 참조로 만든 2.5등신 스프라이트 시트 (행: 주임/신입, 열: 서기·걷기A·걷기B (남동향) · 뒷모습(북서향)).
- `sprites/` — 실제 픽셀 격자로 줄인 48×48 프레임 (투명 배경, 발 기준 하단 정렬) + 4프레임 가로 스트립.
- `portraits/` — 64×64 대화 초상화 (§9.1 규격).
- `previews/` — 확대 미리보기 (어두운 배경, 최근접 확대).
- `tools/pixelize.py` — 마젠타 제거 → 칸 자르기 → 블록 최빈색 축소 → 팔레트 양자화. `python3 pixelize.py <sheet> <concept> <out_dir>` → `python3 touchup.py <sprites_dir> <out_dir>` (Pillow · numpy 필요).

## 알려진 한계 (손 보정 필요)

- **48px 규격**: 원본 그림의 '픽셀 한 칸'이 약 8px이라 실제 해상도가 ~48px. 32px로 줄이면 얼굴과 안경이 사라짐. → **48×48을 캐릭터 규격으로 확정** (2026-11-01, GAME_DESIGN §9.1).
- ✅ 마젠타 번짐 픽셀 정리 · 주임 연구원 안경 1px 테+렌즈 하이라이트 (`tools/touchup.py`, 앞모습 3장). 첫 서기 프레임은 안경이 약하게 보여 추가 손질 여지 있음.
- 가운 안쪽의 어두운 점 노이즈는 남아 있음 (축소 과정에서 생긴 음영).
- 걷기는 2프레임뿐이고 방향은 남동·북서 2개. 아이소메트릭 1방향 고정(§9.1)이면 남동 걷기 + 좌우 반전으로 충분.

## 생성 기록

- 모델: Nano Banana 2 (무료 플랜에서는 GPT Image 2.5 사용 불가). 사용 크레딧: 설정화 1.5 + 스프라이트 시트 1.5 = 3.
- 다음 후보: AutoSprite(`autosprite`, `iso_walk_southeast` 등)로 아이소메트릭 걷기 애니메이션 — 1회 2크레딧.
