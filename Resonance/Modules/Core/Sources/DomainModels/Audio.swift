import Foundation

public struct Audio: Hashable {
    
    public let data: Data
    public let durationSeconds: Int
    
    public init(
        data: Data,
        durationSeconds: Int
    ) {
        self.data = data
        self.durationSeconds = durationSeconds
    }
}
