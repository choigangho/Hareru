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

    // MARK: 1단계 방 그림 (Docs/Art/Environment/stage1)
    // Pixellab /unzoom으로 4배 격자를 되찾은 381×244 픽셀 그림 한 장. 그림 1픽셀 = 아트 픽셀 1칸 (시설 에셋은 그 절반 크기의 픽셀 밀도).

    static let stageRoomName = "room_stage1"
    static let stageRoomImage: CGImage? = bundledImage(stageRoomName)
    static var usesStageRoom: Bool { stageRoomImage != nil }

    /// 방 그림 안에서 격자 (0, 0) 타일 윗꼭짓점의 위치 (위-왼쪽 기준 아트 좌표) — 그림의 열린 바닥에 6×6 마름모를 맞춘 값
    static let stageRoomGridOrigin = CGPoint(x: 166, y: 84)

    /// 방 텍스처의 아트 크기
    static var roomSize: (width: Int, height: Int) {
        if let image = stageRoomImage { return (image.width, image.height) }
        let columns = InstituteState.gridColumns, rows = InstituteState.gridRows
        return ((columns + rows) * tileWidth / 2, wallHeight + (columns + rows) * tileHeight / 2 + floorEdge)
    }

    /// 방 텍스처 안에서 격자 (0,0) 타일 윗꼭짓점의 위치 (위-왼쪽 기준 아트 좌표)
    static var roomGridOrigin: CGPoint {
        if stageRoomImage != nil { return stageRoomGridOrigin }
        return CGPoint(x: CGFloat(InstituteState.gridRows * tileWidth / 2), y: CGFloat(wallHeight))
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

    // MARK: - 방 (벽 두 면 + 창문 + 마루)
    // 텍스처는 에셋 밀도(방 픽셀 1칸 = 2칸)로 그림.
    // 바닥: 고른 마루 테마의 평면 텍스처를 바닥 전체에 이음매 없이 투영 (칸마다 찍지 않음 → 하나로 통일된 바닥)
    // 벽: 고른 외벽 테마로 두 벽면을 한 면씩 이어 그림 (패널 사이 틈 없음). 창문은 오른쪽 벽 가운데 하나로 자동 배치,
    //     유리는 투명하게 뚫어 방 뒤의 연구소 하늘(날씨)이 비치고, 옅은 빛 반사만 얹음.

    /// 바닥 앞쪽 두께 (방 픽셀)
    static let floorEdge = 3

    static func floorAssetName(_ theme: FloorTheme) -> String {
        switch theme {
        case .lightWood: return "floor_light_wood"
        case .darkWood: return "floor_dark_wood"
        }
    }

    struct WallPalette {
        let upper: RGB, stain: RGB, rail: RGB, wainscot: RGB, board: RGB, base: RGB, cap: RGB
        let boardsOnUpper: Bool      // 목재 판벽은 위쪽에도 판자 줄
        let tieHoles: Bool           // 콘크리트 거푸집 구멍
    }

    static func wallPalette(_ theme: WallTheme) -> WallPalette {
        switch theme {
        case .plasterTeal:
            return WallPalette(upper: RGB(0.88, 0.86, 0.78), stain: RGB(0.70, 0.66, 0.52, 0.45), rail: RGB(0.30, 0.37, 0.38),
                               wainscot: RGB(0.43, 0.54, 0.53), board: RGB(0.35, 0.45, 0.45), base: RGB(0.21, 0.25, 0.28),
                               cap: RGB(0.95, 0.93, 0.87), boardsOnUpper: false, tieHoles: false)
        case .woodPanel:
            return WallPalette(upper: RGB(0.62, 0.46, 0.32), stain: RGB(0.40, 0.28, 0.18, 0.45), rail: RGB(0.27, 0.18, 0.11),
                               wainscot: RGB(0.44, 0.30, 0.20), board: RGB(0.33, 0.22, 0.14), base: RGB(0.18, 0.12, 0.08),
                               cap: RGB(0.72, 0.56, 0.40), boardsOnUpper: true, tieHoles: false)
        case .concrete:
            return WallPalette(upper: RGB(0.67, 0.68, 0.66), stain: RGB(0.48, 0.50, 0.48, 0.45), rail: RGB(0.40, 0.42, 0.42),
                               wainscot: RGB(0.56, 0.58, 0.57), board: RGB(0.47, 0.49, 0.48), base: RGB(0.29, 0.31, 0.32),
                               cap: RGB(0.76, 0.77, 0.75), boardsOnUpper: false, tieHoles: true)
        }
    }

    static func makeRoom(floor floorTheme: FloorTheme = .lightWood, wall wallTheme: WallTheme = .plasterTeal) -> SKTexture {
        if let image = stageRoomImage { return texture(image) }
        let size = roomSize, origin = roomGridOrigin
        let columns = InstituteState.gridColumns, rows = InstituteState.gridRows
        func top(_ c: Int, _ r: Int) -> CGPoint {
            CGPoint(x: origin.x + CGFloat((c - r) * tileWidth / 2), y: origin.y + CGFloat((c + r) * tileHeight / 2))
        }
        let density = CGFloat(assetDensity)
        let floorImage = bundledImage(floorAssetName(floorTheme))
        return texture(render(width: size.width * assetDensity, height: size.height * assetDensity) { ctx in
            ctx.scaleBy(x: density, y: density)
            ctx.interpolationQuality = .none
            drawWalls(ctx, palette: wallPalette(wallTheme), leftEnd: top(0, rows), corner: top(0, 0), length: CGFloat(columns * tileWidth / 2))

            let floor = [top(0, 0), top(columns, 0), top(columns, rows), top(0, rows)]
            let edge = CGFloat(floorEdge)
            if let floorImage {
                // 평면 텍스처 1장 = 타일 1칸 (텍셀 32개가 칸의 한 변), 바닥 전체에 이어 깔기
                let n = CGFloat(floorImage.width)
                drawProjected(ctx, floorImage, clip: floor, origin: top(0, 0),
                              across: CGVector(dx: 16 / n, dy: 8 / n), down: CGVector(dx: -16 / n, dy: 8 / n))
            } else {
                fill(ctx, floor, floorLight)
            }
            // 바닥 앞쪽 두께 면 (왼쪽 앞 · 오른쪽 앞)
            let front = top(columns, rows), left = top(0, rows), right = top(columns, 0)
            fill(ctx, [left, front, CGPoint(x: front.x, y: front.y + edge), CGPoint(x: left.x, y: left.y + edge)], floorDark.shaded(0.62))
            fill(ctx, [front, right, CGPoint(x: right.x, y: right.y + edge), CGPoint(x: front.x, y: front.y + edge)], floorDark.shaded(0.5))
        })
    }

    /// 두 벽면을 테마 색으로 이어 그림. 벽면 좌표: u = 벽을 따라 가로 방 픽셀(0…length), v = 위에서 아래로(0…40)
    private static func drawWalls(_ ctx: CGContext, palette w: WallPalette, leftEnd: CGPoint, corner: CGPoint, length: CGFloat) {
        let height = CGFloat(wallHeight)
        // 왼쪽 벽: leftEnd → corner (오른쪽으로 갈수록 올라감), 오른쪽 벽: corner → 오른쪽 끝 (내려감)
        func leftPoint(_ u: CGFloat, _ v: CGFloat) -> CGPoint { CGPoint(x: leftEnd.x + u, y: leftEnd.y - u / 2 - height + v) }
        func rightPoint(_ u: CGFloat, _ v: CGFloat) -> CGPoint { CGPoint(x: corner.x + u, y: corner.y + u / 2 - height + v) }

        for (isLeft, point) in [(true, leftPoint), (false, rightPoint)] as [(Bool, (CGFloat, CGFloat) -> CGPoint)] {
            func quad(_ u0: CGFloat, _ u1: CGFloat, _ v0: CGFloat, _ v1: CGFloat, _ color: RGB) {
                fill(ctx, [point(u0, v0), point(u1, v0), point(u1, v1), point(u0, v1)], color)
            }
            quad(0, length, 0, height, w.upper)
            if w.boardsOnUpper {
                for u in stride(from: CGFloat(5), to: length, by: 6) { quad(u, u + 0.5, 1, 23, w.board) }
            }
            if w.tieHoles {
                for u in stride(from: CGFloat(8), to: length, by: 16) {
                    for v in [CGFloat(6), 15] { quad(u, u + 1, v, v + 1, w.board) }
                }
            }
            // 오래된 얼룩 (위치는 고정 — 벽마다 다르게)
            let stains: [(CGFloat, CGFloat, CGFloat, CGFloat)] = isLeft
                ? [(14, 22, 2, 9), (60, 66, 12, 20), (80, 86, 3, 7)]
                : [(8, 13, 4, 12), (70, 78, 2, 6), (88, 93, 10, 19)]
            for (u0, u1, v0, v1) in stains { quad(u0, u1, v0, v1, w.stain) }
            quad(0, length, 0, 1, w.cap)                         // 천장선
            quad(0, length, 23, 24, w.rail)                      // 걸레받이 위 가로대
            quad(0, length, 24, 38, w.wainscot)                  // 징두리
            for u in stride(from: CGFloat(3), to: length, by: 4) { quad(u, u + 0.5, 24, 38, w.board) }
            quad(0, length, 38, height, w.base)                  // 걸레받이
            if isLeft {
                quad(0, length, 0, height, RGB(0.10, 0.09, 0.14, 0.16))   // 창 반대편이라 그늘
                quad(0, 0.5, 0, height, RGB(0.09, 0.10, 0.16))           // 바깥 끝 테두리
            } else {
                quad(0, 0.5, 0, height, RGB(0.09, 0.10, 0.16, 0.7))      // 모서리
                quad(length - 0.5, length, 0, height, RGB(0.09, 0.10, 0.16))
            }
            quad(0, length, -0.5, 0, RGB(0.09, 0.10, 0.16))       // 윗면 테두리
        }
        drawWindow(ctx, frameColor: w.rail, light: w.cap, at: rightPoint, center: length / 2)
    }

    /// 오른쪽 벽 가운데 창문: 창틀 · 십자 창살 · 창턱, 유리는 투명 + 옅은 빛 반사
    private static func drawWindow(_ ctx: CGContext, frameColor: RGB, light: RGB, at point: (CGFloat, CGFloat) -> CGPoint, center: CGFloat) {
        func quad(_ u0: CGFloat, _ u1: CGFloat, _ v0: CGFloat, _ v1: CGFloat, _ color: RGB) {
            fill(ctx, [point(u0, v0), point(u1, v0), point(u1, v1), point(u0, v1)], color)
        }
        let u0 = center - 11, u1 = center + 11, v0: CGFloat = 4, v1: CGFloat = 21
        let outline = RGB(0.09, 0.10, 0.16)
        quad(u0 - 0.5, u1 + 0.5, v0 - 0.5, v1 + 0.5, outline)
        quad(u0, u1, v0, v1, frameColor)
        quad(u0, u1, v0, v0 + 0.5, light)                        // 위 창틀이 빛을 받음
        // 유리 네 칸 (창살 1px, 창틀 1px)
        let mu = center, mv = (v0 + v1) / 2
        let panes: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (u0 + 1, mu - 0.5, v0 + 1, mv - 0.5), (mu + 0.5, u1 - 1, v0 + 1, mv - 0.5),
            (u0 + 1, mu - 0.5, mv + 0.5, v1 - 1), (mu + 0.5, u1 - 1, mv + 0.5, v1 - 1)
        ]
        ctx.setBlendMode(.clear)
        for (a, b, c, d) in panes { quad(a, b, c, d, RGB(0, 0, 0, 1)) }
        ctx.setBlendMode(.normal)
        // 빛 반사: 칸마다 짧은 사선 두 줄 (반투명 흰색)
        let glint = RGB(1, 1, 1, 0.3)
        for (a, _, _, d) in panes {
            for k in 0..<4 {
                let step = CGFloat(k) * 0.5
                quad(a + 1.5 + step, a + 2 + step, d - 1.5 - CGFloat(k), d - 1 - CGFloat(k), glint)
                if k < 2 { quad(a + 3.5 + step, a + 4 + step, d - 1.5 - CGFloat(k), d - 1 - CGFloat(k), glint) }
            }
        }
        // 창턱
        quad(u0 - 1, u1 + 1, v1 + 0.5, v1 + 1.5, light)
        quad(u0 - 1, u1 + 1, v1 + 1.5, v1 + 2, outline)
    }

    /// 인테리어 서랍 견본: 외벽 테마를 평면으로 (가로 24 · 세로 20 방 픽셀 = 에셋 48×40)
    static func wallSwatch(_ theme: WallTheme) -> CGImage? {
        let w = wallPalette(theme)
        return render(width: 48, height: 40) { ctx in
            ctx.scaleBy(x: 2, y: 2)
            rect(ctx, 0, 0, 24, 20, w.upper)
            if w.boardsOnUpper { for x in stride(from: CGFloat(3), to: 24, by: 6) { rect(ctx, x, 1, 0.5, 10, w.board) } }
            if w.tieHoles { for x in [CGFloat(5), 17] { rect(ctx, x, 4, 1, 1, w.board) } }
            rect(ctx, 14, 2, 5, 6, w.stain)
            rect(ctx, 0, 0, 24, 1, w.cap)
            rect(ctx, 0, 11, 24, 1, w.rail)
            rect(ctx, 0, 12, 24, 6, w.wainscot)
            for x in stride(from: CGFloat(2), to: 24, by: 4) { rect(ctx, x, 12, 0.5, 6, w.board) }
            rect(ctx, 0, 18, 24, 2, w.base)
        }
    }

    /// 평평한 텍스처를 clip 면 안에 기울여 이어 깔기. 이미지 윗줄 왼쪽 끝이 origin, 가로 1텍셀 = across, 세로 1텍셀 = down
    static func drawProjected(_ ctx: CGContext, _ image: CGImage, clip: [CGPoint], origin: CGPoint, across: CGVector, down: CGVector) {
        ctx.saveGState()
        ctx.beginPath()
        ctx.addLines(between: clip)
        ctx.closePath()
        ctx.clip()
        // 이미지 공간은 y가 위로 → (h − y)로 뒤집어 윗줄이 origin에 오게
        let h = CGFloat(image.height)
        ctx.concatenate(CGAffineTransform(a: across.dx, b: across.dy, c: -down.dx, d: -down.dy,
                                          tx: origin.x + h * down.dx, ty: origin.y + h * down.dy))
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: h), byTiling: true)
        ctx.restoreGState()
    }

    // MARK: - 시설 블록

    struct BlockStyle {
        let height: Int
        let top: RGB, left: RGB, right: RGB
    }

    static func style(for kind: FacilityKind) -> BlockStyle {
        switch kind {
        case .researcherDesk, .traineeDesk: return BlockStyle(height: 10, top: RGB(0.66, 0.46, 0.28), left: RGB(0.50, 0.33, 0.20), right: RGB(0.42, 0.27, 0.16))
        case .kanjiArchive: return BlockStyle(height: 28, top: RGB(0.48, 0.33, 0.21), left: RGB(0.38, 0.25, 0.15), right: RGB(0.32, 0.21, 0.13))
        case .copyRoom: return BlockStyle(height: 12, top: RGB(0.85, 0.82, 0.74), left: RGB(0.68, 0.64, 0.56), right: RGB(0.60, 0.56, 0.49))
        case .recordingBooth: return BlockStyle(height: 30, top: RGB(0.52, 0.72, 0.86), left: RGB(0.38, 0.56, 0.70), right: RGB(0.32, 0.48, 0.62))
        case .serverRack: return BlockStyle(height: 32, top: RGB(0.24, 0.28, 0.34), left: RGB(0.17, 0.20, 0.25), right: RGB(0.13, 0.15, 0.19))
        }
    }

    /// 시설 크기(방 픽셀)와, 타일 중심이 텍스처 안 어디인지 (SpriteKit anchorPoint용, 아래-왼쪽 기준 비율)
    /// 에셋 시설은 텍스처가 에셋 밀도(2배)라 텍스처 픽셀 크기 = 이 크기 × assetDensity
    static func facilitySize(_ kind: FacilityKind) -> (width: Int, height: Int, anchor: CGPoint) {
        if let canvas = facilityCanvas(kind) {
            let height = canvas.height / assetDensity
            // 스프라이트 바닥 = 발판 마름모의 아래 꼭짓점, 타일 중심은 그보다 8px(+ 테두리 여백) 위
            return (canvas.width / assetDensity, height,
                    CGPoint(x: 0.5, y: CGFloat(tileHeight / 2 + facilityPadding / assetDensity) / CGFloat(height)))
        }
        let height = style(for: kind).height + tileHeight + 12   // 위쪽 소품 여유 12
        return (tileWidth, height, CGPoint(x: 0.5, y: CGFloat(tileHeight / 2) / CGFloat(height)))
    }

    /// LED 깜빡임 등 프레임 차이가 있는 시설은 frame 0/1 두 장
    static func makeFacility(_ kind: FacilityKind, highlighted: Bool, frame: Int = 0) -> SKTexture {
        if let image = facilityImages[kind] {
            return texture(composeFacility(image, highlighted: highlighted, glow: frame % 2 == 1))
        }
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
            case .researcherDesk, .traineeDesk:
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

    // MARK: - 환경 에셋 (Resources/Art/Environment) — 원본·제작 기록: Docs/Art/Environment
    // 방 픽셀 1칸 = 에셋 2칸 (캐릭터와 같은 밀도). 시설 스프라이트는 바닥이 발판의 아래 꼭짓점.

    static let assetDensity = 2
    /// 콤보 금색 테두리가 잘리지 않게 시설 캔버스 둘레에 두는 여백 (에셋 픽셀)
    static let facilityPadding = 2

    private static func facilityAssetName(_ kind: FacilityKind) -> String {
        switch kind {
        case .researcherDesk, .traineeDesk: return "facility_researcher_desk"   // 신입 책상도 같은 책상
        case .kanjiArchive: return "facility_kanji_archive"
        case .copyRoom: return "facility_copy_room"
        case .recordingBooth: return "facility_recording_booth"
        case .serverRack: return "facility_server_rack"
        }
    }

    private static let facilityImages: [FacilityKind: CGImage] = Dictionary(
        uniqueKeysWithValues: FacilityKind.allCases.compactMap { kind in bundledImage(facilityAssetName(kind)).map { (kind, $0) } })

    /// 시설 캔버스 = 타일 폭(64) + 여백, 높이는 짝수로 맞춰 방 픽셀 정수 크기가 되게
    private static func facilityCanvas(_ kind: FacilityKind) -> (width: Int, height: Int)? {
        guard let image = facilityImages[kind] else { return nil }
        let width = max(tileWidth * assetDensity, image.width) + 2 * facilityPadding
        var height = image.height + 2 * facilityPadding
        height += height % 2
        return (width, height)
    }

    /// 에셋 시설 한 장 합성: 아래 가운데 정렬 → (glow) 발광 픽셀 밝게 → (highlighted) 바깥 1칸 금색 테두리
    static func composeFacility(_ image: CGImage, highlighted: Bool, glow: Bool) -> CGImage? {
        let width = max(tileWidth * assetDensity, image.width) + 2 * facilityPadding
        var height = image.height + 2 * facilityPadding
        height += height % 2
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data else { return nil }
        ctx.interpolationQuality = .none
        // CG 좌표는 y가 위로 → y = 여백이면 아래 정렬
        ctx.draw(image, in: CGRect(x: (width - image.width) / 2, y: facilityPadding, width: image.width, height: image.height))
        let px = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        if glow {
            // 화면·LED처럼 밝고 채도 높은 픽셀만 살짝 더 밝게 (프레임 0/1 깜빡임)
            for i in stride(from: 0, to: width * height * 4, by: 4) where px[i + 3] == 255 {
                let r = Int(px[i]), g = Int(px[i + 1]), b = Int(px[i + 2])
                let high = max(r, g, b), low = min(r, g, b)
                guard high > 150, high - low > 90 else { continue }
                px[i] = UInt8(min(255, r * 5 / 4)); px[i + 1] = UInt8(min(255, g * 5 / 4)); px[i + 2] = UInt8(min(255, b * 5 / 4))
            }
        }
        if highlighted {
            let opaque = (0..<(width * height)).map { px[$0 * 4 + 3] > 0 }
            for y in 0..<height {
                for x in 0..<width where !opaque[y * width + x] {
                    let touches = (x > 0 && opaque[y * width + x - 1]) || (x < width - 1 && opaque[y * width + x + 1])
                        || (y > 0 && opaque[(y - 1) * width + x]) || (y < height - 1 && opaque[(y + 1) * width + x])
                    guard touches else { continue }
                    let i = (y * width + x) * 4
                    px[i] = 255; px[i + 1] = 214; px[i + 2] = 92; px[i + 3] = 255
                }
            }
        }
        return ctx.makeImage()
    }

    /// 벽가 장식 소품 (자리 고정, 그 칸에 시설이 놓이면 숨김). 1단계 방 그림에 이미 그려져 있어 지금은 비어 있음 (소품 에셋은 다음 단계 방에서 재사용)
    static let decorPlacements: [(asset: String, cell: GridPosition)] = []

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
        characterFrames(named: role == .chief ? "chief_researcher" : "newcomer")
    }

    /// 음성 캐릭터 출연진 스프라이트 — 파일 이름은 voiceId (`VoiceProfile.gameCast`, GAME_DESIGN §2.2).
    /// 아직 장면에 등장시키지 않음: 급수별 등장 조건(§2.2)이 정해지면 방문자로 씀
    static let castVoiceIDs = ["ai_kuro", "master_gen", "citizen_mio", "courier_rin", "elder_tsuru",
                               "craftsman_jin", "rival_reina", "inspector_ren", "announcer_ai"]

    static func characterFrames(voiceID: String) -> CharacterFrames? {
        let frames = characterFrames(named: voiceID)
        return frames.artSize.width == CGFloat(characterArtSize) ? frames : nil
    }

    private static func characterFrames(named name: String) -> CharacterFrames {
        // 걷기 프레임은 walk_se_a, _b, _c… 있는 만큼 (Pixellab 템플릿은 6프레임)
        let walkImages = "abcdefghijkl".map { bundledImage("\(name)_walk_se_\($0)") }.prefix { $0 != nil }.compactMap { $0 }
        if let idle = bundledImage("\(name)_idle_se"), let back = bundledImage("\(name)_idle_nw"), walkImages.count >= 2 {
            let side = CGFloat(characterArtSize)
            return CharacterFrames(idleFront: texture(idle), walkFront: walkImages.map { texture($0) }, back: texture(back), artSize: CGSize(width: side, height: side))
        }
        // 에셋을 못 찾으면 코드로 그린 임시 스프라이트 (두 사람 모두)
        let walk = [makeGuide(frame: 0), makeGuide(frame: 1)]
        return CharacterFrames(idleFront: walk[0], walkFront: walk, back: walk[0], artSize: CGSize(width: 16, height: 28))
    }

    static func bundledImage(_ name: String) -> CGImage? {
        for bundle in [Bundle.module, Bundle.main] {
            for sub in [nil, "Art/Characters", "Art/Environment", "Art/UI", "Art/Effects", "Resources/Art/Characters", "Resources/Art/Environment", "Resources/Art/UI", "Resources/Art/Effects"] as [String?] {
                guard let url = bundle.url(forResource: name, withExtension: "png", subdirectory: sub),
                      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
                return image
            }
        }
        return nil
    }

    // MARK: - 픽셀 이펙트 (Resources/Art/Effects, 가로 스트립) — 제작 스크립트: Docs/Art/Effects
    // 투명도 대신 디더링으로 사라지게 그려서 픽셀이 끝까지 또렷함. 밀도는 에셋과 같음 (방 픽셀 1칸 = 2칸).

    enum Effect: String, CaseIterable {
        case dust = "fx_dust"         // 시설 착지 먼지
        case sparkle = "fx_sparkle"   // 콤보 성립
        case ink = "fx_ink"           // 한자 복원 완료 — 먹 번짐
        case motes = "fx_motes"       // 연구P 정산 — 청록 입자
        case drip = "fx_drip"         // 천장 누수 (양동이 위 반복)

        /// 한 프레임의 에셋 픽셀 크기
        var frameSize: CGSize {
            switch self {
            case .dust: return CGSize(width: 56, height: 24)
            case .sparkle: return CGSize(width: 48, height: 48)
            case .ink: return CGSize(width: 56, height: 56)
            case .motes: return CGSize(width: 32, height: 40)
            case .drip: return CGSize(width: 16, height: 48)
            }
        }

        var timePerFrame: TimeInterval {
            switch self {
            case .dust: return 0.07
            case .sparkle: return 0.08
            case .ink: return 0.1
            case .motes: return 0.1
            case .drip: return 0.12
            }
        }
    }

    private static let effectFrameCache: [Effect: [SKTexture]] = {
        var cache: [Effect: [SKTexture]] = [:]
        for effect in Effect.allCases {
            guard let strip = bundledImage(effect.rawValue) else { continue }
            let w = Int(effect.frameSize.width), h = Int(effect.frameSize.height)
            cache[effect] = (0..<(strip.width / w)).compactMap { i in
                strip.cropping(to: CGRect(x: i * w, y: 0, width: w, height: h)).map { texture($0) }
            }
        }
        return cache
    }()

    /// 에셋이 없으면 빈 배열 (장면은 이펙트 없이 그대로 동작)
    static func effectFrames(_ effect: Effect) -> [SKTexture] {
        effectFrameCache[effect] ?? []
    }
}
