import SwiftUI

// MARK: - 탭 3 인사이트 허브 (기억 통계 · 성우 도감 · 손글씨 처방 노트 · 라이선스 고지, SPEC.md §1.4, §3.2, §4)
public struct InsightsHubView: View {
    public enum SectionTab: String, CaseIterable, Identifiable {
        case memory = "기억 통계"
        case voiceCodex = "성우 도감"
        case prescription = "처방 노트"

        public var id: String { rawValue }
    }

    private let sessionEngine: StudySessionEngine
    @State private var selectedSection: SectionTab = .memory
    @State private var handwritingChecksByWordId: [String: Set<Int>] = [:]
    @State private var feedbackMessage: String?
    @State private var speechPlayer = SpeechPlayer()

    public init(engine: StudySessionEngine? = nil) {
        if let engine {
            self.sessionEngine = engine
        } else {
            self.sessionEngine = StudySessionEngine(store: InMemoryMemoryStore())
        }
    }

    // MARK: - 실시간 파생 데이터

    private var snapshotsByWordId: [String: WordMemorySnapshot] {
        _ = sessionEngine.stateRevision
        return sessionEngine.store.allSnapshots()
    }

    private var reviewLogs: [ReviewLogEntry] {
        _ = sessionEngine.stateRevision
        return sessionEngine.store.allReviewLogs()
    }

    private var graduatedWords: [(word: Word, snapshot: WordMemorySnapshot)] {
        let map = snapshotsByWordId
        return sessionEngine.catalog.words.compactMap { word in
            guard let snap = map[word.id], snap.reps > 0 else { return nil }
            return (word, snap)
        }
    }

    private var comebackWords: [(word: Word, snapshot: WordMemorySnapshot)] {
        let map = snapshotsByWordId
        return sessionEngine.catalog.words.compactMap { word in
            guard let snap = map[word.id], snap.comebackCount > 0 else { return nil }
            return (word, snap)
        }
    }

    private var averageRetrievability: Double {
        let items = graduatedWords
        guard !items.isEmpty else { return 0.0 }
        let now = Date()
        let sum = items.reduce(0.0) { acc, pair in
            guard let state = pair.snapshot.memoryState else { return acc }
            return acc + sessionEngine.fsrs.currentRetrievability(for: state, now: now)
        }
        return sum / Double(items.count)
    }

    private var averageStability: Double {
        let items = graduatedWords
        guard !items.isEmpty else { return 0.0 }
        let sum = items.reduce(0.0) { $0 + $1.snapshot.stability }
        return sum / Double(items.count)
    }

    private var averageReactionSeconds: Double {
        let logs = reviewLogs
        guard !logs.isEmpty else { return 0.0 }
        let sum = logs.reduce(0.0) { $0 + $1.reactionSeconds }
        return sum / Double(logs.count)
    }

    private var gradeDistribution: [(grade: EvaluationGrade, count: Int)] {
        let logs = reviewLogs
        var counts: [EvaluationGrade: Int] = [:]
        for log in logs {
            counts[log.grade, default: 0] += 1
        }
        return EvaluationGrade.allCases.map { ($0, counts[$0, default: 0]) }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("인사이트 섹션", selection: $selectedSection) {
                        ForEach(SectionTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let message = feedbackMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.orange)
                            Text(message)
                                .font(.caption.weight(.semibold))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .transition(.opacity)
                    }

                    switch selectedSection {
                    case .memory:
                        memoryStatsSection
                    case .voiceCodex:
                        voiceCodexSection
                    case .prescription:
                        handwritingPrescriptionSection
                    }

                    licenseNoticeCard
                }
                .padding(16)
            }
            .navigationTitle("통계 · 도감 · 노트")
        }
    }

    // MARK: - 1) FSRS 기억 통계 대시보드

    private var memoryStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricCard(
                    title: "평균 기억 인출률 (R)",
                    value: graduatedWords.isEmpty ? "—" : String(format: "%.0f%%", averageRetrievability * 100),
                    subtitle: "목표 유지율 90% 기준",
                    icon: "brain.head.profile",
                    tint: .teal
                )

                metricCard(
                    title: "졸업 완료 단어",
                    value: "\(graduatedWords.count) / \(sessionEngine.catalog.words.count)",
                    subtitle: "한자 \(sessionEngine.catalog.kanjiByCharacter.count)자 수록",
                    icon: "checkmark.seal.fill",
                    tint: .orange
                )

                metricCard(
                    title: "평균 기억 안정도 (S)",
                    value: graduatedWords.isEmpty ? "—" : String(format: "%.1f일", averageStability),
                    subtitle: "90% 기억 유지 예상 일수",
                    icon: "calendar.badge.clock",
                    tint: .indigo
                )

                metricCard(
                    title: "평균 인출 반응 시간",
                    value: reviewLogs.isEmpty ? "—" : String(format: "%.2f초", averageReactionSeconds),
                    subtitle: "총 \(reviewLogs.count)회 평가 기록",
                    icon: "timer",
                    tint: .pink
                )
            }

            // 6단계 히든 등급 분포 카드
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("6단계 히든 기억 등급 분포")
                        .font(.headline)
                    Spacer()
                    Text("반응 시간 × 4버튼")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                let totalLogs = max(1, reviewLogs.count)
                ForEach(gradeDistribution, id: \.grade) { entry in
                    let ratio = Double(entry.count) / Double(totalLogs)
                    HStack(spacing: 10) {
                        Text("\(entry.grade.rawValue). \(entry.grade.displayName)")
                            .font(.caption.weight(.semibold))
                            .frame(width: 112, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.14))
                                Capsule()
                                    .fill(color(for: entry.grade))
                                    .frame(width: max(entry.count > 0 ? 8 : 0, geo.size.width * ratio))
                            }
                        }
                        .frame(height: 8)

                        Text("\(entry.count)회")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            // 역전 성공(Comeback) 단어 하이라이트
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("역전 졸업(Comeback) 단어", systemImage: "flame.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("\(comebackWords.count)개")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                if comebackWords.isEmpty {
                    Text("여러 번 틀려 붉게 침식된 카드를 끝까지 정화하여 졸업시키면 이곳에 역전 기록이 남습니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(comebackWords, id: \.word.id) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.word.term) (\(item.word.reading))")
                                    .font(.subheadline.weight(.bold))
                                Text(item.word.meaning)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("역전 \(item.snapshot.comebackCount)회 · S \(String(format: "%.1f", item.snapshot.stability))일")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.16), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func metricCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                Spacer()
            }
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(title)
                .font(.caption.weight(.semibold))
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func color(for grade: EvaluationGrade) -> Color {
        switch grade {
        case .again: return .red
        case .hiddenHintAssisted: return .orange
        case .hard: return .yellow
        case .good: return .green
        case .hiddenNearEasy: return .teal
        case .easy: return .blue
        }
    }

    // MARK: - 2) 10인 시그니처 성우 도감 (SPEC.md §4)

    private var voiceCodexSection: some View {
        let map = snapshotsByWordId
        return VStack(alignment: .leading, spacing: 14) {
            Text("AivisSpeech 256kbps 시그니처 성우 라인업 (10인)")
                .font(.headline)

            Text("단어와 다의어 서브 예문마다 전담 성우 캐릭터가 배정되어 목소리와 상황으로 기억을 각인시킵니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(VoiceProfile.allPresets) { voice in
                let relatedWords = sessionEngine.catalog.words.filter { word in
                    word.senses.contains { $0.voice.id == voice.id }
                }
                let masteredCount = relatedWords.filter { (map[$0.id]?.reps ?? 0) > 0 }.count

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.orange.opacity(0.18))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(String(voice.label.prefix(1)))
                                    .font(.headline.bold())
                                    .foregroundStyle(.orange)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(voice.label)
                                    .font(.subheadline.weight(.bold))
                                Text(archetypeTitle(voice.archetype))
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.14), in: Capsule())
                                    .foregroundStyle(.secondary)
                            }
                            Text(voice.tagline)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            if let sampleWord = relatedWords.first {
                                let played = speechPlayer.playSingle(
                                    fileName: sampleWord.termAudioFile,
                                    fallbackText: sampleWord.term,
                                    voice: voice
                                )
                                feedbackMessage = played
                                    ? "'\(voice.label)' 담당 단어 '\(sampleWord.term)' 오디오 재생"
                                    : "'\(voice.label)' 담당 단어 '\(sampleWord.term)' (사전 제작 오디오 준비 중)"
                            }
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption.weight(.bold))
                                .padding(8)
                                .background(Color.orange.opacity(0.15), in: Circle())
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack {
                        Text("담당 어휘 \(relatedWords.count)개 · 졸업 \(masteredCount)개")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(relatedWords.prefix(4).map(\.term).joined(separator: " · "))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.primary.opacity(0.8))
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func archetypeTitle(_ archetype: VoiceArchetype) -> String {
        switch archetype {
        case .everyday: return "현실 일상"
        case .homage: return "장르 오마주"
        case .modulated: return "특수 변조"
        }
    }

    // MARK: - 3) 오프라인 손글씨 처방 노트 (SPEC.md §1.4, §3.2)

    private var handwritingPrescriptionSection: some View {
        let leeches = sessionEngine.prescribedLeechWords()

        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("오프라인 손글씨 처방 노트", systemImage: "pencil.and.scribble")
                        .font(.headline)
                    Spacer()
                    Text("처방 대기 \(leeches.count)개")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.15), in: Capsule())
                        .foregroundStyle(.red)
                }

                Text("서로 다른 날 3회 이상 당일 8회 캡에 도달한 고난도 단어는 눈으로만 넘기는 루프를 멈추고, 실제 종이 노트에 손으로 3번 써서 소근육 기억을 깨운 뒤 학습 큐로 복귀시킵니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            if leeches.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.badge.questionmark")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("현재 처방 노트에 분류된 단어가 없습니다.")
                        .font(.subheadline.weight(.semibold))

                    Text("3일 누적 보류 흐름을 지금 바로 체험해보시려면 아래 시뮬레이션 버튼을 눌러보세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        let sampleTarget = sessionEngine.catalog.word(forId: "n3_biz_uketamawaru")
                            ?? sessionEngine.catalog.words.first
                        if let word = sampleTarget {
                            _ = sessionEngine.simulateLeechPrescription(for: word.id)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                feedbackMessage = "'\(word.term)' 단어를 3일 누적 보류(처방 노트 대상)로 시뮬레이션했습니다."
                            }
                        }
                    } label: {
                        Label("테스트용 처방 단어 시뮬레이션 (承る)", systemImage: "wand.and.stars")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                ForEach(leeches) { word in
                    prescriptionWordCard(word)
                }
            }
        }
    }

    private func prescriptionWordCard(_ word: Word) -> some View {
        let checks = handwritingChecksByWordId[word.id] ?? []
        let isAllChecked = checks.count >= 3

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(word.term)
                            .font(.title2.bold())
                        Text(word.reading)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(word.meaning)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text("3일 누적 보류")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.16), in: Capsule())
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("종이 노트에 아래 표제어와 예문을 3번 소리 내어 적어보세요:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(word.segments(for: word.primarySense).map(\.surfaceText).joined())
                    .font(.footnote.weight(.medium))
                Text(word.primarySense.translation.fullText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // 종이 노트 3회 필기 체크 버튼
            HStack(spacing: 10) {
                ForEach(1...3, id: \.self) { step in
                    let checked = checks.contains(step)
                    Button {
                        var current = handwritingChecksByWordId[word.id] ?? []
                        if checked {
                            current.remove(step)
                        } else {
                            current.insert(step)
                        }
                        handwritingChecksByWordId[word.id] = current
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                            Text("노트 \(step)회 쓰기")
                        }
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            checked ? Color.green.opacity(0.18) : Color.secondary.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .foregroundStyle(checked ? .green : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                _ = sessionEngine.completeHandwritingPrescription(for: word.id)
                handwritingChecksByWordId.removeValue(forKey: word.id)
                withAnimation(.easeInOut(duration: 0.25)) {
                    feedbackMessage = "'\(word.term)' 손글씨 처방 완료! 일반 학습 큐로 복귀했습니다."
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                    Text(isAllChecked ? "필기 완료 · 학습 큐로 복귀" : "3회 필기 완료 후 학습 큐 복귀")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(isAllChecked ? .green : .orange)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 4) 오픈 사전 및 음성 라이선스 고지 (SPEC.md §5)

    private var licenseNoticeCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("오픈 사전 및 음성 합성 라이선스 고지", systemImage: "doc.text.magnifyingglass")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text("• 사전 데이터: Electronic Dictionary Research and Development Group (EDRDG)의 JMdict 및 KANJIDIC2 데이터를 기반으로 재구성되었으며, CC BY-SA 4.0 라이선스를 준수합니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("• 음성 에셋: AivisSpeech 엔진 및 상업적 배포 허용(ACML / CC0) 성우 모델로 사전 제작된 고음질 오디오만 사용하며, 비영리 제한(ACML-NC) 모델 및 기계식 기본 TTS 폴백을 사용하지 않습니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview("인사이트 허브") {
    InsightsHubView(engine: StudySessionEngine(store: InMemoryMemoryStore()))
}
