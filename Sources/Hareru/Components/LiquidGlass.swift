import SwiftUI

// MARK: - iOS 26 Liquid Glass 디자인 시스템 (iOS 17~25 자동 폴백)
//
// - iOS 26 / macOS 26 이상: 시스템 `glassEffect` · `.glass` / `.glassProminent` 버튼 스타일 사용
// - 이전 OS: `ultraThinMaterial` + 얇은 하이라이트 테두리로 최대한 비슷한 질감 재현
// 배포 타깃(iOS 17)을 올리지 않고도 최신 OS에서는 네이티브 Liquid Glass가 적용됩니다.

public extension View {
    /// 임의 도형에 Liquid Glass 재질 적용
    @ViewBuilder
    func hareruGlass<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            self
                .background {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        if let tint {
                            shape.fill(tint.opacity(0.16))
                        }
                    }
                }
                .overlay {
                    shape.stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.55), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
                }
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        }
    }

    /// 연속 곡률 둥근 사각형 Liquid Glass 카드
    func hareruGlassCard(
        cornerRadius: CGFloat = 24,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        hareruGlass(
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            tint: tint,
            interactive: interactive
        )
    }

    /// 주요 행동 버튼 (iOS 26: `.glassProminent`, 이전: `.borderedProminent`)
    @ViewBuilder
    func hareruProminentButtonStyle() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// 보조 행동 버튼 (iOS 26: `.glass`, 이전: `.bordered`)
    @ViewBuilder
    func hareruSecondaryButtonStyle() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

// MARK: - 렌즈 굴곡 글라스 (카드 액션 버튼 공용)
// 투명한 Liquid Glass 위에 볼록 렌즈처럼 빛이 맺히는 질감을 더합니다.
// - 위쪽 가장자리: 빛을 받아 밝은 반사광(스펙큘러)
// - 아래쪽 가장자리: 렌즈 두께로 살짝 어두워지는 림
// - 가운데: 색을 칠하지 않아 뒤의 하늘이 그대로 비침
public extension View {
    func lensGlass<S: InsettableShape>(in shape: S, tint: Color? = nil) -> some View {
        self
            .hareruGlass(in: shape, tint: tint, interactive: true)
            .overlay {
                ZStack {
                    shape.fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.28), location: 0.0),
                                .init(color: .white.opacity(0.06), location: 0.42),
                                .init(color: .clear, location: 0.6),
                                .init(color: .black.opacity(0.10), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.75), .white.opacity(0.12), .white.opacity(0.32)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                }
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
    }
}

// MARK: - 인접 글래스 요소 병합 컨테이너 (iOS 26: GlassEffectContainer)
public struct HareruGlassGroup<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    public init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

// MARK: - Liquid Glass 굴절용 은은한 앰비언트 배경 (허브 화면 공용)
public struct HareruAmbientBackground: View {
    private let colors: [Color]

    public init(colors: [Color] = [
        Color(red: 1.00, green: 0.86, blue: 0.70),
        Color(red: 0.98, green: 0.74, blue: 0.80),
        Color(red: 0.72, green: 0.80, blue: 0.98)
    ]) {
        self.colors = colors
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [colors[0].opacity(0.55), colors[2].opacity(0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(colors[1].opacity(0.55))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 120, y: -220)
            Circle()
                .fill(colors[2].opacity(0.50))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: -130, y: 260)
        }
        .ignoresSafeArea()
    }
}
