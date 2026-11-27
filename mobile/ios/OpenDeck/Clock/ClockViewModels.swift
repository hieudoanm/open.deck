import Foundation

// View models ported from omni `Omni/App/Clock` — same logic, SwiftUI-free
// state driving the Clock page's five sections.

@MainActor
final class ClockViewModel: ObservableObject {
    let worldClock = WorldClockViewModel()
    let timer = TimerViewModel()
    let stopwatch = StopwatchViewModel()
    let pomodoro = PomodoroViewModel()

    enum Section: String, CaseIterable, Hashable {
        case watchface
        case worldClock
        case timer
        case stopwatch
        case pomodoro

        var title: String {
            switch self {
            case .watchface: return "Watchface"
            case .worldClock: return "World Clock"
            case .timer: return "Timer"
            case .stopwatch: return "Stopwatch"
            case .pomodoro: return "Pomodoro"
            }
        }

        var systemImage: String {
            switch self {
            case .watchface: return "clock"
            case .worldClock: return "globe"
            case .timer: return "timer"
            case .stopwatch: return "stopwatch"
            case .pomodoro: return "hourglass"
            }
        }
    }
}

@MainActor
final class WorldClockViewModel: ObservableObject {
    let cities: [ClockCity]

    @Published var searchQuery = ""
    @Published private(set) var times: [String]
    @Published private(set) var weather: [WeatherSample?]

    private static let weatherRefreshInterval: TimeInterval = 600

    private let weatherService: OpenMeteoWeatherService
    private var tickTask: Task<Void, Never>?
    private var lastWeatherFetch = Date.distantPast

    init(
        cities: [ClockCity] = ClockCities.all,
        weatherService: OpenMeteoWeatherService = OpenMeteoWeatherService()
    ) {
        self.cities = cities
        self.weatherService = weatherService
        times = Array(repeating: "", count: cities.count)
        weather = Array(repeating: nil, count: cities.count)
    }

    deinit {
        tickTask?.cancel()
    }

    func start() {
        guard tickTask == nil else { return }
        updateTimes()
        tickTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                self.updateTimes()
                if Date().timeIntervalSince(self.lastWeatherFetch) >= Self.weatherRefreshInterval {
                    await self.refreshWeather()
                }
            }
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }

    func cityRows() -> [CityRow] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered: [CityRow] = cities.enumerated().compactMap { index, city -> CityRow? in
            guard query.isEmpty
                || city.label.lowercased().contains(query)
                || city.country.lowercased().contains(query)
            else { return nil }
            return CityRow(city: city, index: index)
        }
        return filtered.sorted { lhs, rhs in
            if lhs.city.isFavorite != rhs.city.isFavorite {
                return lhs.city.isFavorite
            }
            return lhs.city.label < rhs.city.label
        }
    }

    private func updateTimes() {
        let date = Date()
        times = cities.map { ClockFormatter.worldClock(in: $0.timeZone, date: date) }
    }

    private func refreshWeather() async {
        lastWeatherFetch = Date()
        await withTaskGroup(of: (Int, WeatherSample?).self) { group in
            for (index, city) in cities.enumerated() {
                group.addTask {
                    let sample = try? await self.weatherService.weather(
                        latitude: city.latitude,
                        longitude: city.longitude
                    )
                    return (index, sample)
                }
            }
            for await (index, sample) in group {
                if let sample {
                    weather[index] = sample
                }
            }
        }
    }
}

struct CityRow: Identifiable {
    let city: ClockCity
    let index: Int
    var id: Int { index }
}

@MainActor
final class TimerViewModel: ObservableObject {
    struct Preset: Identifiable, Equatable {
        let label: String
        let seconds: Int
        var id: String { label }
    }

    static let presets: [Preset] = [
        Preset(label: "1 min", seconds: 60),
        Preset(label: "5 min", seconds: 300),
        Preset(label: "10 min", seconds: 600),
        Preset(label: "15 min", seconds: 900),
        Preset(label: "30 min", seconds: 1800),
        Preset(label: "60 min", seconds: 3600),
    ]

    @Published private(set) var selectedPreset: Preset
    @Published private(set) var secondsRemaining: Int
    @Published private(set) var isRunning = false
    @Published private(set) var isFinished = false

    private var countdownTask: Task<Void, Never>?

    init() {
        let initial = Self.presets[1]
        selectedPreset = initial
        secondsRemaining = initial.seconds
    }

    var totalSeconds: Int { selectedPreset.seconds }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1 - Double(min(secondsRemaining, totalSeconds)) / Double(totalSeconds)
    }

    var timeText: String { ClockFormatter.timer(secondsRemaining) }

    func applyPreset(_ preset: Preset) {
        selectedPreset = preset
        secondsRemaining = preset.seconds
        isRunning = false
        isFinished = false
        stopTask()
    }

    func reset() {
        secondsRemaining = totalSeconds
        isRunning = false
        isFinished = false
        stopTask()
    }

    func toggleRunning() {
        if isFinished {
            reset()
        } else if isRunning {
            pause()
        } else {
            start()
        }
    }

    private func start() {
        isRunning = true
        countdownTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                self.tick()
            }
        }
    }

    private func pause() {
        isRunning = false
        stopTask()
    }

    private func tick() {
        if secondsRemaining <= 1 {
            secondsRemaining = 0
            isRunning = false
            isFinished = true
            stopTask()
            Chime.timerFinished()
        } else {
            secondsRemaining -= 1
        }
    }

    private func stopTask() {
        countdownTask?.cancel()
        countdownTask = nil
    }
}

@MainActor
final class StopwatchViewModel: ObservableObject {
    struct Lap: Identifiable {
        let id = UUID()
        let index: Int
        let elapsedMilliseconds: Int
        let splitMilliseconds: Int
    }

    @Published private(set) var elapsedMilliseconds: Int = 0
    @Published private(set) var isRunning = false
    @Published private(set) var laps: [Lap] = []

    private var tickTask: Task<Void, Never>?
    private var accumulatedMilliseconds: Int = 0
    private var lastTickDate: Date?

    var timeText: String { ClockFormatter.stopwatch(elapsedMilliseconds) }
    var canReset: Bool { elapsedMilliseconds > 0 }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        lastTickDate = Date()
        tickTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(20))
                guard !Task.isCancelled else { break }
                self.tick()
            }
        }
    }

    func stop() {
        isRunning = false
        tickTask?.cancel()
        tickTask = nil
    }

    func reset() {
        stop()
        accumulatedMilliseconds = 0
        elapsedMilliseconds = 0
        laps = []
    }

    func lap() {
        let lastLapMilliseconds = laps.first?.elapsedMilliseconds ?? 0
        laps.insert(
            Lap(
                index: laps.count + 1,
                elapsedMilliseconds: elapsedMilliseconds,
                splitMilliseconds: elapsedMilliseconds - lastLapMilliseconds
            ),
            at: 0
        )
    }

    private func tick() {
        guard let lastTickDate else { return }
        let now = Date()
        let deltaMilliseconds = Int(now.timeIntervalSince(lastTickDate) * 1000)
        self.lastTickDate = now
        accumulatedMilliseconds += max(0, deltaMilliseconds)
        elapsedMilliseconds = accumulatedMilliseconds
    }
}

@MainActor
final class PomodoroViewModel: ObservableObject {
    struct Preset: Identifiable, Equatable {
        let label: String
        let workMinutes: Int
        let breakMinutes: Int
        var id: String { label }
    }

    enum Phase: Equatable {
        case work
        case `break`

        var title: String { self == .work ? "Focus" : "Break" }
        var label: String { self == .work ? "focus" : "break" }
    }

    static let presets: [Preset] = [
        Preset(label: "25 / 5", workMinutes: 25, breakMinutes: 5),
        Preset(label: "50 / 10", workMinutes: 50, breakMinutes: 10),
        Preset(label: "90 / 20", workMinutes: 90, breakMinutes: 20),
    ]

    @Published private(set) var selectedPreset: Preset
    @Published private(set) var phase: Phase = .work
    @Published private(set) var secondsRemaining: Int
    @Published private(set) var isRunning = false
    @Published private(set) var round: Int = 1

    private var countdownTask: Task<Void, Never>?

    init() {
        let initial = Self.presets[1]
        selectedPreset = initial
        secondsRemaining = initial.workMinutes * 60
    }

    var totalSeconds: Int {
        phase == .work
            ? selectedPreset.workMinutes * 60
            : selectedPreset.breakMinutes * 60
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1 - Double(min(secondsRemaining, totalSeconds)) / Double(totalSeconds)
    }

    var timeText: String { ClockFormatter.countdown(secondsRemaining) }
    var statusText: String { "Round \(round) · \(phase.title) phase" }

    func applyPreset(_ preset: Preset) {
        selectedPreset = preset
        phase = .work
        secondsRemaining = preset.workMinutes * 60
        isRunning = false
        round = 1
        stopTask()
    }

    func reset() {
        secondsRemaining = totalSeconds
        isRunning = false
        stopTask()
    }

    func toggleRunning() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    func skipPhase() {
        switchPhase()
        isRunning = false
        stopTask()
    }

    private func start() {
        isRunning = true
        countdownTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                self.tick()
            }
        }
    }

    private func pause() {
        isRunning = false
        stopTask()
    }

    private func tick() {
        if secondsRemaining <= 1 {
            let endedWork = phase == .work
            switchPhase()
            if endedWork {
                Chime.workPhaseEnded()
            } else {
                Chime.breakPhaseEnded()
            }
        } else {
            secondsRemaining -= 1
        }
    }

    private func switchPhase() {
        let next: Phase = phase == .work ? .break : .work
        phase = next
        if next == .work {
            round += 1
        }
        secondsRemaining = (next == .work ? selectedPreset.workMinutes : selectedPreset.breakMinutes) * 60
        isRunning = false
        stopTask()
    }

    private func stopTask() {
        countdownTask?.cancel()
        countdownTask = nil
    }
}
