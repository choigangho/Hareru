import SwiftUI

// MARK: - 탭 2 「연구소」 — 国立言語遺産研究所(NJL) 경영 화면 (M1: 1단계 사무실)
// 카이로소프트식 가장자리 HUD 레이아웃을 Hareru의 Liquid Glass + 날씨 색온도 팔레트로 재해석한 화면입니다.
public struct InstituteView: View {
    private let sessionEngine: StudySessionEngine
    private let instituteEngine: InstituteEngine
    private let weatherEngine: WeatherAtmosphereEngine

    private enum CommandMenu: String, CaseIterable, Identifiable {
        case restore = "한자 복원"
        case build = "시설 배치"
        case staff = "모듈 · 인물"
        case info = "연구소 정보"

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .restore: return "📜"
            case .build: return "🪑"
            case .staff: return "🤖"
            case .info: return "📊"
            }
        }

        var subtitle: String {
            switch self {
            case .restore: return "연구P로 한자 복원"
            case .build: return "예산으로 설비 확충"
            case .staff: return "연구원 · AI 모듈"
            case .info: return "활성 콤보 · 보너스"
            }
        }
    }

    @State private var isMenuOpen: Bool = false
    @State private var activeMenu: CommandMenu? = nil
    @State private var placingKind: FacilityKind? = nil
    @State private var selectedCell: GridPosition? = nil
    @State private var guideLine: String = ""
    @State private var introIndex: Int? = nil
    /// 연구원 이동 · 버블 · 복원 연출 (저장하지 않음 — 탭을 떠나면 사라져도 됨)
    @State private var runtime: OfficeSimulationRuntime
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        sessionEngine: StudySessionEngine,
        instituteEngine: InstituteEngine,
        weatherEngine: WeatherAtmosphereEngine = .shared
    ) {
        self.sessionEngine = sessionEngine
        self.instituteEngine = instituteEngine
        self.weatherEngine = weatherEngine
        _runtime = State(initialValue: OfficeSimulationRuntime(facilities: instituteEngine.state.facilities))
    }

    private var now: Double { Date().timeIntervalSinceReferenceDate }

    private var state: InstituteState { instituteEngine.state }

    /// 연구소 하늘은 실제 날씨가 아니라 연구소 영향력으로 정해짐 (시간대만 실제를 따름)
    private var palette: WeatherSkyPalette {
        WeatherSkyPalette.resolve(condition: state.instituteSky, timeOfDay: weatherEngine.activeTimeOfDay)
    }

    private var snapshots: [String: WordMemorySnapshot] {
        _ = sessionEngine.stateRevision
        return sessionEngine.store.allSnapshots()
    }

    private var restorableKanjiList: [String] {
        instituteEngine.restorableKanji(catalog: sessionEngine.catalog, snapshots: snapshots)
    }

    public var body: some View {
        ZStack {
            // 배경 하늘 캔버스
            WeatherSkyCanvasView(
                condition: state.instituteSky,
                timeOfDay: weatherEngine.activeTimeOfDay,
                palette: palette
            )

            // 1. 캔버스 풀스크린 배치 (ZStack 바탕)
            InstituteOfficeCanvas(
                state: state,
                comboMemberIDs: instituteEngine.comboMemberIDs,
                runtime: runtime,
                selectedCell: selectedCell,
                placingKind: placingKind,
                onTapCell: handleTap
            )
            .ignoresSafeArea(edges: .horizontal)

            // 가장자리 Floating Liquid Glass HUD 레이어
            VStack(spacing: 8) {
                // ① 최상단 슬림 글라스 상태 리본
                topStatusRibbon

                // ② 좌상단 미니 플로팅 배지 + 선택된 타일 시설 팝업
                HStack(alignment: .top, spacing: 8) {
                    floatingBadges
                    Spacer(minLength: 0)
                    if let cell = selectedCell,
                       placingKind == nil,
                       let facility = instituteEngine.facility(at: cell) {
                        selectedFacilityPopover(facility)
                            .transition(.scale(scale: 0.92, anchor: .topTrailing).combined(with: .opacity))
                    }
                }

                Spacer(minLength: 0)

                // ③ 좌측 플로팅 수직 커맨드 메뉴 스택 & 서브 트레이
                HStack(alignment: .bottom, spacing: 10) {
                    if isMenuOpen {
                        glassCommandStack
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    Spacer(minLength: 0)
                }

                if let activeMenu {
                    commandSubTray(for: activeMenu)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // ④ 하단 2분할 글라스 전광판 (Bottom Glass Ticker)
                bottomGlassTicker

                // 타이쿤식 코너 액션 버튼 ([ ☰ 메뉴 ] / [ 뒤로 ])
                cornerActionDock
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 6)
        }
        .foregroundStyle(palette.primaryTextColor)
        .onAppear {
            runtime.reduceMotion = reduceMotion
            settleAndGreet()
        }
        .onChange(of: reduceMotion) { _, value in runtime.reduceMotion = value }
    }

    // MARK: - ① 최상단 슬림 글라스 리본 바 (Top Status Ribbon)

    private var topStatusRibbon: some View {
        HStack(spacing: 12) {
            // 좌측: 연구소 날씨 아이콘 + 단계 표시
            HStack(spacing: 6) {
                Image(systemName: state.instituteSky.sfSymbolName(for: weatherEngine.activeTimeOfDay))
                    .symbolRenderingMode(.multicolor)
                    .font(.subheadline.weight(.semibold))
                Text("NJL \(state.stage)단계 사무실")
                    .font(.caption.weight(.bold))
                Text("· \(state.instituteSky.koreanTitle)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(palette.secondaryTextColor)
            }
            .accessibilityLabel("NJL \(state.stage)단계 사무실, 연구소 하늘 \(state.instituteSky.koreanTitle)")

            Spacer(minLength: 8)

            // 우측: 研究P · 予算(¥) 모노스페이스 수치
            HStack(spacing: 14) {
                ribbonMetric(icon: "atom", label: "研究P", value: "\(state.researchPoints)")
                Divider()
                    .frame(height: 14)
                    .overlay(palette.secondaryTextColor.opacity(0.3))
                ribbonMetric(icon: "yensign", label: "予算", value: "¥\(state.budget)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .hareruGlass(in: Capsule(), tint: palette.glassTintColor)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.researchPoints)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.budget)
    }

    private func ribbonMetric(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(palette.accentColor)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.secondaryTextColor)
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .contentTransition(.numericText())
        }
    }

    // MARK: - ② 좌측 상단 플로팅 배지 (Floating Badges)

    private var floatingBadges: some View {
        HStack(spacing: 6) {
            miniBadge(emoji: "📜", title: "복원 \(state.restoredKanji.count)/2136")
            miniBadge(emoji: "✨", title: "영향력 \(state.influence)")
            if !instituteEngine.activeCombos.isEmpty {
                miniBadge(emoji: "⚡", title: "콤보 \(instituteEngine.activeCombos.count)", highlighted: true)
            }
        }
    }

    private func miniBadge(emoji: String, title: String, highlighted: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(emoji)
                .font(.caption2)
            Text(title)
                .font(.caption2.weight(.bold).monospacedDigit())
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .hareruGlass(
            in: Capsule(),
            tint: highlighted ? palette.accentColor.opacity(0.45) : palette.glassTintColor
        )
    }

    // MARK: - 선택된 타일 시설 미니 팝업 (캔버스 타일 클릭 시)

    private func selectedFacilityPopover(_ facility: PlacedFacility) -> some View {
        HStack(spacing: 8) {
            Image(systemName: Self.icon(for: facility.kind))
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(facility.kind.title)
                    .font(.caption2.weight(.bold))
                Text(facility.kind.summary)
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryTextColor)
                    .lineLimit(1)
            }
            if facility.kind != .researcherDesk {
                Button("치우기") {
                    if instituteEngine.remove(at: facility.position) {
                        say(InstituteGuideScript.removed(facility.kind))
                        selectedCell = nil
                    }
                }
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .lensGlass(in: Capsule(), tint: palette.accentColor.opacity(0.35))
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .hareruGlass(in: Capsule(), tint: palette.glassTintColor)
    }

    // MARK: - ③ 좌측 플로팅 글라스 커맨드 메뉴 스택 (Glass Command Stack)

    private var glassCommandStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(CommandMenu.allCases) { item in
                let isSelected = activeMenu == item
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        if activeMenu == item {
                            activeMenu = nil
                            placingKind = nil
                        } else {
                            activeMenu = item
                            if item != .build {
                                placingKind = nil
                            }
                            selectedCell = nil
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(item.emoji)
                            .font(.subheadline)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.rawValue)
                                .font(.caption.weight(.bold))
                            Text(item.subtitle)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(palette.secondaryTextColor)
                        }
                        Spacer(minLength: 6)
                        Image(systemName: isSelected ? "chevron.down" : "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(isSelected ? palette.accentColor : palette.secondaryTextColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(width: 164, alignment: .leading)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(palette.accentColor.opacity(0.24))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(palette.accentColor.opacity(0.85), lineWidth: 1)
                                }
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .lensGlass(
            in: RoundedRectangle(cornerRadius: 20, style: .continuous),
            tint: palette.glassTintColor
        )
    }

    // MARK: - 커맨드 서브 미니 트레이 (선택한 메뉴 항목별 플로팅 트레이)

    @ViewBuilder
    private func commandSubTray(for menu: CommandMenu) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch menu {
            case .restore:
                restoreTrayContent
            case .build:
                buildTrayContent
            case .staff:
                staffTrayContent
            case .info:
                infoTrayContent
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lensGlass(
            in: RoundedRectangle(cornerRadius: 20, style: .continuous),
            tint: palette.glassTintColor
        )
    }

    private var restoreTrayContent: some View {
        let restorable = restorableKanjiList
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("한자 복원", systemImage: "scroll.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accentColor)
                Text("비용 研究P \(instituteEngine.restoreCost)")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                if instituteEngine.restoreDiscountPercent > 0 {
                    Text("(-\(instituteEngine.restoreDiscountPercent)%)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(palette.accentColor)
                }
                Spacer()
                Text("누적 \(state.restoredKanji.count)자")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(palette.secondaryTextColor)
            }

            if restorable.isEmpty {
                Text(InstituteGuideScript.nothingToRestore)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryTextColor)
                    .padding(.vertical, 4)
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
            let insight = RestorationInsight(kanji: kanji, catalog: sessionEngine.catalog, snapshots: snapshots)
            if instituteEngine.restore(kanji: kanji, catalog: sessionEngine.catalog, snapshots: snapshots) {
                runtime.startRestoration(insight, time: now)
                say(InstituteGuideScript.restored(kanji, hunEum: hunEum))
            } else {
                say(InstituteGuideScript.notEnoughPoints(cost: cost))
            }
        } label: {
            VStack(spacing: 2) {
                Text(kanji)
                    .jlptTermFont(size: 28)
                Text(hunEum ?? "")
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryTextColor)
                    .lineLimit(1)
            }
            .frame(width: 64, height: 66)
            .lensGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous), tint: palette.glassTintColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kanji) \(hunEum ?? "") 복원")
    }

    private var buildTrayContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("시설 배치", systemImage: "square.grid.2x2.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accentColor)
                Spacer()
                Text(placingKind.map { "'\($0.title)' 놓을 바닥 타일을 탭하세요" } ?? "설치할 시설을 선택하세요")
                    .font(.caption2)
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
                if !isSelected {
                    // 타일을 고르기 편하도록 좌측 메뉴 스택은 접어 시야 확보
                    isMenuOpen = false
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: Self.icon(for: kind))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.accentColor)
                    Spacer()
                    Text("¥\(kind.budgetCost)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(affordable ? palette.secondaryTextColor : Color.red.opacity(0.85))
                }
                Text(kind.title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                Text(kind.summary)
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondaryTextColor)
                    .lineLimit(1)
            }
            .padding(9)
            .frame(width: 112, alignment: .leading)
            .lensGlass(
                in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                tint: isSelected ? palette.accentColor.opacity(0.5) : palette.glassTintColor
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(palette.accentColor, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.title), 예산 \(kind.budgetCost). \(kind.summary)")
    }

    private var staffTrayContent: some View {
        let serverCount = state.facilities.filter { $0.kind == .serverRack }.count
        let boothCount = state.facilities.filter { $0.kind == .recordingBooth }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("모듈 · 인물 현황", systemImage: "person.2.wave.2.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accentColor)
                Spacer()
                Text("상주 인원 1명 · 보조 모듈 \(serverCount + boothCount)기")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(palette.secondaryTextColor)
            }

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    GuidePixelAvatarView()
                        .frame(width: 34, height: 34)
                        .hareruGlass(in: RoundedRectangle(cornerRadius: 10, style: .continuous), tint: palette.glassTintColor)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(InstituteGuideScript.speakerTitle)
                                .font(.caption.weight(.bold))
                            Text("？？？")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(palette.accentColor)
                        }
                        Text("NJL 유일의 상주 연구원 · 한자 문헌 대조 담당")
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryTextColor)
                    }
                }
                Spacer()
            }
        }
    }

    private var infoTrayContent: some View {
        let activeCombos = instituteEngine.activeCombos
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("연구소 효과 · 활성 콤보", systemImage: "chart.bar.xaxis")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accentColor)
                Spacer()
                Text("연구P +\(instituteEngine.researchBonusPercent)% · 복원할인 -\(instituteEngine.restoreDiscountPercent)%")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(palette.accentColor)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FacilityCombo.allCases) { combo in
                        let isUnlocked = activeCombos.contains(combo)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: isUnlocked ? "sparkles" : "lock.fill")
                                    .font(.caption2)
                                    .foregroundStyle(isUnlocked ? palette.accentColor : palette.secondaryTextColor)
                                Text(combo.title)
                                    .font(.caption2.weight(.bold))
                                    .lineLimit(1)
                            }
                            Text(combo.summary)
                                .font(.system(size: 10))
                                .foregroundStyle(palette.secondaryTextColor)
                                .lineLimit(2)
                        }
                        .padding(8)
                        .frame(width: 170, alignment: .leading)
                        .hareruGlass(
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous),
                            tint: isUnlocked ? palette.accentColor.opacity(0.35) : palette.glassTintColor
                        )
                    }
                }
            }
        }
    }

    // MARK: - ④ 하단 2분할 글라스 전광판 (Bottom Glass Ticker)

    private var bottomGlassTicker: some View {
        HStack(spacing: 0) {
            // 좌측 영역: 가이드 연구원 미니 픽셀 얼굴 + ？？？ 태그 + 대사
            Button {
                advanceIntro()
            } label: {
                HStack(spacing: 8) {
                    GuidePixelAvatarView()
                        .frame(width: 34, height: 34)
                        .hareruGlass(in: RoundedRectangle(cornerRadius: 10, style: .continuous), tint: palette.glassTintColor)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(InstituteGuideScript.speakerTitle)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(palette.accentColor)
                            Text("？？？")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(palette.secondaryTextColor)
                            if let introIndex {
                                Text("\(introIndex + 1)/\(InstituteGuideScript.intro.count) ▸")
                                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                                    .foregroundStyle(palette.accentColor)
                            }
                        }
                        Text(guideLine)
                            .font(.caption)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(guideLine)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(introIndex != nil)

            Divider()
                .frame(height: 36)
                .overlay(palette.secondaryTextColor.opacity(0.28))

            // 우측 영역: 현재 상태 요약 (진행 중 복원 / 배치 모드 / 복원 가능 한자)
            VStack(alignment: .trailing, spacing: 2) {
                Text(tickerStatusTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.secondaryTextColor)
                Text(tickerStatusValue)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tickerStatusHighlight ? palette.accentColor : palette.primaryTextColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 126, alignment: .trailing)
        }
        .hareruGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            tint: palette.glassTintColor
        )
    }

    private var tickerStatusTitle: String {
        if let placingKind {
            return "시설 배치 모드"
        }
        if !restorableKanjiList.isEmpty {
            return "한자 복원 가능"
        }
        return "복원 대기 상태"
    }

    private var tickerStatusValue: String {
        if let placingKind {
            return "\(placingKind.title) 타일 선택"
        }
        if let first = restorableKanjiList.first {
            let extra = restorableKanjiList.count > 1 ? " 외 \(restorableKanjiList.count - 1)자" : " 복원 가능"
            return "「\(first)」\(extra)"
        }
        return "신규 복원 대기 중"
    }

    private var tickerStatusHighlight: Bool {
        placingKind != nil || !restorableKanjiList.isEmpty
    }

    // MARK: - 타이쿤식 코너 액션 버튼 ([ ☰ 메뉴 ] / [ 뒤로 ])

    private var cornerActionDock: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                    isMenuOpen.toggle()
                    if !isMenuOpen {
                        activeMenu = nil
                        placingKind = nil
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isMenuOpen ? "xmark" : "line.3.horizontal")
                        .font(.caption.weight(.bold))
                    Text("메뉴")
                        .font(.caption.weight(.bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .lensGlass(
                    in: Capsule(),
                    tint: isMenuOpen ? palette.accentColor.opacity(0.45) : palette.glassTintColor
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isMenuOpen ? "메뉴 닫기" : "메뉴 열기")

            Spacer()

            if isMenuOpen || activeMenu != nil || placingKind != nil || selectedCell != nil {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        if placingKind != nil {
                            placingKind = nil
                        } else if activeMenu != nil {
                            activeMenu = nil
                        } else if isMenuOpen {
                            isMenuOpen = false
                        } else {
                            selectedCell = nil
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.caption2.weight(.bold))
                        Text("뒤로")
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .lensGlass(in: Capsule(), tint: palette.glassTintColor)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .accessibilityLabel("뒤로")
            }
        }
    }

    // MARK: - 동작

    private func handleTap(_ cell: GridPosition) {
        // 복원 연출 중에 사무실을 탭하면 연출만 건너뜀 (결과는 이미 저장됨)
        if runtime.isShowingRestoration {
            runtime.skipRestoration(time: now)
            return
        }
        if let kind = placingKind {
            let combosBefore = Set(instituteEngine.activeCombos)
            if instituteEngine.facility(at: cell) != nil {
                say(InstituteGuideScript.cellOccupied)
            } else if instituteEngine.place(kind, at: cell) {
                let newCombos = instituteEngine.activeCombos.filter { !combosBefore.contains($0) }
                if let placed = instituteEngine.facility(at: cell) {
                    runtime.facilityPlaced(placed, newCombos: newCombos, all: instituteEngine.state.facilities, time: now)
                }
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
        runtime.emitSettlement(result, time: now + 0.3)
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
                guideLine = "그럼 먼저 오늘의 학습 기록부터 정산해 볼게요. [메뉴]를 눌러 사무실을 꾸며 보세요!"
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

// MARK: - 가이드 연구원 미니 픽셀 얼굴 아이콘 (하단 글라스 전광판 · 인물 정보용)
private struct GuidePixelAvatarView: View {
    private static let headSprite = [
        "..hhhh..",
        ".hhhhhh.",
        ".hssssh.",
        ".gegeg..",
        ".hssssh.",
        "..ssss..",
        "..cccc..",
        ".cccccc."
    ]

    private static let colorMap: [Character: Color] = [
        "h": Color(red: 0.16, green: 0.13, blue: 0.16),
        "s": Color(red: 0.98, green: 0.86, blue: 0.76),
        "g": Color(red: 0.25, green: 0.30, blue: 0.40),
        "e": Color(red: 0.55, green: 0.75, blue: 0.95),
        "c": Color(red: 0.96, green: 0.96, blue: 0.98)
    ]

    var body: some View {
        Canvas { context, size in
            let px = max(1, (min(size.width, size.height) / 10).rounded(.down))
            let totalWidth = 8 * px
            let totalHeight = CGFloat(Self.headSprite.count) * px
            let originX = ((size.width - totalWidth) / 2).rounded()
            let originY = ((size.height - totalHeight) / 2).rounded()

            for (y, row) in Self.headSprite.enumerated() {
                for (x, ch) in row.enumerated() {
                    guard let color = Self.colorMap[ch] else { continue }
                    let rect = CGRect(
                        x: originX + CGFloat(x) * px,
                        y: originY + CGFloat(y) * px,
                        width: px,
                        height: px
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("연구소 (1단계 사무실)") {
    InstituteView(
        sessionEngine: StudySessionEngine(store: InMemoryMemoryStore()),
        instituteEngine: InstituteEngine(store: InMemoryInstituteStore(state: InstituteState(budget: 600)))
    )
}
