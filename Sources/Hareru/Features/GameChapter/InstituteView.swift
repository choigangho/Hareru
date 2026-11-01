import SwiftUI

// MARK: - 탭 2 「연구소」 — 国立言語遺産研究所(NJL) 경영 화면 (M1: 1단계 사무실)
// 학습 기록을 연구 포인트로 정산하고, 예산으로 시설을 배치하고, 외운 단어의 한자를 복원합니다.
public struct InstituteView: View {
    private let sessionEngine: StudySessionEngine
    private let instituteEngine: InstituteEngine
    private let weatherEngine: WeatherAtmosphereEngine

    private enum Mode: String, CaseIterable, Identifiable {
        case build = "시설 배치"
        case restore = "한자 복원"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .build
    @State private var placingKind: FacilityKind?
    @State private var selectedCell: GridPosition?
    @State private var guideLine: String = ""
    @State private var introIndex: Int?

    public init(
        sessionEngine: StudySessionEngine,
        instituteEngine: InstituteEngine,
        weatherEngine: WeatherAtmosphereEngine = .shared
    ) {
        self.sessionEngine = sessionEngine
        self.instituteEngine = instituteEngine
        self.weatherEngine = weatherEngine
    }

    private var state: InstituteState { instituteEngine.state }

    /// 연구소 하늘은 실제 날씨가 아니라 연구소 영향력으로 정해짐 (시간대만 실제를 따름)
    private var palette: WeatherSkyPalette {
        WeatherSkyPalette.resolve(condition: state.instituteSky, timeOfDay: weatherEngine.activeTimeOfDay)
    }

    private var snapshots: [String: WordMemorySnapshot] {
        _ = sessionEngine.stateRevision
        return sessionEngine.store.allSnapshots()
    }

    public var body: some View {
        ZStack {
            WeatherSkyCanvasView(
                condition: state.instituteSky,
                timeOfDay: weatherEngine.activeTimeOfDay,
                palette: palette
            )

            VStack(spacing: 10) {
                resourceBar
                InstituteOfficeCanvas(
                    state: state,
                    activeCombos: instituteEngine.activeCombos,
                    selectedCell: selectedCell,
                    placingKind: placingKind,
                    onTapCell: handleTap
                )
                // 픽셀 배율은 정수로 내림하므로, 좌우 여백 없이 화면 폭을 다 써야 2배율 이상이 나옴
                .padding(.horizontal, -12)
                .frame(maxHeight: .infinity)
                guideBubble
                modePanel
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
        .foregroundStyle(palette.primaryTextColor)
        .onAppear(perform: settleAndGreet)
    }

    // MARK: - 자원 바 (研究P · 予算 · 影響力)

    private var resourceBar: some View {
        HStack(spacing: 8) {
            resourceChip(icon: "atom", title: "研究P", value: state.researchPoints)
            resourceChip(icon: "yensign.circle.fill", title: "予算", value: state.budget)
            resourceChip(icon: "sparkles", title: "影響力", value: state.influence)
            Image(systemName: state.instituteSky.sfSymbolName(for: weatherEngine.activeTimeOfDay))
                .symbolRenderingMode(.multicolor)
                .font(.title3)
                .frame(width: 40, height: 40)
                .hareruGlass(in: Circle(), tint: palette.glassTintColor)
                .accessibilityLabel("연구소 하늘 \(state.instituteSky.koreanTitle)")
        }
    }

    private func resourceChip(icon: String, title: String, value: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accentColor)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.secondaryTextColor)
                Text("\(value)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hareruGlass(in: Capsule(), tint: palette.glassTintColor)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
    }

    // MARK: - 가이드 연구원 말풍선 (소개 대사는 탭해서 넘김)

    private var guideBubble: some View {
        Button {
            advanceIntro()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(InstituteGuideScript.speakerTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.accentColor)
                    Text("？？？")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(palette.secondaryTextColor)
                    Spacer()
                    if let introIndex {
                        Text("\(introIndex + 1) / \(InstituteGuideScript.intro.count)  ▸")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(palette.secondaryTextColor)
                    }
                }
                Text(guideLine)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(guideLine)
                    .transition(.opacity)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hareruGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), tint: palette.glassTintColor)
        }
        // 소개가 끝나면 탭해도 아무 일 없음 (disabled는 글씨를 흐리게 만들어서 쓰지 않음)
        .buttonStyle(.plain)
        .allowsHitTesting(introIndex != nil)
    }

    // MARK: - 아래 패널 (시설 배치 · 한자 복원)

    private var modePanel: some View {
        VStack(spacing: 8) {
            Picker("연구소 모드", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in
                placingKind = nil
                selectedCell = nil
            }

            switch mode {
            case .build: buildPanel
            case .restore: restorePanel
            }
        }
        .frame(height: 150)
    }

    private var buildPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let cell = selectedCell, placingKind == nil, let facility = instituteEngine.facility(at: cell) {
                selectedFacilityRow(facility)
            } else {
                Text(placingKind.map { "'\($0.title)'을(를) 놓을 바닥을 누르세요" } ?? "놓을 시설을 고르세요")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryTextColor)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FacilityKind.allCases.filter { !$0.isUnique }) { kind in
                        facilityCard(kind)
                    }
                }
            }
        }
    }

    private func facilityCard(_ kind: FacilityKind) -> some View {
        let isSelected = placingKind == kind
        let affordable = state.budget >= kind.budgetCost
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                placingKind = isSelected ? nil : kind
                selectedCell = nil
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: Self.icon(for: kind))
                    .font(.headline)
                    .foregroundStyle(palette.accentColor)
                Text(kind.title)
                    .font(.caption.weight(.bold))
                Text("予算 \(kind.budgetCost)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(affordable ? palette.secondaryTextColor : Color.red.opacity(0.85))
            }
            .padding(10)
            .frame(width: 96, alignment: .leading)
            .lensGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                       tint: isSelected ? palette.accentColor.opacity(0.5) : palette.glassTintColor)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(palette.accentColor, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.title), 예산 \(kind.budgetCost). \(kind.summary)")
    }

    private func selectedFacilityRow(_ facility: PlacedFacility) -> some View {
        HStack(spacing: 8) {
            Image(systemName: Self.icon(for: facility.kind))
                .foregroundStyle(palette.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(facility.kind.title).font(.caption.weight(.bold))
                Text(facility.kind.summary).font(.caption2).foregroundStyle(palette.secondaryTextColor)
            }
            Spacer()
            if facility.kind != .researcherDesk {
                Button("치우기") {
                    if instituteEngine.remove(at: facility.position) {
                        say(InstituteGuideScript.removed(facility.kind))
                        selectedCell = nil
                    }
                }
                .font(.caption.weight(.semibold))
                .hareruSecondaryButtonStyle()
            }
        }
    }

    private var restorePanel: some View {
        let restorable = instituteEngine.restorableKanji(catalog: sessionEngine.catalog, snapshots: snapshots)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("복원 비용 研究P \(instituteEngine.restoreCost)")
                    .font(.caption.weight(.semibold))
                if instituteEngine.restoreDiscountPercent > 0 {
                    Text("(-\(instituteEngine.restoreDiscountPercent)%)")
                        .font(.caption2)
                        .foregroundStyle(palette.accentColor)
                }
                Spacer()
                Text("복원한 한자 \(state.restoredKanji.count)자")
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryTextColor)
            }
            if restorable.isEmpty {
                Text(InstituteGuideScript.nothingToRestore)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(restorable, id: \.self) { kanji in
                            restoreChip(kanji)
                        }
                    }
                }
            }
        }
    }

    private func restoreChip(_ kanji: String) -> some View {
        let hunEum = sessionEngine.catalog.kanjiInfo(for: kanji)?.koreanHunEum
        return Button {
            let cost = instituteEngine.restoreCost
            if instituteEngine.restore(kanji: kanji, catalog: sessionEngine.catalog, snapshots: snapshots) {
                say(InstituteGuideScript.restored(kanji, hunEum: hunEum))
            } else {
                say(InstituteGuideScript.notEnoughPoints(cost: cost))
            }
        } label: {
            VStack(spacing: 2) {
                Text(kanji)
                    .jlptTermFont(size: 30)
                Text(hunEum ?? "")
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryTextColor)
            }
            .frame(width: 66, height: 70)
            .lensGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), tint: palette.glassTintColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kanji) \(hunEum ?? "") 복원")
    }

    // MARK: - 동작

    private func handleTap(_ cell: GridPosition) {
        if let kind = placingKind {
            let combosBefore = Set(instituteEngine.activeCombos)
            if instituteEngine.facility(at: cell) != nil {
                say(InstituteGuideScript.cellOccupied)
            } else if instituteEngine.place(kind, at: cell) {
                let newCombos = instituteEngine.activeCombos.filter { !combosBefore.contains($0) }
                say(InstituteGuideScript.placed(kind, newCombos: newCombos))
                placingKind = nil
            } else {
                say(InstituteGuideScript.notEnoughBudget(kind))
            }
            selectedCell = cell
        } else {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCell = selectedCell == cell ? nil : cell
            }
        }
    }

    private func settleAndGreet() {
        let result = instituteEngine.settle(logs: sessionEngine.store.allReviewLogs())
        if !state.hasSeenIntro {
            introIndex = 0
            guideLine = InstituteGuideScript.intro[0]
        } else {
            guideLine = InstituteGuideScript.settlement(result)
        }
    }

    private func advanceIntro() {
        guard let index = introIndex else { return }
        let next = index + 1
        withAnimation(.easeInOut(duration: 0.2)) {
            if next < InstituteGuideScript.intro.count {
                introIndex = next
                guideLine = InstituteGuideScript.intro[next]
            } else {
                introIndex = nil
                instituteEngine.markIntroSeen()
                guideLine = "그럼 먼저 오늘의 학습 기록부터 정산해 볼게요. 아래에서 시설을 골라 사무실을 꾸며 보세요!"
            }
        }
    }

    private func say(_ line: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            introIndex = nil
            guideLine = line
        }
    }

    private static func icon(for kind: FacilityKind) -> String {
        switch kind {
        case .researcherDesk: return "desktopcomputer"
        case .kanjiArchive: return "books.vertical.fill"
        case .copyRoom: return "pencil.and.scribble"
        case .recordingBooth: return "mic.fill"
        case .serverRack: return "server.rack"
        }
    }
}

#Preview("연구소 (1단계 사무실)") {
    InstituteView(
        sessionEngine: StudySessionEngine(store: InMemoryMemoryStore()),
        instituteEngine: InstituteEngine(store: InMemoryInstituteStore(state: InstituteState(budget: 600)))
    )
}
