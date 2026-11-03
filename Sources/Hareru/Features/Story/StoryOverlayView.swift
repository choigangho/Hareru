import SwiftUI

// MARK: - 1일차 대사 화면 (탭 위에 겹쳐 띄움)
// 인트로(T-0)는 검은 CRT 화면, 그 뒤로는 실제 탭 화면 위에 대사창. 초상 · 배경 그림이 아직 없는 연출 줄은
// '▸' 지문으로 보여 줍니다 (Docs/Art/N5_ASSET_LIST.md 에셋이 들어오면 그림으로 교체).

struct StoryOverlayView: View {
    @Bindable var director: DayOneDirector
    var onWeatherSync: () -> Void = {}
    var onSkipStudy: () -> Void = {}

    @State private var typed = 0
    @State private var shownLineID: String?
    @State private var showsMeaning = false
    @State private var speech = SpeechPlayer()

    var body: some View {
        Group {
            if director.step == .studyGate {
                studyBanner
            } else if director.isIntro {
                introScreen
            } else {
                sceneOverlay
            }
        }
        .onChange(of: director.index, initial: true) { _, _ in lineChanged() }
        .onChange(of: director.step) { _, _ in lineChanged() }
    }

    // MARK: 인트로 (검은 CRT · 타자)

    private var introScreen: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                Spacer()
                ForEach(introHistory, id: \.id) { line in
                    Text(director.fill(line.korean))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(RetroColor.phosphorDim.opacity(0.55))
                }
                if let line = director.current, director.step == .line {
                    introCurrent(line)
                }
                Spacer()
                interactionArea
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .contentShape(Rectangle())
        .onTapGesture { tapped() }
        .overlay(alignment: .topTrailing) {
            if director.step == .line {
                Button("건너뛰기") { director.skipIntro() }
                    .buttonStyle(RetroKeyStyle(tone: .charcoal))
                    .padding(16)
            }
        }
    }

    /// 지금 줄 위로 쌓이는 앞선 타자 줄 (터미널처럼 최근 5줄)
    private var introHistory: [StoryLine] {
        let upTo = min(director.index, director.lines.count)
        return Array(director.lines[..<upTo].filter { $0.kind == .typewriter }.suffix(5))
    }

    @ViewBuilder
    private func introCurrent(_ line: StoryLine) -> some View {
        switch line.kind {
        case .typewriter:
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(typedText(director.fill(line.korean)))
                    .font(.system(.title3, design: .monospaced))
                    .phosphor()
                RetroCursor(height: 18)
            }
        case .direction:
            Text("▸ " + cleanNote(line.note))
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(RetroColor.cream.opacity(0.6))
        default:
            dialogueBox(line)
        }
    }

    // MARK: 장면 (탭 화면 위)

    private var sceneOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { tapped() }

            VStack(spacing: 14) {
                Spacer()
                if let card = director.card {
                    TutorialCardView(card: card, number: director.activeCard ?? 0, director: director)
                        .padding(.horizontal, 32)
                }
                Spacer()
                if let line = director.current, director.step == .line {
                    lineView(line)
                }
                interactionArea
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 18)
        }
    }

    @ViewBuilder
    private func lineView(_ line: StoryLine) -> some View {
        switch line.kind {
        case .direction:
            Text("▸ " + cleanNote(line.note))
                .font(.footnote.italic())
                .foregroundStyle(RetroColor.cream)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RetroColor.wall, in: RoundedRectangle(cornerRadius: 6))
                .onTapGesture { tapped() }
        case .system:
            systemPanel(line)
        default:
            dialogueBox(line)
        }
    }

    private func systemPanel(_ line: StoryLine) -> some View {
        let isWarning = line.korean.hasPrefix("⚠")
        return VStack(spacing: 6) {
            if !line.japanese.isEmpty {
                Text(StoryRuby.plain(line.japanese))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(RetroColor.phosphorBright)
            }
            Text(director.systemText(line))
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(isWarning ? RetroColor.alert : RetroColor.phosphor)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RetroColor.wall, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(isWarning ? RetroColor.alert : RetroColor.phosphorDim, lineWidth: 2))
        .onTapGesture { tapped() }
    }

    // MARK: 대사창

    private func dialogueBox(_ line: StoryLine) -> some View {
        let isMonologue = line.kind == .monologue
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {
                if let portrait = line.kind.portraitName {
                    portraitView(portrait, closeUp: line.isCloseUp)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        RetroPlate(tone: isMonologue ? .metal : .amber) {
                            Text(isMonologue ? "속마음" : director.speakerTitle(line))
                                .font(.caption.weight(.bold))
                        }
                        if !line.expression.isEmpty {
                            Text(line.expression)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(RetroColor.creamInk)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(RetroColor.cream.opacity(0.7), in: Capsule())
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            if line.japanese.isEmpty {
                Text(typedText(director.fill(line.korean)))
                    .font(isMonologue ? .body.italic() : .body)
                    .foregroundStyle(RetroColor.paperInk)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    StoryRubyText(text: director.fill(line.japanese))
                    if showsMeaning {
                        Text(director.fill(line.korean))
                            .font(.callout)
                            .foregroundStyle(RetroColor.paperInkDim)
                    } else {
                        Button("뜻 보기") { showsMeaning = true }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RetroColor.paperRed)
                            .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
            }

            if director.step == .line {
                HStack {
                    Spacer()
                    Text(isTyping(line) ? "" : "▼")
                        .font(.caption2)
                        .foregroundStyle(RetroColor.paperInkDim)
                }
            }
        }
        .padding(14)
        .background(RetroColor.cream, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(RetroColor.creamInk, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture { tapped() }
    }

    private func portraitView(_ name: String, closeUp: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            RetroSprite(name: "rt_portrait_crt", animated: false)
            if let image = OfficePixelArt.bundledImage(name) {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .offset(x: 10, y: 10)
            }
        }
        .frame(width: 84, height: 92)
        .scaleEffect(closeUp ? 1.6 : 1, anchor: .bottomLeading)
        .animation(.spring(duration: 0.25), value: closeUp)
    }

    // MARK: 입력 · 선택

    @ViewBuilder
    private var interactionArea: some View {
        switch director.step {
        case .voicePick: VoicePickPanel(director: director, speech: speech)
        case .nameInput: NameInputPanel(director: director)
        case let .quest(text): questPanel(text)
        case .commuteInput: CommutePanel(director: director)
        case .weatherSync: weatherPanel
        case .talkChoice: talkPanel
        default: EmptyView()
        }
    }

    private func questPanel(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("오늘의 연구 과제")
                .font(.caption.weight(.bold))
                .foregroundStyle(RetroColor.paperRed)
            Text(text)
                .font(.callout.weight(.semibold))
                .foregroundStyle(RetroColor.paperInk)
            Button(director.current?.id == "D1-312" ? "수리하기" : "받기") { director.completeQuest() }
                .buttonStyle(RetroKeyStyle(tone: .amber))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(RetroNineSlice(name: "rt_paper", animated: false))
    }

    private var weatherPanel: some View {
        choicePanel(title: director.current.map { director.fill($0.korean) } ?? "", options: [
            ("맞추기", { onWeatherSync(); director.setWeatherSync(true) }),
            ("괜찮아요", { director.setWeatherSync(false) }),
        ])
    }

    private var talkPanel: some View {
        let options = (director.current?.note ?? "").split(separator: "`", omittingEmptySubsequences: false).enumerated()
            .filter { $0.offset % 2 == 1 }.map { String($0.element) }
        return choicePanel(title: "", options: options.enumerated().map { item in
            (item.element, { director.chooseTalk(item.offset + 1) })
        })
    }

    private func choicePanel(title: String, options: [(String, () -> Void)]) -> some View {
        VStack(spacing: 10) {
            if !title.isEmpty {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(RetroColor.phosphor)
            }
            ForEach(options.indices, id: \.self) { i in
                Button(options[i].0, action: options[i].1)
                    .buttonStyle(RetroKeyStyle(tone: .cream))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(RetroColor.wall, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: 학습 대기 (T-8)

    private var studyBanner: some View {
        VStack {
            HStack(spacing: 10) {
                Text("오늘의 연구 과제")
                    .font(.caption.weight(.bold))
                Text("새 단어 \(director.studiedInGate) / \(DayOneDirector.studyGoal)")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                Spacer()
                Button(action: onSkipStudy) {
                    Text("과제 끝내기")
                        .padding(.vertical, 10)
                        .padding(.leading, 12)
                        .contentShape(Rectangle())
                }
                    .font(.caption2.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(RetroColor.paperRed)
            }
            .foregroundStyle(RetroColor.paperInk)
            .padding(.horizontal, 14)
            .background(RetroColor.cream, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 14)
            Spacer()
        }
        .padding(.top, 6)
    }

    // MARK: 진행

    private func tapped() {
        guard director.step == .line, let line = director.current else { return }
        if isTyping(line) {
            typed = Int.max
        } else {
            director.advance()
        }
    }

    private func lineChanged() {
        typed = 0
        showsMeaning = false
        guard director.step == .line, let line = director.current, line.id != shownLineID else { return }
        shownLineID = line.id
        if !line.japanese.isEmpty, line.kind == .chief || line.kind == .protagonist {
            speech.playSingle(fileName: line.audioFileName(voice: director.voice))
        }
        let target = director.fill(line.korean).count
        let id = line.id
        Task { @MainActor in
            while typed < target, director.current?.id == id {
                try? await Task.sleep(for: .milliseconds(28))
                if typed < Int.max { typed += 1 }
            }
        }
    }

    /// 한국어 대사 · 독백 · 타자만 한 글자씩 (일본어 줄 · 지문 · 시스템 문구는 바로)
    private func isTyping(_ line: StoryLine) -> Bool {
        guard line.japanese.isEmpty, typed < director.fill(line.korean).count else { return false }
        switch line.kind {
        case .direction, .system, .input, .choice: return false
        default: return true
        }
    }

    private func typedText(_ full: String) -> String {
        typed >= full.count ? full : String(full.prefix(typed))
    }

    /// 비고의 마크다운 표시(** · `)를 걷어낸 지문
    private func cleanNote(_ note: String) -> String {
        note.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
    }
}

// MARK: - 루비 일본어

struct StoryRubyText: View {
    let text: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(StoryRuby.segments(text).enumerated()), id: \.offset) { _, segment in
                VStack(spacing: 0) {
                    Text(segment.ruby ?? " ")
                        .font(.system(size: 10))
                        .foregroundStyle(RetroColor.paperInkDim)
                        .opacity(segment.ruby == nil ? 0 : 1)
                    Text(segment.base)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(RetroColor.paperInk)
                }
                .fixedSize()
            }
        }
    }
}

// MARK: - 튜토리얼 카드 (T-2)

private struct TutorialCardView: View {
    let card: TutorialCard
    let number: Int
    @Bindable var director: DayOneDirector

    @State private var revealedHere = false
    @State private var flashKnown = false

    private var isGate: Bool { director.step == .card(number) }
    private var revealed: Bool { director.isCardRevealed || revealedHere }

    var body: some View {
        VStack(spacing: 14) {
            Text("카드 \(number + 1) / 5")
                .font(.caption2.weight(.bold))
                .foregroundStyle(RetroColor.paperInkDim)
            Text(card.term)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(RetroColor.paperInk)
            if revealed {
                VStack(spacing: 4) {
                    Text(card.reading).font(.callout).foregroundStyle(RetroColor.paperInkDim)
                    Text(card.meaning).font(.title3.weight(.semibold)).foregroundStyle(RetroColor.paperRed)
                }
                .transition(.opacity)
            }
            if isGate { gateButtons }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(RetroNineSlice(name: "rt_paper", animated: false))
        .onChange(of: number) { _, _ in revealedHere = false; flashKnown = false }
    }

    @ViewBuilder
    private var gateButtons: some View {
        if !revealed {
            Button(flashKnown ? "見る" : "정답 보기") {
                withAnimation(.easeOut(duration: 0.2)) { revealedHere = true }
            }
            .buttonStyle(RetroKeyStyle(tone: .amber))
        } else if card.asksAnswer {
            HStack(spacing: 12) {
                Button("모른다") { director.answerCard(knew: false) }
                    .buttonStyle(RetroKeyStyle(tone: .cream))
                Button("안다") { answerKnown() }
                    .buttonStyle(RetroKeyStyle(tone: .amber))
            }
        } else {
            Button("다음") { director.answerCard(knew: nil) }
                .buttonStyle(RetroKeyStyle(tone: .amber))
        }
    }

    /// 見る를 '안다'로 고르면 「정답 보기」 자리에 글자가 잠깐 스며듦 (D1-239)
    private func answerKnown() {
        guard card.term == "見る" else { director.answerCard(knew: true); return }
        withAnimation { revealedHere = false; flashKnown = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            director.answerCard(knew: true)
        }
    }
}

// MARK: - 목소리 고르기 (D1-029)

private struct VoicePickPanel: View {
    @Bindable var director: DayOneDirector
    let speech: SpeechPlayer
    @State private var picked: StoryVoice = .a

    var body: some View {
        VStack(spacing: 12) {
            Text("내 목소리는…")
                .font(.callout.weight(.semibold))
                .foregroundStyle(RetroColor.phosphor)
            HStack(spacing: 10) {
                ForEach(StoryVoice.allCases, id: \.self) { voice in
                    Button(voice.title) {
                        picked = voice
                        speech.playSingle(fileName: "story_d1_027_\(voice.rawValue)")
                    }
                    .buttonStyle(RetroKeyStyle(tone: .cream, latched: picked == voice))
                }
            }
            Button("이 목소리로") { director.chooseVoice(picked) }
                .buttonStyle(RetroKeyStyle(tone: .amber))
        }
        .padding(14)
        .background(RetroColor.wall, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - 이름 입력 (D1-141)

private struct NameInputPanel: View {
    @Bindable var director: DayOneDirector
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text("이름을 알려 주세요")
                .font(.callout.weight(.semibold))
                .foregroundStyle(RetroColor.phosphor)
            TextField("최대 8자", text: $name)
                .focused($focused)
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(RetroColor.phosphorBright)
                .multilineTextAlignment(.center)
                .padding(12)
                .background(RetroNineSlice(name: focused ? "rt_lcd_field_focus" : "rt_lcd_field", animated: false))
                .onChange(of: name) { _, value in if value.count > 8 { name = String(value.prefix(8)) } }
                .onSubmit { director.submitName(name) }
            Button("확인") { director.submitName(name) }
                .buttonStyle(RetroKeyStyle(tone: .amber))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(14)
        .background(RetroColor.wall, in: RoundedRectangle(cornerRadius: 8))
        .onAppear { focused = true }
    }
}

// MARK: - 출근 시간 (D1-509)

private struct CommutePanel: View {
    @Bindable var director: DayOneDirector
    @State private var time = Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date()) ?? Date()

    var body: some View {
        VStack(spacing: 12) {
            Text("출근 시간")
                .font(.callout.weight(.semibold))
                .foregroundStyle(RetroColor.phosphor)
            DatePicker("출근 시간", selection: $time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .colorScheme(.dark)
            HStack(spacing: 12) {
                Button("나중에") { director.setCommute(nil) }
                    .buttonStyle(RetroKeyStyle(tone: .cream))
                Button("이 시간으로") { director.setCommute(time) }
                    .buttonStyle(RetroKeyStyle(tone: .amber))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(RetroColor.wall, in: RoundedRectangle(cornerRadius: 8))
    }
}
