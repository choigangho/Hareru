# 02. 화면이 넷인데 왜 "상태 하나 + 신호"로 묶었나

> 질문: 연구소 · 대화 · 판독 · 퇴근 화면을 각자 만들고 서로 불러 쓰면 되지, 왜 상태 머신과 이벤트 버스를 따로 뒀나?
>
> 짧은 답: **"지금 어느 화면인가"를 한 곳만 알게 하려고.** 여러 곳이 알면 언젠가 서로 다르게 안다.

---

## 1. 상태 머신 — 화면 상태는 enum 하나

[`Game/scripts/flow/game_flow.gd`](../Game/scripts/flow/game_flow.gd)

```gdscript
enum Screen { LAB, DIALOG, READER, LEAVE }
const ALLOWED := {
	Screen.READER: [Screen.LAB, Screen.DIALOG],   # 판독 중엔 바로 퇴근 못 함
	...
}
func go_to(to_screen) -> bool:
	if not can_go(to_screen): return false        # 허용 안 된 이동은 무시
```

- 상태가 **값 하나**라서 "판독 중인데 대화창도 떠 있는" 이상한 조합이 생길 수 없다.
- 허용 전환표가 있으니 규칙(예: 판독 끝내기 전엔 퇴근 못 함)을 코드 한 곳에서 읽을 수 있다.
- Swift 앱에서는 탭 · 시트 · 오버레이가 각자 `@State`를 들고 있어서, 대본이 "학습 탭이 빛난다"고 할 때 어느 상태를 바꿔야 하는지가 매번 달랐다 (`DayOneDirector.swift`의 `case studyGate` 같은 분기).

## 2. 이벤트 버스 — 화면끼리 서로 모르게

[`Game/scripts/autoload/event_bus.gd`](../Game/scripts/autoload/event_bus.gd)는 신호만 있는 전역 노드다.

```gdscript
signal dialog_finished(scene_key)
signal reading_finished
signal stand_up
```

- 대화 화면은 "끝났다"고 **외치기만** 한다. 누가 듣는지 모른다.
- [`main.gd`](../Game/scripts/main.gd)가 듣고 `flow.go_to(LAB)`를 부른다.
- 그래서 대화 화면을 고칠 때 판독 화면 코드를 열 필요가 없다. 직접 참조가 있으면 한쪽 이름만 바꿔도 다른 쪽이 깨진다.

## 3. 로직과 그리기를 나눈 이유

| 로직 (그림 없음, 테스트함) | 그리기 (스크린샷으로 확인) |
| :--- | :--- |
| `DialogueRunner` — 줄 넘기기 · 분기 · 타자 진행 | `DialogScreen` · `DialogText` |
| `ReaderModel` · `StudySession` · `Fsrs` | `ReaderScreen` · `ReaderText` |

로직 쪽은 `RefCounted`(노드가 아님)라서 창 없이 바로 만들어 시험할 수 있다 → [03](03_headless_tests_caught_bugs.md).

## 직접 해 볼 것

- `GameFlow.ALLOWED`에서 `LEAVE`를 `READER`의 허용 목록에 넣으면 어떤 테스트가 깨지는지 보기 (`test_blocked_transition_stays`).
- `EventBus`에 `signal lamp_installed`를 하나 더 만들고, 연구소 화면이 이걸 들으면 `set_light(AFTER_LAMP)` 하게 해 보기.
