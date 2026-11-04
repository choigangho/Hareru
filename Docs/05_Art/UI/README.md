# 연구소 UI 픽셀 아이콘 (2026-11-01)

원칙: 바깥 틀(칩 · 판 · 도크 · 서랍)은 앱의 Liquid Glass 그대로, **안의 아이콘만 픽셀** → '유리창 너머로 들여다보는 픽셀 연구소' (GAME_DESIGN §9.1).
앱 번들 사본은 `Sources/Hareru/Resources/Art/UI` (`icon_<이름>_<16|24>.png`), 코드는 `PixelIcon` (1pt = 1px 정수 배율, 에셋이 없으면 SF Symbol로 대체).

| 이름 | 쓰임 | 그림 |
| :--- | :--- | :--- |
| `research_points` | 研究P 칩 | 펼친 노트 위 청록 불꽃 |
| `influence` | 影響力 칩 | 구름 사이로 나오는 해 (연구소 하늘이 갬) |
| `restored` | 복원 칩 | 붓글씨 한 획이 있는 두루마리 |
| `budget` | 予算 판 | 낡은 동전 더미 |
| `build` · `restore` · `status` | 명령 도크 · 서랍 머리 | 망치+렌치 · 벼루의 붓 · 막대그래프 클립보드 |
| `menu` | 메뉴 버튼 · 메뉴판 머리 | 서랍 두 칸짜리 낡은 서류함 (스크립트로 직접 그림, `Docs/05_Art/Effects/tools/fx_author.py`) |
| `combo` · `locked` | 현황 서랍 콤보 목록 | 호박색 반짝임 · 녹슨 자물쇠 |
| `facility_*` | 건설 카드 · 배치 안내 · 선택 칩 | 시설 스프라이트(`Art/Environment`)를 축소 |

## 생성 기록
- `source/icons_v1.png` — Nano Banana 2, 3×3 아이콘 시트 (1.5 크레딧, 남은 크레딧 1.0). 시설 시트를 참조 이미지로 넣어 화풍을 맞춤.
- 생성기가 일부 아이콘 아래 **영어 라벨**을 그려 넣어서, 행마다 자르는 범위를 라벨 위에서 끊음 (`tools/ui_icons.py`의 `ROW_TOP` · `ROW_BOTTOM`). 다시 만들 때도 글자가 섞이지 않았는지 확인할 것.
- 시설 아이콘은 축소본이라 24px에서 조금 뭉개짐 — 전용 아이콘을 따로 그리면 더 또렷해짐.

## 처리
`tools/ui_icons.py <icons_sheet.png> <facility_sprites_dir> <out_dir>` — 마젠타 제거 → 칸 자르기(라벨 제외) → 블록 최빈색 축소 → 16·24px 정사각 캔버스 가운데 정렬 → 미리보기(`previews/`).

---

# NJL-OS 픽셀 UI 키트 (2026-11-03, 직접 그림 · 생성 크레딧 0)

UI 전면 개편(`Docs/Archive/UI_RESKIN_DRAFT.md` §4)용 재료. **아직 앱에 연결하지 않음** — 디자인이 확정되면 `Resources/Art/UI`로 복사하고 `PixelFrame` · `PixelIcon`에 붙임.
캐논: `Docs/Archive/STORY_BIBLE.md` (2094 · 렉스코드 · Liquid Glass 폐기). 팔레트: `Docs/Archive/PIXELLAB_ASSET_PLAN.md` — 바랜 청록 · 슬레이트 · 남색 `#141824`(외곽선) · 오프화이트 · 호박색 포인트 · 시안 `#00F0FF`(렉스코드/선택).
화풍은 기존 `frame_*.png`(`tools/ui_frames.py`)를 따름: 1px 남색 외곽선, 홈 파인 모서리, 왼쪽 위 빛 / 오른쪽 아래 그늘.

- 스크립트: `tools/njl_os_kit.py <source_dir> <previews_dir>` → `python3 tools/njl_os_kit.py source/njl_os previews`
- 원본: `source/njl_os/njl_*.png` (41장) · cap 값과 쓰임: `source/njl_os/njl_os_manifest.json`
- 전체 미리보기: `previews/preview_njl_os_sheet.png` (원본 x4 + 9-slice를 늘려 본 예시 화면) · 묶음별: `previews/preview_njl_<묶음>_x6.png`
- 9-slice 규칙: 장식은 모서리(cap) 안에만, 가장자리는 단색, 가운데는 주기 2 · 4 무늬 → `.tile`로 늘려도 이음새 없음. 앱에서는 1px = 2pt (cap 8px = 16pt).

| 파일 | 크기 · cap | 쓰임 |
| :--- | :--- | :--- |
| `njl_frame_panel_{dark,light}` | 24×24 · 8 | 판 — 단말 화면 · 서랍 · 대사 창. 리벳 4개 + 호박색/시안 상태 LED, 가운데 주사선 |
| `njl_frame_card_{dark,light}` | 24×24 · 8 | 단어 카드 · 통계 카드. 청록 베젤 + 네 모서리 판독 꺾쇠 + 호박색 표식 |
| `njl_frame_chip_{dark,light}` | 16×16 · 6 | 작은 정보 칩 · 배지 |
| `njl_frame_field_{dark,light}` | 24×24 · 8 | 입력란. 파인 홈 + 아래 시안(밝음: 청록) 밑줄 |
| `njl_button_normal` | 24×24 · 8 | 버튼 기본 — 위 빛줄(호박색) · 아래 2px 두께 |
| `njl_button_pressed` | 24×24 · 8 | 눌림 — 면이 2px 내려가고 두께가 사라짐, 호박색 테두리 |
| `njl_button_disabled` | 24×24 · 8 | 비활성 — 회색 + 사선 빗금 |
| `njl_signal_{1..4}_{16,24}` | 16 · 24 | 평가 버튼 신호 막대: 1 판독 불가(빨강 + X) · 2 흐림(호박) · 3 판독(청록) · 4 선명(시안). 채운 칸 수 = 강도 |
| `njl_tab_{terminal,institute,records,settings}_{normal,selected}` | 24×24 | 탭바: 판독 단말 · 연구소 · 판독 기록 · 단말 설정. 보통 = 슬레이트, 선택 = 청록/호박 몸체 + 시안 화면/불빛 |
| `njl_toggle_{off,on}` | 32×16 | 토글. 켜짐 = 손잡이 오른쪽 · 청록 홈 · 시안 표시등 줄 |
| `njl_segment_track` / `njl_segment_thumb` | 16×16 · 6 | 세그먼트 바깥 홈 / 고른 칸(호박색 테두리, 홈 위에 겹침) |
| `njl_slider_track` / `njl_slider_fill` | 16×8 · 3 (가로) | 슬라이더 빈 홈 / 채운 부분 |
| `njl_slider_knob` | 12×16 | 슬라이더 손잡이 — 미끄럼 방지 홈 + 위 호박색 표시 |
| `njl_heat_{0..4}` | 8×8 | 통계 잔디 칸 5단계 (남색 → 청록 → 시안). 칸 사이 1px 간격은 코드에서 |
| `njl_marker_bar` / `njl_marker_line` | 8×8 | 막대 그래프 끝(호박색 마름모) / 선 그래프 점(시안 고리) |

만들지 않은 것 (요청 범위 밖): 글꼴(오너가 라이선스 확인 후 결정) · 날씨 아이콘 22종(다음 차례) · 모자이크 · 글리치 · 스캔라인 연출(코드로 그림) · 앱 연결.
확인할 점: 버튼은 어둠 톤 한 벌뿐이라 밝은 판 위에서는 무겁게 보임 — 밝음 버튼이 필요하면 추가.

---

# 1막(N5) 스토리 UI — 직접 그림 (2026-11-03, 생성 크레딧 0)

근거: `Docs/Archive/N5_ASSET_LIST.md` §6. 위 NJL-OS 공통 부품과 같은 팔레트 · 9-slice 규칙. 글자(이름 · 제목 · 경고 문구 · 광고)는 코드가 얹음. **아직 앱에 연결하지 않음.**
- 스크립트: `tools/njl_story_ui.py source/njl_story` · 원본 `source/njl_story/` (17장) · cap: `source/njl_story/njl_story_manifest.json`
- **전체 미리보기 (소품 포함 한 장)**: `previews/preview_n5_p1_sheet.png` — `tools/n5_p1_sheet.py <props_dir> <story_dir> <njl_os_dir> <out.png>`. 아래쪽에 9-slice를 늘려 조립한 예시 화면.

| 파일 | 크기 · cap | 쓰임 |
| :--- | :--- | :--- |
| `njl_dialog_box` | 24×24 · 8 | 대사창 본문 (9-slice), 오른쪽 아래 호박 LED |
| `njl_dialog_portrait_frame` | 76×76 | 초상 틀 — 가운데 64×64 구멍(6,6부터)에 초상, 판독 꺾쇠 |
| `njl_dialog_portrait_bg` | 64×64 | 초상 뒤 배경 (주사선 + 옅은 격자) |
| `njl_dialog_name_tab` | 16×12 · 5 | 화자 이름 칸 (가로로 늘림, 호박색 테두리) |
| `njl_dialog_next` | 16×6 (8×6 ×2) | 다음 대사 ▼ 두 프레임 |
| `njl_quest_card` | 32×40 · [위16, 좌8, 아래10, 우8] | 퀘스트 카드 「오늘의 연구 과제」 — 머리 띠 = 제목, 왼쪽 호박 표식 |
| `njl_quest_reward_row` | 16×12 · 5 | 보상 줄 「보상: 연구P + 책상 스탠드」 |
| `njl_quest_icon_16` | 16×16 | 과제 쪽지 아이콘 (체크 칸) |
| `njl_warning_frame` | 24×24 · 8 | 경고창 — 붉은 테두리 + 위 사선 띠 (D1-528 뉴럴링크 동기화, 붉은 깜빡임은 코드) |
| `njl_warning_ticker` | 16×10 · 4 | 경고창 아래 광고 스크롤 줄 (D1-533) |
| `njl_warning_icon_24` | 24×24 | 붉은 삼각형 + 호박 느낌표, 아래 시안 점 = 뉴럴링크 |
| `njl_boot_logo` | 66×16 | 「NJL-OS」 도트 매트릭스 (직접 그린 5×7 도트 글자, 꺼진 점까지 보임) |
| `njl_boot_loader` | 96×8 (24×8 ×4) | 부팅 대기 점 3개, 네 프레임 |
| `njl_boot_bar_track` / `_fill` | 16×8 · 좌우 4 | 부팅 진행 막대 홈 / 4px마다 끊긴 시안 칸 (높이 고정, 가로만 늘림) |
| `njl_tab_ring` | 80×40 (40×40 ×2) | 탭 강조 링 — 밝음/어둠 두 프레임, 24px 탭 아이콘 둘레 (D1-163 · 257 · 403 · 500 · D2-300) |
| `njl_tab_pointer` | 20×10 (10×10 ×2) | 탭 위 안내 화살표 ▼, 2px 통통 |

---

# 레트로 단말 UI 키트 v2 (2026-11-03) — 현재 기준

`Docs/05_Art/StyleRef/ART_BIBLE.md` §6. 위의 NJL-OS(슬레이트) · phosphor v1 키트를 대체. **아직 앱에 연결하지 않음.**
- 스크립트 `tools/retro_ui.py source/retro previews` · 원본 `source/retro/rt_*.png`(43종, 대부분 8프레임 가로 스트립) · 크기 · cap · 쓰임은 `source/retro/retro_manifest.json`
- 시안: `previews/preview_retro_{stats,settings,study}_mock.gif` (402×874, 실제 비율) · 부품 시트 `previews/preview_retro_parts_x2.png`
- 모니터 7종(크림 CRT · 산업용 · 작은 터미널 + 틀어진 변형) · 유리 반사 · 전선 6종 · 키캡 7종(크림/호박/숯색 × 보통/눌림/비활성) · 둥근 단추 4 · 토글 2 · 평가 LED 막대 4 · 잔디 6 · 막대 5 · 커서 · 담쟁이 커튼
- v2.2 추가 (2026-11-03): 윗면이 보이는 몸체 · 탭 아이콘 `rt_tab_*`(+`_on`) · 스캐너 `rt_scanner` · 종이 `rt_paper` · 테이프 · 스캔 빛줄 · 코드 모니터 `rt_code_*` · 노멀맵 `*_n.png`
- 시안: `preview_retro_stats_scroll.gif`(시차 스크롤) · `preview_retro_study_mock.gif`(스캐너 · 종이) · `preview_retro_normalmap_demo.gif`(평면 대 노멀맵 조명)
- v2.3 추가 (2026-11-03, `tools/retro_ui_more.py source/retro previews` — retro_ui.py의 부품 · 도구를 불러 씀):
  - 공통: 명판 칩 `rt_plate_{cream,metal,amber}` · LCD 입력란 `rt_lcd_field(_focus)` · 영수증 토스트 `rt_receipt` + `rt_printer_slot` · 스크롤 레일 `rt_rail` + 손잡이 · 페이더(슬라이더) `rt_fader_*` · 피아노 키 세그먼트 `rt_piano_*` · 키캡 글리프 `rt_glyph_{play,eye,speaker,back,check}`
  - 학습: 넘버 시계 `rt_flip_*`(+넘어가는 날개) · 계기판 `rt_gauge` · 음성 파동 `rt_audio_wave` · 형광 해 `rt_phosphor_sun`
  - 스토리: 인터콤 대사창 `rt_dialog_body` · 초상 CRT `rt_portrait_crt` + 주사선 · 클립보드 `rt_clipboard` + 집게 · 연필 체크칸 · 경고 모니터 `rt_warning_monitor` · 글리치 `rt_glitch` · 부팅 로고 `rt_boot_logo` · 탭 강조 꺾쇠 `rt_tab_ring` · 안내 화살표 `rt_pointer`
  - 시안 GIF: `preview_retro_{dashboard_mock,card_flow,complete_mock,settings_mock,story_mock,boot_warning}.gif`

---

# 레트로 단말 UI — 앱 연결 (2026-11-03)

- 번들: `Sources/Hareru/Resources/Art/UI/rt_*.png` (105종) · `ph_icon_*_24.png` (통계 아이콘 4종)
- 목록: `Sources/Hareru/Components/RetroCatalog.swift` — manifest에서 자동 생성 (프레임 크기 · 수 · cap · 화면 여백). 그림을 다시 만들면 같이 다시 생성.
- 공통 부품 `Sources/Hareru/Components/RetroUI.swift`: `RetroMonitor`(모니터 판) · `RetroKeyStyle`(키캡) · `RetroToggleStyle` · `RetroPlate` · `RetroFlipCounter` · `RetroScannedPaper`(스캐너 위 종이) · `RetroCodeMonitor` · `RetroCursor` · `.phosphor()` · `RetroBackground`(벽돌 + **날씨 창** + 전선 + 담쟁이)
- 바꾼 화면: 탭바(키보드 + 아이콘 키캡) · 학습 대시보드 · 카드(스캐너 위 종이 + 스캔 빛줄 + 평가 키) · 세션 완료 · 통계 · 설정. 연구소 탭의 HUD는 아직 예전 픽셀 틀.
- 날씨(핵심 가치)는 없애지 않고 **연구소 창문 너머 하늘**로 보이게 함 — 실시간 날씨 · 시간대 캔버스 그대로.
- 확인 화면: `previews/simulator_retro_{dashboard,card,stats,settings}.png`
- 남은 것: 연구소 HUD · 온보딩 · 한자 시트 등 나머지 화면, 평가 버튼 이름(판독 불가 · 흐림 · 판독 · 선명) 반영, 글꼴 확정 후 교체, 노멀맵 조명.
- 디테일 보강 (2026-11-03, 시안과 맞춤): `RetroScrollScreen`(시차 스크롤 — 벽 0.2배 · 뒤 모니터 더미 0.45배 · 본문 1배 · 앞 전선/담쟁이 1.35배) · `RetroFarMonitors`(흐리고 어두운 뒤 층) · `RetroForeground` · `RetroDust` · 비네트 · 구석 전선 뭉치 · `RetroScanSweep`(화면마다 지나가는 주사선 띠) · `.retroHangingCable`(모니터 사이 처진 전선 · 빨간 신호선 · 플러그) · 잔디 10pt 칸을 듬성듬성(시안처럼). 학습 대시보드 · 통계 · 설정에 적용.
