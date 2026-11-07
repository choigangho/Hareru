# Hareru — Claude 작업 규칙

이 파일은 이 저장소에서 일하는 모든 Claude 세션이 자동으로 읽는다. 자세한 내용은 링크한 문서가 원본이다.

## 지금 단계
- Godot 전환 중. 순서와 규칙의 원본은 [Docs/00_Project/ROADMAP.md](Docs/00_Project/ROADMAP.md) (§3 작업 규칙, §3-1 에셋 제작 규칙).
- 문서 목차와 문서 규칙은 [Docs/README.md](Docs/README.md). 결정 목차 · 대전제는 [Docs/00_Project/DECISIONS.md](Docs/00_Project/DECISIONS.md).
- 세계관 원본(캐논)은 `Docs/01_World` · [02_Characters/CHARACTERS](Docs/02_Characters/CHARACTERS.md) · `Docs/03_Story` (파일 목록은 [Docs/README](Docs/README.md)). 반전은 [SECRETS](Docs/03_Story/SECRETS.md)에만. 설계 산출물은 [Docs/04_Design/](Docs/04_Design/README.md).
- `Docs/Archive/`는 대체된 옛 문서다. 근거로 쓰지 않는다.
- `_trash/`는 휴지통이다 (git 밖, 지우지 않고 옮겨 둔 것). 근거로 쓰지 않고 검색에서 뺀다. 파일을 없앨 때는 지우지 말고 여기로 옮긴다.
- Swift 앱(`Sources/`)은 기능 동결. `GodotSpike/`는 버리는 참고 코드.

## 꼭 지킬 것
1. **보고는 한국어로.** 됐는 것과 안 된 것을 그대로.
2. **에셋:** 세트마다 대표 샘플 1장 → 소유자 승인 → 나머지 제작. 세트당 Pixellab 30회 상한. 단순한 물건은 `pixelart_workbench`로 직접 그림. (로드맵 §3-1)
3. **화면을 바꾸는 코드는 시안 확정 뒤에만.** 기존 구조에 색만 바꾸는 식의 작업 금지.
4. **범위 밖 일은 하지 않고** [Docs/00_Project/BACKLOG.md](Docs/00_Project/BACKLOG.md)에 적는다.
5. **커밋은 Claude가 알아서** 작업 단위가 끝나 테스트가 통과하면 한다 (2026-11-04 소유자: 기본값으로). 파일을 지정해 스테이징 (`git add -A` 금지), 남의 파일 · 다른 세션 변경은 넣지 않음. **push · 브랜치 전환 · 지우기 · 되돌리기처럼 우려되는 일만 먼저 묻는다.**
6. **API 키(Pixellab, Gemini)는 저장소 · 커밋에 절대 넣지 않는다.**
7. 음성 캐릭터는 NJL 게임 인물만 쓴다. 예전 10인 성우 라인업(이자카야 부장님 등)은 쓰지 않는다.
