import SwiftUI

// MARK: - 연구소 UI 픽셀 아이콘 (Resources/Art/UI, 16px · 24px) — 원본·제작 기록: Docs/Art/UI
// 바깥 틀(칩 · 판 · 도크)은 Liquid Glass 그대로, 안의 아이콘만 게임 화풍 픽셀 → '유리창 너머 픽셀 연구소' (GAME_DESIGN §9.1)
// 1pt = 1px 정수 배율로만 그려서 픽셀이 뭉개지지 않게. 에셋이 없으면 SF Symbol로 대체.
struct PixelIcon: View {
    enum Name: String, CaseIterable {
        case researchPoints = "research_points"
        case influence, restored, budget, build, restore, status, combo, locked, menu, interior
        case facilityResearcherDesk = "facility_researcher_desk"
        case facilityKanjiArchive = "facility_kanji_archive"
        case facilityCopyRoom = "facility_copy_room"
        case facilityRecordingBooth = "facility_recording_booth"
        case facilityServerRack = "facility_server_rack"

        static func facility(_ kind: FacilityKind) -> Name {
            switch kind {
            case .researcherDesk, .traineeDesk: return .facilityResearcherDesk
            case .kanjiArchive: return .facilityKanjiArchive
            case .copyRoom: return .facilityCopyRoom
            case .recordingBooth: return .facilityRecordingBooth
            case .serverRack: return .facilityServerRack
            }
        }

        var fallbackSymbol: String {
            switch self {
            case .researchPoints: return "atom"
            case .influence: return "sparkles"
            case .restored: return "character.book.closed"
            case .budget: return "yensign.circle"
            case .build: return "hammer.fill"
            case .restore: return "character.book.closed.fill"
            case .status: return "chart.bar.doc.horizontal.fill"
            case .combo: return "sparkles"
            case .locked: return "lock.fill"
            case .menu: return "square.grid.2x2.fill"
            case .interior: return "paintbrush.fill"
            case .facilityResearcherDesk: return "desktopcomputer"
            case .facilityKanjiArchive: return "books.vertical.fill"
            case .facilityCopyRoom: return "pencil.and.scribble"
            case .facilityRecordingBooth: return "mic.fill"
            case .facilityServerRack: return "server.rack"
            }
        }
    }

    static let sizes = [16, 24]

    let name: Name
    var size: Int = 16

    /// 아이콘 28장은 작아서 처음 쓸 때 한 번에 읽어 둠
    private static let images: [String: CGImage] = {
        var loaded: [String: CGImage] = [:]
        for name in Name.allCases {
            for size in sizes {
                let key = "icon_\(name.rawValue)_\(size)"
                loaded[key] = OfficePixelArt.bundledImage(key)
            }
        }
        return loaded
    }()

    static func image(_ name: Name, size: Int) -> CGImage? {
        images["icon_\(name.rawValue)_\(size)"]
    }

    var body: some View {
        Group {
            if let image = Self.image(name, size: size) {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
            } else {
                Image(systemName: name.fallbackSymbol)
                    .font(.system(size: CGFloat(size) * 0.75, weight: .semibold))
            }
        }
        .frame(width: CGFloat(size), height: CGFloat(size))
        .accessibilityHidden(true)
    }
}
