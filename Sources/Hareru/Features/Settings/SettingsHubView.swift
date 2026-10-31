import SwiftUI

// MARK: - 설정 화면 (계정 정보 · 목표 급수 변경 · 실시간 날씨/시간대 시뮬레이터 및 분위기 수동 고정 모드)
public struct SettingsHubView: View {
    private let sessionEngine: StudySessionEngine
    private var weatherEngine = WeatherAtmosphereEngine.shared
    @State private var showResetPlanSheet: Bool = false

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

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. 사용자 계정 및 목표 시험 카드
                    userAccountSection

                    // 2. 날씨 및 분위기 테마 설정 (실시간 위치 자동 연동 vs 수동 분위기 고정)
                    weatherAtmosphereSection

                    // 3. 앱 정보
                    appInfoSection
                }
                .padding(18)
                .padding(.bottom, 80) // 플로팅 토글 바 여백
            }
            .navigationTitle("설정")
            .foregroundStyle(palette.primaryTextColor)
        }
        .sheet(isPresented: $showResetPlanSheet) {
            OnboardingFlowView(engine: sessionEngine) { _ in
                showResetPlanSheet = false
            }
        }
    }

    // MARK: - 계정 및 목표 섹션

    private var userAccountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("학습자 프로필 & 목표", systemImage: "person.crop.circle")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.secondaryTextColor)

            if let profile = sessionEngine.userProfile {
                HStack(spacing: 12) {
                    Circle()
                        .fill(palette.accentColor.opacity(0.24))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Text(String(profile.displayName.prefix(1)))
                                .font(.title3.bold())
                                .foregroundStyle(palette.primaryTextColor)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(profile.displayName)
                                .font(.headline.bold())
                            Text(profile.authProvider.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.white.opacity(0.18), in: Capsule())
                        }
                        Text(profile.email)
                            .font(.caption)
                            .foregroundStyle(palette.secondaryTextColor)
                    }

                    Spacer()
                }

                Divider().background(palette.secondaryTextColor.opacity(0.2))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("목표 급수: \(profile.targetLevel.rawValue)")
                            .font(.subheadline.weight(.bold))
                        Text(profile.targetLevel.subtitle)
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryTextColor)
                    }
                    Spacer()
                    Button("목표 재설정") {
                        showResetPlanSheet = true
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(palette.accentColor.opacity(0.22), in: Capsule())
                    .buttonStyle(.plain)
                }
            } else {
                Text("등록된 학습자 프로필이 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryTextColor)

                Button("목표 급수 설정하고 시작하기") {
                    showResetPlanSheet = true
                }
                .hareruProminentButtonStyle()
                .tint(palette.accentColor)
            }
        }
        .padding(18)
        .hareruGlassCard(cornerRadius: 24, tint: palette.glassTintColor)
    }

    // MARK: - 실시간 날씨 & 분위기 시뮬레이터 섹션

    private var weatherAtmosphereSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("날씨 테마 & 분위기", systemImage: "cloud.sun.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.secondaryTextColor)

            // 실시간 날씨 자동 연동 토글
            Toggle(isOn: Binding(
                get: { weatherEngine.isAutomaticMode },
                set: { weatherEngine.isAutomaticMode = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("실시간 위치 날씨 자동 연동")
                        .font(.subheadline.weight(.bold))
                    Text(weatherEngine.weatherSummaryLine)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryTextColor)
                }
            }

            if !weatherEngine.locationAuthorized {
                Button {
                    weatherEngine.requestLocationPermission()
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("현재 위치 날씨 권한 허용하기")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Divider().background(palette.secondaryTextColor.opacity(0.2))

            // 수동 분위기 고정 모드 (비 오는 밤, 눈 내리는 아침 등 즉시 선택 가능)
            VStack(alignment: .leading, spacing: 10) {
                Text("공부 분위기 수동 고정 (시뮬레이터)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondaryTextColor)

                // 기상 상태 선택
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(WeatherCondition.allCases) { cond in
                            let isSelected = (!weatherEngine.isAutomaticMode && weatherEngine.manualCondition == cond)
                            Button {
                                weatherEngine.isAutomaticMode = false
                                weatherEngine.manualCondition = cond
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: cond.sfSymbolName(for: weatherEngine.activeTimeOfDay))
                                    Text(cond.koreanTitle)
                                }
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    isSelected ? palette.accentColor : .white.opacity(0.12),
                                    in: Capsule()
                                )
                                .foregroundStyle(isSelected ? Color.black : palette.primaryTextColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 시간대 선택
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SkyTimeOfDay.allCases) { time in
                            let isSelected = (!weatherEngine.isAutomaticMode && weatherEngine.manualTimeOfDay == time)
                            Button {
                                weatherEngine.isAutomaticMode = false
                                weatherEngine.manualTimeOfDay = time
                            } label: {
                                Text(time.koreanLabel)
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        isSelected ? palette.accentColor : .white.opacity(0.12),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(isSelected ? Color.black : palette.primaryTextColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(18)
        .hareruGlassCard(cornerRadius: 24, tint: palette.glassTintColor)
    }

    // MARK: - 앱 정보

    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hareru (晴れる) v1.0.0")
                .font(.caption.weight(.bold))
            Text("매일 날씨를 확인하듯 즐겁게 개는 일본어 단어장")
                .font(.caption2)
                .foregroundStyle(palette.secondaryTextColor)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hareruGlassCard(cornerRadius: 18, tint: palette.glassTintColor)
    }
}

#Preview("설정 허브") {
    SettingsHubView(engine: StudySessionEngine(store: InMemoryMemoryStore()))
}
