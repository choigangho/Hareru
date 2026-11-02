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

// MARK: - OKLCH 지각 균일 색공간 → sRGB 변환
// 명도(L)·채도(C)를 고정하고 색상각(h)만 바꾸면, 눈에 보이는 밝기와 선명도가 같은 '한 세트'의 색을 만들 수 있습니다.
public extension RGBAColor {
    /// - Parameters:
    ///   - lightness: 0.0(검정) ~ 1.0(흰색) 지각 명도
    ///   - chroma: 0.0(무채색) ~ 약 0.37 채도
    ///   - hueDegrees: 색상각 (0 = 마젠타 레드, 70 = 앰버, 145 = 그린, 240 = 블루)
    static func oklch(lightness: Double, chroma: Double, hueDegrees: Double, alpha: Double = 1.0) -> RGBAColor {
        let hue = hueDegrees * .pi / 180.0
        let a = chroma * cos(hue)
        let b = chroma * sin(hue)

        let l = pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)

        let linearRed = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let linearGreen = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let linearBlue = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        func gammaEncoded(_ value: Double) -> Double {
            let clamped = min(max(value, 0.0), 1.0)
            return clamped <= 0.0031308 ? 12.92 * clamped : 1.055 * pow(clamped, 1.0 / 2.4) - 0.055
        }

        return RGBAColor(
            red: gammaEncoded(linearRed),
            green: gammaEncoded(linearGreen),
            blue: gammaEncoded(linearBlue),
            alpha: alpha
        )
    }

    /// sRGB → OKLCH 역변환 (하늘 색의 색상각을 읽어 버튼 배색의 기준으로 삼을 때 사용)
    var oklchComponents: (lightness: Double, chroma: Double, hueDegrees: Double) {
        func linearized(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let r = linearized(red), g = linearized(green), b = linearized(blue)

        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)

        let lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        let a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        let bAxis = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s

        var hue = atan2(bAxis, a) * 180.0 / .pi
        if hue < 0 { hue += 360 }
        return (lightness, sqrt(a * a + bAxis * bAxis), hue)
    }
}

// MARK: - 대분류별 차분한 테마 컬러 그룹 (대분류 11개 + 분야 없음 — Docs/TOWN_DRAFT.md, Tools/draft_korean.py `DOMAINS`)
public enum CategoryThemeGroup: String, Codable, CaseIterable, Hashable, Sendable {
    case daily = "생활"                 // 식사·가게·접객·주거·건강·날씨 (겐)
    case education = "교육"             // 학교·수업·시험 (미오)
    case society = "사회"               // 문화·관계·가족 (츠루)
    case transport = "교통·이동"        // 탈것·역·길·방향·이동 (린)
    case objects = "사물·형태"          // 도구·가구·물건·색·모양·수리 (진)
    case economy = "경제"               // 돈·거래·시장
    case work = "업무"                  // 회사·비즈니스·기술·안전
    case government = "정치·행정"       // 정부·법률·제도 (렌)
    case academic = "학술"              // 과학·자연·역사·연구
    case abstractLogic = "추상·논리"    // 추상 개념·논리
    case media = "미디어"               // 방송·뉴스·통신
    case fieldless = "분야 없음"        // 분야로 묶기 어려운 기초어, 대분류가 없거나 알 수 없는 단어의 기본 테마

    /// 눈이 피로하지 않은 차분한 저채도 파스텔 3색 팔레트 (상단 파스텔, 중단 소프트 크림/화이트, 하단 포인트 액센트)
    public var palette: ThemePalette {
        switch self {
        case .daily:
            return ThemePalette(hexColors: ["#F6E3CE", "#FBF8F3", "#9C5B2E"])
        case .education:
            return ThemePalette(hexColors: ["#E2EEDC", "#F8FBF6", "#4A6B2F"])
        case .society:
            return ThemePalette(hexColors: ["#DDF0E7", "#F6FBF8", "#2C6E58"])
        case .transport:
            return ThemePalette(hexColors: ["#DCE9F5", "#F6F9FC", "#2F5D86"])
        case .objects:
            return ThemePalette(hexColors: ["#EDE4DA", "#FBF8F5", "#6B5440"])
        case .economy:
            return ThemePalette(hexColors: ["#F3EBCB", "#FCFAF2", "#7A6420"])
        case .work:
            return ThemePalette(hexColors: ["#DCE5F2", "#F7F9FC", "#334E68"])
        case .government:
            return ThemePalette(hexColors: ["#E8E1DA", "#FAF8F6", "#5E4B3C"])
        case .academic:
            return ThemePalette(hexColors: ["#D9ECF0", "#F5FAFB", "#25646F"])
        case .abstractLogic:
            return ThemePalette(hexColors: ["#E4E0F5", "#F8F7FC", "#4C408F"])
        case .media:
            return ThemePalette(hexColors: ["#F4E0E8", "#FCF7F9", "#8B4362"])
        case .fieldless:
            return ThemePalette(hexColors: ["#E6E9EF", "#F8F9FB", "#475569"])
        }
    }

    /// 단어의 `category`(대분류 이름)를 테마 그룹으로 매핑 (대분류가 아니면 `.fieldless`)
    public static func resolve(for category: String) -> CategoryThemeGroup {
        CategoryThemeGroup(rawValue: category.trimmingCharacters(in: .whitespacesAndNewlines)) ?? .fieldless
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
    public static let defaultPalette: ThemePalette = CategoryThemeGroup.fieldless.palette

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
