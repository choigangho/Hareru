import Foundation

// MARK: - 샘플 단어 & 한자 마스터 데이터 (유닛 테스트 · 프리뷰 · 초기 부트스트랩 겸용)
extension Word {
    public static let samples: [Word] = [
        .beer,
        .ramen,
        .amai,
        .kanpai,
        .kansou,
        .uketamawaru,
        .shounin,
        .toriaezu
    ]

    public static let beer = Word(
        id: "n5_food_beer",
        jlptLevel: .n5,
        category: "음식",
        term: "ビール",
        reading: "びーる",
        pitchAccent: 1,
        palette: ThemePalette(hexColors: ["#FFC733", "#FAF5E6", "#73421F"]),
        termAudioFile: "beer_term",
        senses: [
            WordSense(
                id: "n5_food_beer_s1",
                senseNumber: 1,
                partOfSpeech: "명사",
                meaning: "맥주",
                exampleMarkup: "とりあえず、ビールで{乾杯|かんぱい}しましょう。",
                translation: SplitTranslation(
                    before: "일단 ",
                    answer: "맥주",
                    after: "로 건배합시다."
                ),
                voice: .buchou,
                exampleAudioFile: "beer_example"
            )
        ],
        nonKanjiNote: NonKanjiNote(
            kind: .loanword,
            originLanguage: "Dutch / English",
            originTerm: "bier / beer",
            explanation: "네덜란드어 bier에서 유래해 가타카나로 정착한 외래어"
        )
    )

    public static let ramen = Word(
        id: "n5_food_ramen",
        jlptLevel: .n5,
        category: "음식",
        term: "ラーメン",
        reading: "らーめん",
        pitchAccent: 1,
        palette: ThemePalette(hexColors: ["#D9382E", "#F5E0B3", "#40261A"]),
        termAudioFile: "ramen_term",
        senses: [
            WordSense(
                id: "n5_food_ramen_s1",
                senseNumber: 1,
                partOfSpeech: "명사",
                meaning: "라멘",
                exampleMarkup: "{締め|し}はやっぱり{豚骨|とんこつ}ラーメンですね。",
                translation: SplitTranslation(
                    before: "마무리는 역시 돈코츠 ",
                    answer: "라멘",
                    after: "이네요."
                ),
                voice: .tenchou,
                exampleAudioFile: "ramen_example"
            )
        ],
        nonKanjiNote: NonKanjiNote(
            kind: .loanword,
            originLanguage: "Chinese",
            originTerm: "拉麺 (lāmiàn)",
            explanation: "중국어 라몐(拉麺)에서 유래해 일상 가타카나로 굳어진 외래어"
        )
    )

    /// 다의어 1단어 1카드 대표 샘플: 대표 의미(1) + 서브 의미(2, 3)
    public static let amai = Word(
        id: "n5_adj_amai",
        jlptLevel: .n5,
        category: "감각·판단",
        term: "甘い",
        reading: "あまい",
        pitchAccent: 0,
        palette: ThemePalette(hexColors: ["#F472B6", "#FFFBEB", "#831843"]),
        termAudioFile: "amai_term",
        senses: [
            WordSense(
                id: "n5_adj_amai_s1",
                senseNumber: 1,
                partOfSpeech: "イ형용사",
                meaning: "달다, 달콤하다",
                exampleMarkup: "このケーキ、ほどよく{甘|あま}くて{美味|おい}しいですね。",
                translation: SplitTranslation(
                    before: "이 케이크, 적당히 ",
                    answer: "달콤해서",
                    after: " 맛있네요."
                ),
                voice: .cafeStaff,
                exampleAudioFile: "amai_s1_example"
            ),
            WordSense(
                id: "n5_adj_amai_s2",
                senseNumber: 2,
                partOfSpeech: "イ형용사",
                meaning: "(생각·판단이) 무르다, 안일하다",
                exampleMarkup: "{現実|げんじつ}はそんなに{甘|あま}くないぞ。",
                translation: SplitTranslation(
                    before: "현실은 그렇게 ",
                    answer: "만만하지",
                    after: " 않다."
                ),
                voice: .expeditionCaptain,
                subPalette: ThemePalette(hexColors: ["#3F6212", "#ECFCCB", "#1A2E05"]),
                exampleAudioFile: "amai_s2_example"
            ),
            WordSense(
                id: "n5_adj_amai_s3",
                senseNumber: 3,
                partOfSpeech: "イ형용사",
                meaning: "(마무리·경계가) 허술하다",
                exampleMarkup: "アリバイの{詰め|つ}が{甘|あま}いですね。",
                translation: SplitTranslation(
                    before: "알리바이의 마무리가 ",
                    answer: "허술하네요",
                    after: "."
                ),
                voice: .modulatedDetective,
                subPalette: ThemePalette(hexColors: ["#0284C7", "#E0F2FE", "#0C4A6E"]),
                exampleAudioFile: "amai_s3_example"
            )
        ],
        kanjiUsages: [
            WordKanjiUsage(
                kanji: "甘",
                activeReading: "あま.い",
                dictionaryReading: "あま.い",
                readingType: .kunyomi
            )
        ]
    )

    public static let kanpai = Word(
        id: "n4_social_kanpai",
        jlptLevel: .n4,
        category: "모임·회식",
        term: "乾杯",
        reading: "かんぱい",
        pitchAccent: 0,
        palette: ThemePalette(hexColors: ["#F59E0B", "#FEF3C7", "#78350F"]),
        termAudioFile: "kanpai_term",
        senses: [
            WordSense(
                id: "n4_social_kanpai_s1",
                senseNumber: 1,
                partOfSpeech: "명사·동사(する)",
                meaning: "건배",
                exampleMarkup: "{今日|きょう}の{成功|せいこう}を{祝|いわ}って、{乾杯|かんぱい}！",
                translation: SplitTranslation(
                    before: "오늘의 성공을 축하하며, ",
                    answer: "건배",
                    after: "!"
                ),
                voice: .buchou,
                exampleAudioFile: "kanpai_example"
            )
        ],
        kanjiUsages: [
            WordKanjiUsage(
                kanji: "乾",
                activeReading: "かん",
                dictionaryReading: "カン",
                readingType: .onyomi
            ),
            WordKanjiUsage(
                kanji: "杯",
                activeReading: "ぱい",
                dictionaryReading: "ハイ",
                readingType: .onyomi
            )
        ]
    )

    public static let kansou = Word(
        id: "n3_noun_kansou",
        jlptLevel: .n3,
        category: "생활·날씨",
        term: "乾燥",
        reading: "かんそう",
        pitchAccent: 0,
        palette: ThemePalette(hexColors: ["#D97706", "#FEF9C3", "#451A03"]),
        termAudioFile: "kansou_term",
        senses: [
            WordSense(
                id: "n3_noun_kansou_s1",
                senseNumber: 1,
                partOfSpeech: "명사·동사(する)",
                meaning: "건조, 마름",
                exampleMarkup: "{冬|ふゆ}はお{肌|はだ}が{乾燥|かんそう}しやすいねえ。",
                translation: SplitTranslation(
                    before: "겨울에는 피부가 ",
                    answer: "건조해지기",
                    after: " 쉽구나."
                ),
                voice: .kyotoGrandma,
                exampleAudioFile: "kansou_example"
            )
        ],
        kanjiUsages: [
            WordKanjiUsage(
                kanji: "乾",
                activeReading: "かん",
                dictionaryReading: "カン",
                readingType: .onyomi
            ),
            WordKanjiUsage(
                kanji: "燥",
                activeReading: "そう",
                dictionaryReading: "ソウ",
                readingType: .onyomi
            )
        ]
    )

    /// 긴 후리가나 어절 박스 묶음(`{承ります|うけたまわ}`) 및 겸양 다의어 샘플
    public static let uketamawaru = Word(
        id: "n3_biz_uketamawaru",
        jlptLevel: .n3,
        category: "비즈니스·접객",
        term: "承る",
        reading: "うけたまわる",
        pitchAccent: 5,
        palette: ThemePalette(hexColors: ["#475569", "#F1F5F9", "#0F172A"]),
        termAudioFile: "uketamawaru_term",
        senses: [
            WordSense(
                id: "n3_biz_uketamawaru_s1",
                senseNumber: 1,
                partOfSpeech: "동사 5단(겸양어)",
                meaning: "(삼가) 받다, 접수하다",
                exampleMarkup: "ご{予約|よやく}を{承ります|うけたまわ}。",
                translation: SplitTranslation(
                    before: "예약을 ",
                    answer: "접수하겠습니다",
                    after: "."
                ),
                voice: .tokyoSenpai,
                exampleAudioFile: "uketamawaru_s1_example"
            ),
            WordSense(
                id: "n3_biz_uketamawaru_s2",
                senseNumber: 2,
                partOfSpeech: "동사 5단(겸양어)",
                meaning: "(말씀을) 삼가 듣다, 전해 듣다",
                exampleMarkup: "ご{事情|じじょう}はすでに{承って|うけたまわ}おります。",
                translation: SplitTranslation(
                    before: "사정은 이미 ",
                    answer: "전해 듣고",
                    after: " 있습니다."
                ),
                voice: .alchemyMerchant,
                subPalette: ThemePalette(hexColors: ["#7E22CE", "#F3E8FF", "#3B0764"]),
                exampleAudioFile: "uketamawaru_s2_example"
            )
        ],
        kanjiUsages: [
            WordKanjiUsage(
                kanji: "承",
                activeReading: "うけたまわ.る",
                dictionaryReading: "うけたまわ.る",
                readingType: .kunyomi
            )
        ]
    )

    public static let shounin = Word(
        id: "n2_biz_shounin",
        jlptLevel: .n2,
        category: "비즈니스",
        term: "承認",
        reading: "しょうにん",
        pitchAccent: 0,
        palette: ThemePalette(hexColors: ["#B45309", "#FEF3C7", "#451A03"]),
        termAudioFile: "shounin_term",
        senses: [
            WordSense(
                id: "n2_biz_shounin_s1",
                senseNumber: 1,
                partOfSpeech: "명사·동사(する)",
                meaning: "승인, 허락",
                exampleMarkup: "{作戦|さくせん}の{承認|しょうにん}を{求|もと}める。",
                translation: SplitTranslation(
                    before: "작전의 ",
                    answer: "승인",
                    after: "을 요청한다."
                ),
                voice: .knightCommander,
                exampleAudioFile: "shounin_example"
            )
        ],
        kanjiUsages: [
            WordKanjiUsage(
                kanji: "承",
                activeReading: "しょう",
                dictionaryReading: "ショウ",
                readingType: .onyomi
            ),
            WordKanjiUsage(
                kanji: "認",
                activeReading: "にん",
                dictionaryReading: "ニン",
                readingType: .onyomi
            )
        ]
    )

    public static let toriaezu = Word(
        id: "n4_adv_toriaezu",
        jlptLevel: .n4,
        category: "일상 회화",
        term: "とりあえず",
        reading: "とりあえず",
        pitchAccent: 3,
        palette: ThemePalette(hexColors: ["#3B82F6", "#EFF6FF", "#1E3A8A"]),
        termAudioFile: "toriaezu_term",
        senses: [
            WordSense(
                id: "n4_adv_toriaezu_s1",
                senseNumber: 1,
                partOfSpeech: "부사",
                meaning: "우선, 일단",
                exampleMarkup: "とりあえず、お{弁当|べんとう}{温|あたた}めますか？",
                translation: SplitTranslation(
                    before: "",
                    answer: "일단",
                    after: ", 도시락 데워 드릴까요?"
                ),
                voice: .konbiniClerk,
                exampleAudioFile: "toriaezu_example"
            )
        ],
        nonKanjiNote: NonKanjiNote(
            kind: .nativeKana,
            originLanguage: nil,
            originTerm: "取り敢えず",
            explanation: "동사 복합형 '取り敢えず'에서 굳어져 일상에서 히라가나로 표기하는 부사"
        )
    )
}

extension KanjiInfo {
    public static let samples: [KanjiInfo] = [
        KanjiInfo(
            character: "甘",
            koreanHunEum: "달 감",
            meanings: ["달다", "달콤하다", "느슨하다", "만만히 보다"],
            onyomi: ["カン"],
            kunyomi: ["あま.い", "あま.える", "あま.やかす"],
            strokeCount: 5,
            radical: "甘 (달 감)",
            jlptLevel: .n3
        ),
        KanjiInfo(
            character: "乾",
            koreanHunEum: "마를 건",
            meanings: ["마르다", "건조하다", "하늘"],
            onyomi: ["カン", "ケン"],
            kunyomi: ["かわ.く", "かわ.かす", "ほ.す"],
            strokeCount: 11,
            radical: "乙 (새 을)",
            jlptLevel: .n3
        ),
        KanjiInfo(
            character: "杯",
            koreanHunEum: "잔 배",
            meanings: ["술잔", "잔을 세는 단위"],
            onyomi: ["ハイ"],
            kunyomi: ["さかずき"],
            strokeCount: 8,
            radical: "木 (나무 목)",
            jlptLevel: .n3
        ),
        KanjiInfo(
            character: "燥",
            koreanHunEum: "마를 조",
            meanings: ["마르다", "메마르다", "들뜨다"],
            onyomi: ["ソウ"],
            kunyomi: ["はしゃ.ぐ"],
            strokeCount: 17,
            radical: "火 (불 화)",
            jlptLevel: .n2
        ),
        KanjiInfo(
            character: "承",
            koreanHunEum: "받들 승",
            meanings: ["받들다", "삼가 받다", "잇다", "승인하다"],
            onyomi: ["ショウ"],
            kunyomi: ["うけたまわ.る", "う.ける"],
            strokeCount: 8,
            radical: "手 (손 수)",
            jlptLevel: .n3
        ),
        KanjiInfo(
            character: "認",
            koreanHunEum: "알 인",
            meanings: ["인정하다", "알아보다", "허락하다"],
            onyomi: ["ニン"],
            kunyomi: ["みと.める", "したた.める"],
            strokeCount: 14,
            radical: "言 (말씀 언)",
            jlptLevel: .n3
        )
    ]
}
