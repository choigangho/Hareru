# 연구소 환경 에셋 (2026-11-01)

Higgsfield(Nano Banana 2)로 만든 AI 초안 → 픽셀 격자로 축소. 앱 번들 사본은 `Sources/Hareru/Resources/Art/Environment`.
밀도: **방 픽셀 1칸 = 에셋 2칸** (캐릭터와 같음). 캐릭터 설정화(`Docs/Art/Characters/source/sprite_sheet_v1.png`)를 참조 이미지로 넣어 화풍을 맞춤.

| 파일 | 쓰임 |
| :--- | :--- |
| `facility_researcher_desk` · `kanji_archive` · `copy_room` · `recording_booth` · `server_rack` | 시설 5종. 폭 64(= 타일 1칸) 이하, 키 72 이하(방 기준 36px = 캐릭터 1.5배). 바닥 = 발판의 아래 꼭짓점 |
| `prop_plant` · `prop_bucket` · `prop_vending_machine` · `prop_cables` · `prop_boxes` | 벽가 장식 소품 (`OfficePixelArt.decorPlacements`) |
| `texture_floor` · `texture_wall` (76×48) | 평평한 마루·벽 텍스처 — 코드가 아이소메트릭 면에 투영해 이어 깔음 |
| `assets/facility_spare_*` | 앱에 안 넣은 여분 (책 테이블, 두 번째 서버 랙) — 시설 추가 시 후보 |

## 생성 기록
- `source/facilities_v1.png` — 시설 시트 (1.5 크레딧), `source/env_props_v1.png` — 텍스처 + 소품 시트 (1.5 크레딧). 남은 크레딧 2.5 (무료 플랜).
- 자판기 측면에 실제 음료 브랜드를 닮은 로고가 생성되어 **측면 패널의 채도 높은 픽셀을 모두 패널 색으로 덮음** (`tools/env_pixelize.py`). 새로 만들 때도 실존 브랜드·상표가 들어가지 않았는지 확인할 것.
- 녹음 부스의 「ON AIR」 글자는 축소 후 판독 불가 수준의 픽셀 덩어리.

## 처리
`tools/env_pixelize.py <facilities.png> <env_props.png> <out_dir>` — 마젠타 제거 → 연결 성분으로 오브젝트 분리 → 블록 최빈색 축소 → 팔레트 양자화 → 미리보기(`previews/`).

---

# 1막(N5) P1 소품 — 직접 그림 (2026-11-03, 생성 크레딧 0)

근거: `Docs/Art/N5_ASSET_LIST.md` §4 · 장면 비고 `Docs/Story/lines/N5_D1.md` · `N5_D2.md`. **아직 앱에 연결하지 않음.**
- 스크립트: `tools/n5_props.py <out_dir> <prop_bucket.png>` → `python3 tools/n5_props.py source/n5_props ../../../Sources/Hareru/Resources/Art/Environment/prop_bucket.png`
- 원본: `source/n5_props/` (19장) · 크기와 쓰임: `source/n5_props/n5_props_manifest.json`
- 전체 미리보기(스토리 UI와 한 장): `Docs/Art/UI/previews/preview_n5_p1_sheet.png`
- **글자는 글꼴 없이 획 좌표로 직접 찍음** (採用通知 · 常駐人員 · 言 · きみはらめろ · 출근일 오늘 · ？). 시스템 글꼴을 그림에 굳히면 라이선스 문제가 생길 수 있어서. 손글씨는 seed 고정 흔들림.
- `insert_*` = 확대 인서트 컷(정면, 장면 위에 띄움) · `prop_*` = 방 안 소품(에셋 밀도 2배, 기존 `prop_*` 화풍).
- 모자이크는 정지 그림용 덩어리만 그림 — 한 칸씩 풀리는 해독 · 번역 레이어 깨짐은 코드.

| 파일 | 크기 | 장면 · 쓰임 |
| :--- | :--- | :--- |
| `insert_notice_saiyou` | 68×88 | D1-019 「採用通知」 — 기관명 모자이크, 활자 줄은 읽히지 않음, 파란 펜 손글씨 「출근일: 오늘」 + 밑줄, 붉은 직인(안은 모자이크), 그림자 포함 |
| `insert_box_open` | 64×56 | D1-342 짐 상자 — 청록 머그 · 충전기와 감긴 선 · 바닥에 접힌 종이 |
| `insert_memo` | 84×28 | D1-345 쪽지 — 연필 「きみは、[■]らめろ」, [■] 모자이크, 찢은 위 가장자리 · 접은 자국 — **옛 문구** (2026-11-04 「ぜんぶ あきらめろ」 전부 히라가나로 바뀜, 새 확대 컷 `Inbox/set8_closeups/memo_closeup_kana.png`) |
| `insert_memo_file` | 92×36 | D1-357 · D2-200 투명 파일에 꽂힌 쪽지 (반투명 PNG, 반사 줄) |
| `prop_memo_masked` | 18×11 | 신입 책상 위 상시 소품 — 책상에 눕힌 투명 파일 속 쪽지 |
| `insert_mug_new` / `insert_mug_old` | 24×24 | D1-414 머그 둘 — 새것(청록 띠) / 이 나간 낡은 것(바랜 해 하나 · 손잡은 사람 둘 · 얼룩) |
| `insert_board_resident_1` / `_2` | 68×30 | D1-135 벽 게시판 「常駐人員: 1」 / 1을 손으로 지운 번짐 + 서툰 분필 「2」 |
| `prop_desk_lamp_off` / `_on` | 26×28 | 책상 스탠드 — 꺼짐 / 노란 전구 + 반투명 빛무리 (D1-802 · D1-900 · D2-100) |
| `prop_ceiling_patch` / `_loose` | 30×26 | D1-312 천장 물 자국 위 X자 테이프 / R4 한 줄이 떨어져 매달림 + 물방울 |
| `prop_bucket_overflow` | 기존+18×6 | D1-308 넘친 양동이 — 기존 `prop_bucket` 입구를 물로 채우고 옆으로 흐르는 줄기 · 웅덩이 |
| `prop_whiteboard` / `_curve` | 64×58 | 이동식 화이트보드 / D2-308~314 망각 곡선 + 사다리 → 미끄럼틀처럼 보임 |
| `prop_marker_cap` | 8×6 | D2-306 날아간 마커 뚜껑 · D2-327 주워 건넴 |
| `prop_nameplate_chief_blur` / `_first` | 48×24 | D1-249 주임 이름표 — 이름 3글자 블러 + 후리가나 「？？？」 / B4 첫 글자 「言」만 선명 (言継 晴, STORY_BIBLE §3) |

확인할 점: 머그 · 스탠드 · 패치는 인서트 크기 한 벌뿐 — 방 안에 작게 놓을 크기가 필요하면 축소판 추가. 게시판은 폭 68로 시설 규격(64)보다 4px 넓음(인서트 전제).

---

# 연구소 아이소 v2 — 앱 연결 (2026-11-03)

- 번들: `Sources/Hareru/Resources/Art/Environment/room_stage1_v2.png`(420×330 × 8프레임) · `fac_*.png`(68폭 × 8프레임, 시설 6종 — 신입 책상 따로)
- 코드: `IsoGrid` 칸 64×32 · `OfficePixelArt.assetDensity` 1 · `characterPixelRatio` 1 · 방/시설 프레임을 0.15초마다 넘김(`animationFrameDuration`) · 격자 시작점 (210, 126) · `facilityBaseline` 2 · 기본 확대 1배(1~3배)
- v1 방(`room_stage1.png`)의 큰 책상 숨김은 `roomIncludesResearcherDesk = false`로 꺼짐. v1 그림 파일(`room_stage1.png` · `facility_*.png`)은 아직 번들에 남아 있음 — 정리는 나중에.
- 확인 화면: `previews/simulator_iso_stage1_v2.png`. 노멀맵 조명 · 블룸은 아직 시안에만 (SpriteKit `SKLightNode` 연결은 다음 단계).
- 테스트는 칸 크기 · 밀도가 바뀌어 `OfficeSceneTests`의 기대값이 달라짐 — 일괄 테스트 때 함께 고침 (BACKLOG §5-1).
