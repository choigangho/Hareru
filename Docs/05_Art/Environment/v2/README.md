# 환경 에셋 v2 (2026-11-01, 사용자 제공 시트)

원본 `source/` 6장 → `assets/` (처리 스크립트: `Docs/05_Art/Cast/cast_env_v2.py`, 원본 픽셀 약 2.7px → 에셋 1px).
앱 번들: `Sources/Hareru/Resources/Art/Environment` (v1 시설·소품을 덮어씀, v1 마루·벽 텍스처는 삭제 — v1 원본은 `Docs/05_Art/Environment/source`에 남아 있음).

| 시트 | 에셋 | 쓰임 |
| :--- | :--- | :--- |
| ① 핵심 시설 | `facility_*` 5종 | 사무실 시설 (폭 ≤ 64, 키 ≤ 72) |
| ② 쇠퇴 소품 | `prop_*` 5종 | 벽가 장식 — 키를 캐릭터의 약 1.3배 이하로 줄임 |
| ③ 타일셋 | `tile_floor_light/dark` (64×38) · `tile_wall_left/right` · `tile_window` (64×112, 타일 2칸 폭) | 방 그리기. `tile_window`는 민무늬 벽 패널에 창틀을 직접 그리고 **유리를 투명하게 뚫은 것** (`Docs/05_Art/Cast/window_panel.py`) — 뒤의 날씨 하늘이 비치고 옅은 빛 반사만 있음. 원본의 비/맑음 창문 그림(`tile_window_rain/clear`)은 `assets/`에만 보관 |
| ④ 확장 시설 | `expansion_tea_table` · `module_dock` · `microfilm_scanner` · `sign_workbench` | 번들만 — §5.2 시설 확장 때 |
| ⑤ AI 모듈 | `module_onyomi_ai` · `kunyomi_terminal` · `radical_robot` · `etymology_drone` | 번들만 — §5.3 모듈 시스템 때 |
| ⑥ 창밖 간판 | `sign_bookstore` · `street_lamp` · `cafe` · `building` | 번들만 — §5.4 복원 간판 연출 때 |

- 벽 패널은 타일 2칸 폭에 맞추려고 세로로 약 8% 늘림. 패널 기울기가 격자보다 3px(에셋) 완만해서 패널 끝에서 최대 1.5 방 픽셀 어긋날 수 있음.
- ②의 엉킨 전선·양동이에는 원본의 바닥 그림자가 함께 남음 (마루 위에서는 자연스러운 그늘로 보임).
- 간판의 일본어(本 · 珈琲 · カフェ · ビル店舗)는 게임 안 글자이고 실존 상호·상표는 없음.
