import SwiftUI

// MARK: - 단어 도메인 모델
struct Word: Identifiable, Equatable {
    let id = UUID()
    let category: String         // 상단 카테고리 표시용 (예: "음식")
    let term: String             // 단어 (일본어)
    let reading: String          // 읽는 법 (히라가나)
    let meaning: String          // 뜻 (정답)
    let example: String          // 일본어 예문

    // 예문 해석(한국어)을 "앞 / 정답 / 뒤"로 나눠 저장
    let transBefore: String
    let transAnswer: String
    let transAfter: String

    let colors: [Color]          // 단어의 퍼스널 컬러 3개
    let voice: VoiceProfile      // 음성 캐릭터

    // 🔊 오디오 리소스 파일 이름 (Resources/Audio 폴더 기준, 확장자 제외)
    let termAudioFile: String    // 예: "beer_term"
    let exampleAudioFile: String // 예: "beer_example"
}
