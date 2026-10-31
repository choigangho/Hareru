import Foundation

// MARK: - 카드 인터랙션 & 10초 3단 등속 파도 타이밍 상수 (SPEC.md §2.1, §2.2)
/// 실기기 사용성 테스트 시 타이밍을 한 곳에서 즉시 조정할 수 있도록 모든 시간 상수를 중앙 관리합니다.
public struct CardTimingConfig: Codable, Equatable, Hashable, Sendable {
    public let totalSequenceDuration: Double         // 전체 힌트 시퀀스 길이 (기본 10.0초)
    public let waveRampDuration: Double              // 각 파도가 흐림(0.0)→선명(1.0)에 도달하는 일관 시간 (Δ6.0초)
    public let voiceTagStart: Double                 // 캐릭터 이름 태그 출발 시각 (0.0초)
    public let voiceTagDuration: Double              // 캐릭터 이름 태그 선명화 시간 (3.0초)
    public let wave1ExampleStart: Double             // 파도 1(일본어 예문) 출발 시각 (0.0초)
    public let wave2FuriganaStart: Double            // 파도 2(주변 문맥 후리가나) 출발 시각 (2.0초)
    public let wave3ContextStart: Double             // 파도 3(한국어 앞/뒤 문맥) 출발 시각 (4.0초)
    public let waveCurveExponent: Double             // 비선형 easeOut 곡선 지수 (1.6)
    public let answerRevealDuration: Double          // '정답 보기' 클릭 시 해금 애니메이션 시간 (0.25초)
    public let initialDelayBeforeTermAudio: Double   // '정답 보기' 후 단어 음성 재생 대기 시간 (0.50초)
    public let gapBetweenTermAndExampleAudio: Double // 단어 음성 종료 후 예문 음성 간격 (0.45초)

    public init(
        totalSequenceDuration: Double = 10.0,
        waveRampDuration: Double = 6.0,
        voiceTagStart: Double = 0.0,
        voiceTagDuration: Double = 3.0,
        wave1ExampleStart: Double = 0.0,
        wave2FuriganaStart: Double = 2.0,
        wave3ContextStart: Double = 4.0,
        waveCurveExponent: Double = 1.6,
        answerRevealDuration: Double = 0.25,
        initialDelayBeforeTermAudio: Double = 0.50,
        gapBetweenTermAndExampleAudio: Double = 0.45
    ) {
        self.totalSequenceDuration = max(1.0, totalSequenceDuration)
        self.waveRampDuration = max(0.1, waveRampDuration)
        self.voiceTagStart = max(0.0, voiceTagStart)
        self.voiceTagDuration = max(0.1, voiceTagDuration)
        self.wave1ExampleStart = max(0.0, wave1ExampleStart)
        self.wave2FuriganaStart = max(0.0, wave2FuriganaStart)
        self.wave3ContextStart = max(0.0, wave3ContextStart)
        self.waveCurveExponent = max(0.5, waveCurveExponent)
        self.answerRevealDuration = max(0.05, answerRevealDuration)
        self.initialDelayBeforeTermAudio = max(0.0, initialDelayBeforeTermAudio)
        self.gapBetweenTermAndExampleAudio = max(0.0, gapBetweenTermAndExampleAudio)
    }

    public static let standard = CardTimingConfig()

    // MARK: - 시간 경과(`elapsedSeconds`)에 따른 레이어별 선명도 (0.0 ~ 1.0)

    public func voiceTagProgress(at elapsedSeconds: Double) -> Double {
        curvedProgress(elapsed: elapsedSeconds, start: voiceTagStart, duration: voiceTagDuration)
    }

    /// 파도 1 · 일본어 예문 (0.0 ~ 6.0초)
    public func wave1Progress(at elapsedSeconds: Double) -> Double {
        curvedProgress(elapsed: elapsedSeconds, start: wave1ExampleStart, duration: waveRampDuration)
    }

    /// 파도 2 · 주변 문맥 후리가나 (2.0 ~ 8.0초, 표제어 어절 제외)
    public func wave2Progress(at elapsedSeconds: Double) -> Double {
        curvedProgress(elapsed: elapsedSeconds, start: wave2FuriganaStart, duration: waveRampDuration)
    }

    /// 파도 3 · 한국어 앞/뒤 문맥 (4.0 ~ 10.0초)
    public func wave3Progress(at elapsedSeconds: Double) -> Double {
        curvedProgress(elapsed: elapsedSeconds, start: wave3ContextStart, duration: waveRampDuration)
    }

    public func remainingSeconds(at elapsedSeconds: Double) -> Int {
        let left = max(0.0, totalSequenceDuration - max(0.0, elapsedSeconds))
        return Int(ceil(left))
    }

    private func curvedProgress(elapsed: Double, start: Double, duration: Double) -> Double {
        guard elapsed > start else { return 0.0 }
        let linear = min((elapsed - start) / duration, 1.0)
        if linear >= 1.0 { return 1.0 }
        // 동일한 비선형 easeOut 곡선: 초반에 윤곽이 서서히 드러나며 끝에서 완전히 또렷해짐
        return 1.0 - pow(1.0 - linear, waveCurveExponent)
    }
}
