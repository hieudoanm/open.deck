import SwiftUI

// Clock page — port of omni `Omni/Views/Clock`. One page with a segmented
// picker across the five clock sections (watchface, world clock, timer,
// stopwatch, pomodoro).

struct ClockView: View {
    @StateObject private var viewModel = ClockViewModel()
    @State private var section: ClockViewModel.Section = .watchface

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Clock", systemImage: "clock")
                    .font(.headline)
                Spacer()
                Text(Date.now.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(DeckTheme.muted)
            }
            .padding(.bottom, DeckTheme.Spacing.md)

            Picker("Section", selection: $section) {
                ForEach(ClockViewModel.Section.allCases, id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.bottom, DeckTheme.Spacing.md)

            sectionContent(section)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(DeckTheme.Spacing.xl)
    }

    @ViewBuilder
    private func sectionContent(_ section: ClockViewModel.Section) -> some View {
        switch section {
        case .watchface:
            WatchfaceView()
        case .worldClock:
            WorldClockView(viewModel: viewModel.worldClock)
        case .timer:
            TimerView(viewModel: viewModel.timer)
        case .stopwatch:
            StopwatchView(viewModel: viewModel.stopwatch)
        case .pomodoro:
            PomodoroView(viewModel: viewModel.pomodoro)
        }
    }
}

// MARK: - Watchface

private struct WatchfaceView: View {
    private enum Face: Hashable {
        case dot
        case minimal
    }

    @State private var face: Face = .dot
    @State private var now = Date()

    var body: some View {
        VStack(spacing: 0) {
            faceContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: DeckTheme.Spacing.lg) {
                ChipButton(title: "DOT", isSelected: face == .dot) { face = .dot }
                ChipButton(title: "MINIMAL", isSelected: face == .minimal) { face = .minimal }
            }
            .padding(.vertical, DeckTheme.Spacing.md)
        }
        .task {
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    @ViewBuilder
    private var faceContent: some View {
        switch face {
        case .dot: analogFace
        case .minimal: minimalFace
        }
    }

    private var analogFace: some View {
        GeometryReader { geometry in
            let minDimension = min(geometry.size.width, geometry.size.height) * 0.7
            ZStack {
                Circle()
                    .fill(DeckTheme.surfaceRaised)
                    .overlay { Circle().stroke(DeckTheme.stroke, lineWidth: 2) }
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 6)

                handDot(angle: hourAngle, radius: minDimension * 0.30, size: 26, color: DeckTheme.accent)
                handDot(angle: minuteAngle, radius: minDimension * 0.34, size: 18, color: DeckTheme.muted)
                handDot(angle: secondAngle, radius: minDimension * 0.38, size: 10, color: DeckTheme.faint)

                Circle().fill(.white).frame(width: 5, height: 5)
            }
            .frame(width: minDimension, height: minDimension)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(DeckTheme.Spacing.xl)
    }

    private func handDot(angle: Double, radius: CGFloat, size: CGFloat, color: Color) -> some View {
        Circle()
            .fill(color)
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            .frame(width: size, height: size)
            .offset(
                x: radius * sin(angle * .pi / 180),
                y: -radius * cos(angle * .pi / 180)
            )
    }

    private var minimalFace: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: DeckTheme.Spacing.sm) {
                Text(hourText).foregroundStyle(.primary)
                Text(":").foregroundStyle(DeckTheme.faint)
                Text(minuteText).foregroundStyle(DeckTheme.accent)
                Text(":").foregroundStyle(DeckTheme.faint)
                Text(secondText).foregroundStyle(.secondary)
            }
            .font(.system(size: 72, weight: .light, design: .monospaced))
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            Circle().stroke(DeckTheme.stroke, lineWidth: 2).padding(DeckTheme.Spacing.xl)
        }
    }

    private var hourText: String {
        ClockFormatter.two(Calendar.current.component(.hour, from: now))
    }

    private var minuteText: String {
        ClockFormatter.two(Calendar.current.component(.minute, from: now))
    }

    private var secondText: String {
        ClockFormatter.two(Calendar.current.component(.second, from: now))
    }

    private var hourAngle: Double {
        let hours = Double(Calendar.current.component(.hour, from: now))
        let minutes = Double(Calendar.current.component(.minute, from: now))
        return (hours.truncatingRemainder(dividingBy: 12)) * 30 + minutes * 0.5
    }

    private var minuteAngle: Double {
        let minutes = Double(Calendar.current.component(.minute, from: now))
        let seconds = Double(Calendar.current.component(.second, from: now))
        return minutes * 6 + seconds * 0.1
    }

    private var secondAngle: Double {
        Double(Calendar.current.component(.second, from: now)) * 6
    }
}

// MARK: - World Clock

private struct WorldClockView: View {
    @ObservedObject var viewModel: WorldClockViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DeckTheme.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search cities…", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, DeckTheme.Spacing.sm)

            Divider()

            if rows.isEmpty {
                VStack(spacing: DeckTheme.Spacing.sm) {
                    Image(systemName: "globe")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No cities match \"\(viewModel.searchQuery)\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DeckTheme.Spacing.xxxl)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(rows) { row in
                            CityClockRow(
                                city: row.city,
                                time: viewModel.times[row.index],
                                weather: viewModel.weather[row.index]
                            )
                            if row.id != rows.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            Divider()

            Text("Weather via Open-Meteo · 10 min")
                .font(.system(.caption2, design: .monospaced))
                .tracking(1)
                .foregroundStyle(DeckTheme.faint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DeckTheme.Spacing.xs)
        }
        .task {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private var rows: [CityRow] {
        viewModel.cityRows()
    }
}

private struct CityClockRow: View {
    let city: ClockCity
    let time: String
    let weather: WeatherSample?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DeckTheme.Spacing.xs) {
                    Text(city.label.uppercased())
                        .font(.caption2)
                        .tracking(1)
                        .foregroundStyle(DeckTheme.muted)
                    Text(city.country)
                        .font(.caption2)
                        .foregroundStyle(DeckTheme.faint)
                }
                Text(time)
                    .font(.system(.title3, design: .monospaced))
                    .monospacedDigit()
            }

            Spacer()

            if let weather {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(weather.temperatureCelsius.rounded()))°C")
                        .font(.system(.title3, design: .monospaced))
                        .monospacedDigit()
                    Text(weather.conditionText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding(.vertical, DeckTheme.Spacing.sm)
    }
}

// MARK: - Timer

private struct TimerView: View {
    @ObservedObject var viewModel: TimerViewModel

    var body: some View {
        GeometryReader { geometry in
            let ringSize = min(geometry.size.width, geometry.size.height) * 0.5
            VStack(spacing: DeckTheme.Spacing.xxl) {
                presetRow
                Spacer()
                ring(size: ringSize)
                controls
                Spacer()
                CapsuleBadge(text: viewModel.selectedPreset.label, labelColor: .secondary)
            }
            .padding(.vertical, DeckTheme.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DeckTheme.Spacing.sm) {
                ForEach(TimerViewModel.presets) { preset in
                    ChipButton(
                        title: preset.label,
                        isSelected: viewModel.selectedPreset == preset,
                        accessibilityLabel: "Set timer to \(preset.label)"
                    ) {
                        viewModel.applyPreset(preset)
                    }
                }
            }
        }
    }

    private func ring(size: CGFloat) -> some View {
        ClockRing(
            size: size,
            progress: viewModel.progress,
            color: viewModel.isFinished ? .green : DeckTheme.accent
        ) {
            VStack(spacing: 2) {
                Text(viewModel.timeText)
                    .font(.system(size: min(size * 0.21, 64), weight: .medium, design: .monospaced))
                    .monospacedDigit()
                Text(viewModel.isFinished ? "done" : "remaining")
                    .font(.caption)
                    .tracking(2)
                    .foregroundStyle(viewModel.isFinished ? Color.secondary : DeckTheme.accent)
                    .textCase(.uppercase)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: DeckTheme.Spacing.xxl) {
            CircleIconButton(systemImage: "arrow.counterclockwise", size: 30) {
                viewModel.reset()
            }
            .disabled(viewModel.timeText == ClockFormatter.timer(viewModel.totalSeconds) && !viewModel.isFinished)

            CircleIconButton(
                systemImage: viewModel.isRunning ? "pause.fill" : "play.fill",
                size: 64,
                color: viewModel.isRunning ? .red : DeckTheme.accent
            ) {
                viewModel.toggleRunning()
            }
        }
    }
}

// MARK: - Stopwatch

private struct StopwatchView: View {
    @ObservedObject var viewModel: StopwatchViewModel

    var body: some View {
        VStack(spacing: DeckTheme.Spacing.xl) {
            Spacer()

            Text(viewModel.timeText)
                .font(.system(size: 56, weight: .medium, design: .monospaced))
                .monospacedDigit()

            controls

            if !viewModel.laps.isEmpty {
                Divider()
                lapsTable
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, DeckTheme.Spacing.md)
    }

    private var controls: some View {
        HStack(spacing: DeckTheme.Spacing.xxl) {
            CircleIconButton(systemImage: "flag.fill", size: 46, color: .gray) {
                viewModel.lap()
            }
            .disabled(!viewModel.isRunning)

            CircleIconButton(
                systemImage: viewModel.isRunning ? "pause.fill" : "play.fill",
                size: 70,
                color: viewModel.isRunning ? .red : DeckTheme.accent
            ) {
                if viewModel.isRunning {
                    viewModel.stop()
                } else {
                    viewModel.start()
                }
            }

            CircleIconButton(systemImage: "stop.fill", size: 46, color: .gray) {
                viewModel.stop()
            }
            .disabled(!viewModel.isRunning)

            CircleIconButton(systemImage: "arrow.counterclockwise", size: 46, color: .gray) {
                viewModel.reset()
            }
            .disabled(!viewModel.canReset)
        }
    }

    private var lapsTable: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.laps) { lap in
                    HStack {
                        Text("Lap \(lap.index)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("+\(ClockFormatter.stopwatch(lap.splitMilliseconds))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(ClockFormatter.stopwatch(lap.elapsedMilliseconds))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                    .font(.system(.body, design: .monospaced))
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxHeight: 220)
    }
}

// MARK: - Pomodoro

private struct PomodoroView: View {
    @ObservedObject var viewModel: PomodoroViewModel

    var body: some View {
        GeometryReader { geometry in
            let ringSize = min(geometry.size.width, geometry.size.height) * 0.5
            VStack(spacing: DeckTheme.Spacing.xl) {
                presetRow
                CapsuleBadge(
                    text: "\(viewModel.phase.title) · \(viewModel.round) / ∞",
                    font: .system(.caption, design: .monospaced),
                    tint: viewModel.phase == .work ? DeckTheme.accent : .green,
                    labelColor: .secondary
                )
                .accessibilityLabel(viewModel.statusText)

                ring(size: ringSize)

                controls

                Spacer()
            }
            .padding(.vertical, DeckTheme.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DeckTheme.Spacing.sm) {
                ForEach(PomodoroViewModel.presets) { preset in
                    ChipButton(
                        title: preset.label,
                        isSelected: viewModel.selectedPreset == preset,
                        accessibilityLabel: "Set pomodoro to \(preset.workMinutes) minutes work, \(preset.breakMinutes) minutes break"
                    ) {
                        viewModel.applyPreset(preset)
                    }
                }
            }
        }
    }

    private func ring(size: CGFloat) -> some View {
        ClockRing(size: size, progress: viewModel.progress, color: faceColor) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(viewModel.timeText)
                    .font(.system(size: min(size * 0.21, 64), weight: .medium, design: .monospaced))
                    .monospacedDigit()
                Text("min")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: DeckTheme.Spacing.xxl) {
            CircleIconButton(systemImage: "arrow.counterclockwise", size: 30, color: .gray) {
                viewModel.reset()
            }
            .disabled(viewModel.secondsRemaining == viewModel.totalSeconds)

            CircleIconButton(
                systemImage: viewModel.isRunning ? "pause.fill" : "play.fill",
                size: 64,
                color: viewModel.isRunning ? .red : faceColor
            ) {
                viewModel.toggleRunning()
            }

            CircleIconButton(systemImage: "forward.end.fill", size: 30, color: .gray) {
                viewModel.skipPhase()
            }
        }
    }

    private var faceColor: Color {
        viewModel.phase == .work ? DeckTheme.accent : .green
    }
}
