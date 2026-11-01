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

    // MARK: - 방 (벽 두 면 + 창문 틀 + 마루)
    // 텍스처는 에셋 밀도(방 픽셀 1칸 = 2칸)로 그림. 바닥·벽 텍스처 에셋은 아이소메트릭 면에 투영하고,
    // 에셋이 없으면 단색 체크무늬로 대체.

    static func makeRoom() -> SKTexture {
        let size = roomSize, origin = roomGridOrigin
        let columns = InstituteState.gridColumns, rows = InstituteState.gridRows
        func top(_ c: Int, _ r: Int) -> CGPoint {
            CGPoint(x: origin.x + CGFloat((c - r) * tileWidth / 2), y: origin.y + CGFloat((c + r) * tileHeight / 2))
        }
        let density = CGFloat(assetDensity)
        let floorTexture = bundledImage("texture_floor"), wallTexture = bundledImage("texture_wall")
        return texture(render(width: size.width * assetDensity, height: size.height * assetDensity) { ctx in
            ctx.scaleBy(x: density, y: density)
            let wall = CGFloat(wallHeight)
            let leftEnd = top(0, rows), corner = top(0, 0), rightEnd = top(columns, 0)
            let leftWall = [leftEnd, corner, CGPoint(x: corner.x, y: corner.y - wall), CGPoint(x: leftEnd.x, y: leftEnd.y - wall)]
            let rightWall = [corner, rightEnd, CGPoint(x: rightEnd.x, y: rightEnd.y - wall), CGPoint(x: corner.x, y: corner.y - wall)]
            fill(ctx, leftWall, wallShade)
            fill(ctx, rightWall, wallLight)
            if let wallTexture {
                // 벽지 한 장이 벽 높이를 꽉 채우게 (위쪽 전선관이 천장선에 오도록), 가로는 에셋 1칸 = 방 0.5칸
                let down = CGVector(dx: 0, dy: wall / CGFloat(wallTexture.height))
                drawProjected(ctx, wallTexture, clip: rightWall, origin: CGPoint(x: corner.x, y: corner.y - wall),
                              across: texelStep(16, 8), down: down)
                drawProjected(ctx, wallTexture, clip: leftWall, origin: CGPoint(x: leftEnd.x, y: leftEnd.y - wall),
                              across: texelStep(16, -8), down: down)
                fill(ctx, leftWall, RGB(0.12, 0.10, 0.14, 0.16))   // 왼쪽 벽은 창 반대편이라 그늘
            }
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

            if let floorTexture {
                // 마루 텍스처는 바닥 전체에 이어 깔고, 배치 격자가 보이도록 칸마다 옅은 체크 그늘만 얹음
                let floor = [top(0, 0), top(columns, 0), top(columns, rows), top(0, rows)]
                drawProjected(ctx, floorTexture, clip: floor, origin: top(0, 0), across: texelStep(16, 8), down: texelStep(-16, 8))
            }
            for r in 0..<rows {
                for c in 0..<columns {
                    let t = top(c, r)
                    if floorTexture == nil {
                        fill(ctx, diamond(top: t), (c + r) % 2 == 0 ? floorLight : floorDark)
                    } else if (c + r) % 2 == 1 {
                        fill(ctx, diamond(top: t), RGB(0.18, 0.10, 0.04, 0.10))
                    }
                    // 판자 이음매: 타일 아래쪽 두 변에 한 줄
                    fill(ctx, [CGPoint(x: t.x, y: t.y + 15), CGPoint(x: t.x + 16, y: t.y + 7),
                               CGPoint(x: t.x + 16, y: t.y + 8), CGPoint(x: t.x, y: t.y + 16)],
                         floorTexture == nil ? floorSeam : RGB(0.30, 0.20, 0.12, 0.30))
                }
            }
        })
    }

    /// 방 아트 좌표에서 에셋 텍셀 1칸의 길이 = 방 픽셀 0.5칸 (캐릭터·시설과 같은 밀도), 방향은 (dx, dy)
    static func texelStep(_ dx: CGFloat, _ dy: CGFloat) -> CGVector {
        let length = (dx * dx + dy * dy).squareRoot()
        return CGVector(dx: dx / length / CGFloat(assetDensity), dy: dy / length / CGFloat(assetDensity))
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

    // MARK: - 환경 에셋 (Resources/Art/Environment) — 원본·제작 기록: Docs/Art/Environment
    // 방 픽셀 1칸 = 에셋 2칸 (캐릭터와 같은 밀도). 시설 스프라이트는 바닥이 발판의 아래 꼭짓점.

    static let assetDensity = 2
    /// 콤보 금색 테두리가 잘리지 않게 시설 캔버스 둘레에 두는 여백 (에셋 픽셀)
    static let facilityPadding = 2

    private static func facilityAssetName(_ kind: FacilityKind) -> String {
        switch kind {
        case .researcherDesk: return "facility_researcher_desk"
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

    /// 벽가 장식 소품 (자리 고정, 그 칸에 시설이 놓이면 숨김). 쇠퇴한 연구소 분위기용
    static let decorPlacements: [(asset: String, cell: GridPosition)] = [
        ("prop_plant", GridPosition(column: 0, row: 0)),            // 안쪽 구석의 시든 화분
        ("prop_bucket", GridPosition(column: 3, row: 0)),           // 창문 사이 천장 누수
        ("prop_vending_machine", GridPosition(column: 5, row: 0)),  // 오른쪽 벽 끝 낡은 자판기
        ("prop_cables", GridPosition(column: 0, row: 2)),           // 왼쪽 벽가 엉킨 전선
        ("prop_boxes", GridPosition(column: 0, row: 5))             // 왼쪽 벽 끝 기록 상자
    ]

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
            for sub in [nil, "Art/Characters", "Art/Environment", "Resources/Art/Characters", "Resources/Art/Environment"] as [String?] {
                guard let url = bundle.url(forResource: name, withExtension: "png", subdirectory: sub),
                      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
                return image
            }
        }
        return nil
    }
}
