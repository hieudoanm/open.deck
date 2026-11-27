import Foundation
import UIKit

/// Fetches current conditions from Open-Meteo, caching each coordinate's
/// forecast for 10 minutes (port of omni's `OpenMeteoWeatherService`).
actor OpenMeteoWeatherService {
    private struct Key: Hashable {
        let latitude: Double
        let longitude: Double
    }

    private struct Entry {
        let sample: WeatherSample
        let fetchedAt: Date
    }

    private static let cacheTTL: TimeInterval = 600

    private var cache: [Key: Entry] = [:]

    func weather(latitude: Double, longitude: Double) async throws -> WeatherSample {
        let key = Key(latitude: latitude, longitude: longitude)
        if let entry = cache[key], Date().timeIntervalSince(entry.fetchedAt) < Self.cacheTTL {
            return entry.sample
        }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let sample = try Self.parse(data)
        cache[key] = Entry(sample: sample, fetchedAt: Date())
        return sample
    }

    private struct Payload: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
        }
        let current: Current
    }

    private static func parse(_ data: Data) throws -> WeatherSample {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw URLError(.cannotParseResponse)
        }
        return WeatherSample(
            temperatureCelsius: payload.current.temperature_2m,
            weatherCode: payload.current.weather_code
        )
    }
}
