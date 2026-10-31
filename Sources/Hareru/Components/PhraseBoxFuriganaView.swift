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

// MARK: - 어절 박스 묶음 하단 후리가나 뷰 (SPEC.md §2.1)
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

    public var body: some View {
        PhraseFlowLayout(horizontalSpacing: 0, verticalSpacing: 6) {
            ForEach(segments) { segment in
                VStack(alignment: .leading, spacing: 1) {
                    Text(segment.surfaceText)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .fixedSize()
                        .hintBlur(isRevealed ? 1.0 : exampleProgress)

                    if let reading = segment.reading {
                        let effectiveFuriganaProgress: CGFloat = isRevealed
                            ? 1.0
                            : (segment.isTargetWord ? 0.0 : furiganaProgress)

                        Text(reading)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .furiganaBlur(effectiveFuriganaProgress)
                    } else {
                        // 후리가나가 없는 평문 어절도 동일한 수직 베이스라인을 유지
                        Text(" ")
                            .font(.system(size: 10.5))
                            .opacity(0)
                    }
                }
            }
        }
    }
}
