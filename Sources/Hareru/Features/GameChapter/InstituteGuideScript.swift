import Foundation

// MARK: - 가이드 연구원 대사 (한국어 80 · 일본어 20, Docs/GAME_DESIGN.md §6.2)
// 일본어는 감탄사·인사 위주로 짧게. 이름은 엔딩까지 밝히지 않음 (§6.1).
enum InstituteGuideScript {
    static let speakerTitle = "가이드 연구원"

    static let intro: [String] = [
        "「あっ…! 新しい方ですか?」 어서 오세요. 여기는 国立言語遺産研究所, 줄여서 NJL이에요.",
        "지금 이 연구소에 사람은 저 하나뿐이에요. 나머지는 로봇이랑 AI가… 예산도 저 창밖 하늘처럼 흐림이고요.",
        "학습 탭에서 단어를 외우면, 그 기록이 그대로 이곳의 연구 포인트(研究P)가 돼요. 오래 기억할수록 더 많이요.",
        "연구 포인트로는 잊혀진 한자를 복원하고, 예산으로는 시설을 늘릴 수 있어요. 시설끼리 붙여 두면 좋은 일이 생기기도 하고요.",
        "그럼… 「よろしくお願いします!」 함께 한자를 되살려 봐요."
    ]

    static func settlement(_ result: InstituteSettlement) -> String {
        var parts: [String] = []
        if result.gainedPoints > 0 {
            var detail: [String] = []
            if result.newWordCount > 0 { detail.append("새로 외운 단어 \(result.newWordCount)개") }
            if result.reviewCount > 0 { detail.append("다시 떠올린 단어 \(result.reviewCount)개") }
            let bonus = result.bonusPercent > 0 ? " (시설 보너스 +\(result.bonusPercent)%)" : ""
            parts.append("「すごい!」 \(detail.joined(separator: ", ")) — 연구 포인트 +\(result.gainedPoints)\(bonus)!")
        }
        if result.budgetGranted > 0 {
            parts.append("오늘 예산 +\(result.budgetGranted)이 들어왔어요.")
        }
        if parts.isEmpty {
            return "아직 정산할 새 학습 기록이 없어요. 학습 탭에서 카드를 외우고 오시면 연구 포인트로 바꿔 드릴게요."
        }
        return parts.joined(separator: " ")
    }

    static func placed(_ kind: FacilityKind, newCombos: [FacilityCombo]) -> String {
        if let combo = newCombos.first {
            return "「おおっ!」 \(combo.title) 성립! \(combo.summary)."
        }
        return "\(kind.title) 설치 완료! \(kind.summary)."
    }

    static func notEnoughBudget(_ kind: FacilityKind) -> String {
        "\(kind.title)는 예산 \(kind.budgetCost)이 필요해요… 내일 예산이 들어오면 다시 해 봐요."
    }

    static let cellOccupied = "그 자리는 이미 차 있어요. 빈 바닥을 골라 주세요."

    static func removed(_ kind: FacilityKind) -> String {
        "\(kind.title)를 치웠어요. 비용의 절반은 예산으로 돌려받았어요."
    }

    static func restored(_ kanji: String, hunEum: String?) -> String {
        let reading = hunEum.map { " (\($0))" } ?? ""
        return "「やった…!」 '\(kanji)'\(reading) 복원 성공! 이 글자를 읽을 수 있는 사람이 하나 더 늘었네요."
    }

    static func notEnoughPoints(cost: Int) -> String {
        "복원에는 연구 포인트 \(cost)이 필요해요. 학습 탭에서 조금만 더 외워 와요!"
    }

    static let nothingToRestore = "복원할 수 있는 한자가 아직 없어요. 한자가 들어간 단어를 외우면 여기에 나타나요."
}
