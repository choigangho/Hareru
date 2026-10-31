# Project Handover Document: BocaSample (일본어 단어 암기 앱)

> **Document Purpose**: 본 문서는 안티그래비티(Antigravity) 또는 후속 AI 어시스턴트/개발 환경으로 프로젝트의 맥락, 전체 아키텍처, 구현 현황, 특수 인터랙션 규칙 및 향후 로드맵을 완벽히 인계하기 위한 핸드오버 명세서입니다.

---

## 1. 프로젝트 개요 (Overview)
- **앱 성격**: 게이미피케이션 및 인지심리학적 타이밍 인터랙션을 결합한 실무형 iOS 일본어 단어 암기 앱
- **주요 타깃 환경**: iOS 17+, macOS 14+ (SwiftUI, AVFoundation)
- **핵심 차별점**: 단순 플래시카드가 아닌, **10초 점진적 선명화(그라데이션 블러 해제)**와 **회상 반응 속도 기반의 지능형 간격 반복(Spaced Repetition) 알고리즘** 결합

---

## 2. 파일 및 디렉토리 구조 (Directory Structure)

프로젝트 루트: `/Users/choigangho/temp/BocaSample`

```text
BocaSample/
├── Package.swift                    # Swift Package 매니페스트 (Xcode 단독 오픈 및 Canvas 프리뷰 지원)
├── HANDOVER_ANTIGRAVITY.md          # 안티그래비티 인계 명세서 (본 파일)
├── App/
│   └── BocaSampleApp.swift          # @main 앱 진입점
├── Models/
│   ├── Word.swift                   # 단어 도메인 모델 (Identifiable, Equatable)
│   ├── Word+Samples.swift           # 정적 샘플 단어 데이터 (beer, ramen)
│   └── VoiceProfile.swift           # 캐릭터별 음성 프로필 (부장님, 라멘집 사장님 등)
├── Services/
│   └── SpeechPlayer.swift           # ElevenLabs 로컬 오디오 우선 재생 + iOS 기본 TTS 자동 백업
├── Views/
│   ├── WordDeckView.swift           # 상단 카테고리 배지, 진행도 막대 게이지(1/2, 2/2), 카드 전환
│   ├── WordCardView.swift           # 단일 카드 UI, 10초 시퀀스 타이머 및 정답/음성 딜레이 제어
│   └── Components/
│       ├── SplitText.swift          # "앞 문맥 / 정답 / 뒤 문맥" 분할 렌더링 컴포넌트
│       └── HintBlurModifier.swift   # progress 기반의 blur 및 opacity 제어 View 확장
└── Resources/
    ├── Audio/                       # 표준화된 오디오 리소스
    │   ├── beer_term.wav            # 단어 음성: ビール
    │   ├── beer_example.wav         # 예문 음성: とりあえず、ビールで乾杯しましょう。
    │   ├── ramen_term.wav           # 단어 음성: ラーメン
    │   └── ramen_example.wav        # 예문 음성: 締めはやっぱり豚骨ラーメンですね。
    └── Data/
        └── words.json               # 단어 메타데이터 JSON 규격 (스키마 명세)
```

---

## 3. 핵심 인터랙션 규칙 (Core UX & Interaction Spec)

### 3.1. 10초 점진적 선명화 (그라데이션 블러 시퀀스)
- **시작 시점**: 카드가 화면에 나타나는 즉시(`task(id: round)`) 10초 시퀀스 시작 (`withAnimation(.linear(duration: 10.0))`)
- **영향 받는 요소 (점진적 노출)**:
  1. **후리가나 (읽는 법)**: 10초 동안 서서히 선명해짐
  2. **일본어 예문 본문**: 10초 동안 서서히 선명해짐
  3. **예문 한국어 해설 문맥 (`transBefore`, `transAfter`)**: 10초 동안 서서히 선명해짐
- **영향 받지 않는 요소 (정답 보호)**:
  - **단어 뜻 (한국어)**: 10초가 지나도 완전히 흐린 상태 유지
  - **예문 해설 속 정답 단어 (`transAnswer`)**: 10초가 지나도 투명/흐림 유지
  - ➜ 반드시 사용자가 **'정답 보기' 버튼을 눌러야만 즉시(0.25초) 100% 선명**해짐

### 3.2. 정답 공개 후 순차 음성 재생 (Audio Sequence)
- **정답 보기 클릭 ➜ 0.5초 대기 (`initialDelay`)** ➜ 단어 음성(`termAudioFile`) 재생
- 단어 음성 재생 종료 ➜ **0.45초 간격 (`gapDelay`)** ➜ 예문 음성(`exampleAudioFile`) 자동 재생

---

## 4. 향후 로드맵: 그라데이션 타이밍 연동 암기 알고리즘 (Anki / FSRS 변형)

사용자의 주관적 판단에만 의존하지 않고, **"힌트 의존도(반응 속도)"를 측정하여 복습 주기를 강제 보정(Downgrade/Cap)**하는 독자적 알고리즘 설계안:

| '정답 보기' 클릭 시점 | 사용자가 누른 버튼 | 실제 시스템 반영 등급 | 복습 주기 (Interval) | 알고리즘 판정 사유 |
| :--- | :--- | :--- | :--- | :--- |
| **0 ~ 5.9초**<br>(힌트가 심하게 흐림) | 쉬움 (Easy)<br>앎 (Good)<br>애매함 (Hard)<br>모름 (Again) | **쉬움 (Easy)**<br>**앎 (Good)**<br>**애매함 (Hard)**<br>**모름 (Again)** | 3일<br>1일 (or 15분)<br>8분<br>1분 | 힌트 없이 본인 뇌의 기억만으로 인출 성공 (인정) |
| **6.0 ~ 9.9초**<br>(힌트가 60% 이상 노출됨) | **쉬움 (Easy)**<br>**앎 (Good)**<br>애매함 (Hard)<br>모름 (Again) | **애매함 (Hard) 강제**<br>**애매함 (Hard) 강제**<br>모름 (Again) 강제<br>모름 (Again) | 8분<br>8분<br>1분<br>1분 | 후리가나/예문 힌트를 보고 유추했을 가능성 높음 (등급 강등) |
| **10.0초 이후**<br>(힌트가 100% 선명해짐) | **쉬움 / 앎**<br>**애매함 (Hard)**<br>모름 (Again) | **애매함 (Hard)**<br>**모름 (Again) 강제**<br>모름 (Again) | 8분<br>1분<br>1분 | 힌트를 다 보고도 긴가민가했으므로 당일 재학습 대상 |

---

## 5. 데이터 저장 및 확장 가이드 (Production Standards)
1. **오디오 네이밍**: 일본어/한글 파일명은 macOS와 서버 간 유니코드(NFD vs NFC) 인코딩 충돌을 유발하므로, `word_ID_term.wav`, `word_ID_example.wav`와 같은 영문 식별자 표준을 유지할 것.
2. **단어 데이터 파싱**: 추후 로컬 DB(SQLite/CoreData) 또는 [words.json](file:///Users/choigangho/temp/BocaSample/Resources/Data/words.json) 기반의 디코딩 모델(`Decodable`)로 교체하여 정적 코드 의존성을 분리할 것.
