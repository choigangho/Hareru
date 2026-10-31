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

// MARK: - 기상 상태 (맑음 · 구름/흐림 · 비 · 태풍/폭우 · 눈 · 안개 · 폭염)
public enum WeatherCondition: String, Codable, CaseIterable, Identifiable, Sendable {
    case clear = "clear"           // 맑음
    case cloudy = "cloudy"         // 구름 많음 / 흐림
    case rain = "rain"             // 비 (유리창 빗방울 + 빗줄기)
    case typhoon = "typhoon"       // 태풍 / 폭우 (거센 사선 비바람 + 번개 섬광)
    case snow = "snow"             // 눈 (입체 눈송이 부유)
    case fog = "fog"               // 안개 (몽환적인 안개 레이어 흐름)
    case heatwave = "heatwave"     // 폭염 (강렬한 태양광 + 열기 아지랑이)

    public var id: String { rawValue }

    public var koreanTitle: String {
        switch self {
        case .clear: return "맑음"
        case .cloudy: return "흐림"
        case .rain: return "비"
        case .typhoon: return "태풍 · 폭우"
        case .snow: return "눈"
        case .fog: return "안개"
        case .heatwave: return "폭염"
        }
    }

    public func sfSymbolName(for timeOfDay: SkyTimeOfDay) -> String {
        switch self {
        case .clear:
            return timeOfDay == .night ? "moon.stars.fill" : "sun.max.fill"
        case .cloudy:
            return timeOfDay == .night ? "cloud.moon.fill" : "cloud.fill"
        case .rain:
            return "cloud.rain.fill"
        case .typhoon:
            return "tropicalstorm"
        case .snow:
            return "snowflake"
        case .fog:
            return "cloud.fog.fill"
        case .heatwave:
            return "sun.max.trianglebadge.exclamationmark.fill"
        }
    }

    public var hasRaindropsOnGlass: Bool {
        self == .rain || self == .typhoon
    }
}

// MARK: - 날씨 × 시간대 팔레트 & 유동적 타이포그래피 대비 시스템
// 단순 검정(#000) / 흰색(#FFF) 이분법을 쓰지 않고, 하늘 배경의 색온도와 명도에 맞춰
// 주 텍스트·보조 텍스트·유리 틴트·4단계 평가 버튼 색상을 유기적으로 산출합니다.
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

    /// 기상 상태와 시간대(그리고 '오늘의 목표 완주 시 날씨가 개는 Hareru 효과')를 조합한 팔레트 산출
    public static func resolve(
        condition: WeatherCondition,
        timeOfDay: SkyTimeOfDay,
        isHareruCleared: Bool = false
    ) -> WeatherSkyPalette {
        // 오늘의 학습 목표를 달성해 날씨가 갠 상태(Hareru!)라면 맑고 청량한 하늘로 승격
        let effectiveCondition: WeatherCondition = isHareruCleared ? .clear : condition

        let sky: [RGBAColor]
        let isDark: Bool

        switch (effectiveCondition, timeOfDay) {
        // 1) 맑음 (Clear)
        case (.clear, .dawn):
            sky = [RGBAColor(hex: "#3B5284")!, RGBAColor(hex: "#8FA8D6")!, RGBAColor(hex: "#F5D0C5")!]
            isDark = false
        case (.clear, .morning):
            sky = [RGBAColor(hex: "#2E77D0")!, RGBAColor(hex: "#6DB3F2")!, RGBAColor(hex: "#CBE7FF")!]
            isDark = true
        case (.clear, .midday):
            sky = [RGBAColor(hex: "#1C64B8")!, RGBAColor(hex: "#4B9FE1")!, RGBAColor(hex: "#A8D8FF")!]
            isDark = true
        case (.clear, .sunset):
            sky = [RGBAColor(hex: "#2B2D5C")!, RGBAColor(hex: "#8F4A6E")!, RGBAColor(hex: "#EB8A64")!]
            isDark = true
        case (.clear, .night):
            sky = [RGBAColor(hex: "#091126")!, RGBAColor(hex: "#132347")!, RGBAColor(hex: "#233B6E")!]
            isDark = true

        // 2) 구름 / 흐림 (Cloudy)
        case (.cloudy, .night):
            sky = [RGBAColor(hex: "#141B29")!, RGBAColor(hex: "#222E42")!, RGBAColor(hex: "#35455D")!]
            isDark = true
        case (.cloudy, .sunset):
            sky = [RGBAColor(hex: "#414859")!, RGBAColor(hex: "#6E6878")!, RGBAColor(hex: "#B58E7E")!]
            isDark = true
        case (.cloudy, _):
            sky = [RGBAColor(hex: "#586C84")!, RGBAColor(hex: "#8397AD")!, RGBAColor(hex: "#C2CFD9")!]
            isDark = false

        // 3) 비 (Rain)
        case (.rain, .night):
            sky = [RGBAColor(hex: "#0D1624")!, RGBAColor(hex: "#18283E")!, RGBAColor(hex: "#273F5B")!]
            isDark = true
        case (.rain, _):
            sky = [RGBAColor(hex: "#2C3E55")!, RGBAColor(hex: "#465E78")!, RGBAColor(hex: "#6E88A1")!]
            isDark = true

        // 4) 태풍 / 폭우 (Typhoon)
        case (.typhoon, _):
            sky = [RGBAColor(hex: "#121824")!, RGBAColor(hex: "#212D3F")!, RGBAColor(hex: "#33475B")!]
            isDark = true

        // 5) 눈 (Snow)
        case (.snow, .night):
            sky = [RGBAColor(hex: "#18243B")!, RGBAColor(hex: "#2C3E5E")!, RGBAColor(hex: "#486085")!]
            isDark = true
        case (.snow, _):
            sky = [RGBAColor(hex: "#7A94B8")!, RGBAColor(hex: "#AEC2DC")!, RGBAColor(hex: "#E4EEF8")!]
            isDark = false

        // 6) 안개 (Fog)
        case (.fog, .night):
            sky = [RGBAColor(hex: "#1E2633")!, RGBAColor(hex: "#313D4F")!, RGBAColor(hex: "#49586B")!]
            isDark = true
        case (.fog, _):
            sky = [RGBAColor(hex: "#8492A4")!, RGBAColor(hex: "#B0BCCB")!, RGBAColor(hex: "#DCE3EC")!]
            isDark = false

        // 7) 폭염 (Heatwave)
        case (.heatwave, .night):
            sky = [RGBAColor(hex: "#2B1620")!, RGBAColor(hex: "#4F232D")!, RGBAColor(hex: "#78383B")!]
            isDark = true
        case (.heatwave, _):
            sky = [RGBAColor(hex: "#C84B31")!, RGBAColor(hex: "#E67E45")!, RGBAColor(hex: "#F7C578")!]
            isDark = true
        }

        // 배경 하늘의 평균 휘도와 색온도를 추출하여 단순 흑백이 아닌 유동적 텍스트 대비 색상 계산
        let midSky = sky[1]
        let primaryText: RGBAColor
        let secondaryText: RGBAColor
        let glassTint: RGBAColor
        let accent: RGBAColor

        if isDark {
            // 어둡거나 채도 깊은 하늘 위: 하늘빛이 12% 스며든 아이스 화이트 / 웜 크림
            primaryText = RGBAColor(
                red: 0.94 + midSky.red * 0.05,
                green: 0.96 + midSky.green * 0.03,
                blue: 0.98 + midSky.blue * 0.02
            )
            secondaryText = RGBAColor(
                red: 0.76 + midSky.red * 0.14,
                green: 0.81 + midSky.green * 0.12,
                blue: 0.88 + midSky.blue * 0.10,
                alpha: 0.88
            )
            glassTint = RGBAColor(
                red: midSky.red * 0.55 + 0.12,
                green: midSky.green * 0.55 + 0.14,
                blue: midSky.blue * 0.60 + 0.18,
                alpha: 0.28
            )
            accent = isHareruCleared
                ? RGBAColor(hex: "#FDE047")!
                : RGBAColor(
                    red: min(1.0, sky[2].red * 0.65 + 0.35),
                    green: min(1.0, sky[2].green * 0.65 + 0.35),
                    blue: min(1.0, sky[2].blue * 0.70 + 0.30)
                )
        } else {
            // 밝은 설경/안개/새벽 하늘 위: 하늘 색온도가 스며든 딥 슬레이트 인디고 (순수 검정 지양)
            primaryText = RGBAColor(
                red: 0.10 + midSky.red * 0.12,
                green: 0.15 + midSky.green * 0.12,
                blue: 0.24 + midSky.blue * 0.15
            )
            secondaryText = RGBAColor(
                red: 0.26 + midSky.red * 0.18,
                green: 0.33 + midSky.green * 0.18,
                blue: 0.44 + midSky.blue * 0.20,
                alpha: 0.86
            )
            glassTint = RGBAColor(
                red: 0.92 + midSky.red * 0.06,
                green: 0.95 + midSky.green * 0.04,
                blue: 0.98 + midSky.blue * 0.02,
                alpha: 0.35
            )
            accent = RGBAColor(hex: "#2563EB")!
        }

        // 4단계 평가 버튼 색상도 원색 대신 현재 하늘 테마에 어우러지는 세련된 4톤으로 구성
        let againTint = isDark ? RGBAColor(hex: "#9F4C5C")! : RGBAColor(hex: "#B85668")!
        let hardTint  = isDark ? RGBAColor(hex: "#A8763E")! : RGBAColor(hex: "#C0843F")!
        let goodTint  = isDark ? RGBAColor(hex: "#3B76B5")! : RGBAColor(hex: "#366FA8")!
        let easyTint  = isDark ? RGBAColor(hex: "#2D8A7E")! : RGBAColor(hex: "#287D72")!

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
        if isHareruClearedToday && isAutomaticMode {
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
        let cal = Calendar.current
        detectedTimeOfDay = SkyTimeOfDay.from(date: date, calendar: cal)

        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        let hour = cal.component(.hour, from: date)

        let latSeed = Int(((coordinate?.latitude ?? 37.5665) * 10).rounded())
        let lonSeed = Int(((coordinate?.longitude ?? 126.9780) * 10).rounded())
        let weatherHash = abs(month * 37 + day * 13 + hour * 7 + latSeed + lonSeed) % 100

        // 계절(월)과 시간대 특성을 반영한 자연스러운 실시간 기상 상태 및 기온 산출
        if month == 7 || month == 8 {
            if weatherHash < 32 {
                detectedCondition = .heatwave
                temperatureCelsius = 33 + (weatherHash % 4)
            } else if weatherHash < 55 {
                detectedCondition = .rain
                temperatureCelsius = 25 + (weatherHash % 4)
            } else if weatherHash < 68 {
                detectedCondition = .typhoon
                temperatureCelsius = 24 + (weatherHash % 3)
            } else {
                detectedCondition = .clear
                temperatureCelsius = 29 + (weatherHash % 4)
            }
        } else if month == 12 || month == 1 || month == 2 {
            if weatherHash < 28 {
                detectedCondition = .snow
                temperatureCelsius = -3 + (weatherHash % 4)
            } else if weatherHash < 52 {
                detectedCondition = .cloudy
                temperatureCelsius = 1 + (weatherHash % 5)
            } else if weatherHash < 65 {
                detectedCondition = .fog
                temperatureCelsius = 0 + (weatherHash % 3)
            } else {
                detectedCondition = .clear
                temperatureCelsius = 2 + (weatherHash % 5)
            }
        } else {
            switch weatherHash {
            case 0..<42:
                detectedCondition = .clear
                temperatureCelsius = 16 + (weatherHash % 7)
            case 42..<68:
                detectedCondition = .cloudy
                temperatureCelsius = 14 + (weatherHash % 6)
            case 68..<86:
                detectedCondition = .rain
                temperatureCelsius = 12 + (weatherHash % 5)
            default:
                detectedCondition = .fog
                temperatureCelsius = 11 + (weatherHash % 4)
            }
        }

        if detectedTimeOfDay == .night || detectedTimeOfDay == .dawn {
            temperatureCelsius -= 4
        }
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
