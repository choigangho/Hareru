import Foundation

// MARK: - 주임 연구원 대사 (한국어 80 · 일본어 20, Docs/GAME_DESIGN.md §6.2)
// 일본어는 감탄사·인사 위주로 짧게. 이름은 엔딩까지 밝히지 않음 (§6.1).
enum InstituteGuideScript {
    static let speakerTitle = "주임 연구원"

    static let intro: [String] = [
        "「あっ…! 新しい方ですか?」 어서 오세요. 여기는 国立言語遺産研究所, 줄여서 NJL이에요.",
        "지금까지 이 연구소에 사람은 저 하나뿐이었어요. 나머지는 로봇이랑 AI가… 오늘부터는 둘이네요. 예산은 아직 저 창밖 하늘처럼 흐림이지만요.",
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

// MARK: - 원내 방송 AI (`announcer_ai`) — HUD 방송 띠 문구
// 문어체 · 공식 안내체. 연구소 상태와 실제 날씨에서 만들고, 차례로 돌려 보여 줌.
enum InstituteBroadcast {
    static let speakerTitle = "NJL 원내 방송"

    static func lines(
        state: InstituteState,
        settlement: InstituteSettlement?,
        restorableCount: Int,
        activeCombos: [FacilityCombo],
        realWeather: String
    ) -> [String] {
        var lines: [String] = []
        if let settlement, settlement.gainedPoints > 0 {
            lines.append("금일 학습 기록 정산 완료. 研究P +\(settlement.gainedPoints)이 연구소 계좌에 반영되었습니다.")
        }
        if let settlement, settlement.budgetGranted > 0 {
            lines.append("문화 예산 배정 알림 — 本日の予算 +\(settlement.budgetGranted).")
        }
        if restorableCount > 0 {
            lines.append("복원 대기 문자 \(restorableCount)자. 研究P가 충분하면 즉시 복원할 수 있습니다.")
        } else {
            lines.append("현재 복원 대기 문자가 없습니다. 학습 탭에서 한자 어휘를 외우면 목록에 추가됩니다.")
        }
        if let latest = state.restoredKanji.last {
            lines.append("최근 복원 문자 「\(latest)」. 누적 복원 \(state.restoredKanji.count)자 / 상용 2,136자.")
        }
        for combo in activeCombos {
            lines.append("설비 연계 가동 중: \(combo.title).")
        }
        switch state.instituteSky {
        case .rain: lines.append("연구소 상공 강우 지속. 영향력이 오르면 구름이 걷힐 것으로 예측됩니다.")
        case .cloudy: lines.append("연구소 상공 흐림. 晴れ間まで、あと少しです。")
        default: lines.append("연구소 상공 쾌청. 本日も良い研究日和です。")
        }
        lines.append("도시 기상 — \(realWeather).")
        return lines
    }
}
