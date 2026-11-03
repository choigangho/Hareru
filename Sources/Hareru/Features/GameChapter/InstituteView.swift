import SwiftUI
import SpriteKit

// MARK: - 탭 2 「연구소」 — 国立言語遺産研究所(NJL) 경영 화면
// 타이쿤 장르의 '가장자리 HUD'(위: 달력·자금, 아래: 명령 도크)를 Hareru의 Liquid Glass와
// 연구소 하늘 색온도(WeatherSkyPalette)로 재해석. 가운데 사무실은 SpriteKit(OfficeScene).
// 자원·복원은 InstituteEngine이 즉시 확정하고, 장면은 결과를 보여 주기만 함.
public struct InstituteView: View {
    private let sessionEngine: StudySessionEngine
    private let instituteEngine: InstituteEngine
    private let weatherEngine: WeatherAtmosphereEngine

    private enum Command: String, CaseIterable, Identifiable {
        case build = "건설"
        case restore = "복원"
        case status = "현황"
        case interior = "인테리어"
        var id: String { rawValue }

        var icon: PixelIcon.Name {
            switch self {
            case .build: return .build
            case .restore: return .restore
            case .status: return .status
            case .interior: return .interior
            }
        }
    }

    @State private var openCommand: Command?
    @State private var lastPan: CGSize = .zero
    @State private var magnifyStartZoom: Int?
    /// 메뉴판 (메뉴 버튼으로 여닫음 → 항목을 고르면 그 서랍이 열림)
    @State private var isMenuOpen = false
    @State private var placingKind: FacilityKind?
    /// 옮기는 중인 시설 (선택 칩의 '이동' → 옮길 바닥을 누름)
    @State private var movingFacility: PlacedFacility?
    @State private var selectedCell: GridPosition?
    @State private var guideLine = ""
    @State private var introIndex: Int?
    @State private var lastSettlement: InstituteSettlement?
    @State private var runtime: OfficeSimulationRuntime
    @State private var scene: OfficeScene
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(DayOneDirector.doneKey) private var dayOneDone = false
    private var isStoryPlaying: Bool { !dayOneDone }

    public init(
        sessionEngine: StudySessionEngine,
        instituteEngine: InstituteEngine,
        weatherEngine: WeatherAtmosphereEngine = .shared
    ) {
        self.sessionEngine = sessionEngine
        self.instituteEngine = instituteEngine
        self.weatherEngine = weatherEngine
        let runtime = OfficeSimulationRuntime(facilities: instituteEngine.state.facilities)
        _runtime = State(initialValue: runtime)
        _scene = State(initialValue: OfficeScene(runtime: runtime))
    }

    private var now: Double { Date().timeIntervalSinceReferenceDate }
    private var state: InstituteState { instituteEngine.state }

    /// 연구소 하늘은 실제 날씨가 아니라 영향력으로 정해짐 (시간대만 실제를 따름)
    private var palette: WeatherSkyPalette {
        WeatherSkyPalette.resolve(condition: state.instituteSky, timeOfDay: weatherEngine.activeTimeOfDay)
    }

    private var snapshots: [String: WordMemorySnapshot] {
        _ = sessionEngine.stateRevision
        return sessionEngine.store.allSnapshots()
    }

    private var restorable: [String] {
        instituteEngine.restorableKanji(catalog: sessionEngine.catalog, snapshots: snapshots)
    }

    public var body: some View {
        ZStack {
            WeatherSkyCanvasView(
                condition: state.instituteSky,
                timeOfDay: weatherEngine.activeTimeOfDay,
                palette: palette
            )

            VStack(spacing: 8) {
                topEdge
                broadcastStrip

                ZStack(alignment: .bottom) {
                    officeView
                    contextOverlay
                }
                .frame(maxHeight: .infinity)

                HStack(alignment: .bottom, spacing: 8) {
                    // 스토리 장면이 대사창을 띄우는 동안은 주임 팝업을 숨김 (같은 사람이 두 곳에서 말하지 않게)
                    secretaryPopup
                        .opacity(isStoryPlaying ? 0 : 1)
                    menuButton
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 6)
        }
        .foregroundStyle(PixelUI.text)
        // 앱 전체 다크/라이트는 '실제 날씨'를 따르지만, 이 화면의 글씨 색은 '연구소 하늘'을 따르므로
        // 유리 재질도 연구소 하늘에 맞춰야 밝은 유리 위 밝은 글씨(대비 부족)가 생기지 않음
        .environment(\.colorScheme, .dark)   // 픽셀 UI 판은 늘 남색 → 시스템 요소도 어두운 쪽으로
        .onAppear {
            runtime.reduceMotion = reduceMotion
            syncScene()
            settleAndGreet()
        }
        .onChange(of: reduceMotion) { _, value in runtime.reduceMotion = value }
        .onChange(of: state) { _, _ in syncScene() }
        .onChange(of: selectedCell) { _, _ in syncScene() }
        .onChange(of: placingKind) { _, _ in syncScene() }
        .onChange(of: movingFacility) { _, _ in syncScene() }
    }

    // MARK: - 가운데: SpriteKit 사무실

    private var officeView: some View {
        GeometryReader { _ in
            SpriteView(scene: scene, preferredFramesPerSecond: 30, options: [.allowsTransparency])
                .gesture(
                    SpatialTapGesture().onEnded { value in
                        if let cell = scene.cell(atViewPoint: value.location) {
                            handleTap(cell)
                        }
                    }
                )
                // 한 손가락으로 끌어 둘러보기 (탭과 구분되도록 조금 움직여야 시작)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { value in
                            scene.pan(by: CGSize(width: value.translation.width - lastPan.width,
                                                 height: value.translation.height - lastPan.height).asPoint)
                            lastPan = value.translation
                        }
                        .onEnded { _ in lastPan = .zero }
                )
                // 두 손가락 모으기/벌리기 — 정수 배율 단계로 확대·축소
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { value in
                            let start = magnifyStartZoom ?? scene.zoomLevel
                            magnifyStartZoom = start
                            scene.setZoom(Int((Double(start) * value.magnification).rounded()), anchor: value.startLocation)
                        }
                        .onEnded { _ in magnifyStartZoom = nil }
                )
        }
        .padding(.horizontal, -12)   // 정수 배율을 지키려면 화면 폭을 다 써야 함
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("연구소 사무실. 시설 \(state.facilities.count)개, 복원한 한자 \(state.restoredKanji.count)자")
    }

    private func syncScene() {
        // 하늘 중단 색을 방 전체에 은은히 (밤 · 흐림에서 더 진하게)
        let mid = palette.skyGradient[min(1, palette.skyGradient.count - 1)]
        scene.setAmbient(red: mid.red * 0.6, green: mid.green * 0.6, blue: mid.blue * 0.7, amount: palette.isDarkSky ? 0.5 : 0.14)
        scene.apply(
            state: state,
            comboMemberIDs: instituteEngine.comboMemberIDs,
            selectedCell: selectedCell,
            isPlacing: placingKind != nil || movingFacility != nil
        )
    }

    // MARK: - 위쪽 가장자리: 게임 달력 · 자금 · 자원 칩

    private var topEdge: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                calendarPlate
                Spacer(minLength: 4)
                fundsPlate
            }
            HStack(spacing: 6) {
                resourceChip(.researchPoints, "研究P", "\(state.researchPoints)")
                resourceChip(.influence, "影響力", "\(state.influence)")
                resourceChip(.restored, "복원", "\(state.restoredKanji.count)")
                Spacer(minLength: 0)
                Image(systemName: state.instituteSky.sfSymbolName(for: weatherEngine.activeTimeOfDay))
                    .symbolRenderingMode(.multicolor)
                    .font(.subheadline)
                    .frame(width: 34, height: 34)
                    .pixelFrame(.chip)
                    .accessibilityLabel("연구소 하늘 \(state.instituteSky.koreanTitle)")
            }
        }
    }

    private var calendarPlate: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(Self.inWorldDate(Date()))
                .font(.subheadline.weight(.heavy).monospacedDigit())
            Text("NJL \(state.stage)단계 · 사무실")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PixelUI.textDim)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .pixelFrame(.panel)
        .accessibilityElement(children: .combine)
    }

    private var fundsPlate: some View {
        VStack(alignment: .trailing, spacing: 1) {
            HStack(spacing: 3) {
                PixelIcon(name: .budget)
                Text("予算")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PixelUI.textDim)
            }
            Text("¥\(state.budget)")
                .font(.title3.weight(.heavy).monospacedDigit())
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .pixelFrame(.panel)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.budget)
        .accessibilityLabel("예산 \(state.budget)")
    }

    private func resourceChip(_ icon: PixelIcon.Name, _ title: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            PixelIcon(name: icon)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PixelUI.textDim)
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .pixelFrame(.chip)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
        .accessibilityElement(children: .combine)
    }

    /// 게임 속 달력: 연도는 '2XXX', 월·일·요일은 실제 날짜 (하루 학습 = 연구소의 하루)
    static func inWorldDate(_ date: Date, calendar: Calendar = .current) -> String {
        let weekdays = ["日", "月", "火", "水", "木", "金", "土"]
        let parts = calendar.dateComponents([.month, .day, .weekday], from: date)
        return "2XXX年 \(parts.month ?? 1)月 \(parts.day ?? 1)日 (\(weekdays[((parts.weekday ?? 1) - 1) % 7]))"
    }

    // MARK: - 원내 방송 띠

    private var broadcastLines: [String] {
        InstituteBroadcast.lines(
            state: state,
            settlement: lastSettlement,
            restorableCount: restorable.count,
            activeCombos: instituteEngine.activeCombos,
            realWeather: weatherEngine.weatherSummaryLine
        )
    }

    private var broadcastStrip: some View {
        TimelineView(.periodic(from: .now, by: 5)) { timeline in
            let lines = broadcastLines
            let index = Int(timeline.date.timeIntervalSinceReferenceDate / 5) % max(1, lines.count)
            HStack(spacing: 8) {
                Text("📢 \(InstituteBroadcast.speakerTitle)")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(PixelUI.text)
                    .fixedSize()
                Text(lines.isEmpty ? "" : lines[index])
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(index)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .move(edge: .top).combined(with: .opacity)))
            }
            .animation(.easeInOut(duration: 0.35), value: index)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .clipped()
            .pixelFrame(.chip)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - 장면 위 상황 안내 (배치 모드 · 선택한 시설) + 서랍

    @ViewBuilder
    private var contextOverlay: some View {
        VStack(spacing: 8) {
            if let kind = placingKind {
                HStack(spacing: 8) {
                    PixelIcon(name: Self.icon(for: kind))
                    Text("\(kind.title) — 놓을 바닥을 누르세요")
                        .font(.caption.weight(.bold))
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { placingKind = nil }
                    } label: {
                        Image(systemName: "xmark").font(.caption.weight(.bold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("배치 취소")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .pixelFrame(.active)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let moving = movingFacility {
                HStack(spacing: 8) {
                    PixelIcon(name: Self.icon(for: moving.kind))
                    Text("\(moving.kind.title) — 옮길 바닥을 누르세요")
                        .font(.caption.weight(.bold))
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { movingFacility = nil }
                    } label: {
                        Image(systemName: "xmark").font(.caption.weight(.bold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("이동 취소")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .pixelFrame(.active)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let cell = selectedCell, let facility = instituteEngine.facility(at: cell) {
                selectedFacilityChip(facility)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let command = openCommand, placingKind == nil, movingFacility == nil {
                drawer(command)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if isMenuOpen, placingKind == nil, movingFacility == nil {
                menuPanel
                    .transition(.scale(scale: 0.92, anchor: .bottomTrailing).combined(with: .opacity))
            }
        }
        .padding(.bottom, 4)
    }

    private func selectedFacilityChip(_ facility: PlacedFacility) -> some View {
        HStack(spacing: 8) {
            PixelIcon(name: Self.icon(for: facility.kind), size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(facility.kind.title).font(.caption.weight(.bold))
                Text(facility.kind.summary).font(.caption2).foregroundStyle(PixelUI.textDim).lineLimit(1)
            }
            if !(facility.kind == .researcherDesk && OfficePixelArt.roomIncludesResearcherDesk) {   // v1 방 그림의 큰 책상만 고정
                Button("이동") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        movingFacility = facility
                        selectedCell = nil
                    }
                }
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .pixelFrame(.button)
                .buttonStyle(.plain)
            }
            if facility.kind.isRemovable {
                Button("치우기") {
                    if instituteEngine.remove(at: facility.position) {
                        say(InstituteGuideScript.removed(facility.kind))
                        selectedCell = nil
                    }
                }
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .pixelFrame(.button)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .pixelFrame(.chip)
    }

    private func drawer(_ command: Command) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch command {
            case .build: buildDrawer
            case .restore: restoreDrawer
            case .status: statusDrawer
            case .interior: interiorDrawer
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelFrame(.panel)
    }

    private func drawerHeader(_ title: String, icon: PixelIcon.Name, trailing: String) -> some View {
        HStack {
            Label { Text(title) } icon: { PixelIcon(name: icon) }
                .font(.caption.weight(.heavy))
                .foregroundStyle(PixelUI.text)
            Spacer()
            Text(trailing)
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(PixelUI.textDim)
        }
    }

    private var buildDrawer: some View {
        VStack(alignment: .leading, spacing: 8) {
            drawerHeader("시설 건설", icon: .build, trailing: "예산 ¥\(state.budget)")
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
        let affordable = state.budget >= kind.budgetCost
        let owned = state.facilities.filter { $0.kind == kind }.count
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                placingKind = kind
                selectedCell = nil
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    PixelIcon(name: Self.icon(for: kind), size: 24)
                    Spacer()
                    Text("×\(owned)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(PixelUI.textDim)
                }
                Text(kind.title).font(.caption.weight(.bold)).lineLimit(1)
                Text(kind.summary).font(.system(size: 10)).foregroundStyle(PixelUI.textDim).lineLimit(2)
                Text("¥\(kind.budgetCost)")
                    .font(.caption2.weight(.heavy).monospacedDigit())
                    .foregroundStyle(affordable ? PixelUI.text : PixelUI.warning)
            }
            .padding(10)
            .frame(width: 124, alignment: .leading)
            .pixelFrame(.button)
            .opacity(affordable ? 1 : 0.7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.title), 예산 \(kind.budgetCost), 보유 \(owned)개. \(kind.summary)")
    }

    private var restoreDrawer: some View {
        VStack(alignment: .leading, spacing: 8) {
            drawerHeader(
                "한자 복원", icon: .restore,
                trailing: "비용 研究P \(instituteEngine.restoreCost)"
                    + (instituteEngine.restoreDiscountPercent > 0 ? " (-\(instituteEngine.restoreDiscountPercent)%)" : "")
            )
            if restorable.isEmpty {
                Text(InstituteGuideScript.nothingToRestore)
                    .font(.caption)
                    .foregroundStyle(PixelUI.textDim)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(restorable, id: \.self) { restoreChip($0) }
                    }
                }
            }
        }
    }

    private func restoreChip(_ kanji: String) -> some View {
        let hunEum = sessionEngine.catalog.kanjiInfo(for: kanji)?.koreanHunEum
        return Button {
            let cost = instituteEngine.restoreCost
            // 결과(研究P 차감 · 복원 등록)는 엔진이 즉시 저장하고, 장면은 진행 연출만 재생
            let insight = RestorationInsight(kanji: kanji, catalog: sessionEngine.catalog, snapshots: snapshots)
            if instituteEngine.restore(kanji: kanji, catalog: sessionEngine.catalog, snapshots: snapshots) {
                runtime.startRestoration(insight, time: now)
                say(InstituteGuideScript.restored(kanji, hunEum: hunEum))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { openCommand = nil }
            } else {
                say(InstituteGuideScript.notEnoughPoints(cost: cost))
            }
        } label: {
            VStack(spacing: 2) {
                Text(kanji).jlptTermFont(size: 28)
                Text(hunEum ?? "").font(.caption2).foregroundStyle(PixelUI.textDim).lineLimit(1)
            }
            .frame(width: 64, height: 66)
            .pixelFrame(.button)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kanji) \(hunEum ?? "") 복원")
    }

    /// 인테리어: 샘플을 누르면 바닥 · 외벽 전체가 그 테마로 바뀜 (무료). 창문은 오른쪽 벽 가운데에 자동
    private var interiorDrawer: some View {
        VStack(alignment: .leading, spacing: 8) {
            drawerHeader("인테리어", icon: .interior, trailing: "무료 · 고르면 전체 적용")
            interiorRow("바닥") {
                ForEach(FloorTheme.allCases) { theme in
                    interiorSample(theme.title, selected: state.floorTheme == theme,
                                   image: OfficePixelArt.bundledImage(OfficePixelArt.floorAssetName(theme)), scale: 0.5) {
                        instituteEngine.setFloorTheme(theme)
                        say(InstituteGuideScript.interiorChanged(theme.title))
                    }
                }
            }
            interiorRow("외벽") {
                ForEach(WallTheme.allCases) { theme in
                    interiorSample(theme.title, selected: state.wallTheme == theme,
                                   image: OfficePixelArt.wallSwatch(theme), scale: 1) {
                        instituteEngine.setWallTheme(theme)
                        say(InstituteGuideScript.interiorChanged(theme.title))
                    }
                }
            }
        }
    }

    private func interiorRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(PixelUI.textDim)
                .frame(width: 30, alignment: .leading)
                .padding(.top, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { content() }
            }
        }
    }

    /// scale: 이미지 픽셀 → 포인트 배율의 역수 (0.5면 1px = 2pt). 정수 배율로만 확대
    private func interiorSample(_ title: String, selected: Bool, image: CGImage?, scale: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Group {
                    if let image {
                        Image(decorative: image, scale: scale).interpolation(.none)
                    } else {
                        Color.gray.frame(width: 48, height: 40)
                    }
                }
                .frame(width: 64, height: 48)
                .clipped()
                .overlay(Rectangle().stroke(selected ? PixelUI.accent : Color.black.opacity(0.5), lineWidth: selected ? 2 : 1))
                Text(title)
                    .font(.caption2.weight(selected ? .heavy : .semibold))
                    .foregroundStyle(selected ? PixelUI.text : PixelUI.textDim)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var statusDrawer: some View {
        let combos = instituteEngine.activeCombos
        return VStack(alignment: .leading, spacing: 8) {
            drawerHeader("연구소 현황", icon: .status,
                         trailing: "研究P +\(instituteEngine.researchBonusPercent)% · 복원 -\(instituteEngine.restoreDiscountPercent)%")
            HStack(spacing: 8) {
                statusTile("상주 인원", "2명")   // 주임 연구원 + 신입(플레이어)
                statusTile("시설", "\(state.facilities.count)개")
                statusTile("복원", "\(state.restoredKanji.count)/2136")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FacilityCombo.allCases) { combo in
                        let active = combos.contains(combo)
                        VStack(alignment: .leading, spacing: 2) {
                            Label { Text(combo.title) } icon: { PixelIcon(name: active ? .combo : .locked).opacity(active ? 1 : 0.75) }
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(active ? PixelUI.accent : PixelUI.textDim)
                                .lineLimit(1)
                            Text(combo.summary)
                                .font(.system(size: 10))
                                .foregroundStyle(PixelUI.textDim)
                                .lineLimit(2)
                        }
                        .padding(8)
                        .frame(width: 172, alignment: .leading)
                        .pixelFrame(active ? .active : .chip)
                    }
                }
            }
        }
    }

    private func statusTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(PixelUI.textDim)
            Text(value).font(.subheadline.weight(.heavy).monospacedDigit())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelFrame(.chip)
    }

    // MARK: - 아래 가장자리: 비서 팝업 (주임 연구원)

    private var secretaryPopup: some View {
        Button(action: advanceIntro) {
            HStack(alignment: .top, spacing: 10) {
                GuidePortrait()
                    .frame(width: 44, height: 44)
                    .pixelFrame(.panel)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(InstituteGuideScript.speakerTitle)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(PixelUI.text)
                        Text("？？？")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PixelUI.textDim)
                        Spacer()
                        if let introIndex {
                            Text("\(introIndex + 1)/\(InstituteGuideScript.intro.count) ▸")
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .foregroundStyle(PixelUI.accent)
                        }
                    }
                    Text(guideLine)
                        .font(.caption)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(guideLine)
                        .transition(.opacity)
                }
            }
            .padding(10)
            .pixelFrame(.panel)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(introIndex != nil)   // disabled는 글씨를 흐리게 해서 쓰지 않음
        .accessibilityLabel("주임 연구원: \(guideLine)")
    }

    // MARK: - 아래 가장자리: 메뉴 버튼 (여닫음) + 메뉴판

    /// 메뉴판이나 서랍이 열려 있으면 '닫기', 아니면 '메뉴'
    private var isMenuEngaged: Bool { isMenuOpen || openCommand != nil }

    private var menuButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                if isMenuEngaged {
                    isMenuOpen = false
                    openCommand = nil
                } else {
                    isMenuOpen = true
                }
                placingKind = nil
                movingFacility = nil
                selectedCell = nil
            }
        } label: {
            VStack(spacing: 3) {
                PixelIcon(name: .menu, size: 24)
                    .offset(y: isMenuEngaged ? -1 : 0)   // 열려 있으면 1px 들려 보이게
                Text(isMenuEngaged ? "닫기" : "메뉴")
                    .font(.caption2.weight(.heavy))
            }
            .frame(width: 58, height: 64)
            .foregroundStyle(isMenuEngaged ? PixelUI.text : PixelUI.textDim)
            .pixelFrame(isMenuEngaged ? .active : .button)
            .overlay(alignment: .topTrailing) {
                if !isMenuEngaged, !restorable.isEmpty { countBadge(restorable.count) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMenuEngaged ? "메뉴 닫기" : "메뉴 열기")
    }

    /// 메뉴판: 항목 아이콘 격자 (지금은 건설 · 복원 · 현황, 항목이 늘면 4열로 줄바꿈)
    private var menuPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label { Text("메뉴") } icon: { PixelIcon(name: .menu) }
                .font(.caption.weight(.heavy))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Command.allCases.filter { $0 != .interior || !OfficePixelArt.usesStageRoom }) { command in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            isMenuOpen = false
                            openCommand = command
                        }
                    } label: {
                        VStack(spacing: 4) {
                            PixelIcon(name: command.icon, size: 24)
                            Text(command.rawValue)
                                .font(.caption2.weight(.heavy))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .pixelFrame(.button)
                        .overlay(alignment: .topTrailing) {
                            if command == .restore, !restorable.isEmpty { countBadge(restorable.count) }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(command.rawValue)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelFrame(.panel)
    }

    private func countBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .heavy).monospacedDigit())
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.red.opacity(0.85)))
            .foregroundStyle(.white)
            .offset(x: -4, y: 4)
    }

    // MARK: - 동작

    private func handleTap(_ cell: GridPosition) {
        // 복원 연출 중에 사무실을 탭하면 연출만 건너뜀 (결과는 이미 저장됨)
        if runtime.isShowingRestoration {
            runtime.skipRestoration(time: now)
            return
        }
        if let moving = movingFacility {
            let combosBefore = Set(instituteEngine.activeCombos)
            if instituteEngine.move(from: moving.position, to: cell) {
                let newCombos = instituteEngine.activeCombos.filter { !combosBefore.contains($0) }
                if let moved = instituteEngine.facility(at: cell) {
                    runtime.facilityPlaced(moved, newCombos: newCombos, all: instituteEngine.state.facilities, time: now)
                }
                say(newCombos.isEmpty ? InstituteGuideScript.moved(moving.kind) : InstituteGuideScript.placed(moving.kind, newCombos: newCombos))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    movingFacility = nil
                    selectedCell = nil
                }
            } else if cell != moving.position {
                say(InstituteGuideScript.cellOccupied)
            }
            return
        }
        if let kind = placingKind {
            let combosBefore = Set(instituteEngine.activeCombos)
            if instituteEngine.facility(at: cell) != nil || InstituteState.fixedCells.contains(cell) {
                say(InstituteGuideScript.cellOccupied)
                selectedCell = cell
            } else if instituteEngine.place(kind, at: cell) {
                let newCombos = instituteEngine.activeCombos.filter { !combosBefore.contains($0) }
                if let placed = instituteEngine.facility(at: cell) {
                    runtime.facilityPlaced(placed, newCombos: newCombos, all: instituteEngine.state.facilities, time: now)
                }
                say(InstituteGuideScript.placed(kind, newCombos: newCombos))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    placingKind = nil
                    selectedCell = nil
                }
            } else {
                say(InstituteGuideScript.notEnoughBudget(kind))
            }
        } else {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                selectedCell = selectedCell == cell ? nil : cell
                openCommand = nil
                isMenuOpen = false
            }
        }
    }

    private func settleAndGreet() {
        let result = instituteEngine.settle(logs: sessionEngine.store.allReviewLogs())
        lastSettlement = result
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
                guideLine = "아래 [건설]에서 시설을 고르고, [복원]으로 외운 한자를 되살려 보세요!"
            }
        }
    }

    private func say(_ line: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            introIndex = nil
            guideLine = line
        }
    }

    private static func icon(for kind: FacilityKind) -> PixelIcon.Name {
        .facility(kind)
    }
}

// MARK: - 주임 연구원 픽셀 초상화 (장면 스프라이트와 같은 픽셀 데이터, 최근접 확대)
private struct GuidePortrait: View {
    private static let image = OfficePixelArt.guidePortrait()

    var body: some View {
        if let image = Self.image {
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .padding(6)
        }
    }
}

#Preview("연구소 (1단계 사무실)") {
    InstituteView(
        sessionEngine: StudySessionEngine(store: InMemoryMemoryStore()),
        instituteEngine: InstituteEngine(store: InMemoryInstituteStore(state: InstituteState(budget: 600)))
    )
}


private extension CGSize {
    var asPoint: CGPoint { CGPoint(x: width, y: height) }
}
