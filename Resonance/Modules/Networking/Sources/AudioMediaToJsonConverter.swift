import Foundation

struct AudioMediaToJsonConverter: Decodable {

    enum CodingKeys: String, CodingKey {
        case audioBase64 = "Audio"
        case duration = "Duration"
    }

    private let audioBase64: String
    private let duration: Int

    var audioData: Data? {
        Data(base64Encoded: audioBase64, options: .ignoreUnknownCharacters)
    }

    var durationSeconds: Int {
        duration
    }

    init(_ base64String: String) {
        guard
            let jsonData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
            let decoded = try? JSONDecoder().decode(Self.self, from: jsonData)
        else {
            self.audioBase64 = ""
            self.duration = 0
            return
        }

        self = decoded
    }
}

