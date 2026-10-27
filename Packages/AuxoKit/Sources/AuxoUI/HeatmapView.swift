import SwiftUI
import AuxoCore

public struct HeatmapCell: Hashable, Sendable {
    public let day: LocalDay
    public let count: Int
    public let isFuture: Bool
}

public enum HeatmapLayout {
    /// `weekCount` columns of 7 days, the last column being the current week.
    public static func weeks(count weekCount: Int,
                             today: LocalDay,
                             weekStartsOnMonday: Bool,
                             series: ActivitySeries,
                             calendar: Calendar = .current) -> [[HeatmapCell]] {
        let count = max(1, weekCount)
        let weekday = today.weekday(calendar: calendar)           // 1 = Sunday … 7 = Saturday
        let daysIntoWeek = weekStartsOnMonday ? (weekday + 5) % 7 : weekday - 1
        let first = today.adding(days: -daysIntoWeek - 7 * (count - 1), calendar: calendar)

        var weeks: [[HeatmapCell]] = []
        weeks.reserveCapacity(count)
        var day = first
        for _ in 0..<count {
            var column: [HeatmapCell] = []
            column.reserveCapacity(7)
            for _ in 0..<7 {
                column.append(HeatmapCell(day: day, count: series[day], isFuture: day > today))
                day = day.adding(days: 1, calendar: calendar)
            }
            weeks.append(column)
        }
        return weeks
    }
}

/// A GitHub-style contribution grid. Either fits its container (`cellSize == nil`) or uses a
/// fixed cell size (for scrollable full-year grids and share images).
public struct HeatmapView: View {
    private let weeks: [[HeatmapCell]]
    private let color: (HeatmapCell) -> Color
    private let spacing: CGFloat
    private let cellSize: CGFloat?
    private let showMonthLabels: Bool
    private let showWeekdayLabels: Bool
    private let weekStartsOnMonday: Bool
    private let labelColor: Color
    private let labelFontSize: CGFloat
    private let accessibilitySummary: String

    public init(weeks: [[HeatmapCell]],
                spacing: CGFloat = 3,
                cellSize: CGFloat? = nil,
                showMonthLabels: Bool = false,
                showWeekdayLabels: Bool = false,
                weekStartsOnMonday: Bool = false,
                labelColor: Color = .secondary,
                labelFontSize: CGFloat = 9,
                accessibilitySummary: String = "Activity heatmap",
                color: @escaping (HeatmapCell) -> Color) {
        self.weeks = weeks
        self.spacing = spacing
        self.cellSize = cellSize
        self.showMonthLabels = showMonthLabels
        self.showWeekdayLabels = showWeekdayLabels
        self.weekStartsOnMonday = weekStartsOnMonday
        self.labelColor = labelColor
        self.labelFontSize = labelFontSize
        self.accessibilitySummary = accessibilitySummary
        self.color = color
    }

    private var weekdayColumnWidth: CGFloat { showWeekdayLabels ? labelFontSize * 2.6 : 0 }
    private var monthRowHeight: CGFloat { showMonthLabels ? labelFontSize + 4 : 0 }

    public var body: some View {
        Group {
            if let cellSize {
                grid(cell: cellSize)
            } else {
                GeometryReader { proxy in
                    grid(cell: fittedCell(in: proxy.size))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func fittedCell(in size: CGSize) -> CGFloat {
        let columns = CGFloat(max(weeks.count, 1))
        let byWidth = (size.width - weekdayColumnWidth - spacing * (columns - 1)) / columns
        let byHeight = (size.height - monthRowHeight - (showMonthLabels ? 2 : 0) - spacing * 6) / 7
        return max(2, floor(min(byWidth, byHeight)))
    }

    private func grid(cell: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if showMonthLabels {
                HStack(spacing: spacing) {
                    ForEach(weeks.indices, id: \.self) { index in
                        Color.clear
                            .frame(width: cell, height: monthRowHeight)
                            .overlay(alignment: .leading) {
                                if let label = monthLabel(for: index) {
                                    Text(label)
                                        .font(.system(size: labelFontSize))
                                        .foregroundStyle(labelColor)
                                        .fixedSize()
                                }
                            }
                    }
                }
                .padding(.leading, weekdayColumnWidth)
            }

            HStack(alignment: .top, spacing: 0) {
                if showWeekdayLabels {
                    VStack(alignment: .leading, spacing: spacing) {
                        ForEach(0..<7, id: \.self) { row in
                            Text(weekdayLabel(for: row))
                                .font(.system(size: max(7, labelFontSize - 1)))
                                .foregroundStyle(labelColor)
                                .frame(width: weekdayColumnWidth, height: cell, alignment: .leading)
                        }
                    }
                }

                HStack(spacing: spacing) {
                    ForEach(weeks.indices, id: \.self) { index in
                        VStack(spacing: spacing) {
                            ForEach(weeks[index], id: \.day) { cellModel in
                                RoundedRectangle(cornerRadius: max(1, cell * 0.22), style: .continuous)
                                    .fill(cellModel.isFuture ? Color.clear : color(cellModel))
                                    .frame(width: cell, height: cell)
                            }
                        }
                    }
                }
            }
        }
    }

    private func monthLabel(for index: Int) -> String? {
        guard index < weeks.count - 1,
              let first = weeks[index].first(where: { $0.day.day == 1 }) else { return nil }
        let symbols = Calendar.current.shortMonthSymbols
        let i = first.day.month - 1
        return symbols.indices.contains(i) ? symbols[i] : nil
    }

    private func weekdayLabel(for row: Int) -> String {
        guard row % 2 == 1 else { return "" }
        let symbols = Calendar.current.shortWeekdaySymbols       // index 0 = Sunday
        let i = ((weekStartsOnMonday ? 1 : 0) + row) % 7
        return symbols.indices.contains(i) ? symbols[i] : ""
    }
}
