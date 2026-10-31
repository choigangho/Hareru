import SwiftUI

// MARK: - 온보딩 위저드 (1: 이메일 회원가입 ➔ 2: 목표 급수·시험일 설정 ➔ 3: 10문항 4지선다 진단 ➔ 4: 맞춤 계획 리포트)
public struct OnboardingFlowView: View {
    public enum Step: Int, CaseIterable {
        case accountSignUp = 1
        case targetGoal = 2
        case diagnosticQuiz = 3
        case planSummary = 4
    }

    private let sessionEngine: StudySessionEngine
    private let onComplete: (UserStudyProfile) -> Void

    @State private var currentStep: Step = .accountSignUp

    // Step 1: 이메일/비밀번호 회원가입 상태
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var authErrorMessage: String?

    // Step 2: 목표 JLPT 급수 & 시험일 상태
    @State private var selectedLevel: JLPTLevel = .n2
    @State private var examDate: Date = Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date()

    // Step 3: 10문항 4지선다 진단 테스트 상태
    @State private var questions: [DiagnosticQuestion] = []
    @State private var currentQuestionIndex: Int = 0
    @State private var questionStartDate: Date = Date()
    @State private var answers: [DiagnosticAnswerRecord] = []
    @State private var selectedChoiceIndex: Int?

    // Step 4: 최종 생성된 프로필 및 플랜
    @State private var generatedProfile: UserStudyProfile?

    public init(
        engine: StudySessionEngine,
        onComplete: @escaping (UserStudyProfile) -> Void = { _ in }
    ) {
        self.sessionEngine = engine
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            HareruAmbientBackground(colors: [
                Color(red: 0.85, green: 0.90, blue: 0.98),
                Color(red: 0.96, green: 0.88, blue: 0.82),
                Color(red: 0.82, green: 0.93, blue: 0.90)
            ])

            VStack(spacing: 18) {
                stepProgressHeader

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        switch currentStep {
                        case .accountSignUp:
                            accountSignUpCard
                        case .targetGoal:
                            targetGoalCard
                        case .diagnosticQuiz:
                            diagnosticQuizCard
                        case .planSummary:
                            planSummaryCard
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: 420)
        }
    }

    // MARK: - 상단 단계 표시 헤더

    private var stepProgressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Hareru 맞춤 학습 설계")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("단계 \(currentStep.rawValue) / \(Step.allCases.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                    Capsule()
                        .fill(Color.indigo)
                        .frame(width: geo.size.width * (CGFloat(currentStep.rawValue) / CGFloat(Step.allCases.count)))
                        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: currentStep)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Step 1: 이메일/비밀번호 회원가입 카드

    private var accountSignUpCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Label("회원가입", systemImage: "person.crop.circle.badge.plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.indigo)
                Text("학습 기록과 시험일 암기 계획을\n계정에 안전하게 보관하세요")
                    .font(.title3.bold())
                Text("이메일과 비밀번호로 계정을 생성한 뒤, 목표 JLPT 급수와 실력 진단 테스트를 진행합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("닉네임")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("예: 도쿄합격생", text: $displayName)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("이메일")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("you@example.com", text: $email)
                        .textFieldStyle(.plain)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("비밀번호 (6자 이상)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    SecureField("비밀번호 입력", text: $password)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("비밀번호 확인")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    SecureField("비밀번호 다시 입력", text: $confirmPassword)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            if let error = authErrorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }

            VStack(spacing: 10) {
                Button {
                    validateAndProceedFromSignUp()
                } label: {
                    HStack {
                        Text("계정 생성하고 목표 급수 고르기")
                            .fontWeight(.bold)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .hareruProminentButtonStyle()
                .tint(.indigo)

                Button {
                    if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        displayName = "하레루 학습자"
                    }
                    if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        email = "learner@hareru.app"
                    }
                    if password.count < 6 {
                        password = "hareru1234"
                        confirmPassword = "hareru1234"
                    }
                    authErrorMessage = nil
                    withAnimation {
                        currentStep = .targetGoal
                    }
                } label: {
                    Text("데모 계정으로 빠르게 시작하기")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .hareruGlassCard(cornerRadius: 28)
    }

    // MARK: - Step 2: 목표 급수(N5~N1) & 시험일자 선택 카드

    private var targetGoalCard: some View {
        let remainingDays = max(
            1,
            Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: examDate)
            ).day ?? 90
        )

        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Label("목표 시험 설정", systemImage: "calendar.badge.clock")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.indigo)
                Text("어떤 JLPT 급수를 준비하시나요?")
                    .font(.title3.bold())
                Text("해당 급수의 신규 어휘 수와 남은 시험일자를 기준으로 하루 암기 계획을 세워드려요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(JLPTLevel.allCases.reversed()) { level in
                    let isSelected = (selectedLevel == level)
                    Button {
                        selectedLevel = level
                    } label: {
                        HStack(spacing: 12) {
                            Text(level.rawValue)
                                .font(.headline.bold())
                                .frame(width: 44, height: 44)
                                .background(
                                    isSelected ? Color.indigo : Color.secondary.opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .foregroundStyle(isSelected ? .white : .primary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(level.rawValue) 집중 대비")
                                    .font(.subheadline.weight(.bold))
                                Text(level.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.indigo)
                            }
                        }
                        .padding(10)
                        .background(
                            isSelected ? Color.indigo.opacity(0.12) : Color.secondary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("목표 시험일자")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text("D-\(remainingDays)일")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.indigo.opacity(0.15), in: Capsule())
                        .foregroundStyle(.indigo)
                }

                DatePicker(
                    "시험일 선택",
                    selection: $examDate,
                    in: Date().addingTimeInterval(86_400)...Date().addingTimeInterval(86_400 * 365 * 2),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)

                HStack(spacing: 8) {
                    ForEach([30, 60, 90, 180], id: \.self) { days in
                        Button("\(days)일 뒤") {
                            examDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? examDate
                        }
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                        .buttonStyle(.plain)
                    }
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
            .tint(.indigo)
        }
        .padding(22)
        .hareruGlassCard(cornerRadius: 28)
    }

    // MARK: - Step 3: 10문항 4지선다 실력 진단 카드

    @ViewBuilder
    private var diagnosticQuizCard: some View {
        if currentQuestionIndex < questions.count {
            let question = questions[currentQuestionIndex]
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("\(selectedLevel.rawValue) 어휘력 진단", systemImage: "sparkle.magnifyingglass")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.indigo)
                    Spacer()
                    Text("\(currentQuestionIndex + 1) / \(questions.count)")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color.indigo.opacity(0.14), in: Capsule())
                        .foregroundStyle(.indigo)
                }

                VStack(spacing: 6) {
                    Text(question.word.term)
                        .font(.system(size: 40, weight: .bold))
                    Text(question.word.reading)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("가장 알맞은 뜻을 골라주세요")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    question.word.categoryPalette.swiftUIColors[0].opacity(0.45),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )

                VStack(spacing: 10) {
                    ForEach(Array(question.choices.enumerated()), id: \.offset) { idx, choice in
                        let isSelected = (selectedChoiceIndex == idx)
                        Button {
                            submitQuizChoice(choiceIndex: idx, for: question)
                        } label: {
                            HStack {
                                Text("\(idx + 1).")
                                    .font(.subheadline.monospacedDigit().weight(.bold))
                                    .foregroundStyle(.indigo)
                                Text(choice)
                                    .font(.subheadline.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(14)
                            .background(
                                isSelected ? Color.indigo.opacity(0.20) : Color.secondary.opacity(0.09),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
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
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .hareruGlassCard(cornerRadius: 28)
        }
    }

    // MARK: - Step 4: 진단 결과 & 일일 암기 계획 리포트 카드

    @ViewBuilder
    private var planSummaryCard: some View {
        if let profile = generatedProfile {
            let plan = StudyPlanCalculator.evaluatePlan(
                profile: profile,
                snapshots: sessionEngine.store.allSnapshots(),
                reviewLogs: sessionEngine.store.allReviewLogs()
            )
            let badgeColor = feasibilityColor(plan.feasibility)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(plan.feasibility.summaryBadge)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(badgeColor.opacity(0.16), in: Capsule())
                            .foregroundStyle(badgeColor)
                        Spacer()
                        Text("\(profile.targetLevel.rawValue) · D-\(plan.remainingDays)")
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(.secondary)
                    }

                    Text("\(profile.displayName)님의 맞춤 암기 계획")
                        .font(.title3.bold())

                    Text(plan.statusHeadline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(badgeColor)

                    Text(plan.statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.indigo)
                    Text("지금 진단에서 모르는 단어가 많았더라도 걱정하지 마세요! 앞으로 실제 학습에서 정답률이 올라가면 예상 진도 속도와 완주 예측일이 실시간으로 업데이트됩니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    sessionEngine.saveUserProfile(profile)
                    onComplete(profile)
                } label: {
                    HStack {
                        Text("이 계획으로 학습 대시보드 열기")
                            .fontWeight(.bold)
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .hareruProminentButtonStyle()
                .tint(.indigo)
            }
            .padding(22)
            .hareruGlassCard(cornerRadius: 28)
        }
    }

    private func summaryStatBox(title: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
            Text(sub)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func feasibilityColor(_ feasibility: ExamCompletionFeasibility) -> Color {
        switch feasibility {
        case .comfortable: return .teal
        case .achievable: return .orange
        case .tight: return .red
        }
    }

    // MARK: - 내부 동작 헬퍼

    private func validateAndProceedFromSignUp() {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

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
            targetLevel: selectedLevel,
            examDate: examDate,
            diagnosticTestedCount: questions.count,
            diagnosticCorrectCount: correctCount,
            diagnosticAverageSeconds: avgSeconds
        )
        generatedProfile = profile
        withAnimation {
            currentStep = .planSummary
        }
    }
}

#Preview("온보딩 & 10문항 진단") {
    OnboardingFlowView(engine: StudySessionEngine(store: InMemoryMemoryStore()))
}
