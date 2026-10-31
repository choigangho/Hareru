import SwiftUI

// MARK: - 탭 2 게임 그룹 허브 화면 (SMS 에피소드 선택 & 미니게임 확장 그룹, SPEC.md §1.3)
public struct GameHubView: View {
    public let episodes: [SMSEpisode]
    private let sessionEngine: StudySessionEngine?
    @State private var selectedEpisode: SMSEpisode?
    @State private var clearedScoresByEpisodeId: [String: Int] = [:]

    public init(
        episodes: [SMSEpisode] = SMSEpisode.samples,
        engine: StudySessionEngine? = nil
    ) {
        self.episodes = episodes
        self.sessionEngine = engine
    }

    private var availableTickets: [GameTicket] {
        guard let sessionEngine else { return [] }
        _ = sessionEngine.stateRevision
        return sessionEngine.unconsumedGameTickets()
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !availableTickets.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "ticket.fill")
                                .foregroundStyle(.orange)
                            Text("보유 중인 SMS 미션 티켓: \(availableTickets.count)장")
                                .font(.caption.weight(.bold))
                            Spacer()
                            Text("미션 시작 시 1장 자동 사용")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    // 1) 상단 게임 그룹 모드 배너
                    VStack(alignment: .leading, spacing: 10) {
                        Text("게임 모드 그룹")
                            .font(.headline)

                        ForEach(GameModeKind.allCases) { mode in
                            HStack(spacing: 12) {
                                Image(systemName: mode.iconName)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        mode.isPlayable ? Color.orange.opacity(0.18) : Color.secondary.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                    .foregroundStyle(mode.isPlayable ? .orange : .secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(mode.title)
                                            .font(.subheadline.weight(.bold))
                                        Text(mode.isPlayable ? "PLAYABLE" : "COMING SOON")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                mode.isPlayable ? Color.green.opacity(0.18) : Color.secondary.opacity(0.14),
                                                in: Capsule()
                                            )
                                            .foregroundStyle(mode.isPlayable ? .green : .secondary)
                                    }
                                    Text(mode.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    // 2) 캐릭터 SMS 에피소드 스테이지 목록
                    VStack(alignment: .leading, spacing: 12) {
                        Text("가상 일본인 SMS 미션 스테이지")
                            .font(.headline)

                        ForEach(episodes) { episode in
                            episodeCard(episode)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("게임 (SMS 미션)")
            .navigationDestination(item: $selectedEpisode) { episode in
                SMSGameView(episode: episode) { finished, score in
                    clearedScoresByEpisodeId[finished.id] = max(clearedScoresByEpisodeId[finished.id] ?? 0, score)
                    selectedEpisode = nil
                }
            }
        }
    }

    private func episodeCard(_ episode: SMSEpisode) -> some View {
        let accent = episode.palette.accentColor
        let bestScore = clearedScoresByEpisodeId[episode.id]

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(String(episode.voice.label.prefix(1)))
                            .font(.title3.bold())
                            .foregroundStyle(accent)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(episode.title)
                            .font(.headline)
                        if let bestScore {
                            Text("호감도 \(bestScore)%")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.pink.opacity(0.16), in: Capsule())
                                .foregroundStyle(.pink)
                        }
                    }
                    Text("\(episode.voice.label) · \(episode.turns.count)턴 단기 미션")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text(episode.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                if let firstTicket = availableTickets.first {
                    _ = sessionEngine?.consumeGameTicket(id: firstTicket.id)
                }
                selectedEpisode = episode
            } label: {
                HStack {
                    Image(systemName: "message.and.waveform.fill")
                    Text("SMS 미션 시작하기")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview("게임 허브") {
    GameHubView()
}
