import SwiftUI

// MARK: - 탭 2 통계 허브 (3D 글라스 잔디 · 학습 요약 · 4버튼 평가 통계)
// 내부 6단계 히든 기억 등급은 노출하지 않고, 사용자가 직접 누른 4버튼 기록만 날씨 톤으로 보여줍니다.
public struct InsightsHubView: View {
    private let sessionEngine: StudySessionEngine
    private let weatherEngine: WeatherAtmosphereEngine

    public init(engine: StudySessionEngine? = nil, weatherEngine: WeatherAtmosphereEngine = .shared) {
        if let engine {
            self.sessionEngine = engine
        } else {
            self.sessionEngine = StudySessionEngine(store: InMemoryMemoryStore())
        }
        self.weatherEngine = weatherEngine
    }

    private var palette: WeatherSkyPalette { weatherEngine.activePalette }

    // MARK: - 실시간 파생 데이터

    private var reviewLogs: [ReviewLogEntry] {
        _ = sessionEngine.stateRevision
        return sessionEngine.store.allReviewLogs()
    }

    private var learnedSnapshots: [WordMemorySnapshot] {
        _ = sessionEngine.stateRevision
        return sessionEngine.store.allSnapshots().values.filter { $0.reps > 0 }
    }

    private var averageRetrievability: Double {
        let items = learnedSnapshots
        guard !items.isEmpty else { return 0.0 }
        let now = Date()
        let sum = items.reduce(0.0) { acc, snapshot in
            guard let state = snapshot.memoryState else { return acc }
            return acc + sessionEngine.fsrs.currentRetrievability(for: state, now: now)
        }
        return sum / Double(items.count)
    }

    private var averageReactionSeconds: Double {
        let logs = reviewLogs
        guard !logs.isEmpty else { return 0.0 }
        return logs.reduce(0.0) { $0 + $1.reactionSeconds } / Double(logs.count)
    }

    public var body: some View {
        let logs = reviewLogs

        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    GlassGrassHeatmapCard(
                        columns: StudyHeatmapCalculator.weeklyColumns(logs: logs, calendar: sessionEngine.calendar),
                        streak: StudyHeatmapCalculator.currentStreak(logs: logs, calendar: sessionEngine.calendar),
                        palette: palette
                    )

                    summaryGrid(logs: logs)

                    buttonDistributionCard(logs: logs)
                }
                .padding(16)
            }
            .background {
                WeatherSkyCanvasView(
                    condition: weatherEngine.activeCondition,
                    timeOfDay: weatherEngine.activeTimeOfDay,
                    palette: palette,
                    isHareruCleared: weatherEngine.isHareruClearedToday
                )
            }
            .navigationTitle("통계")
        }
    }

    // MARK: - 학습 요약 4칸

    private func summaryGrid(logs: [ReviewLogEntry]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricCard(
                title: "외운 단어",
                value: "\(learnedSnapshots.count) / \(sessionEngine.catalog.words.count)",
                icon: "character.book.closed.fill"
            )
            metricCard(
                title: "평균 기억 유지율",
                value: learnedSnapshots.isEmpty ? "—" : String(format: "%.0f%%", averageRetrievability * 100),
                icon: "brain.head.profile"
            )
            metricCard(
                title: "평균 반응 시간",
                value: logs.isEmpty ? "—" : String(format: "%.1f초", averageReactionSeconds),
                icon: "timer"
            )
            metricCard(
                title: "누적 평가",
                value: "\(logs.count)회",
                icon: "hand.tap.fill"
            )
        }
    }

    private func metricCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.accentColor)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(palette.primaryTextColor)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryTextColor)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hareruGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), tint: palette.glassTintColor)
    }

    // MARK: - 4버튼 평가 통계 (모르겠음 · 애매함 · 알고있음 · 쉬움)

    private func buttonDistributionCard(logs: [ReviewLogEntry]) -> some View {
        let distribution = StudyHeatmapCalculator.buttonDistribution(logs: logs)
        let total = max(1, logs.count)

        return VStack(alignment: .leading, spacing: 14) {
            Text("내 평가 기록")
                .font(.headline)
                .foregroundStyle(palette.primaryTextColor)

            // 비율 한 줄 스택 바
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(distribution.filter { $0.count > 0 }, id: \.button) { entry in
                        Capsule()
                            .fill(palette.buttonColor(for: entry.button))
                            .frame(width: max(6, (geo.size.width - 6) * CGFloat(entry.count) / CGFloat(total)))
                    }
                }
            }
            .frame(height: 10)
            .background(Capsule().fill(palette.secondaryTextColor.opacity(0.18)))

            ForEach(distribution, id: \.button) { entry in
                HStack(spacing: 10) {
                    Circle()
                        .fill(palette.buttonColor(for: entry.button))
                        .frame(width: 10, height: 10)
                    Text(entry.button.koreanTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primaryTextColor)
                    Spacer()
                    Text("\(entry.count)회")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(palette.primaryTextColor)
                    Text(logs.isEmpty ? "—" : String(format: "%.0f%%", Double(entry.count) / Double(total) * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(palette.secondaryTextColor)
                        .frame(width: 40, alignment: .trailing)
                }
            }

            if logs.isEmpty {
                Text("카드를 평가하면 이곳에 버튼별 기록이 쌓입니다.")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryTextColor)
            }
        }
        .padding(16)
        .hareruGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), tint: palette.glassTintColor)
    }
}

// MARK: - 최상단 3D 글라스 잔디 (최근 14주 성실도 히트맵)
struct GlassGrassHeatmapCard: View {
    let columns: [[StudyHeatmapDay]]
    let streak: Int
    let palette: WeatherSkyPalette

    @State private var selectedDay: StudyHeatmapDay?

    private static let spacing: CGFloat = 4
    private static let maxExtrusion: CGFloat = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("성실도 잔디")
                    .font(.headline)
                    .foregroundStyle(palette.primaryTextColor)
                Spacer()
                Label("\(streak)일 연속", systemImage: "flame.fill")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(palette.accentColor)
            }

            GeometryReader { geo in
                let cell = cellSize(for: geo.size.width)
                ZStack(alignment: .topLeading) {
                    HStack(alignment: .top, spacing: Self.spacing) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                            VStack(spacing: Self.spacing) {
                                ForEach(week) { day in
                                    GlassGrassBlock(
                                        level: day.intensityLevel,
                                        isFuture: day.isFuture,
                                        isSelected: selectedDay?.id == day.id,
                                        size: cell,
                                        maxExtrusion: Self.maxExtrusion,
                                        palette: palette
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        guard !day.isFuture else { return }
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            selectedDay = selectedDay?.id == day.id ? nil : day
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if let selectedDay, let position = gridPosition(of: selectedDay) {
                        bubble(for: selectedDay)
                            .position(bubbleCenter(column: position.column, row: position.row, cell: cell, width: geo.size.width))
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                }
            }
            .frame(height: gridHeight)
            .padding(.top, Self.maxExtrusion)

            HStack(spacing: 4) {
                Text("최근 14주")
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryTextColor)
                Spacer()
                Text("적음")
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryTextColor)
                ForEach(0...4, id: \.self) { level in
                    GlassGrassBlock(level: level, isFuture: false, isSelected: false, size: 10, maxExtrusion: 2, palette: palette)
                }
                Text("많음")
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryTextColor)
            }
        }
        .padding(16)
        .hareruGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), tint: palette.glassTintColor)
    }

    // MARK: - 격자 좌표 계산

    private var gridHeight: CGFloat {
        // 셀은 최대 20pt까지 커지므로 그 기준으로 7행 높이를 확보합니다.
        7 * 20 + 6 * Self.spacing
    }

    private func cellSize(for width: CGFloat) -> CGFloat {
        let count = CGFloat(max(1, columns.count))
        let fitted = (width - (count - 1) * Self.spacing) / count
        return min(20, max(10, fitted))
    }

    private func gridPosition(of day: StudyHeatmapDay) -> (column: Int, row: Int)? {
        for (columnIndex, week) in columns.enumerated() {
            if let rowIndex = week.firstIndex(where: { $0.id == day.id }) {
                return (columnIndex, rowIndex)
            }
        }
        return nil
    }

    private func bubbleCenter(column: Int, row: Int, cell: CGFloat, width: CGFloat) -> CGPoint {
        let halfBubbleWidth: CGFloat = 78
        let cellCenterX = CGFloat(column) * (cell + Self.spacing) + cell / 2
        let x = min(max(cellCenterX, halfBubbleWidth), width - halfBubbleWidth)
        let cellTop = CGFloat(row) * (cell + Self.spacing)
        // 위쪽 두 줄은 말풍선을 블록 아래에, 나머지는 블록 위에 띄웁니다.
        let y = row < 2 ? cellTop + cell + 26 : cellTop - 26
        return CGPoint(x: x, y: y)
    }

    // MARK: - 미니 말풍선 (날짜 · 그날의 날씨 · 암기한 단어 수)

    private func bubble(for day: StudyHeatmapDay) -> some View {
        let weather = WeatherAtmosphereEngine.estimatedWeather(
            for: Calendar.current.date(byAdding: .hour, value: 13, to: day.date) ?? day.date
        )
        return HStack(spacing: 8) {
            Image(systemName: weather.condition.sfSymbolName(for: .midday))
                .symbolRenderingMode(.multicolor)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 1) {
                Text(day.date.formatted(.dateTime.month().day().weekday(.abbreviated).locale(Locale(identifier: "ko_KR"))))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.secondaryTextColor)
                Text(day.studiedWordCount > 0 ? "\(day.studiedWordCount)단어 암기" : "쉬어간 날")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(palette.primaryTextColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .fixedSize()
        .hareruGlass(in: Capsule(), tint: palette.glassTintColor)
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }
}

// MARK: - 입체 베벨 글라스 잔디 블록 1칸
struct GlassGrassBlock: View {
    let level: Int
    let isFuture: Bool
    let isSelected: Bool
    let size: CGFloat
    let maxExtrusion: CGFloat
    let palette: WeatherSkyPalette

    private var extrusion: CGFloat {
        guard level > 0 else { return 0.8 }
        return maxExtrusion * CGFloat(level) / 4
    }

    private var faceColor: Color {
        guard level > 0 else { return palette.secondaryTextColor.opacity(isFuture ? 0.06 : 0.16) }
        let base = palette.buttonColor(for: .easy)
        return base.opacity(0.35 + 0.16 * Double(level))
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)

        ZStack {
            // 옆면(돌출 깊이): 아래·오른쪽으로 밀린 어두운 면
            shape
                .fill(faceColor.opacity(level > 0 ? 1 : 0.6))
                .brightness(-0.28)
                .offset(x: extrusion * 0.45, y: extrusion)

            // 윗면: 위에서 비치는 빛을 받는 유리 그라데이션 + 베벨 하이라이트
            shape
                .fill(faceColor)
                .overlay {
                    shape.fill(
                        LinearGradient(
                            colors: [.white.opacity(level > 0 ? 0.42 : 0.16), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                }
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.7), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
                }
                .overlay {
                    if isSelected {
                        shape.strokeBorder(palette.primaryTextColor, lineWidth: 1.4)
                    }
                }
        }
        .frame(width: size, height: size)
        .offset(y: isSelected ? -2 : 0)
        .shadow(color: .black.opacity(level > 0 ? 0.18 : 0), radius: extrusion, y: extrusion)
    }
}

#Preview("통계 허브") {
    InsightsHubView(engine: StudySessionEngine(store: InMemoryMemoryStore()))
}
