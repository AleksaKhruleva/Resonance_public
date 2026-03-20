import Foundation

public enum AudioDurationFormatter {

    public static let defaultString = "0:00"

    public static func string(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
