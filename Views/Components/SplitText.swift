import SwiftUI

// MARK: - "앞 / 정답 / 뒤"로 나뉜 예문 해석 텍스트 컴포넌트
struct SplitText: View {
    let before: String
    let answer: String
    let after: String
    let otherProgress: CGFloat
    let answerProgress: CGFloat

    var body: some View {
        ZStack {
            line(answerVisible: false).hintBlur(otherProgress)
            line(answerVisible: true).hintBlur(answerProgress)
        }
        .multilineTextAlignment(.center)
    }

    private func line(answerVisible: Bool) -> Text {
        let side = Text(before).foregroundStyle(answerVisible ? Color.clear : Color.primary)
        let mid  = Text(answer).foregroundStyle(answerVisible ? Color.primary : Color.clear)
        let tail = Text(after).foregroundStyle(answerVisible ? Color.clear : Color.primary)
        return Text("\(side)\(mid)\(tail)")
    }
}
