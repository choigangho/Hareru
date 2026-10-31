import SwiftUI

// MARK: - 색상 채널 값 타입 (Codable & 침식 보간 계산용)
public struct RGBAColor: Codable, Equatable, Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
        self.alpha = min(max(alpha, 0), 1)
    }

    public init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        guard cleaned.count == 6 || cleaned.count == 8,
              let value = UInt64(cleaned, radix: 16) else {
            return nil
        }
        if cleaned.count == 6 {
            let r = Double((value >> 16) & 0xFF) / 255.0
            let g = Double((value >> 8) & 0xFF) / 255.0
            let b = Double(value & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: 1.0)
        } else {
            let r = Double((value >> 24) & 0xFF) / 255.0
            let g = Double((value >> 16) & 0xFF) / 255.0
            let b = Double((value >> 8) & 0xFF) / 255.0
            let a = Double(value & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: a)
        }
    }

    public var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    public func interpolated(to target: RGBAColor, progress: Double) -> RGBAColor {
        if progress <= 0.0 { return self }
        if progress >= 1.0 { return target }
        return RGBAColor(
            red: (1.0 - progress) * red + progress * target.red,
            green: (1.0 - progress) * green + progress * target.green,
            blue: (1.0 - progress) * blue + progress * target.blue,
            alpha: (1.0 - progress) * alpha + progress * target.alpha
        )
    }
}

// MARK: - 카테고리별 차분한 테마 컬러 그룹 (단어마다 중구난방으로 바뀌지 않도록 카테고리 단위로 통일)
public enum CategoryThemeGroup: String, Codable, CaseIterable, Hashable, Sendable {
    case foodAndDining = "식음료·매장"      // 음식, 디저트, 매장, 편의점 먹거리
    case businessAndWork = "비즈니스·업무"  // 비즈니스, 접객, 성취, 기획·작전
    case socialAndDaily = "일상·모임·관계"  // 일상 회화, 모임, 회식, 시간, 약속
    case emotionAndSense = "감각·감정·상태" // 감각, 온도, 감정, 날씨
    case thoughtAndAction = "사고·판단·행동" // 사고, 판단, 전략, 요구, 안전
    case standardDefault = "기본"          // 카테고리가 애매하거나 분류되지 않은 단어용 기본 테마

    /// 눈이 피로하지 않은 차분한 저채도 파스텔 3색 팔레트 (상단 파스텔, 중단 소프트 크림/화이트, 하단 포인트 액센트)
    public var palette: ThemePalette {
        switch self {
        case .foodAndDining:
            return ThemePalette(hexColors: ["#F6E3CE", "#FBF8F3", "#9C5B2E"])
        case .businessAndWork:
            return ThemePalette(hexColors: ["#DCE5F2", "#F7F9FC", "#334E68"])
        case .socialAndDaily:
            return ThemePalette(hexColors: ["#DDF0E7", "#F6FBF8", "#2C6E58"])
        case .emotionAndSense:
            return ThemePalette(hexColors: ["#F4E0E8", "#FCF7F9", "#8B4362"])
        case .thoughtAndAction:
            return ThemePalette(hexColors: ["#E4E0F5", "#F8F7FC", "#4C408F"])
        case .standardDefault:
            return ThemePalette(hexColors: ["#E6E9EF", "#F8F9FB", "#475569"])
        }
    }

    /// 단어의 `category` 문자열을 분석하여 일관된 카테고리 테마 그룹으로 매핑 (애매한 경우 `.standardDefault` 반환)
    public static func resolve(for category: String) -> CategoryThemeGroup {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .standardDefault }

        if trimmed.contains("음식") || trimmed.contains("식사") || trimmed.contains("디저트")
            || trimmed.contains("매장") || trimmed.contains("편의점") {
            return .foodAndDining
        }
        if trimmed.contains("비즈니스") || trimmed.contains("접객") || trimmed.contains("성취")
            || trimmed.contains("제작") || trimmed.contains("기획") || trimmed.contains("거래") {
            return .businessAndWork
        }
        if trimmed.contains("모임") || trimmed.contains("회식") || trimmed.contains("관계")
            || trimmed.contains("일상") || trimmed.contains("시간") || trimmed.contains("사회") {
            return .socialAndDaily
        }
        if trimmed.contains("감각") || trimmed.contains("온도") || trimmed.contains("감정")
            || trimmed.contains("날씨") || trimmed.contains("생활") {
            return .emotionAndSense
        }
        if trimmed.contains("사고") || trimmed.contains("판단") || trimmed.contains("전략")
            || trimmed.contains("행동") || trimmed.contains("요구") || trimmed.contains("안전") {
            return .thoughtAndAction
        }
        return .standardDefault
    }
}

// MARK: - 카테고리 테마 컬러 & 실패 침식(Red+Black) 팔레트
public struct ThemePalette: Codable, Equatable, Hashable, Sendable {
    /// 채도를 뺀 차콜 블랙 + 딥 크림슨 침식 타깃 팔레트 (SPEC.md §2.3)
    public static let erosionTargets: [RGBAColor] = [
        RGBAColor(hex: "#4A0A12")!, // 상단: 딥 크림슨
        RGBAColor(hex: "#1A070B")!, // 중단: 다크 어비스 와인
        RGBAColor(hex: "#0B0B0F")!  // 하단/액센트: 차콜 블랙
    ]

    /// 카테고리가 애매한 단어를 위한 기본 팔레트
    public static let defaultPalette: ThemePalette = CategoryThemeGroup.standardDefault.palette

    /// 카테고리 이름에 대응하는 표준 카테고리 팔레트 반환
    public static func forCategory(_ category: String) -> ThemePalette {
        CategoryThemeGroup.resolve(for: category).palette
    }

    public let hexColors: [String]

    private enum CodingKeys: String, CodingKey {
        case hexColors
    }

    public init(hexColors: [String]) {
        precondition(!hexColors.isEmpty, "ThemePalette requires at least one hex color.")
        if hexColors.count >= 3 {
            self.hexColors = Array(hexColors.prefix(3))
        } else {
            var padded = hexColors
            while padded.count < 3 {
                padded.append(hexColors.last!)
            }
            self.hexColors = padded
        }
    }

    public init(from decoder: Decoder) throws {
        let hexes: [String]
        if let single = try? decoder.singleValueContainer(),
           let array = try? single.decode([String].self) {
            hexes = array
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            hexes = try container.decode([String].self, forKey: .hexColors)
        }
        guard !hexes.isEmpty else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "ThemePalette requires at least one hex string."
                )
            )
        }
        self.init(hexColors: hexes)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hexColors)
    }

    public var rgbaColors: [RGBAColor] {
        hexColors.map { RGBAColor(hex: $0) ?? RGBAColor(red: 0.25, green: 0.25, blue: 0.30) }
    }

    public var swiftUIColors: [Color] {
        rgbaColors.map(\.swiftUIColor)
    }

    public var accentColor: Color {
        swiftUIColors[2]
    }

    /// 실패 누적 횟수(0 ~ maxFailuresBeforeCap)에 따른 침식 진행도 (0.0 = 본래 퍼스널 컬러, 1.0 = 완전 침식)
    public static func erosionProgress(
        forFailureCount failureCount: Int,
        maxFailuresBeforeCap: Int = 7
    ) -> Double {
        guard failureCount > 0, maxFailuresBeforeCap > 0 else { return 0.0 }
        let linear = min(Double(failureCount) / Double(maxFailuresBeforeCap), 1.0)
        // 첫 실패부터 시각적 변화가 체감되도록 완만한 easeOut 곡선 적용
        return pow(linear, 0.8)
    }

    /// 침식도(0.0 ~ 1.0)를 반영한 RGBA 색상 배열 반환
    public func erodedRGBAColors(erosionProgress: Double) -> [RGBAColor] {
        let clamped = min(max(erosionProgress, 0.0), 1.0)
        guard clamped > 0 else { return rgbaColors }
        return zip(rgbaColors, Self.erosionTargets).map { base, target in
            base.interpolated(to: target, progress: clamped)
        }
    }

    /// 당일 실패 횟수에 따른 SwiftUI 그라데이션 색상 배열 반환 (졸업 정화 시 failureCount = 0 전달)
    public func colors(forFailureCount failureCount: Int, maxFailuresBeforeCap: Int = 7) -> [Color] {
        let progress = Self.erosionProgress(
            forFailureCount: failureCount,
            maxFailuresBeforeCap: maxFailuresBeforeCap
        )
        return erodedRGBAColors(erosionProgress: progress).map(\.swiftUIColor)
    }
}
