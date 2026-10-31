import SwiftUI

// MARK: - 일별 암기 활동 모델
public struct DailyStudyActivity: Identifiable, Equatable, Sendable {
    public let date: Date
    public let dayKey: String
    public let masteredCount: Int
    public let weatherCondition: WeatherCondition

    public var id: String { dayKey }

    public init(date: Date, dayKey: String, masteredCount: Int, weatherCondition: WeatherCondition = .clear) {
        self.date = date
        self.dayKey = dayKey
        self.masteredCount = masteredCount
        self.weatherCondition = weatherCondition
    }
}

// MARK: - 최근 14주 입체(3D Isometric) 글라스 잔디 히트맵
// GitHub 잔디 스타일을 3D 큐브 블록 형태로 발전시켜 학습량에 따라 유리 큐브의 입체 높이와 빛 반사도가 달라집니다.
// 잔디 블록을 터치하면 '그날의 날씨 아이콘 + 암기한 단어 수' 말풍선이 뜹니다.
public struct GlassGrass3DHeatmapView: View {
    public let activities: [String: DailyStudyActivity]
    public let calendar: Calendar
    public let weeksCount: Int

    @State private var selectedDay: DailyStudyActivity?
    private var weatherEngine = WeatherAtmosphereEngine.shared

    public init(
        activities: [String: DailyStudyActivity] = [:],
        calendar: Calendar = .current,
        weeksCount: Int = 14
    ) {
        self.activities = activities
        self.calendar = calendar
        self.weeksCount = weeksCount
    }

    private var palette: WeatherSkyPalette {
        weatherEngine.activePalette
    }

    /// 최근 14주간의 날짜 2D 그리드 (열: 주 0..13, 행: 요일 0..6 [일~토])
    private var gridDays: [[Date]] {
        let today = calendar.startOfDay(for: Date())
        let weekdayOfToday = calendar.component(.weekday, from: today) // 1 = Sun, 7 = Sat
        let daysToCurrentWeekSunday = weekdayOfToday - 1

        guard let thisSunday = calendar.date(byAdding: .day, value: -daysToCurrentWeekSunday, to: today),
              let startSunday = calendar.date(byAdding: .day, value: -(weeksCount - 1) * 7, to: thisSunday) else {
            return []
        }

        var columns: [[Date]] = []
        for w in 0..<weeksCount {
            var col: [Date] = []
            for d in 0..<7 {
                if let day = calendar.date(byAdding: .day, value: w * 7 + d, to: startSunday) {
                    col.append(day)
                }
            }
            columns.append(col)
        }
        return columns
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 상단 타이틀 & 선택된 날짜 상세 말풍선
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("암기 성실도 잔디", systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryTextColor)
                    Text("최근 \(weeksCount)주간의 학습 흔적")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryTextColor)
                }

                Spacer()

                if let sel = selectedDay {
                    HStack(spacing: 6) {
                        Image(systemName: sel.weatherCondition.sfSymbolName(for: .midday))
                            .font(.caption)
                        Text("\(sel.dayKey.suffix(5)) · \(sel.masteredCount)단어 완료")
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(palette.accentColor.opacity(0.22), in: Capsule())
                    .foregroundStyle(palette.primaryTextColor)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    Text("블록을 터치해 확인")
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryTextColor)
                }
            }

            // 3D 글라스 큐브 잔디 매트릭스
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(Array(gridDays.enumerated()), id: \.offset) { weekIdx, week in
                        VStack(spacing: 5) {
                            ForEach(week, id: \.self) { date in
                                let key = DayKeyFormatter.dayKey(for: date, calendar: calendar)
                                let count = activities[key]?.masteredCount ?? 0
                                let condition = activities[key]?.weatherCondition ?? weatherEngine.activeCondition
                                let isSelected = (selectedDay?.dayKey == key)

                                glassCubeBlock(
                                    date: date,
                                    dayKey: key,
                                    count: count,
                                    condition: condition,
                                    isSelected: isSelected
                                )
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
            }

            // 하단 레벨 범례 (미완료 -> 1~5 -> 6~15 -> 16+ 단어)
            HStack(spacing: 6) {
                Text("적음")
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryTextColor)

                ForEach([0, 3, 8, 18], id: \.self) { lvl in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(cubeColor(for: lvl))
                        .frame(width: 12, height: 12)
                }

                Text("많음")
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryTextColor)

                Spacer()

                let totalWords = activities.values.reduce(0) { $0 + $1.masteredCount }
                Text("총 \(totalWords)단어 암기 완료")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(palette.secondaryTextColor)
            }
        }
        .padding(18)
        .hareruGlassCard(cornerRadius: 24, tint: palette.glassTintColor)
    }

    // MARK: - 단일 3D 글라스 큐브 블록

    private func glassCubeBlock(
        date: Date,
        dayKey: String,
        count: Int,
        condition: WeatherCondition,
        isSelected: Bool
    ) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date()
        let heightElevation: CGFloat = isSelected ? 4 : (count > 0 ? min(3.5, 1.0 + CGFloat(count) * 0.15) : 0)

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedDay = DailyStudyActivity(
                    date: date,
                    dayKey: dayKey,
                    masteredCount: count,
                    weatherCondition: condition
                )
            }
        } label: {
            ZStack {
                // 3D 하단 그림자/입체면
                if count > 0 || isSelected {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(cubeColor(for: count).opacity(0.45))
                        .frame(width: 16, height: 16)
                        .offset(x: 1.2, y: 1.2 + heightElevation * 0.4)
                }

                // 큐브 상단 글라스 페이스
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isFuture ? Color.clear : cubeColor(for: count))
                    .frame(width: 16, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(
                                isSelected ? palette.accentColor : (isToday ? Color.white.opacity(0.85) : .white.opacity(0.2)),
                                lineWidth: isSelected ? 1.5 : (isToday ? 1.0 : 0.5)
                            )
                    )
                    .offset(y: -heightElevation)
            }
            .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private func cubeColor(for count: Int) -> Color {
        if count == 0 {
            return palette.isDarkSky ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
        } else if count < 5 {
            return Color.teal.opacity(0.55)
        } else if count < 12 {
            return Color.teal.opacity(0.85)
        } else if count < 20 {
            return Color(red: 0.15, green: 0.78, blue: 0.65)
        } else {
            return Color(red: 0.20, green: 0.92, blue: 0.55)
        }
    }
}
