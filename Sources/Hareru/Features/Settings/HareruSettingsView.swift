import SwiftUI

// MARK: - 탭 4 설정 = 「단말 설정」 (목표 급수/시험일 넘버 시계 · 날씨 시뮬레이터 · 계정) — 레트로 모니터 · 키캡 · 토글
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
                        .retroHangingCable(.dangle, x: 220)
                    if let profile = sessionEngine.userProfile {
                        goalCard(profile: profile)
                            .retroHangingCable(.loop, x: 230)
                    }
                    weatherSimulatorCard
                        .retroHangingCable(.dangle, x: 40)
                    if let profile = sessionEngine.userProfile {
                        accountCard(profile: profile)
                    }
                    HStack { Spacer(minLength: 0); RetroCodeMonitor(kind: .termA).offset(x: 6) }
                }
                .padding(.horizontal, 14)
                .padding(.top, 96)
                .padding(.bottom, 40)
            }
            .retroHidesNavigationBar()
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

    /// 머리: 작은 터미널에 「단말 설정」 + 커서
    private var header: some View {
        HStack(alignment: .bottom, spacing: 6) {
            RetroMonitor(style: .term, glow: 0.18) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("단말 설정").font(.title2.bold()).phosphor()
                        RetroCursor(height: 22)
                    }
                    Text("NJL-OS 2.94 · CONFIG").font(.caption2.monospaced()).phosphor(RetroColor.phosphorDim, glow: 2)
                }
            }
            RetroCodeMonitor(kind: .termB)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - 계정 정보 — 작은 터미널 + 금속 명판

    private func accountCard(profile: UserStudyProfile) -> some View {
        settingsCard(title: "계정", style: .termLeft) {
            HStack(spacing: 12) {
                Text(String(profile.displayName.prefix(1)))
                    .font(.headline.bold())
                    .frame(width: 44, height: 44)
                    .background(RetroNineSlice(name: "rt_plate_cream", animated: false))
                    .foregroundStyle(RetroColor.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName).font(.subheadline.weight(.bold)).phosphor()
                    Text(profile.email).font(.caption).phosphor(RetroColor.phosphorDim, glow: 1)
                }
                Spacer()
                RetroPlate(tone: .metal) {
                    Label(profile.authProvider.rawValue, systemImage: providerIcon(profile.authProvider))
                        .font(.caption2.weight(.bold))
                }
            }

            // 1일차 스토리를 처음부터 (데모 · 확인용)
            Button {
                DayOneDirector.clearStoredProgress()
            } label: {
                Text("1일차 다시 보기").font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RetroKeyStyle(tone: .cream))

            Button(role: .destructive) {
                showSignOutConfirmation = true
            } label: {
                Text("로그아웃").font(.subheadline.weight(.bold)).foregroundStyle(Color(red: 0.62, green: 0.16, blue: 0.14))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RetroKeyStyle(tone: .cream))
        }
    }

    private func providerIcon(_ provider: AuthProviderKind) -> String {
        switch provider {
        case .apple: return "apple.logo"
        case .google: return "g.circle.fill"
        case .email: return "envelope.fill"
        }
    }

    // MARK: - 목표 급수 & 시험일 D-Day — 넘버 시계

    private func goalCard(profile: UserStudyProfile) -> some View {
        let remainingDays = sessionEngine.currentStudyPlanProjection()?.remainingDays
            ?? max(0, sessionEngine.calendar.dateComponents(
                [.day],
                from: sessionEngine.calendar.startOfDay(for: Date()),
                to: sessionEngine.calendar.startOfDay(for: profile.examDate)
            ).day ?? 0)

        return settingsCard(title: "목표", style: .crtTurned) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("JLPT \(profile.targetLevel.rawValue)").font(.title.bold()).phosphor()
                    Text(profile.examDate.formatted(.dateTime.year().month().day().weekday(.wide).locale(Locale(identifier: "ko_KR"))))
                        .font(.caption).phosphor(RetroColor.phosphorDim, glow: 1)
                }
                Spacer()
                RetroFlipCounter(text: "D-\(remainingDays)")
                    .accessibilityLabel("시험까지 \(remainingDays)일")
            }

            Button {
                showGoalResetOnboarding = true
            } label: {
                Label("목표 급수 · 시험일 재설정", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RetroKeyStyle(tone: .amber))
        }
    }

    // MARK: - 날씨 시뮬레이터 (자동 위치 날씨 ↔ 수동 분위기) — 산업용 모니터

    private var weatherSimulatorCard: some View {
        @Bindable var weather = weatherEngine

        return settingsCard(title: "날씨", style: .industrial) {
            HStack(spacing: 10) {
                Image(systemName: weatherEngine.activeCondition.sfSymbolName(for: weatherEngine.activeTimeOfDay))
                    .font(.title2)
                    .phosphor(RetroColor.phosphorBright)
                VStack(alignment: .leading, spacing: 2) {
                    Text(weatherEngine.weatherSummaryLine).font(.subheadline.weight(.semibold)).phosphor()
                    Text(weatherEngine.authorizationStatusDescription).font(.caption2).phosphor(RetroColor.phosphorDim, glow: 1)
                }
            }

            Toggle(isOn: $weather.isAutomaticMode.animation(.easeInOut(duration: 0.6))) {
                Text("현재 위치 날씨 자동 적용").font(.subheadline.weight(.semibold)).phosphor()
            }
            .toggleStyle(RetroToggleStyle())

            if weatherEngine.isAutomaticMode {
                if !weatherEngine.locationAuthorized {
                    Button {
                        weatherEngine.requestLocationPermission()
                    } label: {
                        Label("위치 권한 허용하기", systemImage: "location.fill")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RetroKeyStyle(tone: .cream))
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(WeatherCondition.allCases) { condition in
                        weatherChip(condition)
                    }
                }

                HStack(spacing: 3) {                                         // 시간대 = 피아노 키
                    ForEach(SkyTimeOfDay.allCases) { time in
                        let isActive = weatherEngine.manualTimeOfDay == time
                        Button {
                            withAnimation(.easeInOut(duration: 0.6)) { weather.manualTimeOfDay = time }
                        } label: {
                            Text(time.koreanLabel).font(.caption2.weight(.bold)).lineLimit(1).minimumScaleFactor(0.6)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(RetroKeyStyle(tone: .cream, latched: isActive))
                        .accessibilityAddTraits(isActive ? .isSelected : [])
                    }
                }
            }

            Toggle(isOn: $weather.isHareruClearedToday.animation(.easeInOut(duration: 0.8))) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("晴れる 맑게 갬 미리보기").font(.subheadline.weight(.semibold)).phosphor()
                    Text("오늘의 목표를 끝내면 자동으로 켜집니다").font(.caption2).phosphor(RetroColor.phosphorDim, glow: 1)
                }
            }
            .toggleStyle(RetroToggleStyle())
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
            VStack(spacing: 2) {
                Image(systemName: condition.sfSymbolName(for: weatherEngine.manualTimeOfDay)).font(.subheadline)
                Text(condition.koreanTitle).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(RetroKeyStyle(tone: isActive ? .charcoal : .cream, latched: isActive))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - 공용 판 = 레트로 모니터

    private func settingsCard<Content: View>(title: String, style: RetroMonitorStyle, @ViewBuilder content: () -> Content) -> some View {
        let body = content()
        return RetroMonitor(style: style, glow: 0.2) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.caption.weight(.bold)).phosphor(RetroColor.phosphorDim, glow: 1)
                body
            }
        }
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
