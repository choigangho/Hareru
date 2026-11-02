import SwiftUI

// MARK: - 연구소 화면 픽셀 UI 틀 (Resources/Art/UI/frame_*.png, 9-slice) — 제작 스크립트: Docs/Art/UI/tools/ui_frames.py
// 앱 탭 바(학습 · 연구소 · 통계 · 설정)만 Liquid Glass로 두고, 연구소 화면 안의 판 · 칩 · 버튼 · 서랍은 모두 이 픽셀 틀.
// 12×12px 틀을 1px = 2pt로 그리고, 4px 모서리를 뺀 가운데를 타일로 이어 늘림 (흐려지지 않게 최근접).
enum PixelUI {
    /// 남색 판 위에서 읽히는 고정 색 (연구소 하늘이 밝든 어둡든 같음)
    static let text = Color(red: 0.94, green: 0.93, blue: 0.87)
    static let textDim = Color(red: 0.66, green: 0.70, blue: 0.76)
    static let accent = Color(red: 1.0, green: 0.81, blue: 0.36)
    static let warning = Color(red: 1.0, green: 0.45, blue: 0.40)
}

enum PixelFrameStyle: String {
    case panel = "frame_panel"     // 서랍 · 메뉴판 · 대사 창 · 판
    case button = "frame_button"   // 누를 수 있는 것
    case active = "frame_active"   // 눌려 있는 · 고른 것
    case chip = "frame_chip"       // 작은 정보 칩
}

private enum PixelFrameImages {
    static let images: [PixelFrameStyle: CGImage] = {
        var loaded: [PixelFrameStyle: CGImage] = [:]
        for style in [PixelFrameStyle.panel, .button, .active, .chip] {
            loaded[style] = OfficePixelArt.bundledImage(style.rawValue)
        }
        return loaded
    }()
}

private struct PixelFrameBackground: ViewModifier {
    let style: PixelFrameStyle

    func body(content: Content) -> some View {
        content.background {
            if let image = PixelFrameImages.images[style] {
                // scale 0.5 → 이미지 1px = 2pt, 모서리 4px = 8pt
                Image(decorative: image, scale: 0.5)
                    .resizable(capInsets: EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8), resizingMode: .tile)
                    .interpolation(.none)
            } else {
                Rectangle().fill(Color(red: 0.15, green: 0.17, blue: 0.24).opacity(0.93))
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
            }
        }
    }
}

extension View {
    func pixelFrame(_ style: PixelFrameStyle = .panel) -> some View {
        modifier(PixelFrameBackground(style: style))
    }
}
