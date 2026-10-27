import SwiftUI
import AuxoCore

/// A 1200×630 image (the size X, LinkedIn and Discord preview best) with the streak,
/// rating and title in rank colors, the year's heatmap, and an "Auxo" watermark.
public struct ShareCardView: View {
    public static let size = CGSize(width: 1200, height: 630)

    private let title: String
    private let dotHex: String
    private let stats: StreakStats
    private let unit: String?
    private let rating: RatingInfo?
    private let weeks: [[HeatmapCell]]
    private let levelHex: [String]
    private let level: (HeatmapCell) -> Int
    private let dateText: String

    public init(title: String,
                dotHex: String,
                stats: StreakStats,
                unit: String?,
                rating: RatingInfo?,
                weeks: [[HeatmapCell]],
                levelHex: [String],
                dateText: String,
                level: @escaping (HeatmapCell) -> Int) {
        self.title = title
        self.dotHex = dotHex
        self.stats = stats
        self.unit = unit
        self.rating = rating
        self.weeks = weeks
        self.levelHex = levelHex
        self.dateText = dateText
        self.level = level
    }

    private var accent: Color { Color(hex: levelHex.last ?? "#39D353") }
    private let muted = Color(hex: "#8B949E")

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.surface
            RadialGradient(colors: [accent.opacity(0.22), accent.opacity(0)],
                           center: UnitPoint(x: 0.88, y: 0.06),
                           startRadius: 10,
                           endRadius: 620)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 12) {
                            Circle().fill(Color(hex: dotHex)).frame(width: 18, height: 18)
                            Text(title)
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(Color(hex: "#C9D1D9"))
                        }
                        HStack(alignment: .lastTextBaseline, spacing: 16) {
                            Text(verbatim: String(stats.current))
                                .font(.system(size: 132, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("day streak")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(Color(hex: "#FF8A3D"))
                        }
                    }
                    Spacer(minLength: 24)
                    if let rating {
                        VStack(alignment: .trailing, spacing: 8) {
                            if let rankTitle = rating.title {
                                rankTitleText(rankTitle, rating: rating)
                                    .font(.system(size: 44, weight: .bold))
                            } else {
                                Text("No badge yet")
                                    .font(.system(size: 44, weight: .bold))
                                    .foregroundStyle(muted)
                            }
                            Text(ratingLine(rating))
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(muted)
                        }
                        .padding(.top, 40)
                    }
                }

                Text(statsLine)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(muted)
                    .padding(.top, 8)

                Spacer(minLength: 0)

                HeatmapView(weeks: weeks,
                            spacing: 4,
                            cellSize: 16,
                            showMonthLabels: true,
                            labelColor: Color(hex: "#6E7681"),
                            labelFontSize: 16) { cell in
                    let index = min(max(level(cell), 0), levelHex.count - 1)
                    return Color(hex: levelHex[index])
                }

                Spacer(minLength: 0)

                HStack {
                    Text(dateText)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color(hex: "#6E7681"))
                    Spacer()
                    Text("Auxo")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#C9D1D9"))
                }
            }
            .padding(.horizontal, 64)
            .padding(.vertical, 52)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }

    private var statsLine: String {
        var parts = ["Longest \(stats.longest) days"]
        if let unit { parts.append("\(stats.total.formatted()) \(unit)") }
        parts.append("\(stats.activeDays) active days")
        return parts.joined(separator: "  ·  ")
    }

    private func ratingLine(_ rating: RatingInfo) -> String {
        switch rating.kind {
        case .codeforces:
            if let max = rating.maxRating { return "Rating \(rating.rating)  ·  max \(max)" }
            return "Rating \(rating.rating)"
        case .leetcode:
            if let top = rating.topPercentage { return "Rating \(rating.rating)  ·  top \(String(format: "%.1f", top))%" }
            return "Rating \(rating.rating)"
        }
    }

    private func rankTitleText(_ title: String, rating: RatingInfo) -> Text {
        let tint = RankStyle.color(for: rating, onDark: true)
        if rating.codeforcesRank == .legendaryGrandmaster {
            return Text(verbatim: String(title.prefix(1))).foregroundStyle(Color.white)
                + Text(verbatim: String(title.dropFirst())).foregroundStyle(tint)
        }
        return Text(verbatim: title).foregroundStyle(tint)
    }
}

@MainActor
public enum ShareCardRenderer {
    /// Renders any view to a bitmap at its natural size.
    public static func cgImage<Content: View>(_ view: Content, scale: CGFloat = 1) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.cgImage
    }
}
