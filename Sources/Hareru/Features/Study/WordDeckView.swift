// xcode: set sdk=iOS

import SwiftUI

// MARK: - 전체 덱 화면 (상단 카테고리 + 진행도 막대 게이지 + 카드 전환)
struct WordDeckView: View {
    let words: [Word] = Word.samples
    @State private var currentIndex: Int = 0

    private var currentWord: Word { words[currentIndex] }
    
    // 첫 번째 카드에서는 1/2 (50%), 두 번째 카드에서는 2/2 (100%)
    private var progressRatio: CGFloat {
        CGFloat(currentIndex + 1) / CGFloat(words.count)
    }

    var body: some View {
        ZStack {
            // 배경 그라데이션 (카드가 바뀔 때 부드럽게 색상 전환)
            LinearGradient(colors: currentWord.colors,
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: currentIndex)

            VStack(spacing: 24) {
                // 1. 상단 헤더: 카테고리 배지 + 가로 막대 게이지
                VStack(spacing: 10) {
                    HStack {
                        Label(currentWord.category, systemImage: "fork.knife")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())

                        Spacer()

                        Text("\(currentIndex + 1) / \(words.count)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.primary.opacity(0.75))
                    }

                    // 가로 막대 게이지 (1번째: 반 차지, 2번째: 꽉 참)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.35))
                            Capsule()
                                .fill(currentWord.colors[2])
                                .frame(width: geo.size.width * progressRatio)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
                        }
                    }
                    .frame(height: 8)
                }
                .frame(maxWidth: 340)

                // 2. 단어 카드 본체 (.id를 부여해 카드가 바뀔 때마다 타이머/상태 초기화)
                WordCardView(word: currentWord)
                    .id(currentWord.id)

                // 3. 하단 이전/다음 카드 이동 버튼
                HStack(spacing: 16) {
                    Button {
                        if currentIndex > 0 { currentIndex -= 1 }
                    } label: {
                        Label("이전 카드", systemImage: "chevron.left")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .disabled(currentIndex == 0)

                    Button {
                        if currentIndex < words.count - 1 { currentIndex += 1 }
                    } label: {
                        HStack(spacing: 4) {
                            Text("다음 카드")
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(currentWord.colors[2])
                    .disabled(currentIndex == words.count - 1)
                }
            }
            .padding(.vertical, 20)
        }
    }
}

#Preview {
    WordDeckView()
}
