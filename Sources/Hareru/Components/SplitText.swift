import SwiftUI

// MARK: - "앞 / 정답 / 뒤"로 나뉜 예문 해석 텍스트 컴포넌트
public struct SplitText: View {
    public let before: String
    public let answer: String
    public let after: String
    public let otherProgress: CGFloat
    public let answerProgress: CGFloat
    public var accentColor: Color = .primary

    public init(
        before: String,
        answer: String,
        after: String,
        otherProgress: CGFloat,
        answerProgress: CGFloat,
        accentColor: Color = .primary
    ) {
        self.before = before
        self.answer = answer
        self.after = after
        self.otherProgress = otherProgress
        self.answerProgress = answerProgress
        self.accentColor = accentColor
    }

    public var body: some View {
        ZStack {
            line(answerVisible: false).hintBlur(otherProgress)
            line(answerVisible: true).furiganaBlur(answerProgress)
        }
        .multilineTextAlignment(.center)
    }

    private func line(answerVisible: Bool) -> Text {
        let side = Text(before).foregroundStyle(answerVisible ? Color.clear : Color.secondary)
        let mid  = Text(answer)
            .fontWeight(.semibold)
            .foregroundStyle(answerVisible ? accentColor : Color.clear)
        let tail = Text(after).foregroundStyle(answerVisible ? Color.clear : Color.secondary)
        return Text("\(side)\(mid)\(tail)")
    }
}
