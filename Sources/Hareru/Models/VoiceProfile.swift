import Foundation

// MARK: - 음성 캐릭터 설정
struct VoiceProfile: Codable, Equatable, Hashable {
    let label: String
    let pitch: Float
    let rate: Float

    static let buchou = VoiceProfile(label: "부장님", pitch: 0.75, rate: 0.42)
    static let tenchou = VoiceProfile(label: "라멘집 사장님", pitch: 0.90, rate: 0.48)
}
