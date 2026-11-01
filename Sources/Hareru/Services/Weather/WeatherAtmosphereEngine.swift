import SwiftUI
import Observation
import CoreLocation

// MARK: - 시간대 (새벽 · 아침 · 한낮 · 노을 · 밤)
public enum SkyTimeOfDay: String, Codable, CaseIterable, Identifiable, Sendable {
    case dawn = "dawn"       // 05:00 ~ 07:59 새벽·이른 아침
    case morning = "morning" // 08:00 ~ 11:59 맑은 오전
    case midday = "midday"   // 12:00 ~ 16:59 한낮
    case sunset = "sunset"   // 17:00 ~ 19:29 노을·저녁
    case night = "night"     // 19:30 ~ 04:59 밤

    public var id: String { rawValue }

    public var koreanLabel: String {
        switch self {
        case .dawn: return "새벽녘"
        case .morning: return "아침"
        case .midday: return "낮"
        case .sunset: return "노을 저녁"
        case .night: return "밤"
        }
    }

    public static func from(date: Date, calendar: Calendar = .current) -> SkyTimeOfDay {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let hour = comps.hour ?? 12
        let minute = comps.minute ?? 0
        let totalMinutes = hour * 60 + minute

        switch totalMinutes {
        case (5 * 60)..<(8 * 60):
            return .dawn
        case (8 * 60)..<(12 * 60):
            return .morning
        case (12 * 60)..<(17 * 60):
            return .midday
        case (17 * 60)..<(19 * 60 + 30):
            return .sunset
        default:
            return .night
        }
    }
}

// MARK: - 기상 상태 (22종: 기본 날씨 · 강수 · 시정 · 특수 현상 · 계절 변주)
public enum WeatherCondition: String, Codable, CaseIterable, Identifiable, Sendable {
    // 하늘
    case clear = "clear"                   // 맑음
    case partlyCloudy = "partlyCloudy"     // 구름 조금 (뭉게구름 사이로 햇살)
    case cloudy = "cloudy"                 // 구름 많음
    case overcast = "overcast"             // 흐림 (하늘을 덮은 층운)
    // 강수
    case drizzle = "drizzle"               // 이슬비
    case rain = "rain"                     // 비 (유리창 빗방울 + 빗줄기)
    case thunderstorm = "thunderstorm"     // 뇌우 (갈래 번개 + 구름 속 섬광)
    case typhoon = "typhoon"               // 태풍 / 폭우 (거센 사선 비바람 + 번개)
    case sleet = "sleet"                   // 진눈깨비 (비 + 얼음 알갱이)
    case hail = "hail"                     // 우박 (튀어 오르는 얼음 알갱이)
    case snow = "snow"                     // 눈 (원근이 다른 눈송이 · 결정)
    case blizzard = "blizzard"             // 눈보라 (강풍 + 화이트아웃)
    // 시정
    case mist = "mist"                     // 옅은 안개 (박무)
    case fog = "fog"                       // 안개 (짙은 안개 레이어 흐름)
    case yellowDust = "yellowDust"         // 황사 · 미세먼지
    case heatwave = "heatwave"             // 폭염 (강렬한 태양광 + 열기 아지랑이)
    case windy = "windy"                   // 강풍
    // 특수 현상
    case rainbow = "rainbow"               // 비 갠 뒤 무지개
    case aurora = "aurora"                 // 오로라 (밤)
    case meteorShower = "meteorShower"     // 유성우 (밤)
    // 계절 변주
    case cherryBlossom = "cherryBlossom"   // 벚꽃 흩날림
    case autumnLeaves = "autumnLeaves"     // 단풍 낙엽

    public var id: String { rawValue }

    public var koreanTitle: String {
        switch self {
        case .clear: return "맑음"
        case .partlyCloudy: return "구름 조금"
        case .cloudy: return "구름 많음"
        case .overcast: return "흐림"
        case .drizzle: return "이슬비"
        case .rain: return "비"
        case .thunderstorm: return "뇌우"
        case .typhoon: return "태풍 · 폭우"
        case .sleet: return "진눈깨비"
        case .hail: return "우박"
        case .snow: return "눈"
        case .blizzard: return "눈보라"
        case .mist: return "옅은 안개"
        case .fog: return "안개"
        case .yellowDust: return "황사"
        case .heatwave: return "폭염"
        case .windy: return "강풍"
        case .rainbow: return "무지개"
        case .aurora: return "오로라"
        case .meteorShower: return "유성우"
        case .cherryBlossom: return "벚꽃"
        case .autumnLeaves: return "단풍"
        }
    }

    public func sfSymbolName(for timeOfDay: SkyTimeOfDay) -> String {
        let isNight = timeOfDay == .night
        switch self {
        case .clear: return isNight ? "moon.stars.fill" : "sun.max.fill"
        case .partlyCloudy: return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .overcast: return "smoke.fill"
        case .drizzle: return "cloud.drizzle.fill"
        case .rain: return isNight ? "cloud.moon.rain.fill" : "cloud.rain.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .typhoon: return "tropicalstorm"
        case .sleet: return "cloud.sleet.fill"
        case .hail: return "cloud.hail.fill"
        case .snow: return "snowflake"
        case .blizzard: return "wind.snow"
        case .mist: return isNight ? "moon.haze.fill" : "sun.haze.fill"
        case .fog: return "cloud.fog.fill"
        case .yellowDust: return isNight ? "moon.dust.fill" : "sun.dust.fill"
        case .heatwave: return "sun.max.trianglebadge.exclamationmark.fill"
        case .windy: return "wind"
        case .rainbow: return "rainbow"
        case .aurora: return "sparkles"
        case .meteorShower: return "moon.stars.circle.fill"
        case .cherryBlossom: return "camera.macro"
        case .autumnLeaves: return "leaf.fill"
        }
    }

    /// 학습 카드 유리 위에 빗방울이 맺히는 날씨
    public var hasRaindropsOnGlass: Bool {
        switch self {
        case .drizzle, .rain, .thunderstorm, .typhoon, .sleet: return true
        default: return false
        }
    }
}

// MARK: - 날씨 × 시간대 팔레트 & 유동적 타이포그래피 대비 시스템
// 배색 원칙 (OKLCH 지각 균일 색공간):
// 1) 하늘 3단(천정 · 중단 · 지평선)은 시간대별 '맑은 하늘'을 기준으로 정의합니다.
//    한낮·아침은 같은 색상각 안의 명도 단계(단색 조화), 새벽·노을은 천정의 보랏빛과 지평선의
//    주황빛이 맞서는 분열 보색(Split-complementary) 구조입니다.
// 2) 날씨는 이 기준 하늘을 '무드'로 변형합니다: 채도 배율 · 명도 이동 · 명도 폭 · 색상각 끌림.
//    색상각은 항상 최단 호로 보간해 탁한 중간색이 생기지 않게 합니다.
// 3) 글자색은 하늘 색상각을 머금은 극단 명도(L 0.975 / 0.25)에서 고르고, 천정·중단 두 단과의
//    WCAG 대비가 4.5:1 미만이면 순백 / 더 짙은 먹색으로 한 번 더 밀어 가독성을 보장합니다.
// 4) 강조색은 어두운 하늘에선 중단 색상각의 보색(파란 하늘 → 햇살 금빛),
//    밝은 하늘에선 같은 색상각의 짙은 톤(단색 조화)을 씁니다.
public struct WeatherSkyPalette: Equatable, Sendable {
    public let skyGradient: [RGBAColor]         // 상단 · 중단 · 하단 하늘 그라데이션
    public let primaryText: RGBAColor           // 하늘 색온도가 스며든 주 텍스트 색상
    public let secondaryText: RGBAColor         // 하늘 색온도가 스며든 보조 텍스트 색상
    public let glassSurfaceTint: RGBAColor      // 카드 Liquid Glass 틴트
    public let accentTint: RGBAColor            // 포인트 강조 색상
    public let isDarkSky: Bool                  // 하늘 명도가 어두운지 여부 (유리 반사광 제어용)

    // 4단계 평가 버튼('모르겠음 / 애매함 / 알고있음 / 쉬움') 전용 조화 틴트
    public let buttonAgainTint: RGBAColor       // 모르겠음: 차분한 로즈 슬레이트
    public let buttonHardTint: RGBAColor        // 애매함: 앰버 골드 슬레이트
    public let buttonGoodTint: RGBAColor        // 알고있음: 스카이 애저 블루
    public let buttonEasyTint: RGBAColor        // 쉬움: 에메랄드 민트 시안

    public var skySwiftUIColors: [Color] { skyGradient.map(\.swiftUIColor) }
    public var primaryTextColor: Color { primaryText.swiftUIColor }
    public var secondaryTextColor: Color { secondaryText.swiftUIColor }
    public var glassTintColor: Color { glassSurfaceTint.swiftUIColor }
    public var accentColor: Color { accentTint.swiftUIColor }

    public func buttonColor(for button: ReviewButton) -> Color {
        switch button {
        case .again: return buttonAgainTint.swiftUIColor
        case .hard: return buttonHardTint.swiftUIColor
        case .good: return buttonGoodTint.swiftUIColor
        case .easy: return buttonEasyTint.swiftUIColor
        }
    }

    /// 단어 실패 누적(`failureCount`)에 따른 배경 심연(Erosion) 보간 색상 반환
    public func skyColors(withFailureCount failureCount: Int, maxFailures: Int = 7) -> [Color] {
        let progress = ThemePalette.erosionProgress(forFailureCount: failureCount, maxFailuresBeforeCap: maxFailures)
        guard progress > 0 else { return skySwiftUIColors }
        return zip(skyGradient, ThemePalette.erosionTargets).map { base, target in
            base.interpolated(to: target, progress: progress * 0.72).swiftUIColor
        }
    }

    /// OKLCH 한 점 (명도 L · 채도 C · 색상각 h)
    struct SkyTone {
        var lightness: Double
        var chroma: Double
        var hue: Double
    }

    /// 날씨가 기준 하늘을 바꾸는 방식
    struct SkyMood {
        var chroma: Double = 1.0            // 채도 배율
        var lightness: Double = 0           // 낮 명도 이동
        var nightLightness: Double? = nil   // 밤 명도 이동 (없으면 낮 값의 40%)
        var spread: Double = 1.0            // 3단 사이 명도 폭 (작을수록 뿌연 하늘)
        var hue: Double = 250               // 끌려가는 색상각
        var hueWeight: Double = 0           // 끌림 정도 0 ~ 1
    }

    /// 시간대별 맑은 하늘 3단
    static func clearSky(_ timeOfDay: SkyTimeOfDay) -> [SkyTone] {
        switch timeOfDay {
        case .dawn:
            return [SkyTone(lightness: 0.36, chroma: 0.08, hue: 275),
                    SkyTone(lightness: 0.52, chroma: 0.08, hue: 305),
                    SkyTone(lightness: 0.80, chroma: 0.09, hue: 50)]
        case .morning:
            return [SkyTone(lightness: 0.45, chroma: 0.13, hue: 257),
                    SkyTone(lightness: 0.54, chroma: 0.12, hue: 249),
                    SkyTone(lightness: 0.83, chroma: 0.06, hue: 232)]
        case .midday:
            return [SkyTone(lightness: 0.41, chroma: 0.14, hue: 259),
                    SkyTone(lightness: 0.52, chroma: 0.13, hue: 251),
                    SkyTone(lightness: 0.80, chroma: 0.07, hue: 236)]
        case .sunset:
            return [SkyTone(lightness: 0.29, chroma: 0.08, hue: 285),
                    SkyTone(lightness: 0.45, chroma: 0.11, hue: 345),
                    SkyTone(lightness: 0.72, chroma: 0.13, hue: 52)]
        case .night:
            return [SkyTone(lightness: 0.16, chroma: 0.05, hue: 268),
                    SkyTone(lightness: 0.22, chroma: 0.06, hue: 265),
                    SkyTone(lightness: 0.32, chroma: 0.07, hue: 260)]
        }
    }

    static func mood(for condition: WeatherCondition, timeOfDay: SkyTimeOfDay) -> SkyMood {
        switch condition {
        case .clear: return SkyMood()
        case .partlyCloudy: return SkyMood(chroma: 0.85, lightness: 0.02)
        case .cloudy: return SkyMood(chroma: 0.5, lightness: 0.05, spread: 0.8, hue: 250, hueWeight: 0.3)
        case .overcast: return SkyMood(chroma: 0.22, lightness: 0.15, nightLightness: 0.05, spread: 0.55, hue: 245, hueWeight: 0.6)
        case .drizzle: return SkyMood(chroma: 0.35, lightness: 0.03, spread: 0.7, hue: 240, hueWeight: 0.5)
        case .rain: return SkyMood(chroma: 0.35, lightness: -0.07, nightLightness: -0.03, spread: 0.8, hue: 240, hueWeight: 0.6)
        case .thunderstorm: return SkyMood(chroma: 0.45, lightness: -0.17, nightLightness: -0.05, hue: 280, hueWeight: 0.5)
        case .typhoon: return SkyMood(chroma: 0.32, lightness: -0.19, nightLightness: -0.05, hue: 215, hueWeight: 0.6)
        case .sleet: return SkyMood(chroma: 0.26, lightness: 0.05, spread: 0.7, hue: 235, hueWeight: 0.6)
        case .hail: return SkyMood(chroma: 0.3, lightness: -0.09, nightLightness: -0.03, hue: 200, hueWeight: 0.5)
        case .snow: return SkyMood(chroma: 0.3, lightness: 0.21, nightLightness: 0.08, spread: 0.6, hue: 245, hueWeight: 0.7)
        case .blizzard: return SkyMood(chroma: 0.16, lightness: 0.25, nightLightness: 0.12, spread: 0.35, hue: 235, hueWeight: 0.7)
        case .mist: return SkyMood(chroma: 0.42, lightness: 0.13, nightLightness: 0.05, spread: 0.6, hue: 230, hueWeight: 0.4)
        case .fog: return SkyMood(chroma: 0.2, lightness: 0.19, nightLightness: 0.08, spread: 0.4, hue: 240, hueWeight: 0.5)
        case .yellowDust: return SkyMood(chroma: 0.75, lightness: 0.07, nightLightness: 0.02, spread: 0.6, hue: 75, hueWeight: 1)
        case .heatwave: return SkyMood(chroma: 1.25, lightness: 0.03, hue: 50, hueWeight: 0.9)
        case .windy: return SkyMood(chroma: 0.9, lightness: 0.02, spread: 1.05)
        case .rainbow: return SkyMood(chroma: 1.05, lightness: 0.03, hue: 235, hueWeight: 0.2)
        case .aurora: return timeOfDay == .night ? SkyMood(chroma: 1.2, hue: 205, hueWeight: 0.45) : SkyMood()
        case .meteorShower: return timeOfDay == .night ? SkyMood(lightness: -0.04, nightLightness: -0.04) : SkyMood()
        case .cherryBlossom: return SkyMood(chroma: 0.9, lightness: 0.04, hue: 300, hueWeight: 0.25)
        // 단풍의 주황빛과 보색을 이루도록 짙고 맑은 가을 하늘
        case .autumnLeaves: return SkyMood(lightness: -0.02, hue: 245, hueWeight: 0.15)
        }
    }

    static func mixHue(_ from: Double, toward target: Double, weight: Double) -> Double {
        let delta = (target - from + 540).truncatingRemainder(dividingBy: 360) - 180
        let mixed = from + delta * weight
        return (mixed + 360).truncatingRemainder(dividingBy: 360)
    }

    static func skyTones(condition: WeatherCondition, timeOfDay: SkyTimeOfDay) -> [SkyTone] {
        let base = clearSky(timeOfDay)
        let mood = mood(for: condition, timeOfDay: timeOfDay)
        let shift = timeOfDay == .night ? (mood.nightLightness ?? mood.lightness * 0.4) : mood.lightness
        let midLightness = base[1].lightness
        return base.map { tone in
            SkyTone(
                lightness: min(0.95, max(0.08, midLightness + (tone.lightness - midLightness) * mood.spread + shift)),
                chroma: max(0.025, tone.chroma * mood.chroma),
                hue: mixHue(tone.hue, toward: mood.hue, weight: mood.hueWeight)
            )
        }
    }

    /// 기상 상태와 시간대(그리고 '오늘의 목표 완주 시 날씨가 개는 Hareru 효과')를 조합한 팔레트 산출
    public static func resolve(
        condition: WeatherCondition,
        timeOfDay: SkyTimeOfDay,
        isHareruCleared: Bool = false
    ) -> WeatherSkyPalette {
        // 오늘의 학습 목표를 달성해 날씨가 갠 상태(Hareru!)라면 맑고 청량한 하늘로 승격
        let effectiveCondition: WeatherCondition = isHareruCleared ? .clear : condition

        var tones = skyTones(condition: effectiveCondition, timeOfDay: timeOfDay)
        let skyHue = tones[1].hue
        func skyColors() -> [RGBAColor] {
            tones.map { RGBAColor.oklch(lightness: $0.lightness, chroma: $0.chroma, hueDegrees: $0.hue) }
        }
        var sky = skyColors()

        // 글자색: 하늘 색상각이 스며든 극단 명도 두 후보 중 천정·중단 대비가 더 높은 쪽
        func worstContrast(_ text: RGBAColor) -> Double {
            min(text.contrastRatio(against: sky[0]), text.contrastRatio(against: sky[1]))
        }
        let lightCandidate = RGBAColor.oklch(lightness: 0.975, chroma: 0.012, hueDegrees: skyHue)
        let darkCandidate = RGBAColor.oklch(lightness: 0.25, chroma: 0.045, hueDegrees: skyHue)
        let isDark = worstContrast(lightCandidate) >= worstContrast(darkCandidate)
        let primaryText = isDark ? lightCandidate : darkCandidate

        // 중간 명도(L ≈ 0.57) 하늘은 어느 글자색으로도 4.5:1에 못 미치므로,
        // 글자 대신 천정·중단 명도를 글자 반대쪽으로 조금씩 밀어 대비를 확보 (색상각·채도는 유지)
        var attempts = 0
        while worstContrast(primaryText) < 4.5 && attempts < 12 {
            for index in 0..<2 {
                tones[index].lightness += isDark ? -0.012 : 0.012
            }
            sky = skyColors()
            attempts += 1
        }

        let secondaryText: RGBAColor
        let glassTint: RGBAColor
        let accent: RGBAColor
        // 무채색에 가까운 하늘은 색상각이 불안정하므로 햇살 금빛(85°)을 보색 기준으로 사용
        let complementHue = tones[1].chroma < 0.03 ? 85 : (skyHue + 180).truncatingRemainder(dividingBy: 360)

        if isDark {
            secondaryText = RGBAColor.oklch(lightness: 0.87, chroma: 0.03, hueDegrees: skyHue, alpha: 0.9)
            glassTint = RGBAColor.oklch(
                lightness: max(0.18, tones[1].lightness * 0.62),
                chroma: tones[1].chroma * 0.7,
                hueDegrees: skyHue,
                alpha: 0.28
            )
            accent = isHareruCleared
                ? RGBAColor(hex: "#FDE047")!
                : RGBAColor.oklch(lightness: 0.85, chroma: 0.11, hueDegrees: complementHue)
        } else {
            secondaryText = RGBAColor.oklch(lightness: 0.40, chroma: 0.05, hueDegrees: skyHue, alpha: 0.9)
            glassTint = RGBAColor.oklch(lightness: 0.97, chroma: 0.012, hueDegrees: skyHue, alpha: 0.35)
            accent = RGBAColor.oklch(lightness: 0.47, chroma: 0.14, hueDegrees: tones[1].chroma < 0.03 ? 255 : skyHue)
        }

        // 4단계 평가 버튼: 고정 원색 대신 '지금 하늘'에서 파생한 인접색(Analogous) 한 세트
        // - 색상각: 하늘 중단 색의 색상각을 중심으로 ±24° 안에서만 움직여 어떤 날씨·카테고리 색과도 같은 계열로 어울림
        // - 채도: 낮게 고정해 알록달록하지 않게 (회색 하늘이면 차분한 블루 슬레이트 계열로)
        // - 명도: 모르겠음(가장 짙음) → 쉬움(가장 밝음) 순으로 단계를 둬 색이 비슷해도 순서가 읽히게 함
        // - 흰 글씨 대비 3:1 이상을 지키도록 밝은 하늘에서는 전체 명도를 낮춤
        let skyTone = sky[1].oklchComponents
        let anchorHue = skyTone.chroma < 0.02 ? 250.0 : skyTone.hueDegrees
        let baseLightness = isDark ? 0.50 : 0.45
        func gradeTint(step: Int, hueOffset: Double) -> RGBAColor {
            RGBAColor.oklch(
                lightness: baseLightness + Double(step) * 0.035,
                chroma: 0.055,
                hueDegrees: anchorHue + hueOffset
            )
        }
        let againTint = gradeTint(step: 0, hueOffset: -24)
        let hardTint  = gradeTint(step: 1, hueOffset: -8)
        let goodTint  = gradeTint(step: 2, hueOffset: 8)
        let easyTint  = gradeTint(step: 3, hueOffset: 24)

        return WeatherSkyPalette(
            skyGradient: sky,
            primaryText: primaryText,
            secondaryText: secondaryText,
            glassSurfaceTint: glassTint,
            accentTint: accent,
            isDarkSky: isDark,
            buttonAgainTint: againTint,
            buttonHardTint: hardTint,
            buttonGoodTint: goodTint,
            buttonEasyTint: easyTint
        )
    }
}

// MARK: - WCAG 대비 계산
extension RGBAColor {
    /// WCAG 2.x 상대 휘도
    var relativeLuminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    func contrastRatio(against other: RGBAColor) -> Double {
        let a = relativeLuminance, b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

// MARK: - 실시간 위치 권한(`CoreLocation`) + 날씨·시간대 상태 엔진
@Observable
public final class WeatherAtmosphereEngine: NSObject, CLLocationManagerDelegate {
    public static let shared = WeatherAtmosphereEngine()

    public var isAutomaticMode: Bool = true
    public var manualCondition: WeatherCondition = .rain
    public var manualTimeOfDay: SkyTimeOfDay = .night

    public private(set) var detectedCondition: WeatherCondition = .clear
    public private(set) var detectedTimeOfDay: SkyTimeOfDay = .midday
    public private(set) var temperatureCelsius: Int = 18
    public private(set) var locationTitle: String = "서울"
    public private(set) var locationAuthorized: Bool = false
    public private(set) var authorizationStatusDescription: String = "권한 대기 중"

    /// 오늘의 학습 목표 완주 시 구름이 걷히고 햇살이 비치는 '晴れる(Hareru)' 모드 활성화 여부
    public var isHareruClearedToday: Bool = false

    private let locationManager = CLLocationManager()

    public override init() {
        super.init()
        locationManager.delegate = self
        refreshAtmosphere(for: Date())
    }

    public var activeCondition: WeatherCondition {
        // 목표 완주(晴れる) 시에는 자동·수동 모드 모두 맑게 개어 팔레트와 파티클이 어긋나지 않도록 함
        if isHareruClearedToday {
            return .clear
        }
        return isAutomaticMode ? detectedCondition : manualCondition
    }

    public var activeTimeOfDay: SkyTimeOfDay {
        isAutomaticMode ? detectedTimeOfDay : manualTimeOfDay
    }

    public var activePalette: WeatherSkyPalette {
        WeatherSkyPalette.resolve(
            condition: activeCondition,
            timeOfDay: activeTimeOfDay,
            isHareruCleared: isHareruClearedToday
        )
    }

    public var weatherSummaryLine: String {
        let condLabel = isHareruClearedToday ? "맑게 갬 (晴れる)" : activeCondition.koreanTitle
        return "\(locationTitle) · \(condLabel) \(temperatureCelsius)° · \(activeTimeOfDay.koreanLabel)"
    }

    /// 온보딩 마지막 단계 또는 설정에서 사용자 위치 권한 요청
    public func requestLocationPermission() {
        #if os(iOS)
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
        #elseif os(macOS)
        locationManager.requestAlwaysAuthorization()
        locationManager.requestLocation()
        #endif
        refreshAtmosphere(for: Date())
    }

    /// 현재 시각과 위치(위경도 시드 기반 기상 추정)를 바탕으로 날씨·기온·시간대를 갱신합니다.
    public func refreshAtmosphere(for date: Date = Date(), coordinate: CLLocationCoordinate2D? = nil) {
        if let coordinate {
            lastCoordinate = coordinate
        }
        detectedTimeOfDay = SkyTimeOfDay.from(date: date, calendar: Calendar.current)
        let estimate = Self.estimatedWeather(for: date, coordinate: lastCoordinate)
        detectedCondition = estimate.condition
        temperatureCelsius = estimate.temperature
    }

    private var lastCoordinate: CLLocationCoordinate2D?

    /// 특정 날짜·위치의 계절감 있는 기상 상태와 기온을 결정적으로 추정합니다. (과거 잔디 말풍선의 '그날의 날씨'에도 사용)
    public static func estimatedWeather(
        for date: Date,
        coordinate: CLLocationCoordinate2D? = nil,
        calendar: Calendar = .current
    ) -> (condition: WeatherCondition, temperature: Int) {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let hour = calendar.component(.hour, from: date)
        let timeOfDay = SkyTimeOfDay.from(date: date, calendar: calendar)

        let latSeed = Int(((coordinate?.latitude ?? 37.5665) * 10).rounded())
        let lonSeed = Int(((coordinate?.longitude ?? 126.9780) * 10).rounded())
        let weatherHash = abs(month * 37 + day * 13 + (hour / 6) * 7 + latSeed + lonSeed) % 100
        let latitude = coordinate?.latitude ?? 37.5665

        // 계절별 후보: (날씨, 누적 확률 폭, 기준 기온, 기온 흔들림 폭)
        typealias Candidate = (condition: WeatherCondition, weight: Int, baseTemperature: Int, spread: Int)
        let candidates: [Candidate]
        switch month {
        case 3, 4, 5:
            let blossomWeek = month == 4 && day <= 15
            candidates = [
                (.clear, 22, 15, 7),
                (.partlyCloudy, blossomWeek ? 10 : 16, 14, 6),
                (.cherryBlossom, blossomWeek ? 24 : 0, 15, 5),
                (.yellowDust, month == 5 ? 6 : 14, 13, 6),
                (.cloudy, 10, 12, 5),
                (.drizzle, 9, 11, 4),
                (.rain, 9, 11, 4),
                (.windy, 6, 12, 5),
                (.mist, 6, 10, 4),
                (.hail, month == 5 ? 3 : 1, 12, 3),
                (.rainbow, 3, 16, 4),
            ]
        case 6, 7, 8:
            let monsoon = month == 6 && day >= 20 || month == 7 && day <= 25
            candidates = [
                (.heatwave, month == 6 ? 8 : 24, 33, 4),
                (.clear, 16, 29, 4),
                (.partlyCloudy, 12, 28, 4),
                (.rain, monsoon ? 22 : 10, 25, 4),
                (.drizzle, monsoon ? 8 : 3, 24, 3),
                (.thunderstorm, 10, 26, 3),
                (.typhoon, month == 8 ? 8 : 2, 24, 3),
                (.overcast, 6, 26, 3),
                (.rainbow, 4, 27, 3),
            ]
        case 9, 10, 11:
            let foliage = month == 10 || month == 11 && day <= 20
            candidates = [
                (.clear, 24, 18, 7),
                (.partlyCloudy, 14, 16, 6),
                (.autumnLeaves, foliage ? 20 : 0, 14, 6),
                (.typhoon, month == 9 ? 6 : 0, 22, 3),
                (.cloudy, 10, 13, 5),
                (.overcast, 6, 12, 4),
                (.rain, 8, 12, 4),
                (.fog, 7, 10, 4),
                (.mist, 5, 11, 4),
                (.windy, 6, 11, 5),
            ]
        default:
            candidates = [
                (.snow, 18, -2, 4),
                (.clear, 22, 2, 5),
                (.cloudy, 12, 1, 4),
                (.overcast, 10, 0, 4),
                (.blizzard, 5, -6, 3),
                (.sleet, 7, 1, 3),
                (.fog, 8, 0, 3),
                (.mist, 5, 1, 3),
                (.yellowDust, month == 2 ? 6 : 2, 3, 3),
                (.windy, 6, -1, 4),
            ]
        }

        let total = max(1, candidates.reduce(0) { $0 + $1.weight })
        var pick = weatherHash * total / 100
        var chosen = candidates[0]
        for candidate in candidates where candidate.weight > 0 {
            if pick < candidate.weight {
                chosen = candidate
                break
            }
            pick -= candidate.weight
        }
        var condition = chosen.condition
        var temperature = chosen.baseTemperature + weatherHash % max(1, chosen.spread)

        // 맑은 밤의 천문 현상: 고위도 오로라, 3대 유성우 극대일 (사분의자리 · 페르세우스 · 쌍둥이자리)
        if timeOfDay == .night && condition == .clear {
            let meteorPeak = (month == 1 && (3...4).contains(day))
                || (month == 8 && (11...13).contains(day))
                || (month == 12 && (13...14).contains(day))
            if meteorPeak {
                condition = .meteorShower
            } else if abs(latitude) >= 58 && weatherHash % 3 == 0 {
                condition = .aurora
            }
        }
        // 무지개는 해를 등지고 보는 현상이라 밤에는 비 갠 맑은 하늘로
        if timeOfDay == .night && condition == .rainbow {
            condition = .partlyCloudy
        }
        if condition == .heatwave && timeOfDay == .night {
            temperature -= 2
        }

        if timeOfDay == .night || timeOfDay == .dawn {
            temperature -= 4
        }
        return (condition, temperature)
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            locationAuthorized = true
            authorizationStatusDescription = "현재 위치 날씨 연동됨"
            manager.requestLocation()
        case .denied, .restricted:
            locationAuthorized = false
            authorizationStatusDescription = "기본 도시(서울) 날씨 적용 중"
        case .notDetermined:
            locationAuthorized = false
            authorizationStatusDescription = "위치 권한 미설정"
        @unknown default:
            locationAuthorized = false
            authorizationStatusDescription = "기본 날씨 적용 중"
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        locationAuthorized = true
        authorizationStatusDescription = "실시간 위치 날씨 연동됨"
        refreshAtmosphere(for: Date(), coordinate: loc.coordinate)

        CLGeocoder().reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            if let city = placemarks?.first?.locality ?? placemarks?.first?.administrativeArea {
                DispatchQueue.main.async {
                    self?.locationTitle = city
                }
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        refreshAtmosphere(for: Date())
    }
}
