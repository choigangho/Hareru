# 자유 캐스트 (2026-11-07)

세계관을 바탕으로 새로 만든 조연 후보 스프라이트. 68×68 캔버스, 남쪽(정면) 1장씩. Pixellab `create_image_pro_flash`.
판정은 소유자가 판단 페이지(https://claude.ai/artifact/KMuhRJetypKmoyAmAzFwwQ)에서 했고, 차수별 기록과 이유는 [SELECTION.md](SELECTION.md), 프롬프트는 [prompts.txt](prompts.txt).
아직 게임(`Game/`)에 넣지 않았다. 이름은 전부 임시 id다.

## 폴더
| 폴더 | 내용 |
| :--- | :--- |
| `picked/` | 소유자 선발 12명 — 다음 단계(방향 추가 · 애니메이션 · 게임 반영)의 원본 |
| `hold/` | 소유자 보류 10명. 대부분 다시 그린 판이 있음(아래 표) |
| `dropped/` | 소유자 탈락 27명. 근거로 쓰지 않음 |
| `sheets/` | 비교 · 한눈 보기 시트 (`picked_lineup_x3.png` = 선발 12명) |
| `cutins/` | 컷인 시험작. 탈락 인물(radio_dj, uptown_girl, 1차 barber)이 섞여 있어 그대로 쓰지 않음 |
| `portraits/` | 대화 초상 · 컷인 시험작 (1차 barber, headphone_fan 기준) |
| `scenes/` | 고해상도 장면 시험작 |

## 선발 12
| 갈래 | id | 인물 |
| :--- | :--- | :--- |
| 옛 동네 | `film_kid` | 필름 카메라 아이 |
| 옛 동네 | `letter_writer` | 손편지 대필가 |
| 매체별 가게 | `record_lady` | 레코드 가게 ("가장 좋음") |
| 매체별 가게 | `headphone_shop_owner2` | 유선 헤드폰 가게 ("최고") |
| 매체별 가게 | `cassette_owner` | 카세트 가게 |
| 매체별 가게 | `typewriter_owner2` | 타자기 수리점 |
| 옛 동네 | `barber2` | 바버샵 이발사 (1차 헤드폰 가게 얼굴 · 체격) |
| NeuroLex | `lex_exec` | 간부 |
| NeuroLex | `nl_director` | 이사 초안 — 캐논 인물 `rival_reina`, 확정 아님 |
| NeuroLex | `nl_lawyer` | 고문 변호사 |
| NeuroLex | `nl_associate` | 이사 보좌 |
| NeuroLex | `nl_holo_ad2` | 홀로그램 광고 모델 |

## 보류 → 다시 그린 판
| 보류 | 다시 그린 판 · 결과 |
| :--- | :--- |
| `typewriter_owner` | `typewriter_owner2` 선발 |
| `nl_holo_ad` | `nl_holo_ad2` 선발 |
| `lex_clerk` | `lex_exec` 선발 |
| `headphone_fan` | `headphone_fan2` 보류 → `headphone_fan3` 탈락. 설정(유선 헤드폰 마니아)은 소유자가 좋다고 함 |
| `stray_cat` | `stray_cat2` 탈락. 고양이라는 설정은 좋다고 함 |
| `bartender`, `broken_link_teen`, `librarian`, `rooftop_gardener` | 다시 그린 판(`bartender2` 등 · `archive_keeper`) 모두 탈락 |

세계관 · 디자인 규칙(없는 것: 버스 · 전차 · 신문 · 라디오, 의료 인물 없음, 단발+안경은 주임 전용 등)은 SELECTION.md의 "소유자 판정에서 나온 세계관·디자인 규칙".
