# Hareru Content Tools (`Tools/`)

이 폴더는 iOS 앱 번들에 포함되지 않는 **오프라인 콘텐츠 자동 생성 도구** 전용 공간입니다.

## 구성 예정 스크립트

1. **`generate_scripts.py` (대본 · 컬러 · 후리가나 생성)**
   - JLPT 어휘 및 `JMdict` / `KANJIDIC2` 기반 단어·한자 매핑
   - 다의어 핵심 의미 분리 (최대 2~4개) 및 캐릭터 성우 자동 배정
   - `SplitText`용 `before / answer / after` 3분할 한국어 해석 무결성 자동 검사
2. **`synthesize_aivis.py` (AivisSpeech 로컬 무인 녹음 · 256kbps)**
   - 맥북 로컬 `AivisSpeech Engine` (`http://127.0.0.1:10101`) 연동
   - 캐릭터별 `style_id` 적용 후 단어·예문 오디오 자동 합성 및 **`256kbps` 고음질 `.m4a` 인코딩**
3. **`quick_review` (고속 검수기)**
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
