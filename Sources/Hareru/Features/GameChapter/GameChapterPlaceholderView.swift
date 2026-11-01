import SwiftUI

// MARK: - 탭 2 게임 챕터 (임시 화면)
// 단어 · 통계 · 날씨 · 음성 캐릭터가 엮이는 종합 게임이 들어올 자리입니다. 컨셉은 Docs/BACKLOG.md 참고.
public struct GameChapterPlaceholderView: View {
    private let weatherEngine: WeatherAtmosphereEngine

    public init(weatherEngine: WeatherAtmosphereEngine = .shared) {
        self.weatherEngine = weatherEngine
    }

    private var palette: WeatherSkyPalette { weatherEngine.activePalette }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(palette.accentColor)
                Text("게임 챕터 준비 중")
                    .font(.title3.bold())
                    .foregroundStyle(palette.primaryTextColor)
                Text("외운 단어와 음성 캐릭터, 오늘의 날씨가\n하나의 이야기로 이어질 예정이에요.")
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
            .navigationTitle("게임")
        }
    }
}

#Preview("게임 챕터 (임시)") {
    GameChapterPlaceholderView()
}
