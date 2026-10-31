import SwiftUI

// MARK: - Apple 날씨 앱 스타일 상시 60fps 하늘 & 기상 파티클 렌더러
// - 맑은 밤: 반짝이는 별빛 + 은은한 오로라 광선
// - 맑은 낮 / Hareru(날씨 갬): 대각선 햇살(Sunbeams) + 부유하는 빛 입자
// - 구름 / 안개: 다층 안개·구름 레이어 유영
// - 비: 낙하하는 빗줄기 + 바닥 물보라
// - 태풍 / 폭우: 거센 사선 폭우 + 주기적 번개 섬광
// - 눈: 깊이감(원근)이 다른 눈송이 진자 낙하
// - 폭염: 타오르는 태양 코로나 + 상승하는 열기 아지랑이
public struct WeatherSkyCanvasView: View {
    public let condition: WeatherCondition
    public let timeOfDay: SkyTimeOfDay
    public let palette: WeatherSkyPalette
    public var failureCount: Int = 0
    public var isHareruCleared: Bool = false

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
        ZStack {
            LinearGradient(
                colors: palette.skyColors(withFailureCount: failureCount),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    drawAtmosphere(in: &context, size: size, time: t)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
    }

    private func drawAtmosphere(in context: inout GraphicsContext, size: CGSize, time t: TimeInterval) {
        // 1) 밤하늘 별빛 (맑음 또는 구름 조금인 밤)
        if timeOfDay == .night && (condition == .clear || condition == .cloudy || condition == .snow) {
            drawNightStars(in: &context, size: size, time: t)
        }

        // 2) 기상 상태별 메인 파티클 효과
        switch condition {
        case .clear:
            drawSunbeamsAndLightMotes(in: &context, size: size, time: t, intense: isHareruCleared)
        case .cloudy:
            drawDriftingCloudLayers(in: &context, size: size, time: t, opacityMultiplier: 0.22)
        case .fog:
            drawDriftingCloudLayers(in: &context, size: size, time: t, opacityMultiplier: 0.42)
        case .rain:
            drawDriftingCloudLayers(in: &context, size: size, time: t, opacityMultiplier: 0.18)
            drawRainStreaks(in: &context, size: size, time: t, count: 75, windAngle: 0.14, speed: 720)
        case .typhoon:
            drawTyphoonLightning(in: &context, size: size, time: t)
            drawDriftingCloudLayers(in: &context, size: size, time: t, opacityMultiplier: 0.30)
            drawRainStreaks(in: &context, size: size, time: t, count: 120, windAngle: 0.36, speed: 1080)
        case .snow:
            drawSnowflakes(in: &context, size: size, time: t, count: 68)
        case .heatwave:
            drawHeatwaveShimmer(in: &context, size: size, time: t)
        }
    }

    private func drawNightStars(in context: inout GraphicsContext, size: CGSize, time t: TimeInterval) {
        for i in 0..<46 {
            let seed = Double(i * 97 + 13)
            let x = fmod(seed * 73.1, Double(max(1, size.width)))
            let y = fmod(seed * 41.7, Double(max(1, size.height * 0.65)))
            let twinkle = 0.25 + 0.65 * (0.5 + 0.5 * sin(t * (1.2 + fmod(seed, 2.3)) + seed))
            let radius = 1.0 + fmod(seed, 1.8)
            let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(twinkle)))
        }
    }

    private func drawSunbeamsAndLightMotes(
        in context: inout GraphicsContext,
        size: CGSize,
        time t: TimeInterval,
        intense: Bool
    ) {
        let beamCount = intense ? 5 : 3
        for b in 0..<beamCount {
            let phase = t * 0.25 + Double(b) * 1.3
            let topX = size.width * (0.15 + 0.22 * CGFloat(b)) + CGFloat(sin(phase) * 24)
            var path = Path()
            path.move(to: CGPoint(x: topX, y: -20))
            path.addLine(to: CGPoint(x: topX + 90, y: -20))
            path.addLine(to: CGPoint(x: topX + 260, y: size.height * 0.85))
            path.addLine(to: CGPoint(x: topX + 60, y: size.height * 0.85))
            path.closeSubpath()

            let alpha = (intense ? 0.14 : 0.08) * (0.7 + 0.3 * sin(phase))
            context.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: [.white.opacity(alpha), .clear]),
                    startPoint: CGPoint(x: topX, y: 0),
                    endPoint: CGPoint(x: topX + 180, y: size.height * 0.8)
                )
            )
        }

        // 부유하는 햇빛 먼지 입자
        for i in 0..<28 {
            let seed = Double(i * 53 + 7)
            let x = fmod(seed * 61.3 + sin(t * 0.6 + seed) * 22.0 + Double(size.width), Double(max(1, size.width)))
            let y = fmod(seed * 89.1 - t * (12.0 + fmod(seed, 10.0)) + Double(size.height) * 100.0, Double(max(1, size.height)))
            let alpha = 0.18 + 0.35 * (0.5 + 0.5 * sin(t * 1.5 + seed))
            let r = 1.5 + fmod(seed, 2.5)
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                with: .color(.white.opacity(alpha))
            )
        }
    }

    private func drawDriftingCloudLayers(
        in context: inout GraphicsContext,
        size: CGSize,
        time t: TimeInterval,
        opacityMultiplier: Double
    ) {
        for i in 0..<6 {
            let seed = Double(i * 41 + 19)
            let speed = 14.0 + Double(i) * 5.0
            let w = Double(size.width) * (0.55 + 0.12 * Double(i % 3))
            let h = 95.0 + Double(i % 3) * 38.0
            let totalSpan = Double(size.width) + w * 1.5
            let x = fmod(seed * 83.0 + t * speed, totalSpan) - w * 0.75
            let y = Double(size.height) * (0.06 + 0.14 * Double(i)) + sin(t * 0.4 + seed) * 10.0

            let rect = CGRect(x: x, y: y, width: w, height: h)
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(opacityMultiplier), .clear]),
                    center: CGPoint(x: rect.midX, y: rect.midY),
                    startRadius: 5,
                    endRadius: CGFloat(w * 0.5)
                )
            )
        }
    }

    private func drawRainStreaks(
        in context: inout GraphicsContext,
        size: CGSize,
        time t: TimeInterval,
        count: Int,
        windAngle: Double,
        speed: Double
    ) {
        let w = Double(max(1, size.width))
        let h = Double(max(1, size.height))

        for i in 0..<count {
            let seed = Double(i * 79 + 11)
            let layerSpeed = speed * (0.75 + 0.5 * fmod(seed, 1.0))
            let rawY = fmod(seed * 97.3 + t * layerSpeed, h + 80.0) - 40.0
            let rawX = fmod(seed * 53.7 + rawY * windAngle + w * 10.0, w)
            let length = 18.0 + fmod(seed, 18.0)
            let dx = length * windAngle
            let dy = length

            var streak = Path()
            streak.move(to: CGPoint(x: rawX, y: rawY))
            streak.addLine(to: CGPoint(x: rawX + dx, y: rawY + dy))

            let alpha = 0.22 + 0.32 * fmod(seed * 0.37, 1.0)
            context.stroke(
                streak,
                with: .color(.white.opacity(alpha)),
                lineWidth: 1.2
            )
        }
    }

    private func drawTyphoonLightning(in context: inout GraphicsContext, size: CGSize, time t: TimeInterval) {
        // 약 5.5초 주기로 짧은 이중 번개 플래시 연출
        let cycle = fmod(t, 5.5)
        let flashAlpha: Double
        if cycle < 0.08 {
            flashAlpha = 0.36
        } else if cycle > 0.14 && cycle < 0.20 {
            flashAlpha = 0.22
        } else {
            flashAlpha = 0.0
        }
        guard flashAlpha > 0 else { return }
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(.white.opacity(flashAlpha))
        )
    }

    private func drawSnowflakes(in context: inout GraphicsContext, size: CGSize, time t: TimeInterval, count: Int) {
        let w = Double(max(1, size.width))
        let h = Double(max(1, size.height))

        for i in 0..<count {
            let seed = Double(i * 67 + 23)
            let depth = 0.4 + 0.6 * fmod(seed * 0.19, 1.0)
            let fallSpeed = 38.0 + depth * 55.0
            let y = fmod(seed * 71.0 + t * fallSpeed, h + 30.0) - 15.0
            let sway = sin(t * (1.1 + depth * 0.8) + seed) * (14.0 * depth)
            let x = fmod(seed * 43.0 + sway + w * 10.0, w)
            let radius = 1.6 + depth * 2.8

            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(.white.opacity(0.35 + depth * 0.50))
            )
        }
    }

    private func drawHeatwaveShimmer(in context: inout GraphicsContext, size: CGSize, time t: TimeInterval) {
        // 상단 강렬한 태양 할로
        let pulse = 1.0 + 0.08 * sin(t * 2.1)
        let sunRadius = CGFloat(150.0 * pulse)
        let sunCenter = CGPoint(x: size.width * 0.82, y: size.height * 0.08)
        let sunRect = CGRect(
            x: sunCenter.x - sunRadius,
            y: sunCenter.y - sunRadius,
            width: sunRadius * 2,
            height: sunRadius * 2
        )
        context.fill(
            Path(ellipseIn: sunRect),
            with: .radialGradient(
                Gradient(colors: [Color.yellow.opacity(0.42), Color.orange.opacity(0.18), .clear]),
                center: sunCenter,
                startRadius: 8,
                endRadius: sunRadius
            )
        )

        // 하단에서 피어오르는 열기 아지랑이 물결
        let w = Double(max(1, size.width))
        let h = Double(max(1, size.height))
        for i in 0..<24 {
            let seed = Double(i * 47 + 5)
            let y = h - fmod(seed * 59.0 + t * (28.0 + fmod(seed, 16.0)), h * 0.75)
            let x = fmod(seed * 37.0 + sin(t * 2.6 + seed) * 18.0 + w, w)
            let r = 2.0 + fmod(seed, 3.0)
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: r * 3, height: r * 1.4)),
                with: .color(Color(red: 1.0, green: 0.92, blue: 0.65).opacity(0.22))
            )
        }
    }
}

// MARK: - 카드 유리 표면에 맺혀 흐르는 빗방울 오버레이 (정답 보기 클릭 시 아래로 주르륵 흘러내림!)
public struct CardGlassRaindropOverlay: View {
    public let isRaining: Bool
    public let isRevealed: Bool

    public init(isRaining: Bool, isRevealed: Bool) {
        self.isRaining = isRaining
        self.isRevealed = isRevealed
    }

    public var body: some View {
        if isRaining {
            TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    drawCondensationDrops(in: &context, size: size, time: t)
                }
                .allowsHitTesting(false)
            }
        }
    }

    private func drawCondensationDrops(in context: inout GraphicsContext, size: CGSize, time t: TimeInterval) {
        let w = Double(max(1, size.width))
        let h = Double(max(1, size.height))
        let speedMultiplier = isRevealed ? 3.4 : 1.0

        for i in 0..<22 {
            let seed = Double(i * 83 + 17)
            let baseSpeed = (8.0 + fmod(seed, 14.0)) * speedMultiplier
            let y = fmod(seed * 41.0 + t * baseSpeed, h - 24.0) + 12.0
            let wiggle = sin(t * 1.8 + seed) * 2.2
            let x = 14.0 + fmod(seed * 61.0 + wiggle, max(1.0, w - 28.0))
            let dropW = 4.0 + fmod(seed, 3.5)
            let dropH = dropW * (isRevealed ? 1.85 : 1.35)

            let dropRect = CGRect(x: x, y: y, width: dropW, height: dropH)
            context.fill(
                Path(ellipseIn: dropRect),
                with: .color(.white.opacity(isRevealed ? 0.25 : 0.42))
            )

            // 빗방울 상단 하이라이트 반사점
            let glintRect = CGRect(x: x + dropW * 0.22, y: y + dropH * 0.18, width: dropW * 0.35, height: dropW * 0.35)
            context.fill(
                Path(ellipseIn: glintRect),
                with: .color(.white.opacity(0.75))
            )
        }
    }
}
