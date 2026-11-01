import CoreGraphics
import ImageIO
import SpriteKit

// MARK: - 연구소 픽셀 아트 텍스처 공장 (M1 임시 아트 — 코드로 그린 픽셀)
// 모든 텍스처는 '아트 픽셀 1칸 = 비트맵 1픽셀'로 그린 뒤, SpriteKit에서 최근접 필터링 + 정수 배율로 키웁니다.
// 실제 픽셀 아트 에셋이 생기면 이 파일의 make* 함수만 이미지 로딩으로 바꾸면 됩니다.
enum OfficePixelArt {
    // MARK: 색 (sRGB 0~1)
    struct RGB: Hashable {
        let r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat
        init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) {
            self.r = r; self.g = g; self.b = b; self.a = a
        }
        var cg: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
        func shaded(_ amount: CGFloat) -> RGB { RGB(r * amount, g * amount, b * amount, a) }
    }

    static let floorLight = RGB(0.79, 0.64, 0.48)
    static let floorDark = RGB(0.72, 0.57, 0.42)
    static let floorSeam = RGB(0.55, 0.42, 0.30, 0.55)
    static let wallLight = RGB(0.90, 0.86, 0.78)
    static let wallShade = RGB(0.80, 0.75, 0.67)
    static let wallTrim = RGB(0.62, 0.52, 0.41)
    static let windowFrame = RGB(0.45, 0.36, 0.27)
    static let gold = RGB(1.0, 0.84, 0.36)

    static let tileWidth = Int(IsoGrid.tileArtWidth)    // 32
    static let tileHeight = Int(IsoGrid.tileArtHeight)  // 16
    static let wallHeight = 40

    /// 방(벽 + 바닥) 텍스처의 아트 크기
    static var roomSize: (width: Int, height: Int) {
        let columns = InstituteState.gridColumns, rows = InstituteState.gridRows
        return ((columns + rows) * tileWidth / 2, wallHeight + (columns + rows) * tileHeight / 2)
    }

    /// 방 텍스처 안에서 격자 (0,0) 타일 윗꼭짓점의 위치 (위-왼쪽 기준 아트 좌표)
    static var roomGridOrigin: CGPoint {
        CGPoint(x: CGFloat(InstituteState.gridRows * tileWidth / 2), y: CGFloat(wallHeight))
    }

    // MARK: - 비트맵 그리기 도우미 (위-왼쪽 원점, 안티앨리어싱 끔)

    static func render(width: Int, height: Int, _ draw: (CGContext) -> Void) -> CGImage? {
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setShouldAntialias(false)
        context.setAllowsAntialiasing(false)
        context.interpolationQuality = .none
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        draw(context)
        return context.makeImage()
    }

    static func texture(_ image: CGImage?) -> SKTexture {
        let texture = image.map { SKTexture(cgImage: $0) } ?? SKTexture()
        texture.filteringMode = .nearest
        return texture
    }

    static func fill(_ context: CGContext, _ points: [CGPoint], _ color: RGB) {
        guard let first = points.first else { return }
        context.beginPath()
        context.move(to: first)
        for point in points.dropFirst() { context.addLine(to: point) }
        context.closePath()
        context.setFillColor(color.cg)
        context.fillPath()
    }

    static func rect(_ context: CGContext, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: RGB) {
        context.setFillColor(color.cg)
        context.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    static func diamond(top: CGPoint, inset: CGFloat = 0) -> [CGPoint] {
        let w = CGFloat(tileWidth) / 2 - inset, h = CGFloat(tileHeight) / 2 - inset / 2
        return [CGPoint(x: top.x, y: top.y + inset / 2), CGPoint(x: top.x + w, y: top.y + h),
                CGPoint(x: top.x, y: top.y + 2 * h + inset / 2), CGPoint(x: top.x - w, y: top.y + h)]
    }

    // MARK: - 방 (벽 두 면 + 창문 틀 + 체크무늬 마루)

    static func makeRoom() -> SKTexture {
        let size = roomSize, origin = roomGridOrigin
        let columns = InstituteState.gridColumns, rows = InstituteState.gridRows
        func top(_ c: Int, _ r: Int) -> CGPoint {
            CGPoint(x: origin.x + CGFloat((c - r) * tileWidth / 2), y: origin.y + CGFloat((c + r) * tileHeight / 2))
        }
        return texture(render(width: size.width, height: size.height) { ctx in
            let wall = CGFloat(wallHeight)
            let leftEnd = top(0, rows), corner = top(0, 0), rightEnd = top(columns, 0)
            fill(ctx, [leftEnd, corner, CGPoint(x: corner.x, y: corner.y - wall), CGPoint(x: leftEnd.x, y: leftEnd.y - wall)], wallShade)
            fill(ctx, [corner, rightEnd, CGPoint(x: rightEnd.x, y: rightEnd.y - wall), CGPoint(x: corner.x, y: corner.y - wall)], wallLight)
            // 걸레받이
            fill(ctx, [leftEnd, corner, CGPoint(x: corner.x, y: corner.y - 3), CGPoint(x: leftEnd.x, y: leftEnd.y - 3)], wallTrim.shaded(0.9))
            fill(ctx, [corner, rightEnd, CGPoint(x: rightEnd.x, y: rightEnd.y - 3), CGPoint(x: corner.x, y: corner.y - 3)], wallTrim)

            // 오른쪽 벽 창문: 유리 부분은 투명하게 비워 뒤의 연구소 하늘 캔버스가 비쳐 보이게 함
            for window in windowQuads() {
                fill(ctx, window.frame, windowFrame)
                ctx.setBlendMode(.clear)
                fill(ctx, window.glass, RGB(0, 0, 0, 1))
                ctx.setBlendMode(.normal)
            }

            for r in 0..<rows {
                for c in 0..<columns {
                    let t = top(c, r)
                    fill(ctx, diamond(top: t), (c + r) % 2 == 0 ? floorLight : floorDark)
                    // 판자 이음매: 타일 아래쪽 두 변에 한 줄
                    fill(ctx, [CGPoint(x: t.x, y: t.y + 15), CGPoint(x: t.x + 16, y: t.y + 7),
                               CGPoint(x: t.x + 16, y: t.y + 8), CGPoint(x: t.x, y: t.y + 16)], floorSeam)
                }
            }
        })
    }

    /// 오른쪽 벽(row 0)의 창문 두 개 — (프레임 사각형, 유리 사각형) 아트 좌표
    static func windowQuads() -> [(frame: [CGPoint], glass: [CGPoint])] {
        let origin = roomGridOrigin
        func top(_ c: Int) -> CGPoint {
            CGPoint(x: origin.x + CGFloat(c * tileWidth / 2), y: origin.y + CGFloat(c * tileHeight / 2))
        }
        return [1, 4].map { column in
            let a = top(column), b = top(column + 1)
            func quad(_ inset: CGFloat, _ low: CGFloat, _ high: CGFloat) -> [CGPoint] {
                let ax = a.x + inset, bx = b.x - inset
                let ay = a.y + inset / 2, by = b.y - inset / 2
                return [CGPoint(x: ax, y: ay - low), CGPoint(x: bx, y: by - low),
                        CGPoint(x: bx, y: by - high), CGPoint(x: ax, y: ay - high)]
            }
            return (quad(1, 8, 36), quad(3, 10, 34))
        }
    }

    // MARK: - 시설 블록

    struct BlockStyle {
        let height: Int
        let top: RGB, left: RGB, right: RGB
    }

    static func style(for kind: FacilityKind) -> BlockStyle {
        switch kind {
        case .researcherDesk: return BlockStyle(height: 10, top: RGB(0.66, 0.46, 0.28), left: RGB(0.50, 0.33, 0.20), right: RGB(0.42, 0.27, 0.16))
        case .kanjiArchive: return BlockStyle(height: 28, top: RGB(0.48, 0.33, 0.21), left: RGB(0.38, 0.25, 0.15), right: RGB(0.32, 0.21, 0.13))
        case .copyRoom: return BlockStyle(height: 12, top: RGB(0.85, 0.82, 0.74), left: RGB(0.68, 0.64, 0.56), right: RGB(0.60, 0.56, 0.49))
        case .recordingBooth: return BlockStyle(height: 30, top: RGB(0.52, 0.72, 0.86), left: RGB(0.38, 0.56, 0.70), right: RGB(0.32, 0.48, 0.62))
        case .serverRack: return BlockStyle(height: 32, top: RGB(0.24, 0.28, 0.34), left: RGB(0.17, 0.20, 0.25), right: RGB(0.13, 0.15, 0.19))
        }
    }

    /// 시설 텍스처 크기와, 타일 중심이 텍스처 안 어디인지 (SpriteKit anchorPoint용, 아래-왼쪽 기준 비율)
    static func facilitySize(_ kind: FacilityKind) -> (width: Int, height: Int, anchor: CGPoint) {
        let height = style(for: kind).height + tileHeight + 12   // 위쪽 소품 여유 12
        return (tileWidth, height, CGPoint(x: 0.5, y: CGFloat(tileHeight / 2) / CGFloat(height)))
    }

    /// LED 깜빡임 등 프레임 차이가 있는 시설은 frame 0/1 두 장
    static func makeFacility(_ kind: FacilityKind, highlighted: Bool, frame: Int = 0) -> SKTexture {
        let s = style(for: kind)
        let size = facilitySize(kind)
        return texture(render(width: size.width, height: size.height) { ctx in
            let h = CGFloat(s.height)
            let cx = CGFloat(tileWidth) / 2
            let cy = CGFloat(size.height) - CGFloat(tileHeight) / 2   // 타일 중심 (위-왼쪽 좌표)
            let w: CGFloat = 14, hh: CGFloat = 7
            let left = [CGPoint(x: cx - w, y: cy), CGPoint(x: cx, y: cy + hh), CGPoint(x: cx, y: cy + hh - h), CGPoint(x: cx - w, y: cy - h)]
            let right = [CGPoint(x: cx + w, y: cy), CGPoint(x: cx, y: cy + hh), CGPoint(x: cx, y: cy + hh - h), CGPoint(x: cx + w, y: cy - h)]
            let topFace = [CGPoint(x: cx, y: cy - hh - h), CGPoint(x: cx + w, y: cy - h), CGPoint(x: cx, y: cy + hh - h), CGPoint(x: cx - w, y: cy - h)]

            // 바닥 그림자
            fill(ctx, diamond(top: CGPoint(x: cx + 1, y: cy - 7), inset: 1), RGB(0, 0, 0, 0.18))
            fill(ctx, left, s.left)
            fill(ctx, right, s.right)
            fill(ctx, topFace, s.top)
            // 윗면 하이라이트 한 줄 (볼록한 느낌)
            fill(ctx, [CGPoint(x: cx, y: cy - hh - h), CGPoint(x: cx - w, y: cy - h), CGPoint(x: cx - w + 2, y: cy - h), CGPoint(x: cx, y: cy - hh - h + 1)], s.top.shaded(1.18))

            switch kind {
            case .kanjiArchive:
                let colors = [RGB(0.78, 0.25, 0.22), RGB(0.90, 0.60, 0.20), RGB(0.20, 0.60, 0.58), RGB(0.33, 0.33, 0.70), RGB(0.55, 0.38, 0.22)]
                for shelf in 0..<3 {
                    let base = cy + hh - h + 7 + CGFloat(shelf) * 7
                    for book in 0..<5 {
                        let x = cx + 2 + CGFloat(book) * 2.4
                        let y = base - CGFloat(book) * 1.2
                        rect(ctx, x.rounded(), (y - 5).rounded(), 2, 5, colors[(book + shelf) % colors.count])
                    }
                    fill(ctx, [CGPoint(x: cx, y: base + 1), CGPoint(x: cx + w, y: base - 6), CGPoint(x: cx + w, y: base - 5), CGPoint(x: cx, y: base + 2)], s.left.shaded(0.8))
                }
            case .serverRack:
                for slot in 0..<4 {
                    let y = cy + hh - h + 6 + CGFloat(slot) * 6
                    let lit = (slot + frame) % 3 != 0
                    rect(ctx, cx + 3, (y - CGFloat(slot) * 0).rounded(), 2, 2, lit ? RGB(0.35, 0.95, 0.45) : RGB(0.15, 0.35, 0.18))
                    rect(ctx, cx + 7, y.rounded() - 2, 5, 1, RGB(0.32, 0.36, 0.44))
                }
            case .recordingBooth:
                rect(ctx, cx - 1, cy - h - 12, 2, 7, RGB(0.15, 0.15, 0.18))
                rect(ctx, cx - 2, cy - h - 16, 4, 4, frame == 0 ? RGB(0.62, 0.62, 0.66) : RGB(0.80, 0.80, 0.84))
                rect(ctx, cx - 6, cy - h + 3, 4, 1, RGB(0.90, 0.30, 0.30))   // ON AIR
            case .copyRoom:
                rect(ctx, cx - 5, cy - h - 4, 9, 5, RGB(0.98, 0.97, 0.94))
                rect(ctx, cx - 3, cy - h - 3, 5, 1, RGB(0.20, 0.20, 0.24))
                rect(ctx, cx - 3, cy - h - 1, 3, 1, RGB(0.20, 0.20, 0.24))
                rect(ctx, cx + 4, cy - h - 6, 1, 6, RGB(0.15, 0.15, 0.18))  // 붓
            case .researcherDesk:
                rect(ctx, cx - 8, cy - h - 6, 7, 5, RGB(0.85, 0.86, 0.90))   // 노트북
                rect(ctx, cx - 7, cy - h - 5, 5, 3, frame == 0 ? RGB(0.45, 0.70, 0.95) : RGB(0.55, 0.78, 0.98))
                rect(ctx, cx + 2, cy - h - 7, 5, 7, RGB(0.80, 0.24, 0.22))   // 책 더미
                rect(ctx, cx + 2, cy - h - 4, 5, 1, RGB(0.95, 0.90, 0.80))
            }

            if highlighted {
                ctx.setStrokeColor(gold.cg)
                ctx.setLineWidth(1)
                for face in [left, right, topFace] {
                    ctx.beginPath()
                    ctx.addLines(between: face)
                    ctx.closePath()
                    ctx.strokePath()
                }
            }
        })
    }

    // MARK: - 주임 연구원 (단발 · 안경 · 흰 가운) 8×14, 걷기 두 장

    static let guideSprites: [[String]] = [
        [ "..hhhh..", ".hhhhhh.", ".hssssh.", ".gegeg..", ".hssssh.", "..ssss..", "..cccc..",
          ".cccccc.", "scccccs.", ".cccccc.", "..cccc..", "..pppp..", "..p..p..", "..k..k.." ],
        [ "..hhhh..", ".hhhhhh.", ".hssssh.", ".gegeg..", ".hssssh.", "..ssss..", "..cccc..",
          ".cccccc.", "scccccs.", ".cccccc.", "..cccc..", "..pppp..", "..p..p..", ".k....k." ]
    ]

    static let guidePalette: [Character: RGB] = [
        "h": RGB(0.16, 0.13, 0.16), "s": RGB(0.98, 0.86, 0.76), "g": RGB(0.25, 0.30, 0.40),
        "e": RGB(0.55, 0.75, 0.95), "c": RGB(0.96, 0.96, 0.98), "p": RGB(0.25, 0.30, 0.42),
        "k": RGB(0.15, 0.15, 0.18)
    ]

    static func makeSprite(_ rows: [String], palette: [Character: RGB]) -> CGImage? {
        let width = rows.map(\.count).max() ?? 0
        return render(width: width, height: rows.count) { ctx in
            for (y, line) in rows.enumerated() {
                for (x, char) in line.enumerated() {
                    guard let color = palette[char] else { continue }
                    rect(ctx, CGFloat(x), CGFloat(y), 1, 1, color)
                }
            }
        }
    }

    static func makeGuide(frame: Int) -> SKTexture {
        texture(makeSprite(guideSprites[frame % guideSprites.count], palette: guidePalette))
    }

    /// HUD 초상화용 — 64×64 초상화 에셋, 없으면 코드 스프라이트의 얼굴 위쪽 8줄
    static func guidePortrait() -> CGImage? {
        bundledImage("chief_researcher_portrait") ?? makeSprite(Array(guideSprites[0].prefix(8)), palette: guidePalette)
    }

    // MARK: - 캐릭터 스프라이트 에셋 (Resources/Art/Characters, 48×48 · 발 기준 하단 정렬)
    // 원본·제작 기록: Docs/Art/Characters. 남동(앞) · 북서(뒤) 두 방향만 있고 나머지는 좌우 반전.

    struct CharacterFrames {
        let idleFront: SKTexture
        let walkFront: [SKTexture]
        let back: SKTexture
        let artSize: CGSize
    }

    static let characterArtSize = 48
    /// 캐릭터 픽셀 1칸 = 방 픽셀 0.5칸. 48px 그대로면 벽(40px)보다 커서, 키를 방 기준 24px로 맞춤
    static let characterPixelRatio: CGFloat = 0.5

    static func characterFrames(_ role: ResearcherAgent.Role) -> CharacterFrames {
        let name = role == .chief ? "chief_researcher" : "newcomer"
        let images = ["idle_se", "walk_se_a", "walk_se_b", "idle_nw"].map { bundledImage("\(name)_\($0)") }
        if images.allSatisfy({ $0 != nil }) {
            let t = images.map { texture($0) }
            let side = CGFloat(characterArtSize)
            return CharacterFrames(idleFront: t[0], walkFront: [t[1], t[2]], back: t[3], artSize: CGSize(width: side, height: side))
        }
        // 에셋을 못 찾으면 코드로 그린 임시 스프라이트 (두 사람 모두)
        let walk = [makeGuide(frame: 0), makeGuide(frame: 1)]
        return CharacterFrames(idleFront: walk[0], walkFront: walk, back: walk[0], artSize: CGSize(width: 16, height: 28))
    }

    static func bundledImage(_ name: String) -> CGImage? {
        for bundle in [Bundle.module, Bundle.main] {
            for sub in [nil, "Art/Characters", "Resources/Art/Characters"] as [String?] {
                guard let url = bundle.url(forResource: name, withExtension: "png", subdirectory: sub),
                      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
                return image
            }
        }
        return nil
    }
}
