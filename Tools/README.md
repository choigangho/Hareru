# Hareru Content Tools (`Tools/`)

이 폴더는 iOS 앱 번들에 포함되지 않는 **오프라인 콘텐츠 자동 생성 도구** 전용 공간입니다.

## 구성 예정 스크립트

1. **`generate_scripts.py` (대본 · 컬러 · 후리가나 생성)**
   - JLPT 어휘 및 `JMdict` / `KANJIDIC2` 기반 단어·한자 매핑
   - 다의어 핵심 의미 분리 (최대 2~4개) 및 캐릭터 성우 자동 배정
   - `SplitText`용 `before / answer / after` 3분할 한국어 해석 무결성 자동 검사
2. **`quick_review` (고속 검수기)**
   - 스페이스바로 연속 청취하며 억양이 어색한 항목만 `R` 키로 재합성 큐에 등록

## 현재 동작하는 스크립트

원본 데이터는 `Tools/sources/`(git 제외)에 받고, 스크립트는 그 폴더 밖에서 `python3 -I`로 실행합니다.
출처·라이선스는 `Docs/DATA_PIPELINE.md` 참고.

```bash
python3 -I Tools/build_kanji.py Tools/sources Tools/build/kanji_base.json
python3 -I Tools/build_words.py Tools/sources Tools/build/kanji_base.json Tools/build/words_base.json
```

- `build_kanji.py`: KANJIDIC2 → 상용한자 2,136자 기본 데이터 (음독·훈독·획수·부수·한국어 음·추정 급수)
- `build_words.py`: JLPT 목록 × JMdict × JmdictFurigana → 단어 기본 데이터 (품사·영어 뜻·한자별 읽기)

### 음성 합성 (`synthesize_aivis.py`)

AivisSpeech 앱(엔진 `http://127.0.0.1:10101`)을 켠 뒤:

```bash
python3 -I Tools/synthesize_aivis.py Sources/Hareru/Resources/Data/words.json Tools/voice_cast.json Tools/build/audio
```

- `voice_cast.json`: 대분류 → 담당 인물, 인물 → `style_id` (null이면 건너뜀). 주인공 3종은 모두 합성.
- 출력 `Tools/build/audio/<인물>/<파일>.m4a` (AAC 128kbps). `manifest.json`에 문장·style_id를 기록해 바뀐 것만 다시 합성.
- 입력은 가나 (예문 `{漢字|かな}` → 읽기, 빠진 오쿠리가나 보충). `--dry-run`으로 목록 확인, `--style 인물=id`로 시험 지정.
