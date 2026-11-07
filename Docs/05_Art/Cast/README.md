# 음성 캐릭터 출연진 스프라이트

> **자유 캐스트 (2026-11-07):** 세계관 기반 조연 후보와 소유자 선발 결과는 [free_cast_2026-11-07/](free_cast_2026-11-07/README.md).

> **v2 — Pixellab (2026-11-02) — ❌ 채택 안 함, 앱은 v1으로 되돌림** (이유는 `Docs/05_Art/Characters/README.md`): 9인 전원을 Pixellab `create_character` v3(48×48, 8방향) + 걷기 템플릿 `walking-6-frames`(남동 6프레임)로 다시 만듦. `courier_rin`은 v1 시트가 없어 지금 앱에 스프라이트 없음.
> 원본: `pixellab/<voiceId>/` · id 목록: `Docs/05_Art/Characters/pixellab/characters.json` · 처리: `Docs/05_Art/Characters/tools/pixellab_import.py` · 미리보기: `previews/preview_<voiceId>_pixellab_x6.png`.
> 생성 기록·크레딧은 `Docs/05_Art/Characters/README.md` (11명 합계). 아래 표의 호박색 포인트를 프롬프트에 그대로 넣음. 이하 '처리' 절은 v1(사용자 제공 시트) 기록.

## v1 (2026-11-01, 사용자 제공 시트 — 현재 앱 버전)

GAME_DESIGN §2.2의 10인 중 주임 연구원을 뺀 9인. 파일 이름은 voiceId (`VoiceProfile.gameCast`).
앱 번들 사본: `Sources/Hareru/Resources/Art/Characters/<voiceId>_<idle_se|walk_se_a|walk_se_b|idle_nw>.png` (48×48, 발 기준 하단 정렬).
코드: `OfficePixelArt.characterFrames(voiceID:)`. 아직 장면에 등장시키지 않음 — 급수별 등장 조건이 정해지면 방문자로 씀.

| voiceId | 인물 | 등장 단계 | 호박색 포인트 |
| :--- | :--- | :--- | :--- |
| `ai_kuro` | KURO (구형 언어 기록 안드로이드, NJL-09) | 1단계 (N5) | 외눈 센서 렌즈 |
| `master_gen` | 源 剛 (1층 찻집 마스터) | 1단계 | 목에 건 수건 |
| `citizen_mio` | ミオ (뉴럴링크 세대 고등학생) | 1단계 | 교복 리본 |
| `courier_rin` | 風間 凛 (고문서 스쿠터 배달원) | 2~3단계 | 이마의 고글 — **v1 시트 미수령** |
| `elder_tsuru` | 白石 ツル (최고령 기증자) | 2~3단계 | 비녀 칸자시 |
| `craftsman_jin` | ジン (간판 복원 장인) | 2~3단계 | 네온 한자 프레임 · 고글 |
| `rival_reina` | 神崎 玲奈 (NeuroLex 수석 이사) | 4~5단계 | 홀로그램 데이터패드 · 브로치 |
| `inspector_ren` | 橘 蓮 (문화 예산 감사관) | 4~5단계 | 넥타이 · 배지 |
| `announcer_ai` | NJL 원내 방송 / 도시 기상 AI | 4~5단계 | 파형 모니터 화면 |

## 처리
`cast_env_v2.py <images_dir> <out_dir>` — 베이지 배경은 **테두리에서 번지는 채우기**로만 지움(안쪽의 비슷한 색은 보존) → 4칸 분할 → 출연진 전체에 **같은 배율**(원본 픽셀 약 5.2px → 1px)을 써서 인물 간 키 차이를 유지 → 48×48 프레임.
환경 v2 시트도 같은 스크립트가 처리 (`Docs/05_Art/Environment/v2`).
