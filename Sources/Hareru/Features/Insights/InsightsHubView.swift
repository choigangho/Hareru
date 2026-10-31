import SwiftUI

// MARK: - 통계 허브 뷰
// 1. 최상단: 최근 14주 3D 입체 글라스 잔디 히트맵
// 2. 시험 완주 D-Day 예측 진도 카드
// 3. FSRS 4단계 직관적 평가 분포 ('모르겠음 / 애매함 / 알고있음 / 쉬움' - 히든 등급 완전 숨김!)
// 4. (성우 도감, 손글씨 처방 노트, 라이선스 고지, 역전 단어 등 군더더기 모두 삭제 완료)
public struct InsightsHubView: View {
    private let sessionEngine: StudySessionEngine
    private var weatherEngine = WeatherAtmosphereEngine.shared

    public init(engine: StudySessionEngine? = nil) {
        if let engine {
            self.sessionEngine = engine
        } else {
            self.sessionEngine = StudySessionEngine(store: InMemoryMemoryStore())
        }
    }

    private var palette: WeatherSkyPalette {
        weatherEngine.activePalette
    }

    private var snapshotsByWordId: [String: WordMemorySnapshot] {
        _ = sessionEngine.stateRevision
        return sessionEngine.store.allSnapshots()
    }

    private var reviewLogs: [ReviewLogEntry] {
        _ = sessionEngine.stateRevision
        return sessionEngine.store.allReviewLogs()
    }

    private var masteredWords: [(word: Word, snapshot: WordMemorySnapshot)] {
        let map = snapshotsByWordId
        return sessionEngine.catalog.words.compactMap { word in
            guard let snap = map[word.id], snap.reps > 0 else { return nil }
            return (word, snap)
        }
    }

    // 4단계 사용자 평가 분포 집계 ('모르겠음 / 애매함 / 알고있음 / 쉬움')
    private var fourTierButtonStats: [(button: ReviewButton, count: Int)] {
        let logs = reviewLogs
        var counts: [ReviewButton: Int] = [:]
        for log in logs {
            counts[log.button, default: 0] += 1
        }
        return [
            (.again, counts[.again, default: 0]),
            (.hard, counts[.hard, default: 0]),
            (.good, counts[.good, default: 0]),
            (.easy, counts[.easy, default: 0])
        ]
    }

    // 일별 암기 완료 활동 내역 (잔디 히트맵 데이터)
    private var dailyActivities: [String: DailyStudyActivity] {
        let logs = reviewLogs
        var countsByDay: [String: (count: Int, lastDate: Date)] = [:]
        for log in logs where log.didGraduate {
            let key = DayKeyFormatter.dayKey(for: log.reviewedAt, calendar: sessionEngine.calendar)
            let existing = countsByDay[key]?.count ?? 0
            countsByDay[key] = (existing + 1, log.reviewedAt)
        }

        var map: [String: DailyStudyActivity] = [:]
        for (dayKey, tuple) in countsByDay {
            map[dayKey] = DailyStudyActivity(
                date: tuple.lastDate,
                dayKey: dayKey,
                masteredCount: tuple.count,
                weatherCondition: weatherEngine.activeCondition
            )
        }
        return map
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. 최상단: 최근 14주 3D 글라스 잔디 히트맵
                    GlassGrass3DHeatmapView(
                        activities: dailyActivities,
                        calendar: sessionEngine.calendar,
                        weeksCount: 14
                    )

                    // 2. 시험 D-Day 완주 속도 예측 카드
                    if let plan = sessionEngine.currentStudyPlanProjection() {
                        examPlanProgressCard(plan: plan)
                    }

                    // 3. FSRS 기억 유지율 핵심 지표 요약
                    memoryMetricsGrid

                    // 4. 4단계 평가 분포 ('모르겠음 / 애매함 / 알고있음 / 쉬움' - 히든 완전 배제)
                    evaluationDistributionCard
                }
                .padding(18)
                .padding(.bottom, 80) // 플로팅 토글 바 여백
            }
            .navigationTitle("학습 통계")
            .foregroundStyle(palette.primaryTextColor)
        }
    }

    // MARK: - 시험 D-Day 계획 진도율 카드

    private func examPlanProgressCard(plan: StudyPlanProjection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("\(plan.targetLevel.rawValue) 시험 D-\(plan.remainingDays)", systemImage: "flag.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accentColor)

                Spacer()

                Text(plan.feasibility.summaryBadge)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.18), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(plan.statusHeadline)
                    .font(.subheadline.weight(.bold))
                Text(plan.statusDetail)
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryTextColor)
            }

            // 진행 바
            let progress = plan.totalLevelWords > 0
                ? Double(plan.estimatedKnownWordsFromTest + plan.graduatedWordsInApp) / Double(plan.totalLevelWords)
                : 0.0

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("목표 진척도")
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryTextColor)
                    Spacer()
                    Text("\(Int((progress * 100).rounded()))% 완료 (\(plan.graduatedWordsInApp)단어 암기 완료)")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.2))
                        Capsule()
                            .fill(palette.accentColor)
                            .frame(width: geo.size.width * CGFloat(min(1.0, max(0.0, progress))))
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(18)
        .hareruGlassCard(cornerRadius: 24, tint: palette.glassTintColor)
    }

    // MARK: - 핵심 통계 지표

    private var memoryMetricsGrid: some View {
        let totalMastered = masteredWords.count
        let totalLogs = reviewLogs.count
        let avgSeconds = totalLogs == 0
            ? 0.0
            : reviewLogs.reduce(0.0) { $0 + $1.reactionSeconds } / Double(totalLogs)

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricBox(
                title: "암기 완료 단어",
                value: "\(totalMastered)단어",
                sub: "수록 단어 \(sessionEngine.catalog.words.count)개 중",
                icon: "checkmark.seal.fill"
            )
            metricBox(
                title: "평균 반응 시간",
                value: String(format: "%.2f초", avgSeconds),
                sub: "총 \(totalLogs)회 인출 기록",
                icon: "timer"
            )
        }
    }

    private func metricBox(title: String, value: String, sub: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.accentColor)
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(title)
                .font(.caption.weight(.semibold))
            Text(sub)
                .font(.caption2)
                .foregroundStyle(palette.secondaryTextColor)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hareruGlassCard(cornerRadius: 18, tint: palette.glassTintColor)
    }

    // MARK: - 4단계 평가 분포 ('모르겠음 / 애매함 / 알고있음 / 쉬움')

    private var evaluationDistributionCard: some View {
        let totalLogs = max(1, reviewLogs.count)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("평가 반응 분포")
                    .font(.headline)
                Spacer()
                Text("총 \(reviewLogs.count)회")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(palette.secondaryTextColor)
            }

            ForEach(fourTierButtonStats, id: \.button) { item in
                let ratio = Double(item.count) / Double(totalLogs)
                let btnColor = palette.buttonColor(for: item.button)

                HStack(spacing: 10) {
                    Text(item.button.koreanTitle)
                        .font(.caption.weight(.bold))
                        .frame(width: 60, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.14))
                            Capsule()
                                .fill(btnColor)
                                .frame(width: max(item.count > 0 ? 8 : 0, geo.size.width * ratio))
                        }
                    }
                    .frame(height: 8)

                    Text("\(item.count)회")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(palette.secondaryTextColor)
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .padding(18)
        .hareruGlassCard(cornerRadius: 24, tint: palette.glassTintColor)
    }
}

#Preview("통계 허브") {
    InsightsHubView(engine: StudySessionEngine(store: InMemoryMemoryStore()))
}
