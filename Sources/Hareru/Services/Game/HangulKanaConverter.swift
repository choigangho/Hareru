import Foundation

// MARK: - 미션 어휘 한정 한글 발음 매칭 엔트리 (SPEC.md §1.3)
public struct HangulPhoneticEntry: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let surface: String                  // 변환 결과 일본어 표기 (예: "乾杯", "ビール", "しましょう")
    public let reading: String                  // 히라가나 발음 (예: "かんぱい")
    public let meaning: String                  // 뜻·문법 설명 (예: "건배", "~합시다")
    public let acceptedHangulVariants: [String] // 허용 한글 발음 목록 (예: ["칸파이", "간파이", "캄파이"])
    public let isMissionTarget: Bool            // 현재 스테이지 핵심 목표 표현 여부

    public init(
        id: String,
        surface: String,
        reading: String,
        meaning: String,
        acceptedHangulVariants: [String],
        isMissionTarget: Bool = true
    ) {
        self.id = id
        self.surface = surface
        self.reading = reading
        self.meaning = meaning
        self.acceptedHangulVariants = acceptedHangulVariants
        self.isMissionTarget = isMissionTarget
    }
}

// MARK: - 한글 발음 변환 후보 결과
public struct HangulConversionCandidate: Identifiable, Equatable, Sendable {
    public let entry: HangulPhoneticEntry
    public let matchedHangul: String
    public let score: Double

    public var id: String { entry.id }
}

// MARK: - 미션 컨텍스트 기반 한글 발음 → 일본어 자동 변환기 (SPEC.md §1.3)
/// 별도의 일본어 키보드 설정 없이 한글 자판으로 발음을 입력하면
/// 미션 후보 어휘 풀과 자모 음운 유사도(예: 칸파이/간파이/캄파이 → 乾杯)를 매칭해 일본어로 즉시 변환합니다.
public struct HangulKanaConverter: Sendable {
    public let entries: [HangulPhoneticEntry]

    public init(entries: [HangulPhoneticEntry] = Self.defaultMissionPool) {
        self.entries = entries
    }

    // MARK: - 1) 실시간 입력 토큰에 대한 추천 변환 칩 조회

    /// 현재 입력 중인 마지막 어절(또는 전체 입력)과 매칭되는 일본어 후보 목록 반환
    public func suggestCandidates(for rawInput: String, limit: Int = 5) -> [HangulConversionCandidate] {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            // 입력 전에는 현재 턴의 핵심 미션 어휘를 기본 가이드 칩으로 노출
            return entries
                .filter(\.isMissionTarget)
                .prefix(limit)
                .map { HangulConversionCandidate(entry: $0, matchedHangul: $0.acceptedHangulVariants.first ?? "", score: 1.0) }
        }

        let lastToken = String(trimmed.split(whereSeparator: \.isWhitespace).last ?? Substring(trimmed))
        let querySkeleton = Self.phoneticSkeleton(for: lastToken)
        guard !querySkeleton.isEmpty else { return [] }

        var results: [HangulConversionCandidate] = []

        for entry in entries {
            var bestScore: Double = 0.0
            var bestVariant: String = entry.acceptedHangulVariants.first ?? ""

            for variant in entry.acceptedHangulVariants {
                let variantSkeleton = Self.phoneticSkeleton(for: variant)
                guard !variantSkeleton.isEmpty else { continue }

                let score: Double
                if variant == lastToken {
                    score = 1.0
                } else if variantSkeleton == querySkeleton {
                    score = 0.96
                } else if variantSkeleton.hasPrefix(querySkeleton) || querySkeleton.hasPrefix(variantSkeleton) {
                    let ratio = Double(min(querySkeleton.count, variantSkeleton.count))
                        / Double(max(querySkeleton.count, variantSkeleton.count))
                    score = 0.75 + 0.18 * ratio
                } else if variantSkeleton.contains(querySkeleton) {
                    score = 0.68
                } else {
                    score = Self.similarity(lhs: querySkeleton, rhs: variantSkeleton)
                }

                if score > bestScore {
                    bestScore = score
                    bestVariant = variant
                }
            }

            if bestScore >= 0.62 {
                let targetBoost = entry.isMissionTarget ? 0.02 : 0.0
                results.append(
                    HangulConversionCandidate(
                        entry: entry,
                        matchedHangul: bestVariant,
                        score: min(1.0, bestScore + targetBoost)
                    )
                )
            }
        }

        results.sort { lhs, rhs in
            if abs(lhs.score - rhs.score) > 0.001 {
                return lhs.score > rhs.score
            }
            if lhs.entry.isMissionTarget != rhs.entry.isMissionTarget {
                return lhs.entry.isMissionTarget
            }
            return lhs.entry.id < rhs.entry.id
        }

        return Array(results.prefix(limit))
    }

    // MARK: - 2) 한글 발음 문장 전체 → 일본어 문장 자동 변환

    /// `"토리아에즈 비루데 칸파이 시마쇼"` 또는 `"간파이 시마쇼"` 같은 한글 발음 입력을
    /// 미션 어휘 최장 일치 + 조사/어미 음절 매핑으로 즉시 일본어 문장(`"とりあえず、ビールで乾杯しましょう。"`)으로 변환합니다.
    public func convertFullInput(_ rawInput: String) -> String {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // 공백을 제거한 연속 문자열에서도 최장 일치 어휘 매칭이 작동하도록 정규화
        let compact = trimmed.replacingOccurrences(of: " ", with: "")
        let chars = Array(compact)

        // (변형 한글 문자열, 치환 일본어 표기, 음운 골격) 사전 준비 (길이 내림차순)
        var phrasePatterns: [(hangul: String, skeleton: String, charCount: Int, surface: String)] = []
        for entry in entries {
            for variant in entry.acceptedHangulVariants {
                let cleanVariant = variant.replacingOccurrences(of: " ", with: "")
                guard !cleanVariant.isEmpty else { continue }
                phrasePatterns.append((
                    hangul: cleanVariant,
                    skeleton: Self.phoneticSkeleton(for: cleanVariant),
                    charCount: cleanVariant.count,
                    surface: entry.surface
                ))
            }
        }
        phrasePatterns.sort { lhs, rhs in
            if lhs.charCount != rhs.charCount {
                return lhs.charCount > rhs.charCount
            }
            return lhs.hangul < rhs.hangul
        }

        var output = ""
        var cursor = 0

        while cursor < chars.count {
            let currentChar = chars[cursor]

            // 이미 일본어(한자·히라가나·가타카나)이거나 문장부호면 그대로 보존
            if !Self.isHangulSyllable(currentChar) {
                output.append(currentChar)
                cursor += 1
                continue
            }

            // 1) 미션 어휘·문법 최장 일치 탐색 (정확 일치 및 음운 골격 일치)
            var matchedPattern: (charCount: Int, surface: String)?
            for pattern in phrasePatterns where cursor + pattern.charCount <= chars.count {
                let slice = String(chars[cursor..<(cursor + pattern.charCount)])
                if slice == pattern.hangul || Self.phoneticSkeleton(for: slice) == pattern.skeleton {
                    matchedPattern = (pattern.charCount, pattern.surface)
                    break
                }
            }

            if let match = matchedPattern {
                output += match.surface
                // 'とりあえず' 단독 매칭 직후 자연스러운 쉼표 보정 (뒤에 바로 쉼표가 없을 때)
                if match.surface == "とりあえず",
                   cursor + match.charCount < chars.count,
                   chars[cursor + match.charCount] != "、" && chars[cursor + match.charCount] != "," {
                    output += "、"
                }
                cursor += match.charCount
                continue
            }

            // 2) 단일 한글 음절 → 히라가나 조사/어미 변환 (예: '데' → 'で', '오' → 'を', '네' → 'ね')
            if let kana = Self.singleSyllableToHiragana[currentChar] {
                output += kana
            } else {
                output.append(currentChar)
            }
            cursor += 1
        }

        return output
    }

    // MARK: - 3) 한글 음운 골격 정규화 (예: 칸파이 == 간파이 == 캄파이 == 깐파이)

    /// 한국어 화자가 일본어 발음을 한글로 적을 때 흔히 혼동하는
    /// 평음/경음/격음(ㄱ·ㄲ·ㅋ, ㄷ·ㄸ·ㅌ, ㅂ·ㅃ·ㅍ, ㅈ·ㅉ·ㅊ, ㅅ·ㅆ), 모음(ㅐ·ㅔ), 받침(ㅁ·ㄴ·ㅇ)을 동일 음운 골격으로 정규화합니다.
    public static func phoneticSkeleton(for text: String) -> String {
        let initialMap: [Int: Character] = [
            0: "K", 1: "K", 15: "K", // ㄱ, ㄲ, ㅋ -> K
            2: "N",                  // ㄴ -> N
            3: "T", 4: "T", 16: "T", // ㄷ, ㄸ, ㅌ -> T
            5: "R",                  // ㄹ -> R
            6: "M",                  // ㅁ -> M
            7: "P", 8: "P", 17: "P", // ㅂ, ㅃ, ㅍ -> P
            9: "S", 10: "S",         // ㅅ, ㅆ -> S
            11: "O",                 // ㅇ -> O
            12: "J", 13: "J", 14: "J", // ㅈ, ㅉ, ㅊ -> J
            18: "H"                  // ㅎ -> H
        ]

        let vowelMap: [Int: String] = [
            0: "A",  1: "E",  2: "YA", 3: "YE", 4: "EO",
            5: "E",  6: "YEO", 7: "YE", 8: "O",  9: "WA",
            10: "WE", 11: "OE", 12: "YO", 13: "U", 14: "WO",
            15: "WE", 16: "WI", 17: "YU", 18: "EU", 19: "UI",
            20: "I"
        ]

        var result = ""
        for scalar in text.unicodeScalars {
            // 한글 완성형 음절 (가 ~ 힣: 0xAC00 ... 0xD7A3)
            if (0xAC00...0xD7A3).contains(scalar.value) {
                let offset = Int(scalar.value - 0xAC00)
                let initial = offset / (21 * 28)
                let vowel = (offset % (21 * 28)) / 28
                let final = offset % 28

                // 일본어 장음 축약 보정: '비이루'의 '이'나 '시마쇼우'/'시마쇼오'의 '우'/'오'를 유연하게 흡수
                let initChar = initialMap[initial] ?? "X"
                let vowelStr = vowelMap[vowel] ?? "A"

                // 직전 음절이 같은 모음 계열이고 현재 초성이 'ㅇ'인 장음 표기('비이', '라아', '쇼우', '쇼오')는 생략해 단음 표기와 동일화
                if initChar == "O" && !result.isEmpty {
                    if (vowelStr == "I" && result.hasSuffix("I")) ||
                       (vowelStr == "A" && result.hasSuffix("A")) ||
                       ((vowelStr == "U" || vowelStr == "O") && (result.hasSuffix("O") || result.hasSuffix("YO"))) {
                        continue
                    }
                }

                result.append(initChar)
                result += vowelStr

                // 일본어 발음(ん)에 대응하는 받침(ㄴ=4, ㅁ=16, ㅇ=21)은 모두 'N'으로 통일, 촉음(ㅅ=19, ㄱ=1, ㅂ=17)은 'Q'
                if final == 4 || final == 16 || final == 21 {
                    result.append("N")
                } else if final != 0 {
                    result.append("Q")
                }
            } else if !scalar.properties.isWhitespace {
                result.append(Character(scalar))
            }
        }
        return result
    }

    private static func isHangulSyllable(_ ch: Character) -> Bool {
        guard let scalar = ch.unicodeScalars.first else { return false }
        return (0xAC00...0xD7A3).contains(scalar.value)
    }

    private static func similarity(lhs: String, rhs: String) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0.0 }
        let dist = levenshteinDistance(Array(lhs), Array(rhs))
        let maxLen = max(lhs.count, rhs.count)
        return max(0.0, 1.0 - Double(dist) / Double(maxLen))
    }

    private static func levenshteinDistance(_ a: [Character], _ b: [Character]) -> Int {
        var prev = Array(0...b.count)
        for (i, ca) in a.enumerated() {
            var curr = Array(repeating: 0, count: b.count + 1)
            curr[0] = i + 1
            for (j, cb) in b.enumerated() {
                let cost = (ca == cb) ? 0 : 1
                curr[j + 1] = min(
                    prev[j + 1] + 1,
                    curr[j] + 1,
                    prev[j] + cost
                )
            }
            prev = curr
        }
        return prev[b.count]
    }

    // MARK: - 기본 조사·어미 한글 음절 → 히라가나 매핑 테이블

    private static let singleSyllableToHiragana: [Character: String] = [
        "아": "あ", "이": "い", "우": "う", "에": "え", "오": "お",
        "카": "か", "가": "が", "키": "き", "기": "ぎ", "쿠": "く", "구": "ぐ", "케": "け", "게": "げ", "코": "こ", "고": "ご",
        "사": "さ", "자": "ざ", "시": "し", "지": "じ", "스": "す", "즈": "ず", "세": "せ", "제": "ぜ", "소": "そ", "조": "ぞ",
        "타": "た", "다": "だ", "치": "ち", "츠": "つ", "테": "て", "데": "で", "토": "と", "도": "ど",
        "나": "な", "니": "に", "누": "ぬ", "네": "ね", "노": "の",
        "하": "は", "바": "ば", "파": "ぱ", "히": "ひ", "비": "び", "후": "ふ", "부": "ぶ", "헤": "へ", "베": "べ", "호": "ほ", "보": "ぼ",
        "마": "ま", "미": "み", "무": "む", "메": "め", "모": "も",
        "야": "や", "유": "ゆ", "요": "よ",
        "라": "ら", "리": "り", "루": "る", "레": "れ", "로": "ろ",
        "와": "わ", "을": "を", "를": "を"
    ]

    // MARK: - 기본 미션 어휘·표현 풀 (이자카야 · 오피스 · 일상 스테이지 공용)

    public static let defaultMissionPool: [HangulPhoneticEntry] = [
        HangulPhoneticEntry(
            id: "pool_toriaezu",
            surface: "とりあえず",
            reading: "とりあえず",
            meaning: "우선, 일단",
            acceptedHangulVariants: ["토리아에즈", "도리아에즈", "토리아애즈", "도리아애즈"]
        ),
        HangulPhoneticEntry(
            id: "pool_beer",
            surface: "ビール",
            reading: "びーる",
            meaning: "맥주",
            acceptedHangulVariants: ["비루", "비이루", "삐루"]
        ),
        HangulPhoneticEntry(
            id: "pool_kanpai",
            surface: "乾杯",
            reading: "かんぱい",
            meaning: "건배",
            acceptedHangulVariants: ["칸파이", "간파이", "캄파이", "감파이", "깐파이"]
        ),
        HangulPhoneticEntry(
            id: "pool_shimashou",
            surface: "しましょう",
            reading: "しましょう",
            meaning: "~합시다 (권유)",
            acceptedHangulVariants: ["시마쇼", "시마쇼우", "시마쇼오"]
        ),
        HangulPhoneticEntry(
            id: "pool_amai",
            surface: "甘い",
            reading: "あまい",
            meaning: "달콤하다 / 만만하다 / 허술하다",
            acceptedHangulVariants: ["아마이"]
        ),
        HangulPhoneticEntry(
            id: "pool_amakute",
            surface: "甘くて",
            reading: "あまくて",
            meaning: "달콤해서",
            acceptedHangulVariants: ["아마쿠테", "아마구테", "아마꾸테"]
        ),
        HangulPhoneticEntry(
            id: "pool_oishii",
            surface: "美味しい",
            reading: "おいしい",
            meaning: "맛있다",
            acceptedHangulVariants: ["오이시이", "오이시"]
        ),
        HangulPhoneticEntry(
            id: "pool_shime",
            surface: "締め",
            reading: "しめ",
            meaning: "마무리",
            acceptedHangulVariants: ["시메", "시매"]
        ),
        HangulPhoneticEntry(
            id: "pool_tonkotsu",
            surface: "豚骨",
            reading: "とんこつ",
            meaning: "돈코츠(돼지뼈 육수)",
            acceptedHangulVariants: ["돈코츠", "톤코츠", "돈고츠", "돈꼬츠"]
        ),
        HangulPhoneticEntry(
            id: "pool_ramen",
            surface: "ラーメン",
            reading: "らーめん",
            meaning: "라멘",
            acceptedHangulVariants: ["라멘", "라아멘"]
        ),
        HangulPhoneticEntry(
            id: "pool_desune",
            surface: "ですね",
            reading: "ですね",
            meaning: "~이네요 (공감)",
            acceptedHangulVariants: ["데스네", "대스네"]
        ),
        HangulPhoneticEntry(
            id: "pool_goyoyaku",
            surface: "ご予約",
            reading: "ごよやく",
            meaning: "예약(정중어)",
            acceptedHangulVariants: ["고요야쿠", "고요약쿠", "요야쿠"]
        ),
        HangulPhoneticEntry(
            id: "pool_uketamawarimasu",
            surface: "承ります",
            reading: "うけたまわります",
            meaning: "(삼가) 접수하겠습니다",
            acceptedHangulVariants: ["우케타마와리마스", "우게타마와리마스", "우케따마와리마스"]
        ),
        HangulPhoneticEntry(
            id: "pool_shounin",
            surface: "承認",
            reading: "しょうにん",
            meaning: "승인",
            acceptedHangulVariants: ["쇼닌", "쇼우닌", "쇼오닌"]
        ),
        HangulPhoneticEntry(
            id: "pool_kansou",
            surface: "乾燥",
            reading: "かんそう",
            meaning: "건조",
            acceptedHangulVariants: ["칸소", "간소", "칸소우", "간소우"]
        )
    ]
}
