import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - JLPT 시험지 표준 일본어 폰트 시스템
// - 표제어(단어·한자): 실제 JLPT 문제지 인쇄체와 가장 유사한 명조/교과서체 계열 (Hiragino Mincho ProN / YuMincho / Klee)
// - 예문·후리가나: 모바일 화면에서 가독성이 뛰어난 고딕 계열 (Hiragino Sans / PingFang / Apple SD Gothic)
public enum JLPTFont {
    private static let minchoCandidates = [
        "HiraMinProN-W6",
        "HiraMinProN-W3",
        "YuMincho-Demibold",
        "Klee-Medium",
        "Georgia-Bold"
    ]

    private static let gothicCandidates = [
        "HiraginoSans-W6",
        "HiraginoSans-W5",
        "HiraginoSans-W4",
        "AppleSDGothicNeo-Medium"
    ]

    /// 실제 기기/OS에 설치된 첫 번째 유효 폰트 이름을 탐색하여 반환
    private static func resolvedFontName(from candidates: [String]) -> String? {
        for name in candidates {
            #if canImport(UIKit)
            if UIFont(name: name, size: 16) != nil {
                return name
            }
            #elseif canImport(AppKit)
            if NSFont(name: name, size: 16) != nil {
                return name
            }
            #endif
        }
        return nil
    }

    /// JLPT 시험지 인쇄 명조체 (표제어 한자·단어 전용)
    public static func termMincho(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        if let fontName = resolvedFontName(from: minchoCandidates) {
            return .custom(fontName, size: size)
        }
        return .system(size: size, weight: weight, design: .serif)
    }

    /// 가독성 높은 일본어 고딕체 (예문·후리가나·선택지 전용)
    public static func exampleGothic(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        if let fontName = resolvedFontName(from: gothicCandidates) {
            return .custom(fontName, size: size)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }
}

public extension View {
    /// 표제어(한자/가나)에 JLPT 인쇄 명조체 적용
    func jlptTermFont(size: CGFloat, weight: Font.Weight = .bold) -> some View {
        self.font(JLPTFont.termMincho(size: size, weight: weight))
    }

    /// 일본어 예문에 가독성 높은 고딕체 적용
    func jlptExampleFont(size: CGFloat, weight: Font.Weight = .medium) -> some View {
        self.font(JLPTFont.exampleGothic(size: size, weight: weight))
    }
}
