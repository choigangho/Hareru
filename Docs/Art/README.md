# Hareru 에셋 (Docs/Art)

에셋은 이 폴더 하나에서 관리합니다. 카테고리마다 `source/`(원본) · `previews/`(확대 미리보기) · `tools/`(처리 스크립트) · `README.md`(파일별 쓰임)를 두고, 앱이 쓰는 사본만 `Sources/Hareru/Resources/Art/<카테고리>/`에 넣습니다.

| 폴더 | 내용 |
| :--- | :--- |
| [`Characters/`](Characters/README.md) | 주임 연구원 · 신입(나) 스프라이트 · 초상화 |
| [`Cast/`](Cast/README.md) | 음성 캐릭터 출연진 9인 스프라이트 |
| [`Environment/`](Environment/README.md) | 시설 · 소품 · 타일 · 간판, `stage1/` = 1단계 방 그림 |
| [`Effects/`](Effects/README.md) | 먼지 · 먹 · 반짝임 · 누수 · 입자 |
| [`UI/`](UI/README.md) | 픽셀 프레임 · 아이콘 |
| [`ThirdParty/`](ThirdParty/tech_lab_isometric/README.md) | 구입한 에셋 팩 원본 (재료 보관용, `pack/`은 git 제외) — Tech Lab 아이소메트릭 인테리어 |

---

## 제작 도구: Pixellab

- **역할 분담 (2026-11-02 결정)**: 에셋은 사용자가 [Pixellab](https://www.pixellab.ai) 웹에서 직접 만들어 넘겨줌. Claude는 받은 파일을 규격에 맞게 정리하고 코드에 연결함. MCP로 직접 생성하는 건 사용자가 요청할 때만 (생성마다 크레딧 차감).
- **MCP**: `pixellab` 서버가 이 프로젝트 로컬 설정에 등록됨 (`~/.claude.json`, 키는 저장소 밖). 도구 이름은 `mcp__pixellab__*`.
- **문서**: <https://api.pixellab.ai/mcp/docs> (MCP 도구 전체) · <https://api.pixellab.ai/v2/llms.txt> (REST API)
- MCP 도구가 안 보이면 MCP 설정 문제 — REST/curl로 우회하지 말고 설정부터 확인.

### Hareru 규격 (GAME_DESIGN §9.1)

| 항목 | 규격 |
| :--- | :--- |
| 시점 | 아이소메트릭 2:1, 1방향 고정 |
| 바닥 타일 | 32×16 아트 픽셀 |
| 캐릭터 | 48×48, 발 기준 하단 정렬, 앞(남동) · 뒤(북서) 2방향 + 좌우 반전 |
| 시설 · 소품 | 에셋 밀도 2배 (방 픽셀 1칸 = 에셋 2칸), 폭 64 이하 |
| 방 그림 | 그림 1픽셀 = 방 픽셀 1칸 (`Environment/stage1`) |
| 초상화 | 64×64 이상 |
| 배경 | 투명 PNG. 실존 브랜드 · 로고가 섞이지 않았는지 확인 |
| 팔레트 | 한 단계 에셋은 같은 팔레트를 공유 (도구마다 `palette` 전달) |

### 받은 그림 정리 순서
1. **업스케일된 그림**(AI 생성 · 확대 저장본) → `unzoom_image`로 원래 픽셀 격자 복원 (stage1 방: 1536×1024 → 4배 감지 → 389×256)
2. 테두리가 지저분하면 `correct_pixelart` (크기 유지), 색이 너무 많으면 `reduce_colors` (여러 프레임은 한 번에 → 같은 팔레트)
3. 배경 제거: 단색 배경은 테두리에서 번지는 채우기로 직접, 복잡하면 `remove_background`
4. 원본 · 정리본 · 미리보기를 카테고리 폴더에, 앱 사본을 `Resources/Art`에

### 쓸 만한 MCP 도구 (Hareru 기준)

| 용도 | 도구 |
| :--- | :--- |
| 캐릭터 (출연진 · 방문자) | `create_character` (v3: 최대 256px · 8방향, `standard`: 저렴), `create_character_state` (옷 · 상태 변형), `animate_character` (걷기 등 — 방향은 사용자에게 확인) |
| 시설 · 소품 | `create_1_direction_object` (16~256px, 후보 여러 장 → `select_object_frames`), `create_map_object` (32~400px, 투명 배경), `animate_object` (LED · 화면 깜빡임) |
| 방 · 바닥 | `create_room` (7×6 아이소메트릭 방, **Tier 2+**), `cut_out_room_furniture` (방 속 가구를 떼어 움직이게), `create_isometric_tile` (16~64px), `create_building_kit` |
| 정리 | `unzoom_image`, `correct_pixelart`, `reduce_colors`, `image_to_pixelart` |
| 대화 · 초상화 | `create_portrait_character`, `set_character_portrait`, `get_lip_sync` (대사 입 모양 프레임 — 캐릭터 첫 만남 연출, GAME_DESIGN §12.2) |
| 조명 | `create_normal_map` |
| 작업 관리 | `wait_for_jobs` (`get_*`를 반복 호출하지 말 것), `list_jobs`, `get_balance`, `get_pro_flash_capabilities` (생성 전 무료 견적) |

- 생성 도구는 작업 ID를 바로 돌려주고 2~5분 뒤 완료. 다운로드 URL은 인증 없이 열림.
- 체험 플랜에서는 pro 모드 · pro 타일셋 · `create_room`을 못 씀 (Tier 1/2 이상).

---

## 결정: 게임 엔진은 SpriteKit 유지 (2026-11-02)

Pixellab 문서의 팁 「Claude는 Godot과 잘 맞는다 (헤드리스 실행, GDScript 이해)」를 검토했지만 **Godot은 쓰지 않음**. 연구소는 SwiftUI 앱 안의 SpriteKit(`OfficeScene`) 그대로. 팁이 말하는 장점(화면 없이 실행 · 자동 검사)은 `swift test`의 `OfficeSceneTests`로 이미 갖추고 있음. Pixellab 문서의 Godot 전용 안내(Wang 타일셋 리소스, `create_normal_map`의 `convention="opengl"`)는 해당 없음.
