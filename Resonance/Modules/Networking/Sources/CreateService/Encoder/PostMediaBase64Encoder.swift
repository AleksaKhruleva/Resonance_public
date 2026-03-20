import Foundation

struct PostMediaBase64Encoder: Encodable {

    enum CodingKeys: String, CodingKey {
        case imageBase64 = "Image"
        case audioBase64 = "Audio"
        case duration = "Duration"
    }

    let imageBase64: String
    let audioBase64: String
    let duration: Int

    init(
        imageData: Data,
        audioData: Data,
        duration: Int
    ) {
        self.imageBase64 = imageData.base64EncodedString()
        self.audioBase64 = audioData.base64EncodedString()
        self.duration = duration
    }

    func encodeToBase64String() throws -> String {
        let jsonData = try JSONEncoder().encode(self)
        return jsonData.base64EncodedString()
    }
}
