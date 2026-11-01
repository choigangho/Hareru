import SwiftUI

// MARK: - 탭 3 설정 (계정 · 목표 급수/시험일 D-Day · 날씨 시뮬레이터)
public struct HareruSettingsView: View {
    private let sessionEngine: StudySessionEngine
    private let weatherEngine: WeatherAtmosphereEngine
    @State private var showGoalResetOnboarding: Bool = false
    @State private var showSignOutConfirmation: Bool = false

    public init(engine: StudySessionEngine, weatherEngine: WeatherAtmosphereEngine = .shared) {
        self.sessionEngine = engine
        self.weatherEngine = weatherEngine
    }

    private var palette: WeatherSkyPalette { weatherEngine.activePalette }

    public var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if let profile = sessionEngine.userProfile {
                        accountCard(profile: profile)
                        goalCard(profile: profile)
                    }
                    weatherSimulatorCard
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
            .navigationTitle("설정")
        }
        .sheet(isPresented: $showGoalResetOnboarding) {
            OnboardingFlowView(engine: sessionEngine, initialStep: .targetGoal) { _ in
                showGoalResetOnboarding = false
            }
        }
        .confirmationDialog("로그아웃할까요?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("로그아웃", role: .destructive) {
                sessionEngine.clearUserProfile()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("학습 기록은 이 기기에 그대로 남아 있습니다.")
        }
    }

    // MARK: - 계정 정보

    private func accountCard(profile: UserStudyProfile) -> some View {
        settingsCard(title: "계정") {
            HStack(spacing: 12) {
                Circle()
                    .fill(palette.accentColor.opacity(0.25))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Text(String(profile.displayName.prefix(1)))
                            .font(.headline.bold())
                            .foregroundStyle(palette.primaryTextColor)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryTextColor)
                    Text(profile.email)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryTextColor)
                }
                Spacer()
                Label(profile.authProvider.rawValue, systemImage: providerIcon(profile.authProvider))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(palette.secondaryTextColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(palette.primaryTextColor)
            }

            Button(role: .destructive) {
                showSignOutConfirmation = true
            } label: {
                Text("로그아웃")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .hareruSecondaryButtonStyle()
        }
    }

    private func providerIcon(_ provider: AuthProviderKind) -> String {
        switch provider {
        case .apple: return "apple.logo"
        case .google: return "g.circle.fill"
        case .email: return "envelope.fill"
        }
    }

    // MARK: - 목표 급수 & 시험일 D-Day

    private func goalCard(profile: UserStudyProfile) -> some View {
        let remainingDays = sessionEngine.currentStudyPlanProjection()?.remainingDays
            ?? max(0, sessionEngine.calendar.dateComponents(
                [.day],
                from: sessionEngine.calendar.startOfDay(for: Date()),
                to: sessionEngine.calendar.startOfDay(for: profile.examDate)
            ).day ?? 0)

        return settingsCard(title: "목표") {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("JLPT \(profile.targetLevel.rawValue)")
                        .font(.title2.bold())
                        .foregroundStyle(palette.primaryTextColor)
                    Text(profile.examDate.formatted(.dateTime.year().month().day().weekday(.wide).locale(Locale(identifier: "ko_KR"))))
                        .font(.caption)
                        .foregroundStyle(palette.secondaryTextColor)
                }
                Spacer()
                Text("D-\(remainingDays)")
                    .font(.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(palette.accentColor)
            }

            Button {
                showGoalResetOnboarding = true
            } label: {
                Label("목표 급수 · 시험일 재설정", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .hareruSecondaryButtonStyle()
        }
    }

    // MARK: - 날씨 시뮬레이터 (자동 위치 날씨 ↔ 수동 분위기)

    private var weatherSimulatorCard: some View {
        @Bindable var weather = weatherEngine

        return settingsCard(title: "날씨") {
            HStack(spacing: 10) {
                Image(systemName: weatherEngine.activeCondition.sfSymbolName(for: weatherEngine.activeTimeOfDay))
                    .symbolRenderingMode(.multicolor)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(weatherEngine.weatherSummaryLine)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primaryTextColor)
                    Text(weatherEngine.authorizationStatusDescription)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryTextColor)
                }
            }

            Toggle(isOn: $weather.isAutomaticMode.animation(.easeInOut(duration: 0.6))) {
                Text("현재 위치 날씨 자동 적용")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryTextColor)
            }
            .tint(palette.accentColor)

            if weatherEngine.isAutomaticMode {
                if !weatherEngine.locationAuthorized {
                    Button {
                        weatherEngine.requestLocationPermission()
                    } label: {
                        Label("위치 권한 허용하기", systemImage: "location.fill")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .hareruSecondaryButtonStyle()
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(WeatherCondition.allCases) { condition in
                        weatherChip(condition)
                    }
                }

                Picker("시간대", selection: $weather.manualTimeOfDay.animation(.easeInOut(duration: 0.6))) {
                    ForEach(SkyTimeOfDay.allCases) { time in
                        Text(time.koreanLabel).tag(time)
                    }
                }
                .pickerStyle(.segmented)
            }

            Toggle(isOn: $weather.isHareruClearedToday.animation(.easeInOut(duration: 0.8))) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("晴れる 맑게 갬 미리보기")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primaryTextColor)
                    Text("오늘의 목표를 끝내면 자동으로 켜집니다")
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryTextColor)
                }
            }
            .tint(palette.accentColor)
        }
    }

    private func weatherChip(_ condition: WeatherCondition) -> some View {
        let isActive = weatherEngine.manualCondition == condition && !weatherEngine.isHareruClearedToday
        return Button {
            withAnimation(.easeInOut(duration: 0.6)) {
                weatherEngine.manualCondition = condition
                weatherEngine.isHareruClearedToday = false
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: condition.sfSymbolName(for: weatherEngine.manualTimeOfDay))
                    .symbolRenderingMode(.multicolor)
                    .font(.title3)
                Text(condition.koreanTitle)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(palette.primaryTextColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? palette.accentColor.opacity(0.28) : palette.secondaryTextColor.opacity(0.1))
            }
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(palette.accentColor.opacity(0.8), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 공용 카드 컨테이너

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.secondaryTextColor)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hareruGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), tint: palette.glassTintColor)
    }
}

#Preview("설정") {
    let profile = UserStudyProfile(
        email: "learner@hareru.app",
        displayName: "도쿄합격생",
        passwordHash: UserStudyProfile.hashPassword("hareru1234"),
        targetLevel: .n2,
        examDate: Calendar.current.date(byAdding: .day, value: 40, to: Date()) ?? Date(),
        diagnosticTestedCount: 10,
        diagnosticCorrectCount: 6,
        diagnosticAverageSeconds: 3.8
    )
    HareruSettingsView(engine: StudySessionEngine(store: InMemoryMemoryStore(initialProfile: profile)))
}
