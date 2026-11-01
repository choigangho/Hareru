import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - JLPT 시험지 표준 일본어 폰트 시스템
// - 표제어(단어·한자): 실제 JLPT 문제지 인쇄체와 가장 유사한 명조/교과서체 계열 (Hiragino Mincho ProN / YuMincho / Klee)
// - 예문 본문: 표제어와 같은 명조 계열의 본문용 얇은 굵기 (시험지처럼 문장 전체를 명조로 통일)
// - 후리가나: 작은 크기에서도 획이 뭉개지지 않는 고딕 계열 (Hiragino Sans / Apple SD Gothic)
public enum JLPTFont {
    private static let minchoCandidates = [
        "HiraMinProN-W6",
        "HiraMinProN-W3",
        "YuMincho-Demibold",
        "Klee-Medium",
        "Georgia-Bold"
    ]

    /// 예문 본문용 명조 (표제어보다 얇은 굵기로 장문에서도 답답하지 않게)
    private static let bodyMinchoCandidates = [
        "HiraMinProN-W3",
        "YuMincho-Regular",
        "HiraMinProN-W6",
        "Georgia"
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

    /// 예문 본문용 명조체 (표제어와 같은 글꼴 계열)
    public static func exampleMincho(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let fontName = resolvedFontName(from: bodyMinchoCandidates) {
            return .custom(fontName, size: size)
        }
        return .system(size: size, weight: weight, design: .serif)
    }

    /// 가독성 높은 일본어 고딕체 (후리가나·작은 보조 표기 전용)
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

    /// 일본어 예문 본문에 표제어와 같은 계열의 명조체 적용
    func jlptExampleFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(JLPTFont.exampleMincho(size: size, weight: weight))
    }

    /// 후리가나·읽기 표기에 작은 크기에서도 선명한 고딕체 적용
    func jlptFuriganaFont(size: CGFloat, weight: Font.Weight = .medium) -> some View {
        self.font(JLPTFont.exampleGothic(size: size, weight: weight))
    }
}
