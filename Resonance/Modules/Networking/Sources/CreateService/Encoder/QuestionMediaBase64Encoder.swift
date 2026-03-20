import Foundation

struct QuestionMediaBase64Encoder: Encodable {

    enum CodingKeys: String, CodingKey {
        case audioBase64 = "Audio"
        case duration = "Duration"
    }

    let audioBase64: String
    let duration: Int

    init(
        audioData: Data,
        duration: Int
    ) {
        self.audioBase64 = audioData.base64EncodedString()
        self.duration = duration
    }

    func encodeToBase64String() throws -> String {
        let jsonData = try JSONEncoder().encode(self)
        return jsonData.base64EncodedString()
    }
}
