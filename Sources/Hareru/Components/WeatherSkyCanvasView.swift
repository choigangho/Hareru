import SwiftUI

// MARK: - Apple 날씨 앱 스타일 하늘 & 기상 파티클 렌더러
// 한 장의 Canvas에 뒤에서 앞으로 층을 쌓아 그립니다.
//  1. 천구: 깊이가 다른 별 · 은하수 · 실제 월령을 따르는 달 · 오로라 커튼 · 유성
//  2. 빛: 시간대별 태양 위치와 빛 색(새벽 복숭아빛 → 한낮 흰빛 → 노을 주황), 지평선 산란광, 빛내림
//  3. 구름: 원경 · 중경 · 근경 3겹 시차. 구름마다 여러 덩어리를 겹쳐 그늘 → 해 쪽 밝은 면 순으로 칠해 볼륨을 냄
//  4. 무지개 · 번개(갈래 번개 + 구름 속 섬광)
//  5. 대기: 층운 막 · 안개 띠 · 황사 연무 · 열기 아지랑이
//  6. 강수 · 낙하물: 비 · 이슬비 · 진눈깨비 · 우박(튀어 오름) · 눈(결정 + 보케) · 벚꽃잎 · 낙엽 · 바람 줄기
//  7. 유리창: 맺힌 빗방울(뒤집힌 하늘이 비치는 굴절 렌즈)과 멈칫거리며 흘러내리는 물줄기
// '동작 줄이기'가 켜지면 시간 흐름을 크게 늦추고 번개 섬광을 끕니다.
public struct WeatherSkyCanvasView: View {
    public let condition: WeatherCondition
    public let timeOfDay: SkyTimeOfDay
    public let palette: WeatherSkyPalette
    public var failureCount: Int = 0
    public var isHareruCleared: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        condition: WeatherCondition,
        timeOfDay: SkyTimeOfDay,
        palette: WeatherSkyPalette,
        failureCount: Int = 0,
        isHareruCleared: Bool = false
    ) {
        self.condition = condition
        self.timeOfDay = timeOfDay
        self.palette = palette
        self.failureCount = failureCount
        self.isHareruCleared = isHareruCleared
    }

    public var body: some View {
        let recipe = WeatherSceneRecipe.make(
            condition: isHareruCleared ? .clear : condition,
            timeOfDay: timeOfDay,
            isHareruCleared: isHareruCleared
        )
        ZStack {
            LinearGradient(
                colors: palette.skyColors(withFailureCount: failureCount),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 12.0 : recipe.frameInterval)) { timeline in
                let date = timeline.date
                Canvas { context, size in
                    let renderer = WeatherSkyRenderer(
                        recipe: recipe,
                        timeOfDay: timeOfDay,
                        palette: palette,
                        size: size,
                        time: date.timeIntervalSinceReferenceDate * (reduceMotion ? 0.15 : 1.0),
                        date: date,
                        reduceMotion: reduceMotion
                    )
                    renderer.draw(in: context)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 날씨 장면 레시피 (기상 상태 → 그릴 층과 세기)
struct WeatherSceneRecipe {
    enum Precipitation { case none, drizzle, rain, sleet, hail, snow }
    enum Falling { case none, blossom, leaves }

    var cloudCover = 0.0          // 0 ~ 1
    var cloudShade = 0.0          // 0 하얀 뭉게구름 ~ 1 짙은 비구름
    var cloudSpeed = 1.0
    var overcastDeck = 0.0        // 하늘 위쪽을 덮는 층운 막
    var precipitation = Precipitation.none
    var intensity = 0.0
    var wind = 0.1                // 사선 기울기 (dx / dy)
    var fog = 0.0
    var lightning = 0.0           // 0 없음 ~ 1 잦음
    var starVisibility = 0.0
    var lightVisibility = 1.0     // 해 · 달 원반과 빛무리가 보이는 정도
    var sunBeams = 0.0
    var dust = 0.0
    var heatShimmer = false
    var windStreaks = 0.0
    var aurora = false
    var meteors = false
    var rainbow = false
    var falling = Falling.none
    var glassDrops = 0.0

    /// 비 · 눈 · 번개처럼 빠른 장면만 60fps, 나머지는 30fps로 배터리 절약
    var frameInterval: Double {
        precipitation != .none || lightning > 0 || windStreaks > 0 || falling != .none
            ? 1.0 / 60.0
            : 1.0 / 30.0
    }

    static func make(condition: WeatherCondition, timeOfDay: SkyTimeOfDay, isHareruCleared: Bool) -> WeatherSceneRecipe {
        var r = WeatherSceneRecipe()
        let isNight = timeOfDay == .night
        switch condition {
        case .clear:
            r.cloudCover = 0.08; r.starVisibility = 1; r.sunBeams = 0.35
        case .partlyCloudy:
            r.cloudCover = 0.4; r.starVisibility = 0.75; r.sunBeams = 0.5; r.lightVisibility = 0.85
        case .cloudy:
            r.cloudCover = 0.72; r.cloudShade = 0.25; r.starVisibility = 0.25; r.lightVisibility = 0.45; r.sunBeams = 0.2
        case .overcast:
            r.cloudCover = 0.95; r.cloudShade = 0.45; r.overcastDeck = 0.7; r.lightVisibility = 0.12
        case .drizzle:
            r.cloudCover = 0.8; r.cloudShade = 0.4; r.overcastDeck = 0.5
            r.precipitation = .drizzle; r.intensity = 0.55; r.wind = 0.06
            r.glassDrops = 0.45; r.fog = 0.12; r.lightVisibility = 0.1
        case .rain:
            r.cloudCover = 0.9; r.cloudShade = 0.6; r.overcastDeck = 0.6
            r.precipitation = .rain; r.intensity = 0.72; r.wind = 0.14
            r.glassDrops = 0.8; r.fog = 0.1; r.lightVisibility = 0
        case .thunderstorm:
            r.cloudCover = 1; r.cloudShade = 0.9; r.overcastDeck = 0.85; r.cloudSpeed = 1.6
            r.precipitation = .rain; r.intensity = 0.9; r.wind = 0.22
            r.lightning = 1; r.glassDrops = 0.85; r.lightVisibility = 0
        case .typhoon:
            r.cloudCover = 1; r.cloudShade = 0.85; r.overcastDeck = 0.8; r.cloudSpeed = 4
            r.precipitation = .rain; r.intensity = 1; r.wind = 0.55
            r.lightning = 0.45; r.glassDrops = 1; r.fog = 0.15; r.windStreaks = 0.5; r.lightVisibility = 0
        case .sleet:
            r.cloudCover = 0.9; r.cloudShade = 0.45; r.overcastDeck = 0.6
            r.precipitation = .sleet; r.intensity = 0.7; r.wind = 0.18; r.glassDrops = 0.55; r.lightVisibility = 0.05
        case .hail:
            r.cloudCover = 0.95; r.cloudShade = 0.8; r.overcastDeck = 0.7
            r.precipitation = .hail; r.intensity = 0.8; r.wind = 0.1
            r.lightning = 0.25; r.glassDrops = 0.3; r.lightVisibility = 0
        case .snow:
            r.cloudCover = 0.75; r.cloudShade = 0.2; r.overcastDeck = 0.45
            r.precipitation = .snow; r.intensity = 0.7; r.wind = 0.08
            r.starVisibility = 0.12; r.lightVisibility = 0.15
        case .blizzard:
            r.cloudCover = 0.95; r.cloudShade = 0.3; r.overcastDeck = 0.7; r.cloudSpeed = 3
            r.precipitation = .snow; r.intensity = 1; r.wind = 0.9
            r.fog = 0.45; r.windStreaks = 0.6; r.lightVisibility = 0.05
        case .mist:
            r.cloudCover = 0.3; r.fog = 0.4; r.lightVisibility = 0.55; r.starVisibility = 0.35; r.sunBeams = 0.25
        case .fog:
            r.cloudCover = 0.2; r.fog = 0.85; r.lightVisibility = 0.2
        case .yellowDust:
            r.cloudCover = 0.15; r.dust = 0.75; r.lightVisibility = 0.5; r.starVisibility = 0.15; r.wind = 0.3
        case .heatwave:
            r.cloudCover = 0.04; r.heatShimmer = true; r.sunBeams = 0.6; r.lightVisibility = 1.25; r.starVisibility = 0.6
        case .windy:
            r.cloudCover = 0.5; r.cloudSpeed = 4.5; r.windStreaks = 1; r.starVisibility = 0.8; r.wind = 0.8
            r.falling = .leaves; r.intensity = 0.25
        case .rainbow:
            r.cloudCover = 0.45; r.cloudShade = 0.25; r.rainbow = !isNight; r.sunBeams = 0.5
            r.glassDrops = 0.25; r.starVisibility = 0.6
        case .aurora:
            r.cloudCover = 0.05; r.starVisibility = 1; r.aurora = isNight; r.sunBeams = 0.35
        case .meteorShower:
            r.cloudCover = 0.03; r.starVisibility = 1.15; r.meteors = isNight; r.sunBeams = 0.35
        case .cherryBlossom:
            r.cloudCover = 0.2; r.falling = .blossom; r.intensity = 0.7; r.wind = 0.3; r.sunBeams = 0.4; r.starVisibility = 0.8
        case .autumnLeaves:
            r.cloudCover = 0.25; r.falling = .leaves; r.intensity = 0.6; r.wind = 0.25; r.sunBeams = 0.35; r.starVisibility = 0.8
        }

        if isHareruCleared {
            r.sunBeams = 1
            r.lightVisibility = 1.1
        }
        // 별은 밤에 온전히, 새벽엔 사라져 가는 몇 개만
        switch timeOfDay {
        case .night: break
        case .dawn: r.starVisibility *= 0.3
        default: r.starVisibility = 0
        }
        if isNight { r.sunBeams = 0 }
        return r
    }
}

// MARK: - 결정적 난수 (격자 무늬가 생기지 않는 정수 해시)
@inline(__always)
func weatherNoise(_ index: Int, _ salt: Int = 0) -> Double {
    var x = UInt64(bitPattern: Int64(index &* 0x27D4EB2F &+ salt &* 0x165667B1 &+ 0x9E3779B9))
    x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
    x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
    x ^= x >> 31
    return Double(x >> 11) / Double(UInt64(1) << 53)
}

@inline(__always)
private func wrap(_ value: Double, _ span: Double) -> Double {
    let r = value.truncatingRemainder(dividingBy: span)
    return r < 0 ? r + span : r
}

private func oklchColor(_ l: Double, _ c: Double, _ h: Double, _ alpha: Double = 1) -> Color {
    RGBAColor.oklch(lightness: l, chroma: c, hueDegrees: h, alpha: alpha).swiftUIColor
}

/// 납작한 타원 안을 가장자리까지 부드럽게 사라지는 방사 그라데이션으로 채움 (원형 그라데이션이 타원에 잘려 생기는 딱딱한 경계 방지)
private func fillSoftEllipse(_ context: GraphicsContext, in rect: CGRect, gradient: Gradient) {
    guard rect.width > 0, rect.height > 0 else { return }
    var c = context
    c.translateBy(x: rect.midX, y: rect.midY)
    c.scaleBy(x: 1, y: rect.height / rect.width)
    let r = rect.width / 2
    c.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)),
           with: .radialGradient(gradient, center: .zero, startRadius: 0, endRadius: r))
}

// MARK: - 렌더러
struct WeatherSkyRenderer {
    let recipe: WeatherSceneRecipe
    let timeOfDay: SkyTimeOfDay
    let palette: WeatherSkyPalette
    let size: CGSize
    let time: TimeInterval
    let date: Date
    let reduceMotion: Bool

    private var w: Double { Double(max(1, size.width)) }
    private var h: Double { Double(max(1, size.height)) }
    private var unit: Double { min(w, h) }
    private var isNight: Bool { timeOfDay == .night }
    private var skyHue: Double { palette.skyGradient[1].oklchComponents.hueDegrees }

    func draw(in context: GraphicsContext) {
        if recipe.starVisibility > 0 { drawStars(context) }
        if recipe.aurora { drawAurora(context) }
        if recipe.meteors { drawMeteors(context) }
        drawLightSource(context)
        if recipe.sunBeams > 0 { drawSunBeams(context) }
        if recipe.overcastDeck > 0 { drawOvercastDeck(context) }
        if recipe.cloudCover > 0 { drawClouds(context, layer: 0) }
        if recipe.rainbow { drawRainbow(context) }
        if recipe.cloudCover > 0 {
            drawClouds(context, layer: 1)
            drawClouds(context, layer: 2)
        }
        if recipe.lightning > 0 { drawLightning(context) }
        if recipe.dust > 0 { drawDust(context) }
        if recipe.fog > 0 { drawFog(context) }
        if recipe.heatShimmer { drawHeatShimmer(context) }
        drawPrecipitation(context)
        if recipe.falling != .none { drawFallingFoliage(context) }
        if recipe.windStreaks > 0 { drawWindStreaks(context) }
        if recipe.glassDrops > 0 { drawGlassDrops(context) }
    }

    // MARK: 빛의 색 (시간대별 산란)

    /// 해 · 달의 화면 위치 (화면 비율)
    private var lightPosition: CGPoint {
        let drift = sin(time * 0.01) * 0.01
        switch timeOfDay {
        case .dawn: return CGPoint(x: 0.2 + drift, y: 0.68)
        case .morning: return CGPoint(x: 0.27 + drift, y: 0.2)
        case .midday: return CGPoint(x: 0.72 + drift, y: 0.08)
        case .sunset: return CGPoint(x: 0.8 + drift, y: 0.64)
        case .night: return CGPoint(x: 0.74 + drift, y: 0.15)
        }
    }

    private var lightCenter: CGPoint {
        CGPoint(x: lightPosition.x * size.width, y: lightPosition.y * size.height)
    }

    /// 햇빛 색: 새벽 복숭아 · 한낮 흰빛 · 노을 주황 · 밤 달빛
    private var sunlight: (l: Double, c: Double, h: Double) {
        switch timeOfDay {
        case .dawn: return (0.9, 0.08, 55)
        case .morning: return (0.97, 0.035, 90)
        case .midday: return (0.99, 0.02, 95)
        case .sunset: return (0.83, 0.14, 48)
        case .night: return (0.94, 0.02, 250)
        }
    }

    /// 구름의 볕 드는 면과 그늘 면
    private var cloudLitTone: (l: Double, c: Double, h: Double) {
        let shade = recipe.cloudShade
        switch timeOfDay {
        case .dawn: return (0.86 - shade * 0.3, 0.06 * (1 - shade * 0.6), 35)
        case .morning, .midday: return (0.98 - shade * 0.32, 0.01, 250)
        case .sunset: return (0.79 - shade * 0.3, 0.11 * (1 - shade * 0.6), 40)
        case .night: return (0.42 - shade * 0.12, 0.025, 262)
        }
    }

    private var cloudShadowTone: (l: Double, c: Double, h: Double) {
        let shade = recipe.cloudShade
        switch timeOfDay {
        case .dawn: return (0.6 - shade * 0.25, 0.05, 305)
        case .morning, .midday: return (0.78 - shade * 0.4, 0.025, 250)
        case .sunset: return (0.5 - shade * 0.2, 0.06, 320)
        case .night: return (0.24 - shade * 0.08, 0.03, 265)
        }
    }

    // MARK: 1. 천구

    private func drawStars(_ context: GraphicsContext) {
        let vis = min(1.2, recipe.starVisibility)
        var c = context
        c.blendMode = .plusLighter

        // 은하수: 대각선을 따라 번진 희미한 빛무리
        if vis > 0.6 {
            for i in 0..<22 {
                let p = Double(i) / 21.0
                let x = w * (0.02 + 0.96 * p) + (weatherNoise(i, 1) - 0.5) * w * 0.12
                let y = h * (0.56 - 0.54 * p) + (weatherNoise(i, 2) - 0.5) * h * 0.08
                let r = unit * (0.1 + 0.1 * weatherNoise(i, 3))
                fillSoftEllipse(c, in: CGRect(x: x - r, y: y - r * 0.6, width: r * 2, height: r * 1.2),
                                gradient: Gradient(colors: [oklchColor(0.8, 0.03, 280, 0.07 * (vis - 0.6)), .clear]))
            }
        }

        let count = Int(150 * min(1, vis + 0.15))
        for i in 0..<count {
            let x = weatherNoise(i, 11) * w
            let y = pow(weatherNoise(i, 12), 1.3) * h * 0.72
            let magnitude = pow(weatherNoise(i, 13), 3)          // 밝은 별은 드물게
            let twinkleSpeed = 0.8 + weatherNoise(i, 14) * 2.4
            let twinkle = 0.55 + 0.45 * sin(time * twinkleSpeed + weatherNoise(i, 15) * 6.28)
            let alpha = (0.18 + 0.82 * magnitude) * twinkle * min(1, vis)
            let radius = 0.45 + magnitude * 1.5
            let tint = weatherNoise(i, 16)
            let color: Color = tint < 0.15
                ? oklchColor(0.93, 0.05, 70, alpha)
                : tint > 0.85 ? oklchColor(0.93, 0.05, 240, alpha) : Color.white.opacity(alpha)
            c.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(color))

            if magnitude > 0.55 {
                // 밝은 별의 회절 십자 빛살
                let spike = radius * (4 + 3 * twinkle)
                var cross = Path()
                cross.move(to: CGPoint(x: x - spike, y: y)); cross.addLine(to: CGPoint(x: x + spike, y: y))
                cross.move(to: CGPoint(x: x, y: y - spike)); cross.addLine(to: CGPoint(x: x, y: y + spike))
                c.stroke(cross, with: .color(color.opacity(0.35)), lineWidth: 0.5)
            }
        }
    }

    private func drawAurora(_ context: GraphicsContext) {
        var c = context
        c.blendMode = .plusLighter
        let step = 5.0
        for curtain in 0..<3 {
            let ci = Double(curtain)
            var x = 0.0
            while x < w + step {
                let base = h * (0.32 + 0.07 * ci)
                    + sin(x * 0.006 + time * 0.12 + ci * 1.7) * h * 0.05
                    + sin(x * 0.017 - time * 0.21 + ci) * h * 0.018
                let height = h * (0.1 + 0.1 * (0.5 + 0.5 * sin(x * 0.011 + time * 0.27 + ci * 2.1)))
                let shimmer = 0.5 + 0.5 * sin(x * 0.045 + time * 1.1 + ci * 3)
                let alpha = (0.1 + 0.16 * shimmer) * (1 - ci * 0.22)
                let rect = CGRect(x: x, y: base - height, width: step + 0.6, height: height * 1.15)
                c.fill(
                    Path(rect),
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: oklchColor(0.62, 0.14, 310, alpha * 0.5), location: 0.25),
                            .init(color: oklchColor(0.8, 0.13, 180, alpha * 0.8), location: 0.6),
                            .init(color: oklchColor(0.82, 0.17, 150, alpha), location: 0.86),
                            .init(color: .clear, location: 1),
                        ]),
                        startPoint: CGPoint(x: rect.midX, y: rect.minY),
                        endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                    )
                )
                x += step
            }
        }
    }

    private func drawMeteors(_ context: GraphicsContext) {
        var c = context
        c.blendMode = .plusLighter
        // 모든 유성이 같은 복사점에서 뻗어 나오도록 방향을 맞춤
        let direction = CGVector(dx: -0.82, dy: 0.57)
        for slot in 0..<6 {
            let period = 2.8 + weatherNoise(slot, 41) * 4.5
            let shifted = time + weatherNoise(slot, 42) * period
            let cycle = Int(floor(shifted / period))
            let local = shifted - Double(cycle) * period
            let life = 0.75 + weatherNoise(cycle, slot) * 0.5
            guard local < life else { continue }
            let p = local / life
            let start = CGPoint(
                x: w * (0.35 + 0.6 * weatherNoise(cycle, slot + 50)),
                y: h * (0.03 + 0.3 * weatherNoise(cycle, slot + 60))
            )
            let travel = unit * (0.35 + 0.25 * weatherNoise(cycle, slot + 70)) * p
            let tailLength = unit * 0.22 * min(1, p * 2.2)
            let head = CGPoint(x: start.x + direction.dx * travel, y: start.y + direction.dy * travel)
            let tail = CGPoint(x: head.x - direction.dx * tailLength, y: head.y - direction.dy * tailLength)
            let alpha = sin(Double.pi * p) * 0.9
            var path = Path()
            path.move(to: tail)
            path.addLine(to: head)
            c.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [.clear, oklchColor(0.95, 0.04, 200, alpha)]),
                    startPoint: tail, endPoint: head
                ),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
            )
            c.fill(
                Path(ellipseIn: CGRect(x: head.x - 3, y: head.y - 3, width: 6, height: 6)),
                with: .radialGradient(Gradient(colors: [.white.opacity(alpha), .clear]), center: head, startRadius: 0, endRadius: 3)
            )
        }
    }

    // MARK: 2. 해 · 달 · 산란광

    private func drawLightSource(_ context: GraphicsContext) {
        let vis = recipe.lightVisibility
        let center = lightCenter
        var c = context
        c.blendMode = .plusLighter

        // 새벽 · 노을: 지평선을 따라 번지는 산란광 (구름이 짙어도 은은히 남음)
        if timeOfDay == .dawn || timeOfDay == .sunset {
            let glowAlpha = 0.18 + 0.32 * min(1, vis)
            let rect = CGRect(x: center.x - size.width * 0.9, y: center.y - size.height * 0.24,
                              width: size.width * 1.8, height: size.height * 0.5)
            fillSoftEllipse(c, in: rect, gradient: Gradient(colors: [
                oklchColor(0.82, 0.13, timeOfDay == .dawn ? 55 : 45, glowAlpha), .clear,
            ]))
        }

        guard vis > 0.02 else { return }
        if isNight {
            drawMoon(c, center: center, visibility: min(1, vis))
            return
        }

        let s = sunlight
        let pulse = recipe.heatShimmer ? 1 + 0.06 * sin(time * 1.7) : 1
        let haloRadius = unit * (0.55 + 0.25 * min(1, vis)) * pulse
        c.fill(
            Path(ellipseIn: CGRect(x: center.x - haloRadius, y: center.y - haloRadius, width: haloRadius * 2, height: haloRadius * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: oklchColor(s.l, s.c, s.h, 0.42 * min(1, vis)), location: 0),
                    .init(color: oklchColor(s.l, s.c * 1.3, s.h, 0.12 * min(1, vis)), location: 0.35),
                    .init(color: .clear, location: 1),
                ]),
                center: center, startRadius: 0, endRadius: haloRadius
            )
        )

        if recipe.dust > 0 {
            // 황사 속 해: 빛무리 없이 창백한 원반만
            let r = unit * 0.05
            c.blendMode = .normal
            c.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                   with: .color(oklchColor(0.95, 0.04, 85, 0.55)))
            return
        }

        let diskRadius = unit * (timeOfDay == .dawn || timeOfDay == .sunset ? 0.07 : 0.055)
        c.fill(
            Path(ellipseIn: CGRect(x: center.x - diskRadius * 1.6, y: center.y - diskRadius * 1.6, width: diskRadius * 3.2, height: diskRadius * 3.2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color.white.opacity(0.95 * min(1, vis)), location: 0),
                    .init(color: oklchColor(s.l, s.c, s.h, 0.85 * min(1, vis)), location: 0.55),
                    .init(color: .clear, location: 1),
                ]),
                center: center, startRadius: 0, endRadius: diskRadius * 1.6
            )
        )

        if recipe.heatShimmer {
            // 코로나 빛살 + 렌즈 플레어 고스트 (같은 명도의 OKLCH 색상 3개)
            var rays = c
            rays.translateBy(x: center.x, y: center.y)
            rays.rotate(by: .radians(time * 0.05))
            for i in 0..<16 {
                let angle = Double(i) / 16 * .pi * 2
                let length = unit * (i.isMultiple(of: 2) ? 0.42 : 0.28)
                var ray = Path()
                ray.move(to: CGPoint(x: cos(angle - 0.03) * diskRadius, y: sin(angle - 0.03) * diskRadius))
                ray.addLine(to: CGPoint(x: cos(angle) * length, y: sin(angle) * length))
                ray.addLine(to: CGPoint(x: cos(angle + 0.03) * diskRadius, y: sin(angle + 0.03) * diskRadius))
                ray.closeSubpath()
                rays.fill(ray, with: .radialGradient(
                    Gradient(colors: [oklchColor(0.95, 0.08, 80, 0.16), .clear]),
                    center: .zero, startRadius: diskRadius, endRadius: length
                ))
            }
            let screenCenter = CGPoint(x: size.width / 2, y: size.height / 2)
            for (k, ghost) in [(0.55, 40.0), (0.9, 150.0), (1.35, 300.0)].enumerated() {
                let gx = center.x + (screenCenter.x - center.x) * ghost.0 * 1.6
                let gy = center.y + (screenCenter.y - center.y) * ghost.0 * 1.6
                let gr = unit * (0.03 + 0.03 * Double(k))
                c.fill(Path(ellipseIn: CGRect(x: gx - gr, y: gy - gr, width: gr * 2, height: gr * 2)),
                       with: .radialGradient(Gradient(colors: [oklchColor(0.8, 0.1, ghost.1, 0.1), .clear]),
                                             center: CGPoint(x: gx, y: gy), startRadius: 0, endRadius: gr))
            }
        }
    }

    /// 실제 월령(삭망월 29.53일)에 맞춘 달 모양
    private func drawMoon(_ context: GraphicsContext, center: CGPoint, visibility: Double) {
        let r = unit * 0.045
        let glowRadius = r * 7
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - glowRadius, y: center.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)),
            with: .radialGradient(Gradient(colors: [oklchColor(0.9, 0.03, 240, 0.22 * visibility), .clear]),
                                  center: center, startRadius: r, endRadius: glowRadius)
        )

        let knownNewMoon = Date(timeIntervalSince1970: 947_182_440) // 2000-01-06 18:14 UTC
        let synodic = 29.530588853 * 86_400
        let phase = wrap(date.timeIntervalSince(knownNewMoon), synodic) / synodic // 0 삭 · 0.5 망
        let waxing = phase < 0.5
        let side: Double = waxing ? 1 : -1
        let terminator = cos(2 * .pi * (waxing ? phase : 1 - phase))

        // 어두운 면(지구광)
        var disk = context
        disk.blendMode = .normal
        disk.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                  with: .color(oklchColor(0.32, 0.02, 260, 0.35 * visibility)))

        var lit = Path()
        let steps = 24
        for i in 0...steps {
            let theta = -Double.pi / 2 + Double.pi * Double(i) / Double(steps)
            let point = CGPoint(x: center.x + side * r * cos(theta), y: center.y + r * sin(theta))
            i == 0 ? lit.move(to: point) : lit.addLine(to: point)
        }
        for i in 0...steps {
            let theta = Double.pi / 2 - Double.pi * Double(i) / Double(steps)
            lit.addLine(to: CGPoint(x: center.x + side * r * terminator * cos(theta), y: center.y + r * sin(theta)))
        }
        lit.closeSubpath()
        disk.fill(lit, with: .color(oklchColor(0.95, 0.02, 95, 0.95 * visibility)))

        // 달의 바다 (밝은 면 안에서만)
        var maria = disk
        maria.clip(to: lit)
        for (dx, dy, mr) in [(-0.3, -0.25, 0.28), (0.2, 0.1, 0.22), (-0.1, 0.4, 0.18)] {
            let mc = CGPoint(x: center.x + dx * r, y: center.y + dy * r)
            maria.fill(Path(ellipseIn: CGRect(x: mc.x - mr * r, y: mc.y - mr * r, width: mr * r * 2, height: mr * r * 2)),
                       with: .color(oklchColor(0.78, 0.02, 250, 0.35 * visibility)))
        }
    }

    private func drawSunBeams(_ context: GraphicsContext) {
        var c = context
        c.blendMode = .plusLighter
        let center = lightCenter
        let s = sunlight
        let reach = h * 1.15
        let beamCount = recipe.sunBeams > 0.8 ? 9 : 6
        for b in 0..<beamCount {
            let baseAngle = Double.pi / 2 + (Double(b) / Double(beamCount - 1) - 0.5) * 1.9
                + (center.x > size.width / 2 ? 0.25 : -0.25)
            let angle = baseAngle + sin(time * 0.07 + Double(b) * 1.9) * 0.05
            let spreadWidth = 0.035 + 0.04 * weatherNoise(b, 81)
            let breathe = 0.6 + 0.4 * sin(time * 0.3 + Double(b) * 2.3)
            let alpha = 0.075 * recipe.sunBeams * breathe
            var beam = Path()
            beam.move(to: center)
            beam.addLine(to: CGPoint(x: center.x + cos(angle - spreadWidth) * reach, y: center.y + sin(angle - spreadWidth) * reach))
            beam.addLine(to: CGPoint(x: center.x + cos(angle + spreadWidth) * reach, y: center.y + sin(angle + spreadWidth) * reach))
            beam.closeSubpath()
            c.fill(beam, with: .radialGradient(
                Gradient(colors: [oklchColor(s.l, s.c, s.h, alpha), .clear]),
                center: center, startRadius: 0, endRadius: reach
            ))
        }
    }

    // MARK: 3. 구름

    private func drawOvercastDeck(_ context: GraphicsContext) {
        let shadow = cloudShadowTone
        let deck = recipe.overcastDeck
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: oklchColor(shadow.l - 0.05, shadow.c, shadow.h, 0.85 * deck), location: 0),
                    .init(color: oklchColor(shadow.l, shadow.c, shadow.h, 0.45 * deck), location: 0.35),
                    .init(color: .clear, location: 0.75),
                ]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }

    /// layer 0 원경 · 1 중경 · 2 근경
    private func drawClouds(_ context: GraphicsContext, layer: Int) {
        let cover = recipe.cloudCover
        let counts = [3.0 + cover * 5, 1.0 + cover * 4, cover * 4]
        let count = Int(counts[layer].rounded(.down))
        guard count > 0 else { return }

        let depth = [0.45, 0.75, 1.0][layer]
        let layerAlpha = [0.55, 0.8, 0.95][layer] * min(1, 0.45 + cover)
        let bandTop = [0.04, 0.12, 0.24][layer]
        let bandHeight = [0.16, 0.22, 0.3][layer]
        let speed = (5 + 9 * depth) * recipe.cloudSpeed
        let lit = cloudLitTone
        let shadow = cloudShadowTone
        let light = lightCenter

        context.drawLayer { layerContext in
            layerContext.opacity = layerAlpha
            for i in 0..<count {
                let seed = layer * 100 + i
                let cloudWidth = w * (0.32 + 0.3 * weatherNoise(seed, 1)) * (0.7 + 0.5 * depth) * (0.8 + cover * 0.5)
                let span = w + cloudWidth * 2
                let cx = wrap(weatherNoise(seed, 2) * span + time * speed * (0.8 + 0.4 * weatherNoise(seed, 3)), span) - cloudWidth
                let baseY = h * (bandTop + bandHeight * (1 + cover * 0.8) * weatherNoise(seed, 4)) + sin(time * 0.05 + Double(seed)) * 4
                drawCloud(layerContext, seed: seed, centerX: cx, baseY: baseY, width: cloudWidth,
                          lit: lit, shadow: shadow, light: light)
            }
        }
    }

    private func drawCloud(
        _ context: GraphicsContext,
        seed: Int,
        centerX: Double,
        baseY: Double,
        width: Double,
        lit: (l: Double, c: Double, h: Double),
        shadow: (l: Double, c: Double, h: Double),
        light: CGPoint
    ) {
        let puffCount = 6 + Int(weatherNoise(seed, 5) * 3)
        var puffs: [(x: Double, y: Double, r: Double)] = []
        for j in 0..<puffCount {
            let p = Double(j) / Double(puffCount - 1)
            let bell = sin(Double.pi * p)                           // 가운데가 높이 솟은 적운 실루엣
            let r = width * (0.12 + 0.13 * bell) * (0.8 + 0.4 * weatherNoise(seed * 31 + j, 6))
            let x = centerX + (p - 0.5) * width * 0.68 + (weatherNoise(seed * 31 + j, 7) - 0.5) * width * 0.06
            let y = baseY - r * (0.7 + 0.35 * bell) + sin(time * 0.15 + Double(j) + Double(seed)) * 1.5
            puffs.append((x, y, r))
        }

        // 바닥 그늘 (평평한 구름 밑면)
        let baseRect = CGRect(x: centerX - width * 0.48, y: baseY - width * 0.05, width: width * 0.96, height: width * 0.12)
        fillSoftEllipse(context, in: baseRect, gradient: Gradient(colors: [
            oklchColor(shadow.l - 0.04, shadow.c, shadow.h, 0.9), oklchColor(shadow.l, shadow.c, shadow.h, 0),
        ]))

        // 몸통 (그늘 색)
        for puff in puffs {
            let rect = CGRect(x: puff.x - puff.r, y: puff.y - puff.r, width: puff.r * 2, height: puff.r * 2)
            context.fill(Path(ellipseIn: rect), with: .radialGradient(
                Gradient(stops: [
                    .init(color: oklchColor(shadow.l, shadow.c, shadow.h, 1), location: 0),
                    .init(color: oklchColor(shadow.l, shadow.c, shadow.h, 0.95), location: 0.62),
                    .init(color: oklchColor(shadow.l, shadow.c, shadow.h, 0), location: 1),
                ]),
                center: CGPoint(x: puff.x, y: puff.y), startRadius: 0, endRadius: puff.r
            ))
        }

        // 볕 드는 면: 해(달) 쪽으로 치우친 밝은 덩어리
        for puff in puffs {
            let dx = Double(light.x) - puff.x
            let dy = Double(light.y) - puff.y
            let distance = max(1, hypot(dx, dy))
            let lx = puff.x + dx / distance * puff.r * 0.3
            let ly = puff.y + min(0, dy / distance) * puff.r * 0.3 - puff.r * 0.12
            let lr = puff.r * 0.82
            context.fill(Path(ellipseIn: CGRect(x: lx - lr, y: ly - lr, width: lr * 2, height: lr * 2)), with: .radialGradient(
                Gradient(stops: [
                    .init(color: oklchColor(lit.l, lit.c, lit.h, 0.95), location: 0),
                    .init(color: oklchColor(lit.l, lit.c, lit.h, 0.55), location: 0.55),
                    .init(color: oklchColor(lit.l, lit.c, lit.h, 0), location: 1),
                ]),
                center: CGPoint(x: lx, y: ly), startRadius: 0, endRadius: lr
            ))
        }
    }

    // MARK: 4. 무지개 · 번개

    private func drawRainbow(_ context: GraphicsContext) {
        // 일곱 띠를 같은 명도(L 0.78) · 같은 채도의 OKLCH 색상각으로만 나눠 어느 띠도 튀지 않게 함
        let hues: [Double] = [25, 55, 95, 145, 210, 265, 305]
        let center = CGPoint(x: size.width * 0.5, y: size.height * 1.02)
        let radius = hypot(w, h) * 0.47
        let band = radius * 0.021
        let fade = 0.5 + 0.5 * sin(time * 0.05)
        context.drawLayer { layer in
            layer.opacity = 0.48 + 0.12 * fade
            for (k, hue) in hues.enumerated() {
                let r = radius - Double(k) * band
                var arc = Path()
                arc.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                layer.stroke(arc, with: .color(oklchColor(0.78, 0.15, hue)), lineWidth: band * 1.15)
            }
            // 쌍무지개 (색 순서가 뒤집힌 희미한 바깥 호)
            for (k, hue) in hues.reversed().enumerated() {
                let r = radius * 1.17 - Double(k) * band * 1.2
                var arc = Path()
                arc.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                layer.stroke(arc, with: .color(oklchColor(0.78, 0.1, hue, 0.3)), lineWidth: band * 1.3)
            }
            // 땅 쪽으로 갈수록 옅어지게
            layer.blendMode = .destinationIn
            layer.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [.white, .white.opacity(0.8), .clear]),
                startPoint: CGPoint(x: 0, y: center.y - radius * 1.2),
                endPoint: CGPoint(x: 0, y: size.height * 0.95)
            ))
        }
    }

    private func drawLightning(_ context: GraphicsContext) {
        guard !reduceMotion else { return } // 섬광은 광과민 위험이 있어 '동작 줄이기'에서 끔
        let period = 7.5 - 3.5 * recipe.lightning
        let cycle = Int(floor(time / period))
        let local = time - Double(cycle) * period
        let strikeAt = weatherNoise(cycle, 91) * (period - 1)
        let t = local - strikeAt
        guard t >= 0, t < 0.45 else { return }

        // 두세 번 깜빡이는 실제 번개의 밝기 곡선
        let envelope: Double
        switch t {
        case ..<0.07: envelope = 1
        case 0.12..<0.19: envelope = 0.65
        case 0.27..<0.32: envelope = 0.35
        default: envelope = 0
        }
        guard envelope > 0 else { return }

        let isBolt = weatherNoise(cycle, 92) > 0.3
        let startX = w * (0.12 + 0.76 * weatherNoise(cycle, 93))
        let startY = h * (0.08 + 0.1 * weatherNoise(cycle, 94))
        var c = context
        c.blendMode = .plusLighter

        // 구름 속에서 번지는 섬광
        let glowRadius = unit * 0.7
        c.fill(Path(ellipseIn: CGRect(x: startX - glowRadius, y: startY - glowRadius * 0.6, width: glowRadius * 2, height: glowRadius * 1.2)),
               with: .radialGradient(Gradient(colors: [oklchColor(0.9, 0.06, 285, 0.4 * envelope), .clear]),
                                     center: CGPoint(x: startX, y: startY), startRadius: 0, endRadius: glowRadius))
        c.fill(Path(CGRect(origin: .zero, size: size)), with: .color(oklchColor(0.9, 0.04, 285, 0.12 * envelope)))

        guard isBolt else { return }
        var bolt = Path()
        var point = CGPoint(x: startX, y: startY)
        bolt.move(to: point)
        let segments = 14
        let drop = h * (0.45 + 0.25 * weatherNoise(cycle, 95)) / Double(segments)
        var branchPoints: [CGPoint] = []
        for s in 0..<segments {
            point = CGPoint(x: point.x + (weatherNoise(cycle * 37 + s, 96) - 0.5) * w * 0.08, y: point.y + drop)
            bolt.addLine(to: point)
            if s == 3 || s == 7 || s == 10 { branchPoints.append(point) }
        }
        for (b, origin) in branchPoints.enumerated() {
            var branchPoint = origin
            bolt.move(to: origin)
            let lean = weatherNoise(cycle * 11 + b, 97) > 0.5 ? 1.0 : -1.0
            for s in 0..<4 {
                branchPoint = CGPoint(
                    x: branchPoint.x + lean * w * (0.02 + 0.03 * weatherNoise(cycle * 13 + b * 7 + s, 98)),
                    y: branchPoint.y + drop * 0.7
                )
                bolt.addLine(to: branchPoint)
            }
        }
        c.stroke(bolt, with: .color(oklchColor(0.85, 0.1, 285, 0.22 * envelope)), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
        c.stroke(bolt, with: .color(oklchColor(0.92, 0.06, 285, 0.55 * envelope)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        c.stroke(bolt, with: .color(.white.opacity(envelope)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
    }

    // MARK: 5. 대기

    private var fogTone: (l: Double, c: Double, h: Double) {
        let horizon = palette.skyGradient[2].oklchComponents
        return (min(0.96, horizon.lightness + 0.08), horizon.chroma * 0.5, horizon.hueDegrees)
    }

    private func drawFog(_ context: GraphicsContext) {
        let tone = fogTone
        let density = recipe.fog
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [.clear, oklchColor(tone.l, tone.c, tone.h, 0.65 * density)]),
                startPoint: CGPoint(x: 0, y: size.height * 0.2), endPoint: CGPoint(x: 0, y: size.height)
            )
        )
        for band in 0..<6 {
            let bandWidth = w * (1.3 + 0.4 * weatherNoise(band, 21))
            let bandHeight = h * (0.14 + 0.1 * weatherNoise(band, 22))
            let y = h * (0.28 + 0.12 * Double(band)) + sin(time * 0.08 + Double(band)) * h * 0.015
            let speed = (5 + 7 * weatherNoise(band, 23)) * (band.isMultiple(of: 2) ? 1 : -1)
            let span = w + bandWidth
            let x = wrap(weatherNoise(band, 24) * span + time * speed, span) - bandWidth
            let rect = CGRect(x: x, y: y - bandHeight / 2, width: bandWidth, height: bandHeight)
            fillSoftEllipse(context, in: rect, gradient: Gradient(colors: [
                oklchColor(tone.l, tone.c, tone.h, 0.5 * density), .clear,
            ]))
        }
    }

    private func drawDust(_ context: GraphicsContext) {
        let amount = recipe.dust
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [oklchColor(0.78, 0.07, 80, 0.25 * amount), oklchColor(0.82, 0.08, 75, 0.55 * amount)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
            )
        )
        var grains = Path()
        for i in 0..<90 {
            let speed = 18 + 40 * weatherNoise(i, 31)
            let x = wrap(weatherNoise(i, 32) * w + time * speed, w)
            let y = wrap(weatherNoise(i, 33) * h + sin(time * 0.6 + Double(i)) * 8, h)
            let r = 0.6 + 1.2 * weatherNoise(i, 34)
            grains.addEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * 2))
        }
        context.fill(grains, with: .color(oklchColor(0.86, 0.06, 80, 0.4 * amount)))
    }

    private func drawHeatShimmer(_ context: GraphicsContext) {
        // 지면 열기: 위로 피어오르며 일렁이는 반투명 띠
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [.clear, oklchColor(0.88, 0.09, 65, 0.28)]),
                startPoint: CGPoint(x: 0, y: size.height * 0.55), endPoint: CGPoint(x: 0, y: size.height)
            )
        )
        for band in 0..<7 {
            let rise = wrap(time * (10 + 4 * weatherNoise(band, 61)) + weatherNoise(band, 62) * h * 0.35, h * 0.35)
            let y0 = h - rise
            let fade = 1 - rise / (h * 0.35)
            var path = Path()
            let step = 8.0
            var x = 0.0
            path.move(to: CGPoint(x: 0, y: y0))
            while x <= w {
                path.addLine(to: CGPoint(x: x, y: y0 + sin(x * 0.035 + time * 2.4 + Double(band)) * 3))
                x += step
            }
            x = w
            while x >= 0 {
                path.addLine(to: CGPoint(x: x, y: y0 + 7 + sin(x * 0.028 - time * 2.0 + Double(band) * 2) * 3))
                x -= step
            }
            path.closeSubpath()
            context.fill(path, with: .color(oklchColor(0.95, 0.05, 80, 0.07 * fade)))
        }
    }

    // MARK: 6. 강수 · 낙하물

    private var rainTone: Color {
        let base = palette.isDarkSky ? 0.9 : 0.97
        return oklchColor(base, 0.02, skyHue)
    }

    private func drawPrecipitation(_ context: GraphicsContext) {
        switch recipe.precipitation {
        case .none:
            return
        case .drizzle:
            drawRain(context, density: 0.8 * recipe.intensity, speed: 420, length: 7, drizzle: true)
        case .rain:
            drawRain(context, density: recipe.intensity, speed: 950, length: 26, drizzle: false)
            if recipe.intensity > 0.4 { drawSplashes(context) }
        case .sleet:
            drawRain(context, density: 0.55 * recipe.intensity, speed: 800, length: 18, drizzle: false)
            drawPellets(context, count: 45, speed: 480, radius: 1.4, bounce: false)
        case .hail:
            drawRain(context, density: 0.35, speed: 900, length: 20, drizzle: false)
            drawPellets(context, count: Int(70 * recipe.intensity), speed: 720, radius: 2.4, bounce: true)
        case .snow:
            drawSnow(context)
        }
    }

    private func drawRain(_ context: GraphicsContext, density: Double, speed: Double, length: Double, drizzle: Bool) {
        let gust = recipe.wind * (1 + 0.25 * sin(time * 0.7))
        let color = rainTone
        // 원경(가늘고 느림) → 근경(굵고 빠름) 세 겹
        for (layer, depth) in [0.4, 0.7, 1.0].enumerated() {
            let count = Int(density * (drizzle ? 90 : 60) * (layer == 0 ? 1.4 : 1.0))
            let layerSpeed = speed * (0.55 + 0.45 * depth)
            let streakLength = length * (0.5 + 0.5 * depth)
            var heads = Path()
            var tails = Path()
            for i in 0..<count {
                let seed = layer * 1000 + i
                let fall = h + streakLength + 40
                let y = wrap(weatherNoise(seed, 1) * fall + time * layerSpeed * (0.9 + 0.2 * weatherNoise(seed, 2)), fall) - streakLength
                let x = wrap(weatherNoise(seed, 3) * (w + 120) + y * gust, w + 120) - 60
                let dx = streakLength * gust
                let mid = CGPoint(x: x + dx * 0.5, y: y + streakLength * 0.5)
                tails.move(to: CGPoint(x: x, y: y))
                tails.addLine(to: mid)
                heads.move(to: mid)
                heads.addLine(to: CGPoint(x: x + dx, y: y + streakLength))
            }
            let alpha = (drizzle ? 0.18 : 0.14) + 0.3 * depth
            let width = (drizzle ? 0.6 : 0.7) + 0.8 * depth
            context.stroke(tails, with: .color(color.opacity(alpha * 0.4)), style: StrokeStyle(lineWidth: width, lineCap: .round))
            context.stroke(heads, with: .color(color.opacity(alpha)), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
    }

    private func drawSplashes(_ context: GraphicsContext) {
        var rings = Path()
        var droplets = Path()
        for i in 0..<Int(26 * recipe.intensity) {
            let period = 0.45 + 0.3 * weatherNoise(i, 51)
            let shifted = time + weatherNoise(i, 52) * period
            let cycle = Int(floor(shifted / period))
            let p = (shifted - Double(cycle) * period) / period
            let x = weatherNoise(cycle * 17 + i, 53) * w
            let y = h - 4 - weatherNoise(cycle * 17 + i, 54) * h * 0.06
            let rw = 2 + 12 * p
            rings.addEllipse(in: CGRect(x: x - rw, y: y - rw * 0.18, width: rw * 2, height: rw * 0.36))
            // 왕관 모양으로 튀는 물방울
            for k in 0..<3 {
                let angle = Double.pi * (0.2 + 0.3 * Double(k))
                let dx = cos(angle) * 10 * p
                let dy = -sin(angle) * 14 * p + 30 * p * p
                droplets.addEllipse(in: CGRect(x: x + dx - 0.8, y: y + dy - 0.8, width: 1.6, height: 1.6))
            }
        }
        context.stroke(rings, with: .color(rainTone.opacity(0.28)), lineWidth: 0.7)
        context.fill(droplets, with: .color(rainTone.opacity(0.35)))
    }

    private func drawPellets(_ context: GraphicsContext, count: Int, speed: Double, radius: Double, bounce: Bool) {
        let ground = h - 10
        let bounceSpan = bounce ? 0.28 * speed : 0
        var pellets = Path()
        var glints = Path()
        for i in 0..<count {
            let depth = 0.5 + 0.5 * weatherNoise(i, 71)
            let fallSpeed = speed * (0.7 + 0.3 * depth)
            let span = ground + 20 + bounceSpan
            var y = wrap(weatherNoise(i, 72) * span + time * fallSpeed, span) - 20
            var x = wrap(weatherNoise(i, 73) * w + y * recipe.wind, w)
            if bounce && y > ground {
                // 바닥에 맞고 통 튀어 오르는 우박
                let tau = (y - ground) / fallSpeed
                y = ground - (190 * tau - 0.5 * 1400 * tau * tau) * depth
                x += (weatherNoise(i, 74) - 0.5) * 60 * tau
            }
            let r = radius * (0.6 + 0.6 * depth)
            pellets.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            glints.addEllipse(in: CGRect(x: x - r * 0.45, y: y - r * 0.55, width: r * 0.6, height: r * 0.6))
        }
        context.fill(pellets, with: .color(oklchColor(0.95, 0.015, 220, 0.72)))
        context.fill(glints, with: .color(.white.opacity(0.95)))
    }

    private static let crystal: Path = {
        // 여섯 갈래 눈 결정 (각 갈래에 잔가지 한 쌍)
        var p = Path()
        for arm in 0..<6 {
            let a = Double(arm) * .pi / 3
            let tip = CGPoint(x: cos(a), y: sin(a))
            p.move(to: .zero)
            p.addLine(to: tip)
            let branchBase = CGPoint(x: cos(a) * 0.55, y: sin(a) * 0.55)
            for side in [-1.0, 1.0] {
                p.move(to: branchBase)
                p.addLine(to: CGPoint(x: branchBase.x + cos(a + side * 0.75) * 0.3, y: branchBase.y + sin(a + side * 0.75) * 0.3))
            }
        }
        return p
    }()

    private func drawSnow(_ context: GraphicsContext) {
        let intensity = recipe.intensity
        let wind = recipe.wind
        let blizzard = wind > 0.5
        // 원경 작은 점 · 중경 둥근 눈 · 근경 결정 · 아주 가까운 보케
        let layers: [(count: Int, depth: Double)] = [
            (Int(90 * intensity), 0.3), (Int(55 * intensity), 0.6), (Int(22 * intensity), 0.9),
        ]
        for (layer, spec) in layers.enumerated() {
            let depth = spec.depth
            var flakes = Path()
            for i in 0..<spec.count {
                let seed = layer * 1000 + i
                let fallSpeed = (22 + 60 * depth) * (blizzard ? 2.4 : 1) * (0.85 + 0.3 * weatherNoise(seed, 1))
                let span = h + 40
                let y = wrap(weatherNoise(seed, 2) * span + time * fallSpeed, span) - 20
                let sway = sin(time * (0.6 + 0.8 * weatherNoise(seed, 3)) + weatherNoise(seed, 4) * 6.28) * 16 * depth
                let x = wrap(weatherNoise(seed, 5) * (w + 40) + sway + time * fallSpeed * wind, w + 40) - 20
                let r = (0.7 + 1.6 * weatherNoise(seed, 6)) * (0.6 + 2.2 * depth)

                if layer == 2 && r > 3.2 {
                    var crystal = context
                    crystal.translateBy(x: x, y: y)
                    crystal.rotate(by: .radians(time * (0.4 + weatherNoise(seed, 7)) + Double(seed)))
                    crystal.scaleBy(x: r * 1.4, y: r * 1.4)
                    crystal.stroke(Self.crystal, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 0.9 / (r * 1.4), lineCap: .round))
                } else {
                    flakes.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                }
            }
            context.fill(flakes, with: .color(.white.opacity(0.35 + 0.5 * depth)))
        }

        // 렌즈 바로 앞을 스치는 흐릿한 큰 눈송이
        for i in 0..<Int(6 * intensity) {
            let fallSpeed = 70.0 * (blizzard ? 2.5 : 1)
            let span = h + 80
            let y = wrap(weatherNoise(i, 201) * span + time * fallSpeed, span) - 40
            let x = wrap(weatherNoise(i, 202) * w + sin(time * 0.4 + Double(i)) * 30 + time * fallSpeed * wind, w)
            let r = 10 + 10 * weatherNoise(i, 203)
            context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .radialGradient(Gradient(colors: [.white.opacity(0.28), .white.opacity(0.1), .clear]),
                                               center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
        }
    }

    private static let petal: Path = {
        // 끝이 살짝 갈라진 벚꽃잎 (단위 크기)
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0.5))
        p.addQuadCurve(to: CGPoint(x: -0.13, y: -0.45), control: CGPoint(x: -0.6, y: 0.05))
        p.addLine(to: CGPoint(x: 0, y: -0.3))
        p.addLine(to: CGPoint(x: 0.13, y: -0.45))
        p.addQuadCurve(to: CGPoint(x: 0, y: 0.5), control: CGPoint(x: 0.6, y: 0.05))
        p.closeSubpath()
        return p
    }()

    private static let leaf: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -0.5))
        p.addQuadCurve(to: CGPoint(x: 0, y: 0.42), control: CGPoint(x: 0.5, y: -0.05))
        p.addQuadCurve(to: CGPoint(x: 0, y: -0.5), control: CGPoint(x: -0.5, y: -0.05))
        p.closeSubpath()
        p.move(to: CGPoint(x: 0, y: 0.42))
        p.addLine(to: CGPoint(x: 0, y: 0.6))
        return p
    }()

    private func drawFallingFoliage(_ context: GraphicsContext) {
        let blossom = recipe.falling == .blossom
        let count = Int((blossom ? 44 : 26) * recipe.intensity)
        // 낙엽은 같은 명도(L 0.66) · 채도의 인접 색상각(붉은 단풍 ~ 은행 노랑)으로 통일
        let leafHues: [Double] = [28, 42, 58, 78]
        for i in 0..<count {
            let depth = 0.4 + 0.6 * weatherNoise(i, 301)
            let fallSpeed = (blossom ? 22 : 30) + 40 * depth
            let span = h + 60
            let y = wrap(weatherNoise(i, 302) * span + time * fallSpeed, span) - 30
            let sway = sin(time * (0.7 + 0.6 * weatherNoise(i, 303)) + Double(i)) * 28 * depth
            let drift = time * fallSpeed * (recipe.wind + 0.15)
            let x = wrap(weatherNoise(i, 304) * (w + 60) + sway + drift, w + 60) - 30
            let scale = (blossom ? 7.0 : 13.0) * (0.5 + 0.7 * depth)
            let flip = cos(time * (1.2 + 1.6 * weatherNoise(i, 305)) + Double(i))

            var c = context
            c.translateBy(x: x, y: y)
            c.rotate(by: .radians(time * (0.6 + weatherNoise(i, 306)) * (i.isMultiple(of: 2) ? 1 : -1) + Double(i)))
            c.scaleBy(x: scale * max(0.15, abs(flip)), y: scale)
            c.opacity = 0.55 + 0.45 * depth
            if blossom {
                c.fill(Self.petal, with: .linearGradient(
                    Gradient(colors: [oklchColor(0.8, 0.1, 355), oklchColor(0.94, 0.04, 350)]),
                    startPoint: CGPoint(x: 0, y: 0.5), endPoint: CGPoint(x: 0, y: -0.4)
                ))
            } else {
                let hue = leafHues[i % leafHues.count]
                c.fill(Self.leaf, with: .color(oklchColor(flip > 0 ? 0.66 : 0.58, 0.14, hue)))
                c.stroke(Self.leaf, with: .color(oklchColor(0.45, 0.08, hue, 0.6)), lineWidth: 0.06)
            }
        }
    }

    private func drawWindStreaks(_ context: GraphicsContext) {
        var c = context
        c.blendMode = .plusLighter
        let strength = recipe.windStreaks
        for i in 0..<Int(14 * strength) {
            let speed = 380 + 300 * weatherNoise(i, 401)
            let length = w * (0.25 + 0.25 * weatherNoise(i, 402))
            let span = w + length * 2 + 200
            let x = wrap(weatherNoise(i, 403) * span + time * speed, span) - length - 100
            let y = h * (0.1 + 0.8 * weatherNoise(i, 404))
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addCurve(
                to: CGPoint(x: x + length, y: y + 6 * sin(Double(i))),
                control1: CGPoint(x: x + length * 0.33, y: y - 10),
                control2: CGPoint(x: x + length * 0.66, y: y + 10)
            )
            c.stroke(path, with: .linearGradient(
                Gradient(colors: [.clear, .white.opacity(0.22 * strength), .clear]),
                startPoint: CGPoint(x: x, y: y), endPoint: CGPoint(x: x + length, y: y)
            ), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
        }
    }

    // MARK: 7. 유리창 빗방울

    private func drawGlassDrops(_ context: GraphicsContext) {
        let amount = recipe.glassDrops
        let tone = RaindropLensTone(palette: palette)

        // 맺혔다 사라지는 작은 물방울
        for i in 0..<Int(46 * amount) {
            let life = 6 + 8 * weatherNoise(i, 501)
            let shifted = time + weatherNoise(i, 502) * life
            let cycle = Int(floor(shifted / life))
            let p = (shifted - Double(cycle) * life) / life
            let grow = min(1, p * 5) * min(1, (1 - p) * 4)
            guard grow > 0.05 else { continue }
            let x = weatherNoise(cycle * 7 + i, 503) * w
            let y = weatherNoise(cycle * 7 + i, 504) * h
            let r = (1.4 + 3.2 * pow(weatherNoise(cycle * 7 + i, 505), 2)) * grow
            RaindropLens.draw(context, center: CGPoint(x: x, y: y), radius: r, elongation: 1.05, tone: tone)
        }

        // 멈칫거리며 흘러내리는 큰 물방울과 젖은 자국
        for i in 0..<Int(7 * amount) {
            let period = 7 + 6 * weatherNoise(i, 511)
            let shifted = time + weatherNoise(i, 512) * period
            let cycle = Int(floor(shifted / period))
            let local = shifted - Double(cycle) * period
            let speed = h / period * 0.9
            // 빠르게 미끄러졌다 멈추기를 반복 (stick-slip)
            let travel = speed * (local - sin(local * 2 * .pi / 1.4) * 1.4 / (2 * .pi))
            let startX = weatherNoise(cycle * 13 + i, 513) * w
            let startY = -10 + weatherNoise(cycle * 13 + i, 514) * h * 0.3
            let y = startY + travel
            let x = startX + sin(y * 0.03 + Double(i)) * 3
            let r = 3.5 + 2.5 * weatherNoise(cycle * 13 + i, 515)

            // 젖은 자국: 물방울 바로 뒤에서 가장 짙고 위로 갈수록 마름
            let trailTop = max(startY, y - 160)
            var trail = Path()
            var sy = trailTop
            trail.move(to: CGPoint(x: startX + sin(sy * 0.03 + Double(i)) * 3, y: sy))
            while sy < y - r {
                sy += 6
                trail.addLine(to: CGPoint(x: startX + sin(sy * 0.03 + Double(i)) * 3, y: sy))
            }
            context.stroke(trail, with: .linearGradient(
                Gradient(colors: [.clear, .white.opacity(0.07)]),
                startPoint: CGPoint(x: x, y: trailTop), endPoint: CGPoint(x: x, y: y)
            ), style: StrokeStyle(lineWidth: r * 0.8, lineCap: .round))
            // 자국을 따라 남는 작은 물알
            var bead = trailTop + 10
            var k = 0
            while bead < y - r * 2 {
                if weatherNoise(cycle * 31 + i * 5 + k, 516) > 0.55 {
                    let bx = startX + sin(bead * 0.03 + Double(i)) * 3
                    RaindropLens.draw(context, center: CGPoint(x: bx, y: bead), radius: r * 0.3, elongation: 1, tone: tone)
                }
                bead += 14
                k += 1
            }
            RaindropLens.draw(context, center: CGPoint(x: x, y: y), radius: r, elongation: 1.3, tone: tone)
        }
    }
}

// MARK: - 굴절 렌즈 빗방울 (하늘이 위아래 뒤집혀 비치는 모습)
struct RaindropLensTone {
    let top: Color      // 물방울 윗부분: 아래쪽(지평선) 하늘이 비침
    let bottom: Color   // 물방울 아랫부분: 위쪽(천정) 하늘이 비침
    let rim: Color

    init(palette: WeatherSkyPalette) {
        top = palette.skyGradient[2].interpolated(to: RGBAColor(red: 1, green: 1, blue: 1), progress: 0.25).swiftUIColor.opacity(0.75)
        bottom = palette.skyGradient[0].swiftUIColor.opacity(0.7)
        rim = palette.skyGradient[0].interpolated(to: RGBAColor(red: 0, green: 0, blue: 0), progress: 0.45).swiftUIColor.opacity(0.4)
    }

    init(top: Color, bottom: Color, rim: Color) {
        self.top = top
        self.bottom = bottom
        self.rim = rim
    }
}

enum RaindropLens {
    static func draw(_ context: GraphicsContext, center: CGPoint, radius r: Double, elongation: Double, tone: RaindropLensTone) {
        guard r > 0.4 else { return }
        let rect = CGRect(x: center.x - r, y: center.y - r * elongation, width: r * 2, height: r * 2 * elongation)
        let body = Path(ellipseIn: rect)
        // 아래로 드리운 그림자
        context.fill(Path(ellipseIn: rect.offsetBy(dx: r * 0.12, dy: r * 0.22)), with: .color(tone.rim.opacity(0.5)))
        context.fill(body, with: .linearGradient(
            Gradient(colors: [tone.top, tone.bottom]),
            startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)
        ))
        context.stroke(body, with: .color(tone.rim), lineWidth: max(0.4, r * 0.12))
        // 반사 하이라이트(좌상단)와 아래쪽에 모이는 투과광
        let glint = CGRect(x: rect.minX + r * 0.45, y: rect.minY + r * 0.3 * elongation, width: r * 0.42, height: r * 0.36)
        context.fill(Path(ellipseIn: glint), with: .color(.white.opacity(0.9)))
        let caustic = CGRect(x: rect.midX - r * 0.4, y: rect.maxY - r * 0.55 * elongation, width: r * 0.8, height: r * 0.3)
        context.fill(Path(ellipseIn: caustic), with: .color(.white.opacity(0.28)))
    }
}

// MARK: - 카드 유리 표면에 맺혀 흐르는 빗방울 오버레이 (정답 보기 클릭 시 아래로 주르륵 흘러내림!)
public struct CardGlassRaindropOverlay: View {
    public let isRaining: Bool
    public let isRevealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isRaining: Bool, isRevealed: Bool) {
        self.isRaining = isRaining
        self.isRevealed = isRevealed
    }

    public var body: some View {
        if isRaining {
            TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 10.0 : 1.0 / 45.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate * (reduceMotion ? 0.15 : 1.0)
                Canvas { context, size in
                    drawCondensationDrops(in: context, size: size, time: t)
                }
                .allowsHitTesting(false)
            }
        }
    }

    private static let tone = RaindropLensTone(
        top: .white.opacity(0.32),
        bottom: .white.opacity(0.08),
        rim: .black.opacity(0.14)
    )

    private func drawCondensationDrops(in context: GraphicsContext, size: CGSize, time t: TimeInterval) {
        let w = Double(max(1, size.width))
        let h = Double(max(1, size.height))
        let speedMultiplier = isRevealed ? 3.4 : 1.0

        for i in 0..<22 {
            let baseSpeed = (8.0 + 14 * weatherNoise(i, 601)) * speedMultiplier
            let y = wrap(weatherNoise(i, 602) * h + t * baseSpeed, max(1, h - 24)) + 12
            let wiggle = sin(t * 1.8 + Double(i)) * 2.2
            let x = 14.0 + wrap(weatherNoise(i, 603) * w + wiggle, max(1.0, w - 28.0))
            let r = 2.0 + 1.8 * weatherNoise(i, 604)
            RaindropLens.draw(context, center: CGPoint(x: x, y: y), radius: r,
                              elongation: isRevealed ? 1.6 : 1.15, tone: Self.tone)
        }
    }
}
