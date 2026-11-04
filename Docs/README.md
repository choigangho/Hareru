# Hareru 문서 목차

> 상태: **확정** (2026-11-04) — 1단계(틀) · 2단계(옮기기) · 3단계(쪼개기) 완료.
> Claude 세션 규칙: [CLAUDE.md](../CLAUDE.md). 순서와 작업 규칙: [00_Project/ROADMAP.md](00_Project/ROADMAP.md).

## 문서 규칙

1. **한 주제는 한 파일.** 다른 문서는 복사하지 않고 링크만 건다.
2. **설정은 주제별로 나눈다.** 세계관 · 인물 · 스토리 · 시스템을 각각의 폴더에.
3. **반전(스포일러)은 [03_Story/SECRETS.md](03_Story/SECRETS.md) 한 곳에만.** 그림 · 음성 작업에는 필요 없다.
4. **모든 문서 맨 위에 머리말** (상태 · 원본 여부 · 관련). 틀은 [_TEMPLATE.md](_TEMPLATE.md).
5. **결정은 [00_Project/DECISIONS.md](00_Project/DECISIONS.md)에 목차로.** 최신 결정이 이기고, 옛 결정은 '대체됨'으로 표시한다.

상태 표시: **확정** (소유자 확인) · **초안** · **빈 틀** (자리만 있음) · **보류 아이디어** · **보관** (대체됨, [Archive/](Archive/README.md))

## 폴더

| 폴더 | 내용 |
| :--- | :--- |
| [00_Project/](00_Project/README.md) | 로드맵 · 백로그 · 결정 기록(대전제) · 용어집 |
| [01_World/](01_World/README.md) | 세계관 — 연대기 · 언어 · NeuroLex · NJL · 장소 |
| [02_Characters/](02_Characters/README.md) | 인물 개요 표 + 인물 한 명에 파일 하나 |
| [03_Story/](03_Story/README.md) | 큰 줄기 · 반전 · 집필 규칙 · 막별 대본 (N5 있음, N4~N1 빈 틀) |
| [04_Design/](04_Design/README.md) | 게임 시스템 — 하루 흐름 · 말 잃기 · 진행 · 이벤트 · 경제 · UI 원칙 · 시안 |
| [05_Art/](05_Art/README.md) | 아트 기준표 · Day 1 에셋 목록 · 에셋 원본 폴더 |
| 06_Voice/ | [음성 배정 규칙](06_Voice/VOICE_RULES.md) · 샘플 |
| [07_Data/](07_Data/DATA_PIPELINE.md) | 단어 데이터 파이프라인 |
| [Archive/](Archive/README.md) | 대체된 옛 문서 (지우지 않음, 근거로 쓰지 않음) |

## 어디에 쓰나

| 쓰려는 것 | 파일 |
| :--- | :--- |
| 소유자가 정한 것 | [00_Project/DECISIONS.md](00_Project/DECISIONS.md) |
| 지금 안 할 일 | [00_Project/BACKLOG.md](00_Project/BACKLOG.md) |
| 새 용어 · 일본어 표기 | [00_Project/GLOSSARY.md](00_Project/GLOSSARY.md) |
| 인물 성격 · 말투 · 표정 | `02_Characters/<인물>.md` |
| 새 장소 | `01_World/Places/` ([_TEMPLATE](01_World/Places/_TEMPLATE.md) 복사) |
| 반전 · 숨긴 사실 | [03_Story/SECRETS.md](03_Story/SECRETS.md) |
| 다음 막 대본 | `03_Story/Acts/N4/` … |
