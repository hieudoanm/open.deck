import Foundation

// Ported from omni `OmniCore/Models/Clock` — keep in sync conceptually.

struct ClockCity: Identifiable, Equatable, Sendable {
    let id: Int
    let label: String
    let country: String
    let timeZoneIdentifier: String
    let latitude: Double
    let longitude: Double
    let isFavorite: Bool

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }
}

enum ClockCities {
    static let all: [ClockCity] = [
        ClockCity(id: 0, label: "Los Angeles", country: "United States", timeZoneIdentifier: "America/Los_Angeles", latitude: 34.0522, longitude: -118.2437, isFavorite: false),
        ClockCity(id: 1, label: "Dallas", country: "United States", timeZoneIdentifier: "America/Chicago", latitude: 32.7767, longitude: -96.797, isFavorite: true),
        ClockCity(id: 2, label: "New York", country: "United States", timeZoneIdentifier: "America/New_York", latitude: 40.7128, longitude: -74.006, isFavorite: false),
        ClockCity(id: 3, label: "London", country: "United Kingdom", timeZoneIdentifier: "Europe/London", latitude: 51.5072, longitude: -0.1276, isFavorite: false),
        ClockCity(id: 4, label: "Frankfurt", country: "Germany", timeZoneIdentifier: "Europe/Berlin", latitude: 50.1109, longitude: 8.6821, isFavorite: false),
        ClockCity(id: 5, label: "Paris", country: "France", timeZoneIdentifier: "Europe/Paris", latitude: 48.8566, longitude: 2.3522, isFavorite: false),
        ClockCity(id: 6, label: "Helsinki", country: "Finland", timeZoneIdentifier: "Europe/Helsinki", latitude: 60.1695, longitude: 24.9354, isFavorite: false),
        ClockCity(id: 7, label: "Dubai", country: "United Arab Emirates", timeZoneIdentifier: "Asia/Dubai", latitude: 25.2048, longitude: 55.2708, isFavorite: false),
        ClockCity(id: 8, label: "Bangkok", country: "Thailand", timeZoneIdentifier: "Asia/Bangkok", latitude: 13.7563, longitude: 100.5018, isFavorite: false),
        ClockCity(id: 9, label: "Ho Chi Minh City", country: "Vietnam", timeZoneIdentifier: "Asia/Ho_Chi_Minh", latitude: 10.8231, longitude: 106.6297, isFavorite: true),
        ClockCity(id: 10, label: "Singapore", country: "Singapore", timeZoneIdentifier: "Asia/Singapore", latitude: 1.3521, longitude: 103.8198, isFavorite: false),
        ClockCity(id: 11, label: "Tokyo", country: "Japan", timeZoneIdentifier: "Asia/Tokyo", latitude: 35.6895, longitude: 139.6917, isFavorite: false),
        ClockCity(id: 12, label: "Sydney", country: "Australia", timeZoneIdentifier: "Australia/Sydney", latitude: -33.8688, longitude: 151.2093, isFavorite: false),
        ClockCity(id: 13, label: "Melbourne", country: "Australia", timeZoneIdentifier: "Australia/Melbourne", latitude: -37.8136, longitude: 144.9631, isFavorite: true),
    ]

    static var favorites: [ClockCity] { all.filter(\.isFavorite) }
    static var standard: [ClockCity] { all.filter { !$0.isFavorite } }
}

struct WeatherSample: Equatable, Sendable {
    let temperatureCelsius: Double
    let weatherCode: Int

    var conditionText: String {
        Self.conditionText(for: weatherCode)
    }

    static func conditionText(for code: Int) -> String {
        conditions[code] ?? "Unknown"
    }

    private static let conditions: [Int: String] = [
        0: "Clear sky",
        1: "Mainly clear",
        2: "Partly cloudy",
        3: "Overcast",
        45: "Fog",
        48: "Rime fog",
        51: "Light drizzle",
        53: "Drizzle",
        55: "Dense drizzle",
        61: "Light rain",
        63: "Moderate rain",
        65: "Heavy rain",
        71: "Light snow",
        73: "Moderate snow",
        75: "Heavy snow",
        80: "Light showers",
        81: "Showers",
        82: "Heavy showers",
        95: "Thunderstorm",
        96: "Storm w/ hail",
        99: "Heavy storm",
    ]
}
