import SwiftUI

// MARK: - 메인 4탭 정의 (학습 · 연구소 · 통계 · 설정)
public enum HareruMainTab: String, CaseIterable, Identifiable, Sendable {
    case study
    case game
    case insights
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .study: return "학습"
        case .game: return "연구소"
        case .insights: return "통계"
        case .settings: return "설정"
        }
    }

    public var systemImage: String {
        switch self {
        case .study: return "rectangle.stack.fill"
        case .game: return "building.columns.fill"
        case .insights: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - iOS 26 플로팅 Liquid Glass 캡슐 탭 바
// 기본 TabView 바 대신 화면 하단에 떠 있는 유리 필(Pill)을 두고,
// 선택된 탭 뒤의 굴곡진 유리 인디케이터가 `matchedGeometryEffect`로 미끄러지듯 이동합니다.
public struct FloatingGlassTabBar: View {
    @Binding private var selection: HareruMainTab
    private let palette: WeatherSkyPalette
    @Namespace private var indicatorNamespace

    public init(selection: Binding<HareruMainTab>, palette: WeatherSkyPalette) {
        _selection = selection
        self.palette = palette
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(HareruMainTab.allCases) { tab in
                let isActive = selection == tab
                Button {
                    guard selection != tab else { return }
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 17, weight: .semibold))
                            .symbolEffect(.bounce, value: isActive)
                        Text(tab.title)
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(isActive ? palette.primaryTextColor : palette.secondaryTextColor)
                    .frame(width: 70, height: 50)
                    .background {
                        if isActive {
                            activeIndicator
                                .matchedGeometryEffect(id: "activeTabIndicator", in: indicatorNamespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .padding(5)
        .hareruGlass(in: Capsule(), tint: palette.glassTintColor, interactive: true)
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
    }

    /// 볼록한 유리 렌즈처럼 위쪽은 밝고 아래쪽은 살짝 그늘진 굴곡 인디케이터
    private var activeIndicator: some View {
        Capsule()
            .fill(palette.accentColor.opacity(0.22))
            .overlay {
                Capsule().fill(
                    LinearGradient(
                        colors: [.white.opacity(0.38), .white.opacity(0.04), .black.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .overlay {
                Capsule().strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.75), .white.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
            }
            .shadow(color: palette.accentColor.opacity(0.3), radius: 6, y: 2)
    }
}
