import Foundation
import AVFoundation

// MARK: - 음성 재생 서비스 (사전 제작된 고음질 로컬 오디오 전용 재생, TTS 폴백 없음)
final class SpeechPlayer: NSObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    private var sequenceTask: Task<Void, Never>?
    private var nextAction: (() -> Void)?

    private func setupAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    func stop() {
        sequenceTask?.cancel()
        sequenceTask = nil
        nextAction = nil
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        audioPlayer = nil
    }

    /// 단일 오디오 재생 (사전 제작된 오디오 파일만 재생하며, 미수신 시 재생하지 않음)
    func playSingle(fileName: String, fallbackText: String = "", voice: VoiceProfile? = nil) {
        stop()
        _ = playInternal(fileName: fileName)
    }

    /// 정답 공개 시:
    /// 1) initialDelay(초) 후 단어 음성 재생
    /// 2) 단어 음성이 끝나면 gapDelay(초) 후 예문 음성 자동 재생
    func playTermThenExample(
        for word: Word,
        initialDelay: Double = 0.5,
        gapDelay: Double = 0.45
    ) {
        stop()

        nextAction = { [weak self] in
            self?.sequenceTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(gapDelay))
                guard !Task.isCancelled else { return }
                _ = self?.playInternal(fileName: word.exampleAudioFile)
            }
        }

        sequenceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(initialDelay))
            guard !Task.isCancelled else { return }
            let started = self?.playInternal(fileName: word.termAudioFile) ?? false
            if !started {
                self?.nextAction = nil
            }
        }
    }

    @discardableResult
    private func playInternal(fileName: String) -> Bool {
        setupAudioSession()

        guard let url = Self.resolveAudioURL(for: fileName),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            return false
        }
        self.audioPlayer = player
        player.delegate = self
        return player.play()
    }

    private static func resolveAudioURL(for fileName: String) -> URL? {
        let cleanStem = AudioFileName.normalize(fileName)
        guard !cleanStem.isEmpty else { return nil }
        let supportedExtensions = ["m4a", "wav", "mp3"]

        // 1) Swift Package(Bundle.module) 및 앱 번들(Bundle.main) 검색
        let bundles: [Bundle] = [Bundle.module, Bundle.main]
        for bundle in bundles {
            for ext in supportedExtensions {
                if let url = bundle.url(forResource: cleanStem, withExtension: ext) {
                    return url
                }
                if let url = bundle.url(forResource: cleanStem, withExtension: ext, subdirectory: "Audio") {
                    return url
                }
                if let url = bundle.url(forResource: cleanStem, withExtension: ext, subdirectory: "Resources/Audio") {
                    return url
                }
            }
        }

        // 2) Swift Playgrounds / 프리뷰 환경을 위한 상대 경로 탐색
        let sourceDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Services
            .deletingLastPathComponent() // Sources/Hareru
        let audioDir = sourceDir.appendingPathComponent("Resources/Audio", isDirectory: true)

        for ext in supportedExtensions {
            let candidate = audioDir.appendingPathComponent("\(cleanStem).\(ext)")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag, let next = nextAction else { return }
        nextAction = nil
        next()
    }
}
