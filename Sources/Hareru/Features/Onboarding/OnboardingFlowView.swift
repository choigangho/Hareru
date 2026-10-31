import SwiftUI

// MARK: - 온보딩 위저드
// 1. Apple · Google · 이메일 회원가입/로그인 통합
// 2. 목표 JLPT 급수 & 현 시점에서 가장 가까운 공식 JLPT 시험 2개 회차(7월/12월 첫째 일요일) 자동 제안
// 3. 선택한 급수 단어 10장 4지선다 실력 진단 (JLPT 인쇄 명조 폰트 적용)
// 4. 맞춤 암기 계획 리포트 + 사용자 위치 권한 허용("현재 계신 곳의 하늘과 날씨를 단어장에 담을게요")
public struct OnboardingFlowView: View {
    public enum Step: Int, CaseIterable {
        case accountAuth = 1
        case targetGoal = 2
        case diagnosticQuiz = 3
        case planAndLocation = 4
    }

    public enum AuthMode: String, CaseIterable, Identifiable {
        case signUp = "회원가입"
        case signIn = "로그인"

        public var id: String { rawValue }
    }

    private let sessionEngine: StudySessionEngine
    private let weatherEngine: WeatherAtmosphereEngine
    private let onComplete: (UserStudyProfile) -> Void

    @State private var currentStep: Step = .accountAuth
    @State private var authMode: AuthMode = .signUp
    @State private var selectedProvider: AuthProviderKind = .email

    // Step 1: 계정 입력 상태
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var authErrorMessage: String?

    // Step 2: 목표 급수 & 가장 가까운 2개 공식 시험 회차 선택
    @State private var selectedLevel: JLPTLevel = .n2
    @State private var upcomingSessions: [OfficialJLPTExamSession] = OfficialJLPTExamSession.upcomingTwoSessions()
    @State private var selectedSessionId: String = ""

    // Step 3: 10문항 4지선다 진단 테스트 상태
    @State private var questions: [DiagnosticQuestion] = []
    @State private var currentQuestionIndex: Int = 0
    @State private var questionStartDate: Date = Date()
    @State private var answers: [DiagnosticAnswerRecord] = []
    @State private var selectedChoiceIndex: Int?

    // Step 4: 최종 생성 프로필 및 위치 권한 상태
    @State private var generatedProfile: UserStudyProfile?
    @State private var didRequestLocationInStep4: Bool = false

    public init(
        engine: StudySessionEngine,
        weatherEngine: WeatherAtmosphereEngine = .shared,
        onComplete: @escaping (UserStudyProfile) -> Void = { _ in }
    ) {
        self.sessionEngine = engine
        self.weatherEngine = weatherEngine
        self.onComplete = onComplete
    }

    private var palette: WeatherSkyPalette {
        weatherEngine.activePalette
    }

    private var selectedExamSession: OfficialJLPTExamSession {
        if let match = upcomingSessions.first(where: { $0.id == selectedSessionId }) {
            return match
        }
        return upcomingSessions.first ?? OfficialJLPTExamSession(
            id: "default",
            year: 2026,
            round: 2,
            examDate: Calendar.current.date(byAdding: .day, value: 60, to: Date()) ?? Date(),
            remainingDays: 60
        )
    }

    public var body: some View {
        ZStack {
            WeatherSkyCanvasView(
                condition: weatherEngine.activeCondition,
                timeOfDay: weatherEngine.activeTimeOfDay,
                palette: palette
            )

            VStack(spacing: 18) {
                stepProgressHeader

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        switch currentStep {
                        case .accountAuth:
                            accountAuthCard
                        case .targetGoal:
                            targetGoalCard
                        case .diagnosticQuiz:
                            diagnosticQuizCard
                        case .planAndLocation:
                            planAndLocationCard
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: 420)
            .foregroundStyle(palette.primaryTextColor)
        }
        .onAppear {
            if selectedSessionId.isEmpty, let first = upcomingSessions.first {
                selectedSessionId = first.id
            }
        }
    }

    // MARK: - 상단 단계 헤더

    private var stepProgressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: weatherEngine.activeCondition.sfSymbolName(for: weatherEngine.activeTimeOfDay))
                    Text("Hareru (晴れる)")
                        .font(.subheadline.weight(.bold))
                }
                Spacer()
                Text("\(currentStep.rawValue) / \(Step.allCases.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(palette.secondaryTextColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.24))
                    Capsule()
                        .fill(palette.accentColor)
                        .frame(width: geo.size.width * (CGFloat(currentStep.rawValue) / CGFloat(Step.allCases.count)))
                        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: currentStep)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Step 1: Apple · Google · 이메일 회원가입/로그인

    private var accountAuthCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("오늘의 하늘과 함께\n일본어 단어를 시작해 보세요")
                    .font(.title3.bold())
                Text("Apple, Google 또는 이메일 계정으로 학습 기록과 시험일 계획을 동기화합니다.")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryTextColor)
            }

            // 소셜 간편 로그인 (Apple / Google)
            VStack(spacing: 10) {
                Button {
                    signInWithSocialProvider(.apple)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo")
                            .font(.body.weight(.semibold))
                        Text("Apple로 계속하기")
                            .font(.subheadline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    signInWithSocialProvider(.google)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "g.circle.fill")
                            .font(.body.weight(.semibold))
                        Text("Google 계정으로 계속하기")
                            .font(.subheadline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.90), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(Color(red: 0.12, green: 0.15, blue: 0.22))
                }
                .buttonStyle(.plain)
            }

            HStack {
                Rectangle().fill(.white.opacity(0.22)).frame(height: 1)
                Text("또는 이메일")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.secondaryTextColor)
                Rectangle().fill(.white.opacity(0.22)).frame(height: 1)
            }

            // 이메일 회원가입 / 로그인 모드 토글
            Picker("인증 방식", selection: $authMode) {
                ForEach(AuthMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 10) {
                if authMode == .signUp {
                    inputField(title: "닉네임", placeholder: "예: 도쿄합격생", text: $displayName)
                }

                inputField(title: "이메일", placeholder: "you@example.com", text: $email)

                secureInputField(title: "비밀번호 (6자 이상)", placeholder: "비밀번호 입력", text: $password)

                if authMode == .signUp {
                    secureInputField(title: "비밀번호 확인", placeholder: "비밀번호 다시 입력", text: $confirmPassword)
                }
            }

            if let error = authErrorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.45))
            }

            Button {
                validateAndProceedFromEmailAuth()
            } label: {
                HStack {
                    Text(authMode == .signUp ? "이메일로 가입하고 계속하기" : "이메일로 로그인하고 계속하기")
                        .fontWeight(.bold)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .hareruProminentButtonStyle()
            .tint(palette.accentColor)
        }
        .padding(22)
        .hareruGlassCard(cornerRadius: 28, tint: palette.glassTintColor)
    }

    private func inputField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.secondaryTextColor)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .padding(11)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func secureInputField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.secondaryTextColor)
            SecureField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(11)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Step 2: 목표 급수 & 가장 가까운 2개 공식 JLPT 시험일 선택

    private var targetGoalCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("준비하시는 급수와\n응시 회차를 선택해 주세요")
                    .font(.title3.bold())
                Text("JLPT 공식 일정(7월 · 12월 첫째 일요일) 중 가장 가까운 두 시험일을 자동으로 계산했습니다.")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryTextColor)
            }

            // 1) 가장 가까운 2개 공식 시험 회차 선택 카드
            VStack(alignment: .leading, spacing: 8) {
                Text("응시할 시험 회차 (자동 계산됨)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondaryTextColor)

                HStack(spacing: 10) {
                    ForEach(upcomingSessions) { session in
                        let isSelected = (session.id == selectedExamSession.id)
                        Button {
                            selectedSessionId = session.id
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("D-\(session.remainingDays)")
                                        .font(.caption.monospacedDigit().weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            isSelected ? palette.accentColor : .white.opacity(0.18),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(isSelected ? .black : palette.primaryTextColor)
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(palette.accentColor)
                                    }
                                }

                                Text(session.title)
                                    .font(.subheadline.weight(.bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)

                                Text(session.formattedDateString)
                                    .font(.caption2)
                                    .foregroundStyle(palette.secondaryTextColor)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                isSelected ? .white.opacity(0.24) : .white.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(isSelected ? palette.accentColor : .clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 2) 목표 급수 선택 (N5~N1)
            VStack(alignment: .leading, spacing: 8) {
                Text("목표 JLPT 급수")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondaryTextColor)

                ForEach(JLPTLevel.allCases.reversed()) { level in
                    let isSelected = (selectedLevel == level)
                    Button {
                        selectedLevel = level
                    } label: {
                        HStack(spacing: 12) {
                            Text(level.rawValue)
                                .font(.headline.bold())
                                .frame(width: 42, height: 42)
                                .background(
                                    isSelected ? palette.accentColor : .white.opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .foregroundStyle(isSelected ? .black : palette.primaryTextColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(level.rawValue) 집중 대비")
                                    .font(.subheadline.weight(.bold))
                                Text(level.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(palette.secondaryTextColor)
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(palette.accentColor)
                            }
                        }
                        .padding(10)
                        .background(
                            isSelected ? .white.opacity(0.22) : .white.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                startDiagnosticQuiz()
            } label: {
                HStack {
                    Text("\(selectedLevel.rawValue) 단어 10장 실력 테스트 시작")
                        .fontWeight(.bold)
                    Image(systemName: "bolt.fill")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .hareruProminentButtonStyle()
            .tint(palette.accentColor)
        }
        .padding(22)
        .hareruGlassCard(cornerRadius: 28, tint: palette.glassTintColor)
    }

    // MARK: - Step 3: 10문항 4지선다 실력 진단 (JLPT 명조 폰트 적용)

    @ViewBuilder
    private var diagnosticQuizCard: some View {
        if currentQuestionIndex < questions.count {
            let question = questions[currentQuestionIndex]
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("\(selectedLevel.rawValue) 실력 진단")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryTextColor)
                    Spacer()
                    Text("\(currentQuestionIndex + 1) / \(questions.count)")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.16), in: Capsule())
                }

                VStack(spacing: 8) {
                    Text(question.word.term)
                        .jlptTermFont(size: 42, weight: .bold)
                    Text(question.word.reading)
                        .jlptExampleFont(size: 16, weight: .medium)
                        .foregroundStyle(palette.secondaryTextColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(spacing: 10) {
                    ForEach(Array(question.choices.enumerated()), id: \.offset) { idx, choice in
                        let isSelected = (selectedChoiceIndex == idx)
                        Button {
                            submitQuizChoice(choiceIndex: idx, for: question)
                        } label: {
                            HStack {
                                Text("\(idx + 1).")
                                    .font(.subheadline.monospacedDigit().weight(.bold))
                                    .foregroundStyle(palette.secondaryTextColor)
                                Text(choice)
                                    .font(.subheadline.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(14)
                            .background(
                                isSelected ? .white.opacity(0.28) : .white.opacity(0.11),
                                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    submitQuizChoice(choiceIndex: -1, for: question)
                } label: {
                    Text("모르겠어요 (건너뛰기)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .hareruGlassCard(cornerRadius: 28, tint: palette.glassTintColor)
        }
    }

    // MARK: - Step 4: 맞춤 암기 계획 리포트 + 실시간 날씨 위치 권한 요청

    @ViewBuilder
    private var planAndLocationCard: some View {
        if let profile = generatedProfile {
            let plan = StudyPlanCalculator.evaluatePlan(
                profile: profile,
                snapshots: sessionEngine.store.allSnapshots(),
                reviewLogs: sessionEngine.store.allReviewLogs()
            )

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(plan.feasibility.summaryBadge)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.18), in: Capsule())
                        Spacer()
                        Text("\(profile.targetLevel.rawValue) · D-\(plan.remainingDays)")
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(palette.secondaryTextColor)
                    }

                    Text("\(profile.displayName)님의 일일 암기 계획")
                        .font(.title3.bold())

                    Text(plan.statusHeadline)
                        .font(.subheadline.weight(.semibold))

                    Text(plan.statusDetail)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryTextColor)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    summaryStatBox(
                        title: "10장 진단 결과",
                        value: "\(profile.diagnosticCorrectCount) / \(profile.diagnosticTestedCount) 정답",
                        sub: String(format: "평균 %.1f초 응답", profile.diagnosticAverageSeconds)
                    )
                    summaryStatBox(
                        title: "추정 기저 어휘",
                        value: "약 \(plan.estimatedKnownWordsFromTest)단어",
                        sub: "전체 \(plan.totalLevelWords)단어 중"
                    )
                    summaryStatBox(
                        title: "하루 목표 암기량",
                        value: "일 \(plan.requiredDailyNewWords)단어",
                        sub: "남은 \(plan.remainingWordsToLearn)단어 ÷ \(plan.remainingDays)일"
                    )
                    summaryStatBox(
                        title: "예상 소화 가능 속도",
                        value: "일 \(plan.estimatedDailyPaceCapacity)단어",
                        sub: "현재 속도 시 \(plan.expectedDaysAtCurrentPace)일 소요"
                    )
                }

                // 사용자 위치 정보 허용 카드 (현재 위치 날씨·시간대 배경 동기화)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill.viewfinder")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("현재 계신 곳의 하늘과 날씨를 단어장에 담을게요")
                                .font(.caption.weight(.bold))
                            Text(weatherEngine.locationAuthorized
                                 ? "위치 연동 완료 (\(weatherEngine.weatherSummaryLine))"
                                 : "아침·저녁·비·눈·맑음 등 현재 위치의 실시간 날씨를 앱 배경에 그대로 반영합니다.")
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryTextColor)
                        }
                    }

                    if !weatherEngine.locationAuthorized {
                        Button {
                            didRequestLocationInStep4 = true
                            weatherEngine.requestLocationPermission()
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                Text(didRequestLocationInStep4 ? "위치 날씨 동기화 완료" : "현재 위치 날씨 연동 허용하기")
                                    .fontWeight(.semibold)
                            }
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button {
                    if !didRequestLocationInStep4 {
                        weatherEngine.requestLocationPermission()
                    }
                    sessionEngine.saveUserProfile(profile)
                    onComplete(profile)
                } label: {
                    HStack {
                        Text("이 계획으로 시작하기")
                            .fontWeight(.bold)
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .hareruProminentButtonStyle()
                .tint(palette.accentColor)
            }
            .padding(22)
            .hareruGlassCard(cornerRadius: 28, tint: palette.glassTintColor)
        }
    }

    private func summaryStatBox(title: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.secondaryTextColor)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
            Text(sub)
                .font(.caption2)
                .foregroundStyle(palette.secondaryTextColor)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 내부 동작 헬퍼

    private func signInWithSocialProvider(_ provider: AuthProviderKind) {
        selectedProvider = provider
        displayName = provider == .apple ? "Apple 학습자" : "Google 학습자"
        email = provider == .apple ? "apple.user@privaterelay.appleid.com" : "google.user@gmail.com"
        password = "social_oauth_token"
        confirmPassword = "social_oauth_token"
        authErrorMessage = nil
        withAnimation {
            currentStep = .targetGoal
        }
    }

    private func validateAndProceedFromEmailAuth() {
        selectedProvider = .email
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        if authMode == .signUp {
            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                authErrorMessage = "닉네임을 입력해 주세요."
                return
            }
            guard trimmedEmail.contains("@") && trimmedEmail.contains(".") else {
                authErrorMessage = "올바른 이메일 주소를 입력해 주세요."
                return
            }
            guard password.count >= 6 else {
                authErrorMessage = "비밀번호는 6자 이상 입력해 주세요."
                return
            }
            guard password == confirmPassword else {
                authErrorMessage = "비밀번호와 비밀번호 확인이 일치하지 않습니다."
                return
            }
        } else {
            guard trimmedEmail.contains("@") && trimmedEmail.contains(".") else {
                authErrorMessage = "로그인할 이메일 주소를 입력해 주세요."
                return
            }
            guard password.count >= 6 else {
                authErrorMessage = "비밀번호(6자 이상)를 입력해 주세요."
                return
            }
            if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                displayName = String(trimmedEmail.split(separator: "@").first ?? "학습자")
            }
        }

        authErrorMessage = nil
        withAnimation {
            currentStep = .targetGoal
        }
    }

    private func startDiagnosticQuiz() {
        questions = StudyPlanCalculator.makeDiagnosticQuestions(
            for: selectedLevel,
            catalog: sessionEngine.catalog,
            count: 10
        )
        currentQuestionIndex = 0
        answers = []
        selectedChoiceIndex = nil
        questionStartDate = Date()
        withAnimation {
            currentStep = .diagnosticQuiz
        }
    }

    private func submitQuizChoice(choiceIndex: Int, for question: DiagnosticQuestion) {
        selectedChoiceIndex = choiceIndex
        let elapsed = max(0.2, Date().timeIntervalSince(questionStartDate))
        let isCorrect = (choiceIndex == question.correctIndex)

        answers.append(
            DiagnosticAnswerRecord(
                questionId: question.id,
                wordId: question.word.id,
                selectedIndex: choiceIndex,
                isCorrect: isCorrect,
                reactionSeconds: elapsed
            )
        )

        if currentQuestionIndex + 1 < questions.count {
            currentQuestionIndex += 1
            selectedChoiceIndex = nil
            questionStartDate = Date()
        } else {
            finalizeDiagnosticAndBuildProfile()
        }
    }

    private func finalizeDiagnosticAndBuildProfile() {
        let correctCount = answers.filter(\.isCorrect).count
        let avgSeconds = answers.isEmpty
            ? 4.0
            : answers.reduce(0.0) { $0 + $1.reactionSeconds } / Double(answers.count)

        let profile = UserStudyProfile(
            email: email.isEmpty ? "learner@hareru.app" : email,
            displayName: displayName.isEmpty ? "하레루 학습자" : displayName,
            passwordHash: UserStudyProfile.hashPassword(password.isEmpty ? "hareru1234" : password),
            authProvider: selectedProvider,
            targetLevel: selectedLevel,
            examDate: selectedExamSession.examDate,
            diagnosticTestedCount: questions.count,
            diagnosticCorrectCount: correctCount,
            diagnosticAverageSeconds: avgSeconds
        )
        generatedProfile = profile
        withAnimation {
            currentStep = .planAndLocation
        }
    }
}

#Preview("온보딩 & 10문항 진단") {
    OnboardingFlowView(engine: StudySessionEngine(store: InMemoryMemoryStore()))
}
