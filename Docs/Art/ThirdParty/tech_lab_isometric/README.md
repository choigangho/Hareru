# Tech Lab — Isometric Pixel Interior (Antahonist, itch.io)

구입한 에셋 팩 (2026-11-02, 약 4천원). **재료로만 보관** — 무엇을 어떻게 쓸지는 나중에 결정. 아직 앱(`Sources/Hareru/Resources`)에는 아무것도 넣지 않음.

## 파일 위치 — git에는 안 올라감

- 원본: `pack/` (Downloads에서 그대로 복사, `.DS_Store`만 뺌. 파일 993개, 5.6MB)
- `.gitignore`의 `Docs/Art/ThirdParty/*/pack/`로 제외. 이 저장소는 GitHub 공개 저장소라 원본을 올리면 아래 라이선스의 '그대로 재배포 금지'에 걸림.
- 다른 컴퓨터에서 작업하려면 itch.io 구매 내역에서 다시 받아 `pack/`에 풀기.

## 라이선스 요점 (`pack/LICENSE.txt`)

- 상업·비상업 게임에 무제한 사용, 수정 가능, 출시한 게임에 포함 가능. 출처 표기는 선택.
- 금지: 원본을 그대로 또는 다른 에셋 팩·템플릿 안에 넣어 재판매·재배포 · **AI 모델 학습에 사용** · 자기 작품이라 주장.
  → Pixellab 등 생성 도구에 **스타일 참조로 올리지 않음** (학습 해당 여부가 애매하므로 피함).
  → 앱 번들에 넣는 건 '출시한 게임에 포함'이라 괜찮음. 그때는 우리가 고친(색 바꾼) 사본만 `Resources`에 넣음.

## 규격 — Hareru와 맞춰 보면

| 팩 | Hareru |
| :--- | :--- |
| `*_64`: 1m = 64×32 마름모 | 시설 에셋 밀도 2배와 같음 (방 타일 32×16 × 2) → 크기 조정 없이 그대로 맞음 |
| `*_32`: 1m = 32×16 | 방 격자 1:1 |
| 벽 2.6m, 2방향 (`_r0` 뒷벽 · `_r1` 왼벽) | 벽 높이 40 방 픽셀 — 비교 필요 |
| 소품 4방향 (`_r0`~`_r3`), 발 기준점 · 3D 박스 = `manifest_64.json` | 깊이 정렬에 바로 쓸 수 있음 |
| LED·화면 있는 기기는 8프레임 루프 (150ms), `anim/` 가로 스트립 | 시설 애니메이션에 활용 가능 |
| 팔레트 ENDESGA 32 고정 | **톤이 다름** — 쨍한 주황 책상·베이지 체크 바닥·새것. 쓰려면 바랜 청록·회색·오프화이트 + 호박색 포인트로 색 대응표를 만들어 일괄 변환 + 녹·때 추가 |

## 들어 있는 것

- 소품 21종 (`props_64`, `props_32`): ac_unit, boxes, cable_spool, desk_pc, extinguisher, folders, instrument_cart, network_cabinet, office_chair, parts_crate, parts_shelf, printer_3d, printer_station, robot_arm, server_rack_door, server_rack_open, toolbox, trash_bin, ups_unit, whiteboard, workbench
  - `static/` 그림자 포함 · `layers/` 몸체·그림자 분리 · `anim/`, `anim_layers/` 8프레임 루프
- 벽 12종 (`walls_*`): camera, clock, door, extinguisher, outlets, panel, pipes, plain, screen, shelf, sign, vent
- 바닥 5종 (`floors_*`): plain, cables, grate, hazard, trunk (각 2방향)
- 완성 방 4개 (`rooms_64`): server_room, electronics_lab, control_room, tech_hq + `anim/`
- 스토어 미리보기 (`preview/`)

## 쓸 만한 후보 (결정 전 메모)

- 연구소와 겹치는 것: 서버랙·네트워크 캐비닛·UPS(서버실 `facility_server_rack`), 책상 PC(`facility_researcher_desk`), 부품 선반·상자·소화기·쓰레기통(소품).
- 없는 것: 종이 사전·한자 서고·녹음 부스·낡은 가구 같은 언어 연구소 고유 물건 → 계속 직접 제작.
