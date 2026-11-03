import SwiftUI

// MARK: - 레트로 단말 UI (ART_BIBLE §6~8) — Liquid Glass를 대체하는 공통 부품
// 그림은 Resources/Art/UI/rt_*.png (1px = 1pt, 가로 스트립 = 8프레임 · 150ms). 목록 · cap은 RetroCatalog(자동 생성).
// - RetroMonitor: 둥근 레트로 모니터 몸체 + 녹색 CRT 화면. 내용은 화면 안쪽 여백에 맞춰 들어감
// - RetroKeyStyle: 입체 키캡 버튼 (크림 · 호박 · 숯색), 누르면 4pt 내려감
// - .phosphor(): 형광 녹색 글자 + 번짐 · RetroBackground: 어두운 벽돌 + 가장자리 전선 + 담쟁이 + 날씨 창

enum RetroColor {
    static let ink = Color(red: 0.14, green: 0.09, blue: 0.13)
    static let wall = Color(red: 0.078, green: 0.051, blue: 0.067)
    static let phosphorDim = Color(red: 0.30, green: 0.75, blue: 0.40)
    static let phosphor = Color(red: 0.54, green: 0.94, blue: 0.54)
    static let phosphorBright = Color(red: 0.83, green: 1.0, blue: 0.78)
    static let amber = Color(red: 1.0, green: 0.82, blue: 0.38)
    static let alert = Color(red: 0.95, green: 0.48, blue: 0.41)
    static let cream = Color(red: 0.92, green: 0.87, blue: 0.68)
    static let creamInk = Color(red: 0.37, green: 0.33, blue: 0.27)
    static let paperInk = Color(red: 0.16, green: 0.11, blue: 0.12)
    static let amberInk = Color(red: 0.35, green: 0.16, blue: 0.08)
    static let paperInkDim = Color(red: 0.40, green: 0.33, blue: 0.31)
    /// 종이 위 붉은 펜 (정답 강조 · 한자 밑줄)
    static let paperRed = Color(red: 0.62, green: 0.20, blue: 0.16)
}

// MARK: 그림 불러오기 (프레임 자르기 · 캐시)

enum RetroArt {
    private static var cache: [String: [CGImage]] = [:]
    private static let lock = NSLock()

    static func frames(_ name: String) -> [CGImage] {
        lock.lock(); defer { lock.unlock() }
        if let hit = cache[name] { return hit }
        guard let strip = OfficePixelArt.bundledImage(name) else { cache[name] = []; return [] }
        let width = RetroCatalog.entries[name]?.frameWidth ?? strip.width
        let result = OfficePixelArt.frames(of: strip, frameWidth: width)
        cache[name] = result
        return result
    }

    static func image(_ name: String, frame: Int = 0) -> CGImage? {
        let all = frames(name)
        return all.isEmpty ? nil : all[frame % all.count]
    }

    static func caps(_ name: String) -> EdgeInsets {
        guard let c = RetroCatalog.entries[name]?.cap else { return EdgeInsets() }
        return EdgeInsets(top: c.top, leading: c.left, bottom: c.bottom, trailing: c.right)
    }

    static func screen(_ name: String) -> EdgeInsets {
        guard let s = RetroCatalog.entries[name]?.screen else { return EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12) }
        // 유리 가장자리 명암 띠(5px) 안쪽부터 내용
        return EdgeInsets(top: s.top + 6, leading: s.left + 6, bottom: s.bottom + 6, trailing: s.right + 6)
    }
}

/// 8프레임 · 150ms 공용 시계 — 프레임 수를 넘겨 받는 그림 뷰
struct RetroTicker<Content: View>: View {
    var animated = true
    @ViewBuilder let content: (Int) -> Content

    var body: some View {
        if animated {
            TimelineView(.periodic(from: .now, by: OfficePixelArt.animationFrameDuration)) { context in
                content(Int(context.date.timeIntervalSinceReferenceDate / OfficePixelArt.animationFrameDuration) % 8)
            }
        } else {
            content(0)
        }
    }
}

/// 1px = 1pt 그림 한 장 (최근접 확대)
struct RetroSprite: View {
    let name: String
    var animated = true
    var scale: CGFloat = 1

    var body: some View {
        let count = RetroArt.frames(name).count
        RetroTicker(animated: animated && count > 1) { frame in
            if let image = RetroArt.image(name, frame: frame) {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
            }
        }
    }
}

/// 9-slice로 늘린 그림 (가운데 · 가장자리는 타일 반복 — 무늬가 늘어나 흐려지지 않게)
struct RetroNineSlice: View {
    let name: String
    var animated = true

    var body: some View {
        let count = RetroArt.frames(name).count
        RetroTicker(animated: animated && count > 1) { frame in
            if let image = RetroArt.image(name, frame: frame) {
                Image(decorative: image, scale: 1)
                    .resizable(capInsets: RetroArt.caps(name), resizingMode: .tile)
                    .interpolation(.none)
            }
        }
    }
}

// MARK: 모니터 판

enum RetroMonitorStyle: String, CaseIterable {
    case crt = "rt_monitor_crt"
    case crtTurned = "rt_monitor_crt_turned"
    case industrial = "rt_monitor_industrial"
    case industrialTurned = "rt_monitor_industrial_turned"
    case term = "rt_monitor_term"
    case termLeft = "rt_monitor_term_turned_left"
    case termRight = "rt_monitor_term_turned_right"
}

struct RetroMonitor<Content: View>: View {
    var style: RetroMonitorStyle = .crt
    /// 화면이 주변을 비추는 녹색 번짐 세기 (0 = 없음)
    var glow: Double = 0.22
    @ViewBuilder let content: () -> Content

    var body: some View {
        let inset = RetroArt.screen(style.rawValue)
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(inset)
            .background {
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(RetroColor.phosphor.opacity(glow))
                        .padding(inset)
                        .blur(radius: 16)
                    RetroNineSlice(name: style.rawValue)
                    RetroSprite(name: "rt_glass_glare", animated: false)
                        .padding(.top, inset.top - 5)
                        .padding(.leading, inset.leading - 5)
                }
            }
            .overlay {
                RetroScanSweep()                                             // 화면 위를 지나가는 밝은 주사선 띠
                    .padding(EdgeInsets(top: inset.top - 4, leading: inset.leading - 4, bottom: inset.bottom - 4, trailing: inset.trailing - 4))
                    .allowsHitTesting(false)
            }
            .compositingGroup()   // 판 전체를 한 덩어리로 — 안쪽 글자마다 그림자가 생기지 않게
            .shadow(color: .black.opacity(0.7), radius: 3, x: 3, y: 6)
    }
}

/// 코드만 흐르는 장식 모니터 (통째로 구운 8프레임 그림)
struct RetroCodeMonitor: View {
    enum Kind: String { case termA = "rt_code_term_a", termB = "rt_code_term_b", wide = "rt_code_crt_wide", industrial = "rt_code_industrial" }
    let kind: Kind

    var body: some View {
        RetroSprite(name: kind.rawValue)
            .compositingGroup()   // 판 전체를 한 덩어리로 — 안쪽 글자마다 그림자가 생기지 않게
            .shadow(color: .black.opacity(0.7), radius: 3, x: 3, y: 6)
            .accessibilityHidden(true)
    }
}

// MARK: 형광 글자

extension View {
    /// CRT 형광 글자: 색 + 번짐
    func phosphor(_ color: Color = RetroColor.phosphor, glow: CGFloat = 3) -> some View {
        foregroundStyle(color)
            .shadow(color: color.opacity(0.65), radius: glow)
    }
}

/// 블록 커서 (4프레임 켜짐 · 4프레임 꺼짐)
struct RetroCursor: View {
    var height: CGFloat = 20

    var body: some View {
        RetroTicker { frame in
            Rectangle()
                .fill(RetroColor.phosphor)
                .frame(width: height * 0.45, height: height)
                .shadow(color: RetroColor.phosphor.opacity(0.7), radius: 3)
                .opacity(frame < 4 ? 1 : 0)
        }
        .accessibilityHidden(true)
    }
}

// MARK: 키캡 버튼 · 토글

enum RetroKeyTone: String {
    case cream, amber, charcoal

    var textColor: Color {
        switch self {
        case .cream: return RetroColor.creamInk
        case .amber: return RetroColor.amberInk
        case .charcoal: return RetroColor.cream
        }
    }
}

struct RetroKeyStyle: ButtonStyle {
    var tone: RetroKeyTone = .cream
    /// 고른 상태로 눌려 있는 키 (탭바 · 세그먼트)
    var latched = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed || latched
        let name = !isEnabled && tone == .cream ? "rt_key_cream_disabled" : "rt_key_\(tone.rawValue)_\(down ? "pressed" : "normal")"
        configuration.label
            .font(.body.weight(.bold))
            .foregroundStyle(tone.textColor.opacity(isEnabled ? 1 : 0.5))
            .padding(.horizontal, 14)
            .padding(.top, 8 + (down ? 4 : 0))
            .padding(.bottom, 14 - (down ? 4 : 0))
            .frame(minHeight: 44)
            .background(RetroNineSlice(name: name, animated: false))
            .contentShape(Rectangle())
    }
}

struct RetroToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
            Spacer(minLength: 8)
            Button {
                withAnimation(.easeOut(duration: 0.12)) { configuration.isOn.toggle() }
            } label: {
                RetroSprite(name: configuration.isOn ? "rt_toggle_on" : "rt_toggle_off")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(configuration.isOn ? "켜짐" : "꺼짐")
        }
    }
}

/// 명판 칩 (크림 · 금속 · 호박)
struct RetroPlate<Content: View>: View {
    enum Tone: String { case cream = "rt_plate_cream", metal = "rt_plate_metal", amber = "rt_plate_amber" }
    var tone: Tone = .metal
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .foregroundStyle(tone == .amber ? RetroColor.amberInk : RetroColor.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RetroNineSlice(name: tone.rawValue, animated: false))
            .compositingGroup()
            .shadow(color: .black.opacity(0.6), radius: 2, x: 2, y: 4)
    }
}

/// 넘버 시계 (D-33 같은 글자 · 숫자 칸)
struct RetroFlipCounter: View {
    let text: String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                let key = ch == "-" ? "dash" : String(ch)
                if RetroCatalog.entries["rt_flip_\(key)"] != nil {
                    RetroSprite(name: "rt_flip_\(key)", animated: false)
                }
            }
        }
        .accessibilityLabel(text)
    }
}

// MARK: 배경 — 벽돌 벽 + 날씨 창 + 가장자리 전선 + 담쟁이

struct RetroBackground<Sky: View>: View {
    /// 위쪽 창 높이 (0이면 창 없음)
    var windowHeight: CGFloat = 150
    @ViewBuilder let sky: () -> Sky

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                RetroColor.wall
                Canvas { ctx, size in                                       // 아주 어두운 벽돌 줄눈
                    let mortar = Color(red: 0.055, green: 0.031, blue: 0.043)
                    var row = 0
                    var y: CGFloat = 0
                    while y < size.height {
                        ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(mortar))
                        var x: CGFloat = row % 2 == 0 ? 14 : 0
                        while x < size.width {
                            ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 12)), with: .color(mortar))
                            x += 28
                        }
                        y += 12
                        row += 1
                    }
                }
                if windowHeight > 0 {
                    weatherWindow(width: geo.size.width)
                        .padding(.top, geo.safeAreaInsets.top + 4)
                }
                cables(height: geo.size.height)
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                    .allowsHitTesting(false)
                ivy
            }
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }

    /// 연구소 창: 나무 틀 안에 지금 날씨 하늘이 보임 (빗물 줄 · 유리 반사)
    private func weatherWindow(width: CGFloat) -> some View {
        let inner = RoundedRectangle(cornerRadius: 3)
        return sky()
            .frame(width: width - 40, height: windowHeight)
            .clipShape(inner)
            .overlay(alignment: .center) {
                Rectangle().fill(Color(red: 0.36, green: 0.21, blue: 0.19)).frame(width: 4)   // 창살
            }
            .overlay {
                LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .center)
                    .clipShape(inner)
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.47, green: 0.30, blue: 0.27)))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(RetroColor.ink, lineWidth: 2))
            .shadow(color: .black.opacity(0.6), radius: 4, y: 4)
    }

    private func cables(height: CGFloat) -> some View {
        HStack {
            tiledBundle(height: height).offset(x: -8)
            Spacer()
            tiledBundle(height: height).scaleEffect(x: -1).offset(x: 8, y: 30)
        }
        .allowsHitTesting(false)
    }

    private func tiledBundle(height: CGFloat) -> some View {
        Group {
            if let image = RetroArt.image("rt_cable_bundle_v") {
                Image(decorative: image, scale: 1)
                    .resizable(resizingMode: .tile)
                    .interpolation(.none)
                    .frame(width: CGFloat(image.width), height: height + 64)
            }
        }
    }

    private var ivy: some View {
        HStack(alignment: .top) {
            RetroSprite(name: "rt_ivy_curtain_200").offset(x: -30, y: -36)
            Spacer()
            RetroSprite(name: "rt_ivy_curtain_200").scaleEffect(x: -1).offset(x: 30, y: -46)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }
}

extension RetroBackground where Sky == EmptyView {
    init(windowHeight: CGFloat = 0) {
        self.windowHeight = windowHeight
        self.sky = { EmptyView() }
    }
}

extension View {
    /// 제목은 머리 모니터가 대신하므로 시스템 내비게이션 바를 숨김 (iOS만)
    @ViewBuilder
    func retroHidesNavigationBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}


// MARK: 스캐너 위 종이 (학습 카드) — 평판 스캐너 유리 + 테이프로 붙인 종이 + 지나가는 스캔 빛줄

struct RetroScannedPaper<Content: View>: View {
    /// 0 → 1로 바뀌면 빛줄이 종이 위에서 아래로 한 번 지나감 (바깥에서 애니메이션)
    var scanProgress: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        let inset = RetroArt.screen("rt_scanner")
        content()
            .background(RetroNineSlice(name: "rt_paper", animated: false))
            .overlay(alignment: .topLeading) {
                RetroSprite(name: "rt_tape", animated: false).offset(x: -6, y: -4)
            }
            .overlay(alignment: .topTrailing) {
                RetroSprite(name: "rt_tape", animated: false).scaleEffect(x: -1).offset(x: 6, y: -4)
            }
            .overlay {
                GeometryReader { geo in
                    if scanProgress > -0.05 && scanProgress < 1.05 {
                        ZStack {
                            Rectangle().fill(RetroColor.phosphor.opacity(0.25)).frame(height: 10).blur(radius: 8)
                            RetroNineSlice(name: "rt_scan_bar")
                        }
                        .frame(width: geo.size.width + 20, height: 16)
                        .position(x: geo.size.width / 2, y: geo.size.height * scanProgress)
                    }
                }
                .allowsHitTesting(false)
            }
            .padding(EdgeInsets(top: inset.top - 2, leading: inset.leading - 4, bottom: inset.bottom - 2, trailing: inset.trailing - 4))
            .background(RetroNineSlice(name: "rt_scanner", animated: false))
            .compositingGroup()
            .shadow(color: .black.opacity(0.7), radius: 4, x: 3, y: 7)
    }
}


// MARK: - 시안의 디테일 (화면 주사선 띠 · 모니터 사이 전선 · 깊이 층 · 먼지 · 시차 스크롤)

/// CRT 화면을 위에서 아래로 천천히 지나가는 밝은 띠 (4초 주기, 화면마다 시작 위치가 다름)
struct RetroScanSweep: View {
    @State private var phase = Double.random(in: 0..<4)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
            GeometryReader { geo in
                let t = (context.date.timeIntervalSinceReferenceDate + phase).truncatingRemainder(dividingBy: 4) / 4
                LinearGradient(colors: [.clear, RetroColor.phosphorBright.opacity(0.10), RetroColor.phosphorBright.opacity(0.22), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 14)
                    .offset(y: geo.size.height * t - 7)
            }
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

enum RetroCable: String {
    case loop = "rt_cable_loop_a"        // 처진 검은 전선
    case red = "rt_cable_loop_c"         // 빨간 신호선
    case dangle = "rt_cable_dangle_b"    // 삐져나온 크림 전선 + 플러그
}

extension View {
    /// 모니터 아래로 처진 전선 — 다음 모니터 밑으로 들어가 보이게 (그 뒤에 오는 뷰가 위에 그려짐)
    func retroHangingCable(_ cable: RetroCable, x: CGFloat, drop: CGFloat = 0) -> some View {
        overlay(alignment: .bottomLeading) {
            RetroSprite(name: cable.rawValue, animated: false)
                .offset(x: x, y: CGFloat(RetroCatalog.entries[cable.rawValue]?.frameHeight ?? 30) - 8 + drop)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// 스크롤 위치 (시차용) — ScrollView 내용 맨 위에 붙여 읽음
struct RetroScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// 날씨 창 · 벽 · 뒤 층(흐린 모니터 더미) · 본문 · 앞 층(흐린 전선 · 담쟁이) · 먼지 · 비네트를 겹친 스크롤 화면.
/// 뒤 층은 0.45배, 앞 층은 1.35배로 움직여 깊이가 생김 (ART_BIBLE §7 시차 스크롤)
struct RetroScrollScreen<Sky: View, Content: View>: View {
    var windowHeight: CGFloat = 120
    @ViewBuilder let sky: () -> Sky
    @ViewBuilder let content: () -> Content
    @State private var scroll: CGFloat = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            content()
                .background(alignment: .top) {
                    GeometryReader { geo in
                        Color.clear.preference(key: RetroScrollOffsetKey.self, value: -geo.frame(in: .named("retroScroll")).minY)
                    }
                    .frame(height: 0)
                }
        }
        .coordinateSpace(name: "retroScroll")
        .onPreferenceChange(RetroScrollOffsetKey.self) { scroll = max(0, $0) }
        .background {
            ZStack(alignment: .top) {
                RetroBackground(windowHeight: windowHeight, sky: sky)
                    .offset(y: -scroll * 0.2)
                RetroFarMonitors()
                    .offset(y: -scroll * 0.45)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            ZStack {
                RetroForeground(scroll: scroll)
                RetroDust()
                RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center, startRadius: 180, endRadius: 520)
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        RetroSprite(name: "rt_cable_coil", animated: false).offset(x: 10, y: -78)
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// 뒤 층: 멀리 쌓인 모니터 더미 (흐리고 어둡게) — 앞 모니터 사이 틈으로 보임
struct RetroFarMonitors: View {
    private struct Slot: Identifiable { let id: Int; let style: RetroMonitorStyle; let x, y, w, h: CGFloat }
    private static let slots: [Slot] = {
        var result: [Slot] = []
        var seed: UInt64 = 7
        func next() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 33) / CGFloat(1 << 31) }
        let styles: [RetroMonitorStyle] = [.term, .termLeft, .industrial, .termRight]
        var y: CGFloat = 250           // 날씨 창 아래부터 (창을 가리지 않게)
        var id = 0
        while y < 2400 {
            for column in 0..<4 {
                result.append(Slot(id: id, style: styles[Int(next() * 4) % 4], x: CGFloat(column) * 112 - 34 + next() * 12,
                                   y: y + next() * 12, w: 110 + next() * 40, h: 80 + next() * 22))
                id += 1
            }
            y += 96
        }
        return result
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Self.slots) { slot in
                RetroNineSlice(name: slot.style.rawValue, animated: false)
                    .frame(width: slot.w, height: slot.h)
                    .offset(x: slot.x, y: slot.y)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .blur(radius: 1.2)
        .overlay(Color(red: 0.04, green: 0.02, blue: 0.04).opacity(0.72))
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

/// 앞 층: 카메라 가까이 있는 전선 다발 · 담쟁이 (크고 흐리고 어둡게, 1.35배로 움직임)
struct RetroForeground: View {
    var scroll: CGFloat

    var body: some View {
        GeometryReader { geo in
            let shift = (scroll * 1.35).truncatingRemainder(dividingBy: 64)
            ZStack(alignment: .topLeading) {
                if let image = RetroArt.image("rt_cable_bundle_v") {
                    let tile = Image(decorative: image, scale: 1).resizable(resizingMode: .tile).interpolation(.none)
                    tile.frame(width: 32, height: geo.size.height + 128).offset(x: -14, y: -shift - 64)
                    tile.frame(width: 32, height: geo.size.height + 128).scaleEffect(x: -1).offset(x: geo.size.width - 18, y: -shift - 34)
                }
                ForEach(0..<4, id: \.self) { k in
                    let y = CGFloat(k) * 560 - (scroll * 1.35).truncatingRemainder(dividingBy: 2240)
                    RetroSprite(name: "rt_ivy_curtain_200").scaleEffect(1.1).offset(x: -176, y: y + 120)
                    RetroSprite(name: "rt_ivy_curtain_200").scaleEffect(x: -1.1, y: 1.1).offset(x: geo.size.width - 34, y: y + 380)
                }
            }
            .blur(radius: 1.4)
            .brightness(-0.22)
        }
        .ignoresSafeArea()
    }
}

/// 화면 빛 속에 떠다니는 먼지 (위로 천천히 올라가며 깜빡)
struct RetroDust: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<28 {
                    let seed = Double(i) * 12.9898
                    let x0 = (sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1)
                    let y0 = (sin(seed * 1.7) * 23421.631).truncatingRemainder(dividingBy: 1)
                    let speed = 4 + Double(i % 5) * 2
                    let x = (abs(x0) * size.width + sin(t * 0.3 + Double(i)) * 6)
                    let y = (abs(y0) * size.height - t * speed).truncatingRemainder(dividingBy: size.height)
                    let yy = y < 0 ? y + size.height : y
                    let alpha = 0.25 + 0.25 * sin(t * 0.8 + Double(i))
                    ctx.fill(Path(CGRect(x: x.rounded(), y: yy.rounded(), width: i % 4 == 0 ? 2 : 1, height: 1)),
                             with: .color(Color(red: 0.85, green: 1, blue: 0.85, opacity: Double(max(0, alpha)))))
                }
            }
        }
        .ignoresSafeArea()
    }
}
