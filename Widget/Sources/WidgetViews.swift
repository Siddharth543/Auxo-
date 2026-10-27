import SwiftUI
import WidgetKit
import AppIntents
import AuxoCore
import AuxoUI

/// Colors for the current widget rendering mode. When macOS dims desktop widgets (or iOS
/// tints the home screen), colors are replaced by white shades so the grid stays readable.
struct WidgetColors {
    let settings: AppSettings
    let fullColor: Bool

    func levels(for source: Source) -> [Color] {
        fullColor
            ? Palette.levels(for: source, settings: settings)
            : Palette.dimmedOpacities.map { Color.white.opacity($0) }
    }

    var combined: [Color] {
        fullColor
            ? Palette.combinedLevels(settings: settings)
            : Palette.dimmedCombinedOpacities.map { Color.white.opacity($0) }
    }
}

struct WidgetRootView: View {
    let entry: AuxoEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var colors: WidgetColors {
        WidgetColors(settings: entry.settings, fullColor: renderingMode == .fullColor)
    }

    var body: some View {
        Group {
            if entry.items.isEmpty {
                EmptyWidgetView()
            } else {
                switch entry.layout {
                case .single:
                    SingleView(item: entry.items[0], entry: entry, colors: colors, family: family)
                case .stacked where family == .systemSmall:
                    SingleView(item: entry.items[0], entry: entry, colors: colors, family: family)
                case .stacked:
                    StackedView(entry: entry, colors: colors, family: family)
                case .combined:
                    CombinedView(entry: entry, colors: colors, family: family)
                }
            }
        }
        .widgetURL(widgetURL)
    }

    private var widgetURL: URL? {
        if entry.layout == .single, let item = entry.items.first {
            return URL(string: "auxo://account/\(item.account.id)")
        }
        return URL(string: "auxo://dashboard")
    }
}

// MARK: - Shared pieces

enum WidgetMetrics {
    static func weeks(_ family: WidgetFamily, stacked: Bool) -> Int {
        switch family {
        case .systemSmall: return 8
        case .systemMedium: return stacked ? 26 : 20
        case .systemLarge: return 26
        case .systemExtraLarge: return 53
        default: return 20
        }
    }

    static func stackLimit(_ family: WidgetFamily) -> Int {
        family == .systemMedium ? 2 : 3
    }

    static func showsLabels(_ family: WidgetFamily) -> Bool {
        family == .systemLarge || family == .systemExtraLarge
    }
}

struct StreakBadge: View {
    let days: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .foregroundStyle(Color(hex: "#FF8A3D"))
                .widgetAccentable()
            Text("\(days)d")
                .monospacedDigit()
        }
        .font(.system(size: 12, weight: .semibold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days) day streak")
    }
}

struct RefreshButton: View {
    var body: some View {
        Button(intent: RefreshIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Refresh")
    }
}

struct LegendView: View {
    let colors: [Color]

    var body: some View {
        HStack(spacing: 3) {
            Text("Less")
            ForEach(colors.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2).fill(colors[index]).frame(width: 9, height: 9)
            }
            Text("More")
        }
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}

struct EmptyWidgetView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Open Auxo to add an account")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Layouts

struct SingleView: View {
    let item: WidgetItem
    let entry: AuxoEntry
    let colors: WidgetColors
    let family: WidgetFamily

    var body: some View {
        let series = item.snapshot?.series ?? ActivitySeries()
        let stats = StreakStats.compute(series, today: entry.today)
        let source = item.account.source
        let levels = colors.levels(for: source)
        let stale = item.snapshot?.hasError == true
        let rating = item.snapshot?.rating
        let weeks = HeatmapLayout.weeks(count: WidgetMetrics.weeks(family, stacked: false),
                                        today: entry.today,
                                        weekStartsOnMonday: entry.settings.weekStartsOnMonday,
                                        series: series)
        let unit = source.unit(codeforcesAcceptedOnly: entry.settings.codeforcesAcceptedOnly)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                SourceLabel(source, short: family == .systemSmall || family == .systemMedium)
                if family != .systemSmall, let rating {
                    RankText(rating, onDark: true, monochrome: !colors.fullColor)
                }
                Spacer(minLength: 4)
                StreakBadge(days: stats.current)
            }
            .font(.system(size: 12, weight: .semibold))

            HeatmapView(weeks: weeks,
                        spacing: family == .systemSmall ? 2 : 3,
                        showMonthLabels: WidgetMetrics.showsLabels(family),
                        showWeekdayLabels: WidgetMetrics.showsLabels(family),
                        weekStartsOnMonday: entry.settings.weekStartsOnMonday,
                        accessibilitySummary: "\(source.displayName): \(stats.current) day streak, \(stats.activeDays) active days this year") { cell in
                levels[source.level(for: cell.count)]
            }
            .opacity(stale ? 0.45 : 1)

            if stale {
                Text("\(source.displayName) unavailable · cached")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }

            switch family {
            case .systemSmall:
                Group {
                    if let rating {
                        RankText(rating, onDark: true, monochrome: !colors.fullColor)
                    } else {
                        Text("\(stats.total) this year").foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 10, weight: .semibold))
            case .systemLarge:
                largeDetails(stats: stats, rating: rating, unit: unit)
                footer(text: nil)
            case .systemExtraLarge:
                footer(text: "\(stats.total.formatted()) \(unit) in the past year · \(stats.activeDays) active days · longest \(stats.longest)d",
                       legend: levels)
            default:
                footer(text: "\(stats.total.formatted()) \(unit) · \(stats.activeDays) active days")
            }
        }
    }

    @ViewBuilder
    private func largeDetails(stats: StreakStats, rating: RatingInfo?, unit: String) -> some View {
        if let rating {
            VStack(alignment: .leading, spacing: 1) {
                if let title = rating.title {
                    RankText(rating, onDark: true, monochrome: !colors.fullColor)
                        .font(.system(size: 15, weight: .bold))
                        .accessibilityLabel("\(title), rating \(rating.rating)")
                } else {
                    RankText(rating, onDark: true, monochrome: !colors.fullColor)
                        .font(.system(size: 15, weight: .bold))
                }
                Text(detail(rating))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
            GridRow {
                bigStat("\(stats.current)", "current streak")
                bigStat("\(stats.longest)", "longest streak")
            }
            GridRow {
                bigStat(stats.total.formatted(), "\(unit), past year")
                bigStat("\(stats.activeDays)", "active days")
            }
        }
    }

    private func detail(_ rating: RatingInfo) -> String {
        switch rating.kind {
        case .codeforces:
            if let max = rating.maxRating { return "max \(max) (\(CodeforcesRank(rating: max).title))" }
            return "Codeforces rating"
        case .leetcode:
            if let top = rating.topPercentage { return "top \(String(format: "%.1f", top))% · \(rating.contests ?? 0) contests" }
            return "LeetCode contest rating"
        }
    }

    private func bigStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func footer(text: String?, legend: [Color]? = nil) -> some View {
        HStack(spacing: 8) {
            Text(text ?? "Updated \(entry.date.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let legend { LegendView(colors: legend) }
            RefreshButton()
        }
    }
}

struct StackedView: View {
    let entry: AuxoEntry
    let colors: WidgetColors
    let family: WidgetFamily

    var body: some View {
        let items = Array(entry.items.prefix(WidgetMetrics.stackLimit(family)))
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items) { item in
                row(item)
            }
            Spacer(minLength: 0)
            HStack {
                Text("Updated \(entry.date.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                RefreshButton()
            }
        }
    }

    private func row(_ item: WidgetItem) -> some View {
        let series = item.snapshot?.series ?? ActivitySeries()
        let stats = StreakStats.compute(series, today: entry.today)
        let source = item.account.source
        let levels = colors.levels(for: source)
        let stale = item.snapshot?.hasError == true
        let weeks = HeatmapLayout.weeks(count: WidgetMetrics.weeks(family, stacked: true),
                                        today: entry.today,
                                        weekStartsOnMonday: entry.settings.weekStartsOnMonday,
                                        series: series)
        return Link(destination: URL(string: "auxo://account/\(item.account.id)") ?? URL(fileURLWithPath: "/")) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    SourceLabel(source, short: family != .systemExtraLarge)
                    if let rating = item.snapshot?.rating {
                        RankText(rating, onDark: true, monochrome: !colors.fullColor)
                    }
                    if stale {
                        Text("cached").foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    StreakBadge(days: stats.current)
                }
                .font(.system(size: 11, weight: .semibold))

                HeatmapView(weeks: weeks,
                            spacing: 2,
                            weekStartsOnMonday: entry.settings.weekStartsOnMonday,
                            accessibilitySummary: "\(source.displayName): \(stats.current) day streak") { cell in
                    levels[source.level(for: cell.count)]
                }
                .opacity(stale ? 0.45 : 1)
            }
        }
    }
}

struct CombinedView: View {
    let entry: AuxoEntry
    let colors: WidgetColors
    let family: WidgetFamily

    var body: some View {
        let series = ActivitySeries.combined(entry.items.map { $0.snapshot?.series ?? ActivitySeries() })
        let stats = StreakStats.compute(series, today: entry.today)
        let levels = colors.combined
        let weeks = HeatmapLayout.weeks(count: WidgetMetrics.weeks(family, stacked: false),
                                        today: entry.today,
                                        weekStartsOnMonday: entry.settings.weekStartsOnMonday,
                                        series: series)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(family == .systemSmall ? "All" : "All streaks")
                    .fontWeight(.semibold)
                HStack(spacing: 3) {
                    ForEach(entry.items) { item in
                        Circle()
                            .fill(colors.fullColor ? SourceStyle.color(item.account.source) : Color.white.opacity(0.7))
                            .frame(width: 6, height: 6)
                    }
                }
                Spacer(minLength: 4)
                StreakBadge(days: stats.current)
            }
            .font(.system(size: 12, weight: .semibold))

            HeatmapView(weeks: weeks,
                        spacing: family == .systemSmall ? 2 : 3,
                        showMonthLabels: WidgetMetrics.showsLabels(family),
                        showWeekdayLabels: WidgetMetrics.showsLabels(family),
                        weekStartsOnMonday: entry.settings.weekStartsOnMonday,
                        accessibilitySummary: "All streaks: \(stats.current) day streak, active \(stats.activeDays) days this year") { cell in
                levels[min(cell.count, levels.count - 1)]
            }

            if family == .systemSmall {
                Text("\(stats.activeDays) active days")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    Text("Active on any source: \(stats.activeDays) days · longest \(stats.longest)d")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if family != .systemMedium { LegendView(colors: levels) }
                    RefreshButton()
                }
            }
        }
    }
}
