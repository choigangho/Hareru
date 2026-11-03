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

public extension HareruMainTab {
    /// 레트로 키캡 아이콘 (rt_tab_*): 판독 단말 · 연구소 · 판독 기록 · 단말 설정
    var retroIcon: String {
        switch self {
        case .study: return "terminal"
        case .game: return "institute"
        case .insights: return "records"
        case .settings: return "settings"
        }
    }
}

// MARK: - 하단 탭 바 = 크림 키보드 위 키캡 넷 (ART_BIBLE §7 — 글자 대신 아이콘)
// 고른 탭은 숯색 키가 눌린 채로 있고 아이콘이 형광 녹색 · 오른쪽 위 LED가 켜짐. 이름은 VoiceOver 라벨로만.
public struct FloatingGlassTabBar: View {
    @Binding private var selection: HareruMainTab
    private let palette: WeatherSkyPalette

    public init(selection: Binding<HareruMainTab>, palette: WeatherSkyPalette) {
        _selection = selection
        self.palette = palette
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(HareruMainTab.allCases) { tab in
                let isActive = selection == tab
                Button {
                    guard selection != tab else { return }
                    withAnimation(.easeOut(duration: 0.12)) { selection = tab }
                } label: {
                    RetroSprite(name: "rt_tab_\(tab.retroIcon)\(isActive ? "_on" : "")", animated: false, scale: 2)
                        .shadow(color: isActive ? RetroColor.phosphor.opacity(0.7) : .clear, radius: 4)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .overlay(alignment: .topTrailing) {
                            if isActive {
                                Circle().fill(RetroColor.phosphor).frame(width: 5, height: 5)
                                    .shadow(color: RetroColor.phosphor, radius: 2)
                                    .offset(x: -2, y: -4)
                            }
                        }
                }
                .buttonStyle(RetroKeyStyle(tone: isActive ? .charcoal : .cream, latched: isActive))
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 9)
        .padding(.bottom, 11)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(RetroColor.cream)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(
                    LinearGradient(colors: [Color(red: 1, green: 0.97, blue: 0.86), Color(red: 0.55, green: 0.49, blue: 0.37)],
                                   startPoint: .top, endPoint: .bottom), lineWidth: 3))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(RetroColor.ink, lineWidth: 1))
        }
        .shadow(color: .black.opacity(0.7), radius: 6, y: 6)
        .padding(.horizontal, 8)
    }
}
