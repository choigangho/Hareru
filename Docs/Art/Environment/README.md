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
