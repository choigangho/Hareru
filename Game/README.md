# Game — Hareru Godot 프로젝트 (P2 버티컬 슬라이스)

로드맵: [../Docs/00_Project/ROADMAP.md](../Docs/00_Project/ROADMAP.md) P2. 화면 기준: 확정 시안 [../Docs/04_Design/mocks/](../Docs/04_Design/mocks/).
`GodotSpike/` 코드는 옮겨 쓰지 않음 — 여기 코드는 테스트와 함께 새로 씀.

## 실행
```
godot --path Game                                    # 게임 (D1을 T-0부터. -- --from=T-7 이면 그 장면부터)
godot --headless --path Game -- --autoplay           # D1을 실제 화면으로 끝까지 자동 진행 (퇴근 도달 = 0)
godot --headless --path Game -- --autoplay --save=user://ap.json --quit-line=D1-216   # 중간에 끄기 → 같은 --save로 다시 켜면 이어짐
godot --path Game -- --autoplay --from=T-8 --shot-line=D1-803 --shot=out.png   # 흐름 중간 스크린샷
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
- `art/` — `Docs/05_Art/Inbox`의 확정 그림 복사본 (원본은 Inbox, `tools/sync_art.py`로 맞춤)
- 그림 좌표의 원본: `Docs/05_Art/Inbox/**/*.txt`, `Docs/05_Art/SLICE_ASSETS.md`

## 저장
- `user://save.json` (macOS: `~/Library/Application Support/Godot/app_userdata/Hareru/`). 장면 · 카드가 바뀔 때마다, 단어가 졸업할 때마다, 창을 닫을 때 저장. 임시 파일에 쓴 뒤 이름 바꾸기.
- 내용: `version` · FSRS 기록(영구) · 오늘 더미 · 실패 · 노출(오늘만 — 새벽 4시가 지나면 버림) · 스토리 진행(`story.D1`).
- 이전: `SaveGame.migrate()`가 옛 버전을 한 단계씩 올림 (v1 → v2). 모르는 버전은 쓰지 않고 새로 시작.
- 새로 시작: `godot --path Game -- --new`. `--from` · `--autoplay`는 `--save`를 주지 않으면 저장하지 않음.

## 윈도우판 만들기
- 템플릿: Godot 4.7.2 공식 내보내기 템플릿 중 `windows_*` (`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`)
- `godot --headless --path Game --export-release "Windows" <폴더>/Hareru.exe` — pck를 exe 안에 넣은 파일 하나 (약 110MB, zip 38MB)
- 글꼴은 시스템 글꼴 목록(Mac 히라기노 → 윈도우 Yu Gothic · 맑은 고딕 · Yu Mincho)에서 고름 (BACKLOG 17 픽셀 글꼴 정해지면 파일로 넣음)
