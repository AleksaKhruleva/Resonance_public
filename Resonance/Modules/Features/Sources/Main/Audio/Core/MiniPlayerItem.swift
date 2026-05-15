import Foundation
import Core

struct MiniPlayerItem: Equatable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let audio: Audio

    static func == (lhs: MiniPlayerItem, rhs: MiniPlayerItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
