import SwiftUI
import AuxoCore
import AuxoUI

/// Rounded, outlined container used for dashboard cards.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.secondary.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.secondary.opacity(0.18)))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

/// "Synced" / "Unavailable" pill for an account.
struct StatusPill: View {
    let snapshot: AccountSnapshot?

    var body: some View {
        let failing = snapshot?.hasError ?? false
        let neverLoaded = snapshot?.lastSuccess == nil
        Text(failing ? (neverLoaded ? "Error" : "Unavailable") : (neverLoaded ? "Not synced" : "Synced"))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundStyle(failing ? Color.orange : Color.green)
            .background(Capsule().fill((failing ? Color.orange : Color.green).opacity(0.14)))
            .help(snapshot?.lastError ?? "")
    }
}

/// A labelled number for the stats rows.
struct StatItem: View {
    let label: String
    let value: String
    var tint: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(tint ?? .primary)
                .monospacedDigit()
        }
    }
}

/// The year grid inside a dark well, scrollable when the window is narrow.
struct YearHeatmap: View {
    let weeks: [[HeatmapCell]]
    let weekStartsOnMonday: Bool
    let summary: String
    let color: (HeatmapCell) -> Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HeatmapView(weeks: weeks,
                        spacing: 3,
                        cellSize: 11,
                        showMonthLabels: true,
                        showWeekdayLabels: true,
                        weekStartsOnMonday: weekStartsOnMonday,
                        labelColor: Color.white.opacity(0.55),
                        accessibilitySummary: summary,
                        color: color)
                .padding(12)
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.surface))
        .defaultScrollAnchor(.trailing)
    }
}
