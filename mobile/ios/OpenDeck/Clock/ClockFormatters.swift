import Foundation

enum ClockFormatter {
    static func timer(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let secs = clamped % 60
        if hours > 0 {
            return "\(two(hours)):\(two(minutes)):\(two(secs))"
        }
        return "\(two(minutes)):\(two(secs))"
    }

    static func countdown(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        return "\(two(clamped / 60)):\(two(clamped % 60))"
    }

    static func stopwatch(_ milliseconds: Int) -> String {
        let clamped = max(0, milliseconds)
        let minutes = clamped / 60000
        let seconds = (clamped % 60000) / 1000
        let centis = (clamped % 1000) / 10
        return "\(two(minutes)):\(two(seconds)).\(two(centis))"
    }

    static func worldClock(in timeZone: TimeZone, date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return "\(two(components.hour ?? 0)):\(two(components.minute ?? 0)):\(two(components.second ?? 0))"
    }

    static func two(_ number: Int) -> String {
        String(format: "%02d", number)
    }
}
