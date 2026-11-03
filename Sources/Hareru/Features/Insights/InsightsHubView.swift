import SwiftUI

// MARK: - 탭 3 통계 허브 = 「판독 기록」 (레트로 모니터 더미 · 형광 잔디 · 학습 요약 · 4버튼 평가 통계)
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
            RetroScrollScreen(windowHeight: 120) {
                WeatherSkyCanvasView(
                    condition: weatherEngine.activeCondition,
                    timeOfDay: weatherEngine.activeTimeOfDay,
                    palette: palette,
                    isHareruCleared: weatherEngine.isHareruClearedToday
                )
            } content: {
                VStack(alignment: .leading, spacing: 14) {
                    header
                        .retroHangingCable(.dangle, x: 214)

                    GlassGrassHeatmapCard(
                        columns: StudyHeatmapCalculator.weeklyColumns(logs: logs, calendar: sessionEngine.calendar),
                        streak: StudyHeatmapCalculator.currentStreak(logs: logs, calendar: sessionEngine.calendar),
                        palette: palette
                    )
                    .retroHangingCable(.loop, x: 110)

                    summaryGrid(logs: logs)
                        .retroHangingCable(.red, x: 140, drop: -6)

                    HStack { RetroCodeMonitor(kind: .industrial).offset(x: -6); Spacer(minLength: 0) }

                    buttonDistributionCard(logs: logs)
                        .retroHangingCable(.dangle, x: 300)

                    HStack { Spacer(minLength: 0); RetroCodeMonitor(kind: .termA).offset(x: 6) }
                }
                .padding(.horizontal, 14)
                .padding(.top, 96)
                .padding(.bottom, 40)
            }
            .retroHidesNavigationBar()
        }
    }

    /// 머리: 작은 터미널(오른쪽으로 틀어짐)에 제목 + 커서, 옆에 코드만 흐르는 모니터
    private var header: some View {
        HStack(alignment: .bottom, spacing: 6) {
            RetroMonitor(style: .termRight, glow: 0.18) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("판독 기록").font(.title2.bold()).phosphor()
                        RetroCursor(height: 22)
                    }
                    Text("NJL-OS 2.94 · STATS").font(.caption2.monospaced()).phosphor(RetroColor.phosphorDim, glow: 2)
                }
            }
            RetroCodeMonitor(kind: .termB)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - 학습 요약 4칸 (작은 터미널, 조금씩 틀어지고 어긋나게)

    private func summaryGrid(logs: [ReviewLogEntry]) -> some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                metricCard(title: "외운 단어", value: "\(learnedSnapshots.count)/\(sessionEngine.catalog.words.count)",
                           icon: "cards", style: .term)
                metricCard(title: "평균 기억 유지율",
                           value: learnedSnapshots.isEmpty ? "—" : String(format: "%.0f%%", averageRetrievability * 100),
                           icon: "gauge", style: .termLeft)
                    .offset(y: 5)
            }
            GridRow {
                metricCard(title: "평균 반응 시간", value: logs.isEmpty ? "—" : String(format: "%.1f초", averageReactionSeconds),
                           icon: "stopwatch", style: .termRight)
                metricCard(title: "누적 평가", value: "\(logs.count)회", icon: "counter", style: .term)
                    .offset(y: 4)
            }
        }
    }

    private func metricCard(title: String, value: String, icon: String, style: RetroMonitorStyle) -> some View {
        RetroMonitor(style: style, glow: 0.16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 6) {
                    RetroSprite(name: "ph_icon_\(icon)_24")
                    Text(value)
                        .font(.title3.bold().monospacedDigit())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .phosphor(RetroColor.phosphorBright)
                }
                Text(title).font(.caption.weight(.semibold)).phosphor(RetroColor.phosphorDim, glow: 2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 4버튼 평가 통계 — 산업용 모니터, 버튼마다 LED 막대 + 흐르는 빛 막대

    private func buttonDistributionCard(logs: [ReviewLogEntry]) -> some View {
        let distribution = StudyHeatmapCalculator.buttonDistribution(logs: logs)
        let total = max(1, logs.count)

        return RetroMonitor(style: .industrialTurned, glow: 0.2) {
            VStack(alignment: .leading, spacing: 10) {
                Text("내 평가 기록").font(.headline).phosphor()
                ForEach(distribution, id: \.button) { entry in
                    let level = entry.button.retroLevel
                    HStack(spacing: 8) {
                        RetroSprite(name: "rt_ledbar_\(level)")
                        Text(entry.button.koreanTitle)
                            .font(.subheadline.weight(.semibold))
                            .phosphor(level == 1 ? RetroColor.alert : RetroColor.phosphor, glow: 2)
                            .frame(width: 70, alignment: .leading)
                        GeometryReader { geo in
                            let ratio = CGFloat(entry.count) / CGFloat(total)
                            if entry.count > 0 {
                                RetroNineSlice(name: "rt_bar_fill_\(level)")
                                    .frame(width: max(10, geo.size.width * ratio), height: 10)
                            }
                        }
                        .frame(height: 10)
                        Text("\(entry.count)회")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .phosphor(RetroColor.phosphorDim, glow: 2)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
                if logs.isEmpty {
                    Text("카드를 평가하면 이곳에 버튼별 기록이 쌓입니다.")
                        .font(.caption).phosphor(RetroColor.phosphorDim, glow: 2)
                }
            }
        }
    }
}

extension ReviewButton {
    /// 신호 막대 칸 수 (판독 불가 1 ~ 선명 4) — rt_ledbar_* · rt_bar_fill_*
    var retroLevel: Int {
        switch self {
        case .again: return 1
        case .hard: return 2
        case .good: return 3
        case .easy: return 4
        }
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
        RetroMonitor(style: .crt, glow: 0.24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("성실도 잔디").font(.headline).phosphor()
                    Spacer()
                    Text("\(streak)일 연속")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .phosphor(RetroColor.amber, glow: 2)
                }

                GeometryReader { geo in
                    let cell = cellSize(for: geo.size.width)
                    let gap = columnGap(for: geo.size.width)
                    ZStack(alignment: .topLeading) {
                        HStack(alignment: .top, spacing: gap) {
                            ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                                VStack(spacing: Self.rowGap) {
                                    ForEach(week) { day in
                                        GlassGrassBlock(
                                            level: day.intensityLevel,
                                            isFuture: day.isFuture,
                                            isSelected: selectedDay?.id == day.id,
                                            size: cell,
                                            maxExtrusion: Self.maxExtrusion,
                                            palette: palette,
                                            isToday: Calendar.current.isDateInToday(day.date)
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
                                .position(bubbleCenter(column: position.column, row: position.row, cell: cell, gap: gap, width: geo.size.width))
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                                .allowsHitTesting(false)
                        }
                    }
                }
                .frame(height: gridHeight)

                HStack(spacing: 4) {
                    Text("최근 14주").font(.caption2).phosphor(RetroColor.phosphorDim, glow: 1)
                    Spacer()
                    Text("적음").font(.caption2).phosphor(RetroColor.phosphorDim, glow: 1)
                    ForEach(0...4, id: \.self) { level in
                        GlassGrassBlock(level: level, isFuture: false, isSelected: false, size: 10, maxExtrusion: 2, palette: palette)
                    }
                    Text("많음").font(.caption2).phosphor(RetroColor.phosphorDim, glow: 1)
                }
            }
        }
    }

    // MARK: - 격자 좌표 계산

    /// 시안처럼 10pt 형광 칸을 듬성듬성 — 칸 사이 간격으로 폭을 채움
    private static let rowGap: CGFloat = 5

    private var gridHeight: CGFloat {
        7 * 10 + 6 * Self.rowGap
    }

    private func cellSize(for width: CGFloat) -> CGFloat { 10 }

    private func columnGap(for width: CGFloat) -> CGFloat {
        let count = CGFloat(max(1, columns.count))
        return max(2, (width - count * 10) / max(1, count - 1))
    }

    private func gridPosition(of day: StudyHeatmapDay) -> (column: Int, row: Int)? {
        for (columnIndex, week) in columns.enumerated() {
            if let rowIndex = week.firstIndex(where: { $0.id == day.id }) {
                return (columnIndex, rowIndex)
            }
        }
        return nil
    }

    private func bubbleCenter(column: Int, row: Int, cell: CGFloat, gap: CGFloat, width: CGFloat) -> CGPoint {
        let halfBubbleWidth: CGFloat = 78
        let cellCenterX = CGFloat(column) * (cell + gap) + cell / 2
        let x = min(max(cellCenterX, halfBubbleWidth), width - halfBubbleWidth)
        let cellTop = CGFloat(row) * (cell + Self.rowGap)
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
                    .foregroundStyle(RetroColor.creamInk)
                Text(day.studiedWordCount > 0 ? "\(day.studiedWordCount)단어 암기" : "쉬어간 날")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(RetroColor.ink)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .fixedSize()
        .background(RetroNineSlice(name: "rt_plate_metal", animated: false))
        .shadow(color: .black.opacity(0.6), radius: 3, y: 4)
    }
}

// MARK: - 잔디 블록 1칸 — 화면 속 형광 칸 그림 (rt_heat_0~4, 오늘은 숨 쉬듯 켜졌다 꺼짐)
struct GlassGrassBlock: View {
    let level: Int
    let isFuture: Bool
    let isSelected: Bool
    let size: CGFloat
    let maxExtrusion: CGFloat
    let palette: WeatherSkyPalette
    var isToday = false

    var body: some View {
        let name = isToday && level > 0 ? "rt_heat_today" : "rt_heat_\(max(0, min(4, level)))"
        RetroSprite(name: name, animated: isToday, scale: size / 10)
            .opacity(isFuture ? 0.25 : 1)
            .overlay {
                if isSelected {
                    Rectangle().strokeBorder(RetroColor.phosphorBright, lineWidth: 1)
                }
            }
            .frame(width: size, height: size)
    }
}

#Preview("통계 허브") {
    InsightsHubView(engine: StudySessionEngine(store: InMemoryMemoryStore()))
}
