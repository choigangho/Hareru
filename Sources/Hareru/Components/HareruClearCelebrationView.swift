import SwiftUI

// MARK: - 오늘의 목표 완주 '晴れる(Hareru)' 클리어 연출
// 화면을 덮고 있던 구름이 좌우로 걷히고, 중앙에서 햇살이 천천히 회전하며 퍼져 나옵니다.
public struct HareruClearCelebrationView: View {
    private let palette: WeatherSkyPalette
    @State private var cloudsParted: Bool = false
    @State private var sunRisen: Bool = false

    public init(palette: WeatherSkyPalette) {
        self.palette = palette
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            ZStack {
                // 1) 햇살 광선 (천천히 회전)
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let angle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 120) * 3
                    sunburst
                        .rotationEffect(.degrees(angle))
                }
                .frame(width: width * 1.6, height: width * 1.6)
                .scaleEffect(sunRisen ? 1.0 : 0.3)
                .opacity(sunRisen ? 0.9 : 0)
                .position(x: width / 2, y: geo.size.height * 0.22)

                // 2) 걷히는 구름 두 덩어리
                cloudCluster
                    .offset(x: cloudsParted ? -width : -width * 0.12)
                    .opacity(cloudsParted ? 0 : 1)
                    .position(x: width / 2, y: geo.size.height * 0.24)

                cloudCluster
                    .scaleEffect(x: -1, y: 1)
                    .offset(x: cloudsParted ? width : width * 0.12)
                    .opacity(cloudsParted ? 0 : 1)
                    .position(x: width / 2, y: geo.size.height * 0.30)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2)) {
                cloudsParted = true
            }
            withAnimation(.easeOut(duration: 2.6).delay(0.5)) {
                sunRisen = true
            }
        }
    }

    private var sunburst: some View {
        ZStack {
            ForEach(0..<14, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.55), Color.white.opacity(0)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 26, height: 260)
                    .offset(y: -150)
                    .rotationEffect(.degrees(Double(index) / 14 * 360))
            }
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.95), Color.yellow.opacity(0.6), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)
        }
        .blendMode(.screen)
    }

    private var cloudCluster: some View {
        ZStack {
            Image(systemName: "cloud.fill")
                .font(.system(size: 220))
                .offset(x: -40, y: 10)
            Image(systemName: "cloud.fill")
                .font(.system(size: 160))
                .offset(x: 90, y: -30)
        }
        .foregroundStyle(
            LinearGradient(
                colors: [Color.white.opacity(0.95), palette.secondaryTextColor.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
    }
}

#Preview("晴れる 클리어 연출") {
    let palette = WeatherSkyPalette.resolve(condition: .clear, timeOfDay: .midday, isHareruCleared: true)
    ZStack {
        WeatherSkyCanvasView(condition: .clear, timeOfDay: .midday, palette: palette, isHareruCleared: true)
        HareruClearCelebrationView(palette: palette)
    }
}
