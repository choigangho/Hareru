import SwiftUI

// MARK: - 어절 단위 줄바꿈 플로우 레이아웃 (어절 박스 내부 끊김 원천 차단)
public struct PhraseFlowLayout: Layout {
    public var horizontalSpacing: CGFloat
    public var verticalSpacing: CGFloat

    public init(horizontalSpacing: CGFloat = 0, verticalSpacing: CGFloat = 6) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let totalHeight = rows.enumerated().reduce(CGFloat.zero) { acc, pair in
            let (idx, row) = pair
            return acc + row.height + (idx > 0 ? verticalSpacing : 0)
        }
        let widestRow = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? widestRow, height: totalHeight)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            // 각 줄을 가운데 정렬하여 카드 중앙 시선 흐름 유지
            var x = bounds.minX + max(0, (bounds.width - row.width) / 2)
            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private struct RowItem {
        let subview: LayoutSubview
        let size: CGSize
    }

    private struct Row {
        var items: [RowItem] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = current.items.isEmpty
                ? size.width
                : current.width + horizontalSpacing + size.width

            if !current.items.isEmpty && nextWidth > maxWidth {
                rows.append(current)
                current = Row(items: [RowItem(subview: subview, size: size)], width: size.width, height: size.height)
            } else {
                current.items.append(RowItem(subview: subview, size: size))
                current.width = nextWidth
                current.height = max(current.height, size.height)
            }
        }

        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

// MARK: - 어절 박스 묶음 상단 루비(후리가나) 뷰 (SPEC.md §2.1)
/// - 파도 1(`exampleProgress`): 일본어 예문 본문 노출 (0~6초)
/// - 파도 2(`furiganaProgress`): 주변 문맥 후리가나만 하단에 노출 (2~8초)
/// - 표제어 보호(`segment.isTargetWord == true`): 정답 보기(`isRevealed == true`) 전까지 후리가나 잠금 유지!
public struct PhraseBoxFuriganaView: View {
    public let segments: [FuriganaSegment]
    public let exampleProgress: CGFloat
    public let furiganaProgress: CGFloat
    public let isRevealed: Bool

    public init(
        segments: [FuriganaSegment],
        exampleProgress: CGFloat,
        furiganaProgress: CGFloat,
        isRevealed: Bool
    ) {
        self.segments = segments
        self.exampleProgress = exampleProgress
        self.furiganaProgress = furiganaProgress
        self.isRevealed = isRevealed
    }

    private static let bodySize: CGFloat = 18
    private static let rubySize: CGFloat = 10

    public var body: some View {
        PhraseFlowLayout(horizontalSpacing: 0, verticalSpacing: 4) {
            ForEach(segments) { segment in
                // 표준 루비 배치: 후리가나는 '한자 부분(baseText)' 바로 위 가운데에만 얹고,
                // 오쿠리가나·조사는 후리가나 없이 한자 오른쪽에 같은 기준선으로 이어 붙임
                HStack(alignment: .bottom, spacing: 0) {
                    VStack(spacing: 0) {
                        rubyText(for: segment)
                        Text(segment.baseText)
                            .jlptExampleFont(size: Self.bodySize)
                            .foregroundStyle(.primary)
                            .fixedSize()
                    }

                    if !segment.okurigana.isEmpty {
                        Text(segment.okurigana)
                            .jlptExampleFont(size: Self.bodySize)
                            .foregroundStyle(.primary)
                            .fixedSize()
                    }
                }
                .hintBlur(isRevealed ? 1.0 : exampleProgress)
            }
        }
    }

    /// 후리가나가 없는 어절도 같은 높이의 빈 루비 줄을 두어 모든 어절의 기준선을 맞춤
    @ViewBuilder
    private func rubyText(for segment: FuriganaSegment) -> some View {
        if let reading = segment.reading {
            let effectiveFuriganaProgress: CGFloat = isRevealed
                ? 1.0
                : (segment.isTargetWord ? 0.0 : furiganaProgress)

            Text(reading)
                .jlptFuriganaFont(size: Self.rubySize)
                .foregroundStyle(.secondary)
                .fixedSize()
                .furiganaBlur(effectiveFuriganaProgress)
        } else {
            Text(" ")
                .jlptFuriganaFont(size: Self.rubySize)
                .opacity(0)
        }
    }
}
