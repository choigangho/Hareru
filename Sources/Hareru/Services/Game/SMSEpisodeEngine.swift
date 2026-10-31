import Foundation
import Observation

// MARK: - 분기형 SMS 에피소드 진행 엔진 (SPEC.md §1.3)
@Observable
public final class SMSEpisodeEngine {
    public let episode: SMSEpisode
    public let converter: HangulKanaConverter

    public private(set) var messages: [SMSChatMessage] = []
    public private(set) var currentTurnIndex: Int = 0
    public private(set) var affectionScore: Int = 20
    public private(set) var isNPCTyping: Bool = false
    public private(set) var isEpisodeCleared: Bool = false
    public var inputText: String = ""

    private var typingTask: Task<Void, Never>?

    public init(
        episode: SMSEpisode,
        converter: HangulKanaConverter = HangulKanaConverter()
    ) {
        self.episode = episode
        self.converter = converter
        startEpisode()
    }

    public var currentTurn: SMSTurnStage? {
        guard currentTurnIndex >= 0 && currentTurnIndex < episode.turns.count else {
            return nil
        }
        return episode.turns[currentTurnIndex]
    }

    public var totalTurns: Int {
        episode.turns.count
    }

    /// 입력창의 한글 발음을 실시간 일본어 문장으로 변환한 미리보기 텍스트
    public var convertedPreviewText: String {
        converter.convertFullInput(inputText)
    }

    /// 현재 입력 중인 어절에 대한 추천 일본어 변환 칩 목록
    public var liveCandidates: [HangulConversionCandidate] {
        converter.suggestCandidates(for: inputText, limit: 5)
    }

    // MARK: - 1) 에피소드 시작 및 초기화

    public func startEpisode() {
        typingTask?.cancel()
        typingTask = nil
        messages = []
        currentTurnIndex = 0
        affectionScore = 20
        isNPCTyping = false
        isEpisodeCleared = false
        inputText = ""

        if let firstTurn = currentTurn {
            messages.append(
                SMSChatMessage(
                    sender: .npc,
                    japaneseText: firstTurn.npcPromptText,
                    koreanTranslation: firstTurn.npcPromptTranslation,
                    audioFile: firstTurn.npcPromptAudioFile
                )
            )
        }
    }

    // MARK: - 2) 후보 칩 선택 시 현재 입력창에 일본어 어절 삽입

    public func applyCandidate(_ entry: HangulPhoneticEntry) {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            inputText = entry.surface
            return
        }

        var parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        if let last = parts.last,
           last.unicodeScalars.contains(where: { (0xAC00...0xD7A3).contains($0.value) }) {
            parts.removeLast()
            parts.append(entry.surface)
            inputText = parts.joined(separator: "")
        } else {
            inputText = trimmed + entry.surface
        }
    }

    // MARK: - 3) 답장 판정 순수 함수 (즉시 검증 & 단위 테스트 겸용)

    public func evaluateReply(
        rawInput: String,
        for turn: SMSTurnStage
    ) -> (convertedJapanese: String, branch: SMSTurnReplyBranch) {
        let converted = converter.convertFullInput(rawInput)
        let normalizedSurface = converted.lowercased()
        let normalizedHiragana = JapaneseScript.toHiragana(converted)

        var matchedGroups = 0
        let totalGroups = max(1, turn.requiredKeywordGroups.count)

        for group in turn.requiredKeywordGroups {
            let groupMatched = group.contains { keyword in
                let cleanKey = keyword.lowercased()
                let hiraKey = JapaneseScript.toHiragana(keyword)
                return normalizedSurface.contains(cleanKey) || normalizedHiragana.contains(hiraKey)
            }
            if groupMatched {
                matchedGroups += 1
            }
        }

        let branch: SMSTurnReplyBranch
        if matchedGroups == totalGroups || (totalGroups >= 3 && matchedGroups >= totalGroups - 1) {
            branch = turn.greatBranch
        } else if matchedGroups >= 1 {
            branch = turn.partialBranch
        } else {
            branch = turn.hintBranch
        }

        return (converted, branch)
    }

    // MARK: - 4) 답장 전송 및 상대방 '입력 중•••' 연출 진행

    /// 즉시 동기식 처리 (`typingDelay == 0`이면 대기 없이 바로 다음 턴 반영)
    @discardableResult
    public func submitReplyImmediately(_ customInput: String? = nil) -> SMSTurnReplyBranch? {
        guard !isNPCTyping, !isEpisodeCleared, let turn = currentTurn else { return nil }
        let raw = (customInput ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let (converted, branch) = evaluateReply(rawInput: raw, for: turn)
        inputText = ""

        messages.append(
            SMSChatMessage(
                sender: .player,
                japaneseText: converted,
                rawHangulInput: (raw != converted) ? raw : nil,
                coachingTip: branch.coachingTip,
                affectionDelta: branch.tier.affectionDelta
            )
        )

        applyNPCBranchResponse(branch, for: turn)
        return branch
    }

    /// 실제 UI에서 `'입력 중•••'` 인디케이터 애니메이션 후 캐릭터 답장과 음성을 노출
    public func sendPlayerInputWithTypingAnimation(
        typingDelay: Double = 0.65,
        onNPCVoiceReady: ((String?) -> Void)? = nil
    ) {
        guard !isNPCTyping, !isEpisodeCleared, let turn = currentTurn else { return }
        let raw = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        let (converted, branch) = evaluateReply(rawInput: raw, for: turn)
        inputText = ""

        messages.append(
            SMSChatMessage(
                sender: .player,
                japaneseText: converted,
                rawHangulInput: (raw != converted) ? raw : nil,
                coachingTip: branch.coachingTip,
                affectionDelta: branch.tier.affectionDelta
            )
        )

        isNPCTyping = true
        typingTask?.cancel()
        typingTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(typingDelay))
            guard !Task.isCancelled, let self else { return }
            self.isNPCTyping = false
            self.applyNPCBranchResponse(branch, for: turn)
            onNPCVoiceReady?(branch.audioFile)
        }
    }

    private func applyNPCBranchResponse(_ branch: SMSTurnReplyBranch, for turn: SMSTurnStage) {
        affectionScore = min(100, affectionScore + branch.tier.affectionDelta)

        messages.append(
            SMSChatMessage(
                sender: .npc,
                japaneseText: branch.npcText,
                koreanTranslation: branch.npcTranslation,
                audioFile: branch.audioFile,
                stamp: branch.stamp
            )
        )

        // 대성공 또는 부분 성공이면 다음 턴으로 전진, 힌트 유도(.retryHint)면 현재 턴에서 재도전 기회 부여
        guard branch.tier != .retryHint else { return }

        let nextIndex = currentTurnIndex + 1
        if nextIndex < episode.turns.count {
            currentTurnIndex = nextIndex
            let nextTurn = episode.turns[nextIndex]
            messages.append(
                SMSChatMessage(
                    sender: .npc,
                    japaneseText: nextTurn.npcPromptText,
                    koreanTranslation: nextTurn.npcPromptTranslation,
                    audioFile: nextTurn.npcPromptAudioFile
                )
            )
        } else {
            isEpisodeCleared = true
        }
    }
}
