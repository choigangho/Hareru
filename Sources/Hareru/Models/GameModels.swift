import Foundation

// MARK: - 탭 2 게임 그룹 카테고리 (확장형 미니게임 아키텍처, SPEC.md §1.3)
public enum GameModeKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case smsEpisode = "sms_episode"
    case speedSnap = "speed_snap"
    case kanjiPuzzle = "kanji_puzzle"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .smsEpisode: return "캐릭터 SMS 미션"
        case .speedSnap: return "초속 스냅 매칭"
        case .kanjiPuzzle: return "한자 어절 퍼즐"
        }
    }

    public var subtitle: String {
        switch self {
        case .smsEpisode: return "오늘 졸업한 단어로 성우 캐릭터와 3턴 대화 미션"
        case .speedSnap: return "1.5초 안에 뜻을 낚아채는 순발력 복습 (오픈 예정)"
        case .kanjiPuzzle: return "어절 조각을 맞춰 문장을 완성하는 미니게임 (오픈 예정)"
        }
    }

    public var iconName: String {
        switch self {
        case .smsEpisode: return "bubble.left.and.bubble.right.fill"
        case .speedSnap: return "bolt.fill"
        case .kanjiPuzzle: return "puzzlepiece.extension.fill"
        }
    }

    public var isPlayable: Bool {
        self == .smsEpisode
    }
}

// MARK: - SMS 감정 스탬프 & 판정 등급
public enum SMSMoodStamp: String, Codable, Equatable, Hashable, Sendable {
    case cheers = "🍻 건배!"
    case delighted = "✨ 최고!"
    case impressed = "👏 완벽!"
    case curious = "🤔 오호?"
    case gentleHint = "💡 힌트!"
}

public enum SMSReplyTier: String, Codable, Equatable, Hashable, Sendable {
    case greatSuccess = "great"     // 목표 어휘 + 문법 모두 정확히 구사
    case partialSuccess = "partial" // 핵심 어휘 일부만 포함
    case retryHint = "retry"        // 목표 어휘 누락 (턴 소모 없이 재시도 유도)

    public var affectionDelta: Int {
        switch self {
        case .greatSuccess: return 40
        case .partialSuccess: return 25
        case .retryHint: return 0
        }
    }
}

// MARK: - 분기형 사전 합성 캐릭터 응답 노드 (SPEC.md §1.3)
public struct SMSTurnReplyBranch: Codable, Equatable, Hashable, Sendable {
    public let tier: SMSReplyTier
    public let npcText: String
    public let npcTranslation: String
    public let audioFile: String?       // 256kbps 사전 제작 오디오 파일 스템
    public let stamp: SMSMoodStamp
    public let coachingTip: String      // 내 말풍선 하단 1줄 코칭 배지

    public init(
        tier: SMSReplyTier,
        npcText: String,
        npcTranslation: String,
        audioFile: String? = nil,
        stamp: SMSMoodStamp,
        coachingTip: String
    ) {
        self.tier = tier
        self.npcText = npcText
        self.npcTranslation = npcTranslation
        self.audioFile = audioFile.map(AudioFileName.normalize)
        self.stamp = stamp
        self.coachingTip = coachingTip
    }
}

// MARK: - 단일 턴 미션 스테이지 (3~4턴 단기 결판 구조)
public struct SMSTurnStage: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let turnNumber: Int
    public let npcPromptText: String
    public let npcPromptTranslation: String
    public let npcPromptAudioFile: String?
    public let missionGuide: String             // 상단 미션 배너 문구
    public let sampleHangulHint: String         // 한글 발음 입력 예시 힌트
    public let requiredKeywordGroups: [[String]] // 각 그룹 중 최소 1개 매칭 여부로 달성도 채점
    public let greatBranch: SMSTurnReplyBranch
    public let partialBranch: SMSTurnReplyBranch
    public let hintBranch: SMSTurnReplyBranch

    public var id: Int { turnNumber }

    public init(
        turnNumber: Int,
        npcPromptText: String,
        npcPromptTranslation: String,
        npcPromptAudioFile: String? = nil,
        missionGuide: String,
        sampleHangulHint: String,
        requiredKeywordGroups: [[String]],
        greatBranch: SMSTurnReplyBranch,
        partialBranch: SMSTurnReplyBranch,
        hintBranch: SMSTurnReplyBranch
    ) {
        self.turnNumber = turnNumber
        self.npcPromptText = npcPromptText
        self.npcPromptTranslation = npcPromptTranslation
        self.npcPromptAudioFile = npcPromptAudioFile.map(AudioFileName.normalize)
        self.missionGuide = missionGuide
        self.sampleHangulHint = sampleHangulHint
        self.requiredKeywordGroups = requiredKeywordGroups
        self.greatBranch = greatBranch
        self.partialBranch = partialBranch
        self.hintBranch = hintBranch
    }
}

// MARK: - 캐릭터 SMS 에피소드 시나리오 모델
public struct SMSEpisode: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let voice: VoiceProfile
    public let palette: ThemePalette
    public let targetWordIds: [String]
    public let turns: [SMSTurnStage]

    public init(
        id: String,
        title: String,
        subtitle: String,
        voice: VoiceProfile,
        palette: ThemePalette,
        targetWordIds: [String],
        turns: [SMSTurnStage]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.voice = voice
        self.palette = palette
        self.targetWordIds = targetWordIds
        self.turns = turns
    }
}

// MARK: - 실시간 채팅 말풍선 메시지 모델
public struct SMSChatMessage: Identifiable, Equatable, Sendable {
    public enum Sender: Equatable, Sendable {
        case npc
        case player
    }

    public let id: String
    public let sender: Sender
    public let japaneseText: String
    public let koreanTranslation: String?
    public let rawHangulInput: String?
    public let audioFile: String?
    public let stamp: SMSMoodStamp?
    public let coachingTip: String?
    public let affectionDelta: Int

    public init(
        id: String = UUID().uuidString,
        sender: Sender,
        japaneseText: String,
        koreanTranslation: String? = nil,
        rawHangulInput: String? = nil,
        audioFile: String? = nil,
        stamp: SMSMoodStamp? = nil,
        coachingTip: String? = nil,
        affectionDelta: Int = 0
    ) {
        self.id = id
        self.sender = sender
        self.japaneseText = japaneseText
        self.koreanTranslation = koreanTranslation
        self.rawHangulInput = rawHangulInput
        self.audioFile = audioFile
        self.stamp = stamp
        self.coachingTip = coachingTip
        self.affectionDelta = affectionDelta
    }
}

// MARK: - 기본 내장 SMS 에피소드 샘플 데이터
extension SMSEpisode {
    public static let samples: [SMSEpisode] = [
        .buchouIzakaya,
        .senpaiOffice,
        .tenchouRamen
    ]

    /// 에피소드 1: 이자카야 부장님과 금요일 회식 3턴 미션
    public static let buchouIzakaya = SMSEpisode(
        id: "ep_buchou_izakaya",
        title: "금요일 밤의 첫 잔",
        subtitle: "퇴근 후 단골 이자카야에서 부장님의 기분을 맞춰 드려라!",
        voice: .buchou,
        palette: ThemePalette(hexColors: ["#FFC733", "#FAF5E6", "#73421F"]),
        targetWordIds: ["n4_adv_toriaezu", "n5_food_beer", "n4_social_kanpai", "n5_food_ramen"],
        turns: [
            SMSTurnStage(
                turnNumber: 1,
                npcPromptText: "今週もお疲れ！さて、最初は何を頼もうか？",
                npcPromptTranslation: "이번 주도 고생했어! 자, 첫 잔은 뭘로 시킬까?",
                npcPromptAudioFile: "beer_term",
                missionGuide: "[とりあえず] + [ビール] + [乾杯] + [しましょう]를 넣어 건배를 제안해 보세요!",
                sampleHangulHint: "토리아에즈 비루데 칸파이 시마쇼",
                requiredKeywordGroups: [
                    ["とりあえず"],
                    ["ビール", "びーる"],
                    ["乾杯", "かんぱい"],
                    ["しましょう", "ましょう"]
                ],
                greatBranch: SMSTurnReplyBranch(
                    tier: .greatSuccess,
                    npcText: "おお、いいねえ！とりあえず生ビールで乾杯だ！",
                    npcTranslation: "오오, 좋지! 일단 생맥주로 건배다!",
                    audioFile: "beer_example",
                    stamp: .cheers,
                    coachingTip: "✨ 완벽해요! 'とりあえず(일단)'와 '~ましょう(권유)'까지 찰떡같이 연결했습니다."
                ),
                partialBranch: SMSTurnReplyBranch(
                    tier: .partialSuccess,
                    npcText: "よし、まずはビールだな！みんなで乾杯しよう！",
                    npcTranslation: "좋아, 우선 맥주지! 다 같이 건배하자!",
                    audioFile: "beer_example",
                    stamp: .curious,
                    coachingTip: "👍 의미는 통했어요! 'とりあえず、ビールで乾杯しましょう'처럼 권유형까지 넣으면 만점!"
                ),
                hintBranch: SMSTurnReplyBranch(
                    tier: .retryHint,
                    npcText: "ん？最初はやっぱり冷たいビールで乾杯じゃないか？",
                    npcTranslation: "응? 첫 잔인데 시원한 맥주(ビール)로 건배(乾杯) 어때?",
                    audioFile: "beer_term",
                    stamp: .gentleHint,
                    coachingTip: "💡 한글로 '토리아에즈 비루데 칸파이 시마쇼'라고 입력하거나 아래 칩을 눌러보세요!"
                )
            ),
            SMSTurnStage(
                turnNumber: 2,
                npcPromptText: "ここのデザートも頼んでみたぞ。味はどうだい？",
                npcPromptTranslation: "여기 디저트도 시켜 봤네. 맛은 어떤가?",
                npcPromptAudioFile: nil,
                missionGuide: "[甘い/甘くて] + [美味しい]를 활용해 디저트 맛을 칭찬해 보세요!",
                sampleHangulHint: "아마쿠테 오이시이 데스네",
                requiredKeywordGroups: [
                    ["甘", "あま"],
                    ["美味", "おいし"]
                ],
                greatBranch: SMSTurnReplyBranch(
                    tier: .greatSuccess,
                    npcText: "ははは、気に入ってくれてよかった！もう一皿頼もう！",
                    npcTranslation: "하하하, 마음에 들어 하니 다행이군! 한 접시 더 시키자!",
                    audioFile: nil,
                    stamp: .delighted,
                    coachingTip: "✨ '甘くて美味しい(달콤해서 맛있다)' 형용사 연결이 아주 자연스럽습니다!"
                ),
                partialBranch: SMSTurnReplyBranch(
                    tier: .partialSuccess,
                    npcText: "そうか、甘いものは別腹だからなあ！",
                    npcTranslation: "그런가, 단 음식은 배가 따로 있으니까 말이지!",
                    audioFile: nil,
                    stamp: .curious,
                    coachingTip: "👍 좋아요! '甘くて美味しいですね'까지 함께 쓰면 표현이 훨씬 풍부해집니다."
                ),
                hintBranch: SMSTurnReplyBranch(
                    tier: .retryHint,
                    npcText: "どうした、甘くて美味しいかい？感想を聞かせてくれ！",
                    npcTranslation: "왜 그러나, 달콤해서 맛있나? 소감을 들려주게!",
                    audioFile: nil,
                    stamp: .gentleHint,
                    coachingTip: "💡 한글로 '아마쿠테 오이시이 데스네'라고 입력해 보세요!"
                )
            ),
            SMSTurnStage(
                turnNumber: 3,
                npcPromptText: "よし、そろそろお開きにするか！最後の締めは何がいい？",
                npcPromptTranslation: "좋아, 슬슬 파할까! 마지막 마무리 음식은 뭐가 좋겠나?",
                npcPromptAudioFile: "ramen_term",
                missionGuide: "[締め] + [豚骨] + [ラーメン]을 사용해 마무리 라멘을 제안해 보세요!",
                sampleHangulHint: "시메와 돈코츠 라멘 데스네",
                requiredKeywordGroups: [
                    ["締", "しめ"],
                    ["豚骨", "とんこつ"],
                    ["ラーメン", "らーめん"]
                ],
                greatBranch: SMSTurnReplyBranch(
                    tier: .greatSuccess,
                    npcText: "さすがよく分かってる！締めはやっぱり豚骨ラーメンだな！行こう！",
                    npcTranslation: "역시 잘 아는군! 마무리는 역시 돈코츠 라멘이지! 가자고!",
                    audioFile: "ramen_example",
                    stamp: .impressed,
                    coachingTip: "🎉 스테이지 클리어! 회식 자리 필수 표현 3단 콤보를 완벽하게 마스터했습니다."
                ),
                partialBranch: SMSTurnReplyBranch(
                    tier: .partialSuccess,
                    npcText: "おお、ラーメンいいな！隣の豚骨ラーメン屋に行こう！",
                    npcTranslation: "오오, 라멘 좋지! 옆집 돈코츠 라멘집으로 가자!",
                    audioFile: "ramen_example",
                    stamp: .cheers,
                    coachingTip: "👍 통과! '締めは豚骨ラーメンですね'처럼 '締め(마무리)'까지 챙기면 완벽합니다."
                ),
                hintBranch: SMSTurnReplyBranch(
                    tier: .retryHint,
                    npcText: "飲んだ後の締めといえば、温かいスープのあれだろう？",
                    npcTranslation: "술 마신 뒤 마무리(締め)라고 하면, 따뜻한 국물의 그거 아니겠나?",
                    audioFile: "ramen_term",
                    stamp: .gentleHint,
                    coachingTip: "💡 한글로 '시메와 돈코츠 라멘 데스네'라고 입력해 보세요!"
                )
            )
        ]
    )

    /// 에피소드 2: 도쿄 오피스 선배와 비즈니스 접객·보고 미션
    public static let senpaiOffice = SMSEpisode(
        id: "ep_senpai_office",
        title: "VIP 예약 접수의 정석",
        subtitle: "도쿄 오피스 선배에게 정중한 겸양어와 비즈니스 어휘를 보여주세요!",
        voice: .tokyoSenpai,
        palette: ThemePalette(hexColors: ["#475569", "#F1F5F9", "#0F172A"]),
        targetWordIds: ["n3_biz_uketamawaru", "n2_biz_shounin", "n3_noun_kansou"],
        turns: [
            SMSTurnStage(
                turnNumber: 1,
                npcPromptText: "お客様から予約の電話が来てるよ。どう対応する？",
                npcPromptTranslation: "고객님께 예약 전화가 왔어. 어떻게 응대할래?",
                missionGuide: "[ご予約] + [承ります]를 사용해 정중하게 예약을 접수해 보세요!",
                sampleHangulHint: "고요야쿠오 우케타마와리마스",
                requiredKeywordGroups: [
                    ["予約", "よやく"],
                    ["承", "うけたまわ"]
                ],
                greatBranch: SMSTurnReplyBranch(
                    tier: .greatSuccess,
                    npcText: "完璧な敬語だね！「ご予約を承ります」、そのまま使おう。",
                    npcTranslation: "완벽한 경어네! '예약을 접수하겠습니다', 그대로 쓰자.",
                    stamp: .impressed,
                    coachingTip: "✨ 훌륭해요! 겸양어 '承ります(삼가 받다/접수하다)'를 정확히 구사했습니다."
                ),
                partialBranch: SMSTurnReplyBranch(
                    tier: .partialSuccess,
                    npcText: "うん、意味は伝わるよ。「ご予約を承ります」と言うともっと丁寧だね。",
                    npcTranslation: "응, 의미는 통하네. 'ご予約を承ります'라고 하면 더 정중해.",
                    stamp: .curious,
                    coachingTip: "👍 'ご予約(예약)'과 '承ります'를 함께 묶어 쓰면 비즈니스 매너 만점입니다!"
                ),
                hintBranch: SMSTurnReplyBranch(
                    tier: .retryHint,
                    npcText: "「受ける」の謙譲語を思い出してみて！「ご〜を承ります」だよ。",
                    npcTranslation: "'받다'의 겸양어를 떠올려 봐! 'ご~を承ります'야.",
                    stamp: .gentleHint,
                    coachingTip: "💡 한글로 '고요야쿠오 우케타마와리마스'라고 입력해 보세요!"
                )
            ),
            SMSTurnStage(
                turnNumber: 2,
                npcPromptText: "次の企画書、進めるには何が必要かな？",
                npcPromptTranslation: "다음 기획서, 진행하려면 뭐가 필요할까?",
                missionGuide: "[承認]을 사용해 승인 절차를 언급해 보세요!",
                sampleHangulHint: "쇼닌데스네",
                requiredKeywordGroups: [
                    ["承認", "しょうにん"]
                ],
                greatBranch: SMSTurnReplyBranch(
                    tier: .greatSuccess,
                    npcText: "その通り！まずは部長の承認をもらおう。",
                    npcTranslation: "정확해! 우선 부장님의 승인을 받자.",
                    stamp: .delighted,
                    coachingTip: "✨ 비즈니스 핵심 명사 '承認(승인)'을 정확하게 인출했습니다!"
                ),
                partialBranch: SMSTurnReplyBranch(
                    tier: .partialSuccess,
                    npcText: "そうだね、承認が必要だね。",
                    npcTranslation: "맞아, 승인이 필요하지.",
                    stamp: .curious,
                    coachingTip: "👍 잘했어요!"
                ),
                hintBranch: SMSTurnReplyBranch(
                    tier: .retryHint,
                    npcText: "許可や「承認（しょうにん）」が必要だよね！",
                    npcTranslation: "허가나 '승인(承認)'이 필요하겠지!",
                    stamp: .gentleHint,
                    coachingTip: "💡 한글로 '쇼닌' 또는 '쇼닌데스네'라고 입력해 보세요!"
                )
            ),
            SMSTurnStage(
                turnNumber: 3,
                npcPromptText: "ところで最近オフィスの中、空気がカラカラじゃない？",
                npcPromptTranslation: "그나저나 요즘 사무실 안 공기가 너무 메마르지 않아?",
                missionGuide: "[乾燥]를 사용해 공기가 건조하다고 답해보세요!",
                sampleHangulHint: "칸소 데스네",
                requiredKeywordGroups: [
                    ["乾燥", "かんそう"]
                ],
                greatBranch: SMSTurnReplyBranch(
                    tier: .greatSuccess,
                    npcText: "やっぱり乾燥してるよね！加湿器をつけよう。今日もありがとう！",
                    npcTranslation: "역시 건조하지! 가습기 틀자. 오늘도 고마워!",
                    stamp: .impressed,
                    coachingTip: "🎉 오피스 에피소드 클리어! 겸양어부터 일상 한자어까지 깔끔하게 통과했습니다."
                ),
                partialBranch: SMSTurnReplyBranch(
                    tier: .partialSuccess,
                    npcText: "うん、乾燥に気をつけよう！",
                    npcTranslation: "응, 건조함에 주의하자!",
                    stamp: .delighted,
                    coachingTip: "👍 클리어 완료!"
                ),
                hintBranch: SMSTurnReplyBranch(
                    tier: .retryHint,
                    npcText: "空気が「乾燥（かんそう）」してるって言いたいんだよね？",
                    npcTranslation: "공기가 '건조(乾燥)'하다고 말하고 싶은 거지?",
                    stamp: .gentleHint,
                    coachingTip: "💡 한글로 '칸소 데스네'라고 입력해 보세요!"
                )
            )
        ]
    )

    /// 에피소드 3: 라멘집 사장님과 심야 단골 미션
    public static let tenchouRamen = SMSEpisode(
        id: "ep_tenchou_ramen",
        title: "심야의 진한 돈코츠",
        subtitle: "육수에 자부심 넘치는 사장님께 최고의 주문을 넣어 보세요!",
        voice: .tenchou,
        palette: ThemePalette(hexColors: ["#D9382E", "#F5E0B3", "#40261A"]),
        targetWordIds: ["n5_food_ramen", "n5_adj_amai"],
        turns: [
            SMSTurnStage(
                turnNumber: 1,
                npcPromptText: "いらっしゃい！今日の締めは何にするかい？",
                npcPromptTranslation: "어서 오쇼! 오늘 마무리는 뭘로 하겠수?",
                npcPromptAudioFile: "ramen_term",
                missionGuide: "[豚骨] + [ラーメン]으로 사장님의 시그니처 메뉴를 주문해 보세요!",
                sampleHangulHint: "돈코츠 라멘 데스네",
                requiredKeywordGroups: [
                    ["豚骨", "とんこつ"],
                    ["ラーメン", "らーめん"]
                ],
                greatBranch: SMSTurnReplyBranch(
                    tier: .greatSuccess,
                    npcText: "あいよっ！特製豚骨ラーメン、バリカタで一丁！",
                    npcTranslation: "옛다! 특제 돈코츠 라멘, 바리카타(꼬들면)로 한 그릇!",
                    audioFile: "ramen_example",
                    stamp: .impressed,
                    coachingTip: "✨ 사장님 기분 최고조! '豚骨ラーメン'을 정확하게 주문했습니다."
                ),
                partialBranch: SMSTurnReplyBranch(
                    tier: .partialSuccess,
                    npcText: "おう、ラーメンだな！すぐ作るぞ！",
                    npcTranslation: "오우, 라멘이지! 금방 만들어 주마!",
                    audioFile: "ramen_example",
                    stamp: .cheers,
                    coachingTip: "👍 '豚骨(돈코츠)'까지 붙이면 사장님 호감도가 더 크게 오릅니다!"
                ),
                hintBranch: SMSTurnReplyBranch(
                    tier: .retryHint,
                    npcText: "うちは自慢の「豚骨ラーメン」が一番人気だぜ！",
                    npcTranslation: "우리 집은 자랑거리인 '돈코츠 라멘'이 제일 인기라구!",
                    audioFile: "ramen_term",
                    stamp: .gentleHint,
                    coachingTip: "💡 한글로 '돈코츠 라멘'이라고 입력해 보세요!"
                )
            )
        ]
    )
}
