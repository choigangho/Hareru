import SwiftUI

// MARK: - 샘플 단어 데이터 저장소
extension Word {
    static let samples: [Word] = [.beer, .ramen]

    static let beer = Word(
        category: "음식",
        term: "ビール",
        reading: "びーる",
        meaning: "맥주",
        example: "とりあえず、ビールで乾杯しましょう。",
        transBefore: "일단 ",
        transAnswer: "맥주",
        transAfter: "로 건배합시다.",
        colors: [
            Color(red: 1.00, green: 0.78, blue: 0.20),  // 노랑 (맥주 본체)
            Color(red: 0.98, green: 0.96, blue: 0.90),  // 흰색 (거품)
            Color(red: 0.45, green: 0.26, blue: 0.12)   // 갈색 (이자카야 분위기)
        ],
        voice: .buchou,
        termAudioFile: "beer_term",
        exampleAudioFile: "beer_example"
    )

    static let ramen = Word(
        category: "음식",
        term: "ラーメン",
        reading: "らーめん",
        meaning: "라멘",
        example: "締めはやっぱり豚骨ラーメンですね。",
        transBefore: "마무리는 역시 돈코츠 ",
        transAnswer: "라멘",
        transAfter: "이네요.",
        colors: [
            Color(red: 0.85, green: 0.22, blue: 0.18),  // 빨강 (라멘 그릇/식욕)
            Color(red: 0.96, green: 0.88, blue: 0.70),  // 베이지 (진한 돈코츠 국물)
            Color(red: 0.25, green: 0.15, blue: 0.10)   // 진갈색 (차슈/나무 젓가락)
        ],
        voice: .tenchou,
        termAudioFile: "ramen_term",
        exampleAudioFile: "ramen_example"
    )
}
