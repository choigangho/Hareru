import Foundation
import AVFoundation

// MARK: - 음성 재생 서비스 (로컬 오디오 파일 우선 재생 + iOS 기본 TTS 자동 폴백)
final class SpeechPlayer: NSObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    
    // 단어 재생이 끝난 후 예문을 이어서 재생하기 위한 대기열
    private var nextAction: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    private func setupAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    func stop() {
        nextAction = nil
        if audioPlayer?.isPlaying == true { audioPlayer?.stop() }
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
    }

    /// 단일 오디오 재생 (오디오 파일이 번들이나 Resources/Audio에 있으면 재생, 없으면 TTS로 읽음)
    func playSingle(fileName: String, fallbackText: String, voice: VoiceProfile) {
        stop()
        playInternal(fileName: fileName, fallbackText: fallbackText, voice: voice)
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
            // 단어 음성이 끝난 뒤 자연스러운 호흡(gapDelay)을 두고 예문 재생
            DispatchQueue.main.asyncAfter(deadline: .now() + gapDelay) {
                self?.playInternal(fileName: word.exampleAudioFile,
                                   fallbackText: word.example,
                                   voice: word.voice)
            }
        }

        // "정답 보기"를 누른 후 약간의 텀(initialDelay)을 둔 뒤 단어 음성 시작
        DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) { [weak self] in
            self?.playInternal(fileName: word.termAudioFile,
                               fallbackText: word.term,
                               voice: word.voice)
        }
    }

    private func playInternal(fileName: String, fallbackText: String, voice: VoiceProfile) {
        setupAudioSession()

        // 1순위: 프로젝트 번들 또는 Resources/Audio 폴더의 오디오 파일(mp3, m4a, wav) 탐색
        if let url = Self.resolveAudioURL(for: fileName),
           let player = try? AVAudioPlayer(contentsOf: url) {
            self.audioPlayer = player
            player.delegate = self
            player.play()
            return
        }

        // 2순위: 오디오 파일이 없을 때는 iOS 기본 TTS로 재생
        let utterance = AVSpeechUtterance(string: fallbackText)
        utterance.voice = Self.japaneseVoice()
        utterance.pitchMultiplier = voice.pitch
        utterance.rate = voice.rate
        synthesizer.speak(utterance)
    }

    private static func resolveAudioURL(for fileName: String) -> URL? {
        let supportedExtensions = ["wav", "mp3", "m4a"]

        // 1) Swift Package(Bundle.module) 및 앱 번들(Bundle.main) 검색
        let bundles: [Bundle] = [Bundle.module, Bundle.main]
        for bundle in bundles {
            for ext in supportedExtensions {
                if let url = bundle.url(forResource: fileName, withExtension: ext) {
                    return url
                }
                if let url = bundle.url(forResource: fileName, withExtension: ext, subdirectory: "Audio") {
                    return url
                }
                if let url = bundle.url(forResource: fileName, withExtension: ext, subdirectory: "Resources/Audio") {
                    return url
                }
            }
        }

        // 2) Swift Playgrounds / 프리뷰 환경을 위한 상대 경로 탐색
        let sourceDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Services
            .deletingLastPathComponent() // BocaSample root
        let audioDir = sourceDir.appendingPathComponent("Resources/Audio", isDirectory: true)

        for ext in supportedExtensions {
            let candidate = audioDir.appendingPathComponent("\(fileName).\(ext)")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    // 오디오 파일 재생 완료 콜백
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag, let next = nextAction else { return }
        nextAction = nil
        next()
    }

    // TTS 읽기 완료 콜백
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard let next = nextAction else { return }
        nextAction = nil
        next()
    }

    private static func japaneseVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ja-JP" }
        if let otoya = voices.first(where: { $0.name.contains("Otoya") }) { return otoya }
        return voices.max(by: { $0.quality.rawValue < $1.quality.rawValue })
            ?? AVSpeechSynthesisVoice(language: "ja-JP")
    }
}
