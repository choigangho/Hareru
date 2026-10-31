import SwiftUI

// MARK: - 힌트 블러(흐림) 효과 모디파이어
extension View {
    func hintBlur(_ progress: CGFloat) -> some View {
        self
            .blur(radius: 14 * (1 - progress))
            .opacity(0.2 + 0.8 * progress)
    }
}
