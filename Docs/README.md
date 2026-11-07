# Hareru 문서 목차

> 상태: **확정** (2026-11-07 — 폴더마다 있던 작은 README와 인물 · 장소 파일들을 합침. 옛 파일은 저장소 안 `_trash/`에)
> Claude 세션 규칙: [CLAUDE.md](../CLAUDE.md). 순서와 작업 규칙: [00_Project/ROADMAP.md](00_Project/ROADMAP.md).

## 문서 규칙

1. **한 주제는 한 파일.** 다른 문서는 복사하지 않고 링크만 건다. 짧은 내용은 새 파일을 만들지 말고 가까운 파일에 절로 넣는다.
2. **설정은 주제별로 나눈다.** 세계관 · 인물 · 스토리 · 시스템을 각각의 폴더에. 폴더 목차는 이 파일 하나뿐이다 (폴더마다 README를 만들지 않는다).
3. **반전(스포일러)은 [03_Story/SECRETS.md](03_Story/SECRETS.md) 한 곳에만.** 그림 · 음성 작업에는 필요 없다.
4. **모든 문서 맨 위에 머리말** — 아래 틀.
5. **결정은 [00_Project/DECISIONS.md](00_Project/DECISIONS.md)에 목차로.** 최신 결정이 이기고, 옛 결정은 '대체됨'으로 표시한다.

상태 표시: **확정** (소유자 확인) · **초안** · **빈 틀** (자리만 있음) · **보류 아이디어** · **보관** (대체됨, [Archive/](Archive/README.md))

머리말 틀:

```markdown
# 문서 제목

> 상태: **초안** | **확정** | **빈 틀** | **보관** (YYYY-MM-DD)
> 원본 여부: 이 주제의 원본은 이 파일 (다른 문서는 여기로 링크만)
> 관련: [다른 문서](경로)

한두 줄로 이 문서가 무엇을 정하는지.
```

## 파일

| 폴더 | 파일 | 내용 |
| :--- | :--- | :--- |
| **00_Project** 진행 관리 | [ROADMAP](00_Project/ROADMAP.md) | 단계 (P0~P4) · 작업 규칙 · 에셋 제작 규칙 |
| | [BACKLOG](00_Project/BACKLOG.md) | 지금 단계 밖의 일 |
| | [DECISIONS](00_Project/DECISIONS.md) | 대전제 · 소유자 결정 목차 · 결정 규칙 |
| | [GLOSSARY](00_Project/GLOSSARY.md) | 용어 · 한국어/일본어 표기 |
| **01_World** 세계관 (캐논) | [TIMELINE](01_World/TIMELINE.md) | 연대기 · 공개 순서 |
| | [LANGUAGE](01_World/LANGUAGE.md) | 2094년 일본어 양극화 · 이름 체계 |
| | [NEUROLEX](01_World/NEUROLEX.md) | NeuroLex 회사 · 렉스코드 (겉모습 · 쓰는 규칙) |
| | [NJL](01_World/NJL.md) | 国立言語遺産研究所 · 연구소 성장 단계 |
| | [PLACES](01_World/PLACES.md) | 장소 4곳 · 하루 학습 = 장소 방문 · 장소별 에피소드 |
| **02_Characters** 인물 (캐논) | [CHARACTERS](02_Characters/CHARACTERS.md) | 개요 표 + 인물별 절 |
| **03_Story** 스토리 (캐논) | [MAIN_PLOT](03_Story/MAIN_PLOT.md) | 큰 줄기 · 최종장 · 장소별 에피소드 · 엔딩 조건 |
| | [SECRETS](03_Story/SECRETS.md) | 반전 · 숨겨진 사실 (스포일러, 여기에만) |
| | [WRITING_RULES](03_Story/WRITING_RULES.md) | 대사 언어 비율 · 표기 규칙 위치 |
| | [Acts/N5/N5_SCRIPT](03_Story/Acts/N5/N5_SCRIPT.md) | 1막 대본 (집필 규칙 §0 · 장면 · 예문 금지 목록 §4) |
| | `Acts/N5/lines/` | 대사 데이터 — `Tools/export_story_game.py` · `Tools/synthesize_story.py`가 읽음 |
| | [Acts/N5/N5_DIALOGUE_BOOK.html](03_Story/Acts/N5/N5_DIALOGUE_BOOK.html) | 보기용 대사집 — `python3 Docs/03_Story/Acts/N5/tools/build_dialogue_book.py`로 다시 만듦 |
| | `Acts/N5/imports/` | 예전 제미나이 대화 (Tools/gemini_chat.py) |
| **04_Design** | [README](04_Design/README.md) | 게임 시스템 — 하루 흐름 · 말 잃기 · 진행 · 이벤트 · 경제 · UI 원칙 · 시안 |
| **05_Art** | [README](05_Art/README.md) | 아트 기준표 · Day 1 에셋 목록 · 에셋 원본 폴더 |
| **06_Voice** | [VOICE_RULES](06_Voice/VOICE_RULES.md) | 음성 배정 규칙 · 샘플 |
| **07_Data** | [DATA_PIPELINE](07_Data/DATA_PIPELINE.md) | 단어 데이터 파이프라인 |
| **08_Study** | [README](08_Study/README.md) | 공부 기록 — 단계마다 새로 배운 개념 |
| **Archive** | [README](Archive/README.md) | 대체된 옛 문서 (지우지 않음, 근거로 쓰지 않음) |

막(급수) 하나 = 폴더 하나: 대본 `N?_SCRIPT.md` + `lines/`. N4~N1은 대본을 쓰기 시작할 때 `Acts/N4/`처럼 만든다 (빈 틀을 미리 두지 않음). 막 요약 · 새로 만나는 인물 · 장소 · 랠리 지도 · 장면 목록 순으로 쓴다.

## 어디에 쓰나

| 쓰려는 것 | 파일 |
| :--- | :--- |
| 소유자가 정한 것 | [00_Project/DECISIONS.md](00_Project/DECISIONS.md) |
| 지금 안 할 일 | [00_Project/BACKLOG.md](00_Project/BACKLOG.md) |
| 새 용어 · 일본어 표기 | [00_Project/GLOSSARY.md](00_Project/GLOSSARY.md) |
| 인물 성격 · 말투 · 표정 | [02_Characters/CHARACTERS.md](02_Characters/CHARACTERS.md)의 그 인물 절 |
| 새 장소 | [01_World/PLACES.md](01_World/PLACES.md) |
| 반전 · 숨긴 사실 | [03_Story/SECRETS.md](03_Story/SECRETS.md) |
| 다음 막 대본 | `03_Story/Acts/N4/` … |
