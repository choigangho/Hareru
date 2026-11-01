import SwiftUI

// MARK: - 탭 2 「연구소」 게임 챕터 (임시 화면)
// 国立言語遺産研究所(NJL)를 키우는 경영 시뮬레이션이 들어올 자리입니다. 기획은 Docs/GAME_DESIGN.md 참고.
public struct GameChapterPlaceholderView: View {
    private let weatherEngine: WeatherAtmosphereEngine

    public init(weatherEngine: WeatherAtmosphereEngine = .shared) {
        self.weatherEngine = weatherEngine
    }

    private var palette: WeatherSkyPalette { weatherEngine.activePalette }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(palette.accentColor)
                Text("연구소 준비 중")
                    .font(.title3.bold())
                    .foregroundStyle(palette.primaryTextColor)
                Text("잊혀진 한자를 되살리는 마지막 연구소가\n곧 문을 열어요.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.secondaryTextColor)
            }
            .padding(28)
            .hareruGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous), tint: palette.glassTintColor)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                WeatherSkyCanvasView(
                    condition: weatherEngine.activeCondition,
                    timeOfDay: weatherEngine.activeTimeOfDay,
                    palette: palette,
                    isHareruCleared: weatherEngine.isHareruClearedToday
                )
            }
            .navigationTitle("연구소")
        }
    }
}

#Preview("연구소 (임시)") {
    GameChapterPlaceholderView()
}
