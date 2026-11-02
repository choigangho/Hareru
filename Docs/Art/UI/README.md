# 연구소 UI 픽셀 아이콘 (2026-11-01)

원칙: 바깥 틀(칩 · 판 · 도크 · 서랍)은 앱의 Liquid Glass 그대로, **안의 아이콘만 픽셀** → '유리창 너머로 들여다보는 픽셀 연구소' (GAME_DESIGN §9.1).
앱 번들 사본은 `Sources/Hareru/Resources/Art/UI` (`icon_<이름>_<16|24>.png`), 코드는 `PixelIcon` (1pt = 1px 정수 배율, 에셋이 없으면 SF Symbol로 대체).

| 이름 | 쓰임 | 그림 |
| :--- | :--- | :--- |
| `research_points` | 研究P 칩 | 펼친 노트 위 청록 불꽃 |
| `influence` | 影響力 칩 | 구름 사이로 나오는 해 (연구소 하늘이 갬) |
| `restored` | 복원 칩 | 붓글씨 한 획이 있는 두루마리 |
| `budget` | 予算 판 | 낡은 동전 더미 |
| `build` · `restore` · `status` | 명령 도크 · 서랍 머리 | 망치+렌치 · 벼루의 붓 · 막대그래프 클립보드 |
| `menu` | 메뉴 버튼 · 메뉴판 머리 | 서랍 두 칸짜리 낡은 서류함 (스크립트로 직접 그림, `Docs/Art/Effects/tools/fx_author.py`) |
| `combo` · `locked` | 현황 서랍 콤보 목록 | 호박색 반짝임 · 녹슨 자물쇠 |
| `facility_*` | 건설 카드 · 배치 안내 · 선택 칩 | 시설 스프라이트(`Art/Environment`)를 축소 |

## 생성 기록
- `source/icons_v1.png` — Nano Banana 2, 3×3 아이콘 시트 (1.5 크레딧, 남은 크레딧 1.0). 시설 시트를 참조 이미지로 넣어 화풍을 맞춤.
- 생성기가 일부 아이콘 아래 **영어 라벨**을 그려 넣어서, 행마다 자르는 범위를 라벨 위에서 끊음 (`tools/ui_icons.py`의 `ROW_TOP` · `ROW_BOTTOM`). 다시 만들 때도 글자가 섞이지 않았는지 확인할 것.
- 시설 아이콘은 축소본이라 24px에서 조금 뭉개짐 — 전용 아이콘을 따로 그리면 더 또렷해짐.

## 처리
`tools/ui_icons.py <icons_sheet.png> <facility_sprites_dir> <out_dir>` — 마젠타 제거 → 칸 자르기(라벨 제외) → 블록 최빈색 축소 → 16·24px 정사각 캔버스 가운데 정렬 → 미리보기(`previews/`).
