import SwiftUI

// MARK: - 힌트 블러(흐림) 효과 모디파이어
public extension View {
    /// 일반 힌트 레이어용 블러 (0.0일 때 은은한 실루엣, 1.0일 때 100% 선명)
    func hintBlur(_ progress: CGFloat) -> some View {
        let clamped = min(max(progress, 0.0), 1.0)
        return self
            .blur(radius: 14 * (1 - clamped))
            .opacity(0.18 + 0.82 * clamped)
    }

    /// 후리가나 및 완전 보호 요소용 블러 (0.0일 때 길이·윤곽 스포일러 없이 완전 투명, 1.0일 때 선명)
    func furiganaBlur(_ progress: CGFloat) -> some View {
        let clamped = min(max(progress, 0.0), 1.0)
        return self
            .blur(radius: 8 * (1 - clamped))
            .opacity(Double(clamped))
    }
}
