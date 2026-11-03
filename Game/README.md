# Game — Hareru Godot 프로젝트 (P2 버티컬 슬라이스)

로드맵: [../Docs/GODOT_ROADMAP.md](../Docs/GODOT_ROADMAP.md) P2. 화면 기준: 확정 시안 [../Docs/Design/mocks/](../Docs/Design/mocks/).
`GodotSpike/` 코드는 옮겨 쓰지 않음 — 여기 코드는 테스트와 함께 새로 씀.

## 실행
```
godot --path Game                                    # 게임
godot --headless --path Game -s res://tests/run_tests.gd   # 창 없는 테스트 (0 = 통과)
godot --path Game -- --shot=out.png --light=before|after|night [--day] [--screen=lab|dialog|reader|leave]
```
처음 한 번(또는 그림을 바꾼 뒤): `python3 Game/tools/sync_art.py` → `godot --headless --path Game --import`

## 구조
- `scripts/flow/game_flow.gd` — 화면 상태 머신 하나 (LAB / DIALOG / READER / LEAVE), 허용 전환표
- `scripts/autoload/event_bus.gd` — 전역 신호 (화면끼리 직접 참조하지 않음)
- `scripts/main.gd` — 상태가 바뀌면 화면 노드 교체, 실행 인자, 스크린샷
- `scenes/lab/lab_screen.gd` — 연구소 단면 (M-1): 배경 · 소품 · 앉은 인물 · 밝기 층 (① 스탠드 전 / ② 후 / ③ 밤, 곱하기 · 더하기 블렌드) · 창밖 낮 · 힌트 점
- `scenes/placeholder/` — 아직 안 만든 화면(대화 · 판독 · 퇴근) 자리
- `art/` — `Docs/Art/Inbox`의 확정 그림 복사본 (원본은 Inbox, `tools/sync_art.py`로 맞춤)
- 그림 좌표의 원본: `Docs/Art/Inbox/**/*.txt`, `Docs/Design/SLICE_ASSETS.md`
