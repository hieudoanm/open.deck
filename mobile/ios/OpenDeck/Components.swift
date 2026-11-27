import SwiftUI

/// Shared controls for the dashboard pages — ports of omni's
/// `ChipButton` / `CircleIconButton` / `CapsuleBadge` / `ClockRing`.

struct ChipButton: View {
    let title: String
    let isSelected: Bool
    var accessibilityLabel: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .monospaced))
                .tracking(2)
                .padding(.horizontal, DeckTheme.Spacing.xl)
                .padding(.vertical, DeckTheme.Spacing.xs)
                .background(isSelected ? DeckTheme.accent : DeckTheme.surfaceRaised, in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct CircleIconButton: View {
    let systemImage: String
    var size: CGFloat = 46
    var color: Color = DeckTheme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size >= 60 ? 22 : 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(color, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemImage)
    }
}

struct CapsuleBadge: View {
    let text: String
    var font: Font = .caption2
    var tint: Color = DeckTheme.accent
    var labelColor: Color = DeckTheme.accent

    var body: some View {
        Text(text)
            .font(font)
            .tracking(2)
            .padding(.horizontal, DeckTheme.Spacing.md)
            .padding(.vertical, DeckTheme.Spacing.xxs)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(labelColor)
    }
}

/// Circular countdown ring shared by Timer and Pomodoro.
struct ClockRing<Center: View>: View {
    var size: CGFloat = 160
    let progress: Double
    let color: Color
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            Circle()
                .stroke(DeckTheme.track, lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center()
        }
        .frame(width: size, height: size)
    }
}

/// A titled card used by the dashboard pages.
struct DeckCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DeckTheme.Spacing.sm) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(DeckTheme.muted)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DeckTheme.Spacing.lg)
        .background(DeckTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DeckTheme.stroke, lineWidth: 1)
        )
    }
}
