import SwiftUI
import AuxoCore

/// "1834 · Expert", colored by the Codeforces rank ladder (or LeetCode badge).
/// Legendary Grandmaster gets the Codeforces treatment: first letter black (white on dark).
public struct RankText: View {
    private let rating: RatingInfo
    private let onDark: Bool
    private let showTitle: Bool
    private let monochrome: Bool

    public init(_ rating: RatingInfo, onDark: Bool, showTitle: Bool = true, monochrome: Bool = false) {
        self.rating = rating
        self.onDark = onDark
        self.showTitle = showTitle
        self.monochrome = monochrome
    }

    public var body: some View {
        label
            .lineLimit(1)
            .accessibilityLabel(accessibilityText)
    }

    private var tint: Color {
        monochrome ? .primary : RankStyle.color(for: rating, onDark: onDark)
    }

    private var label: Text {
        var text = Text(verbatim: String(rating.rating)).foregroundStyle(tint)
        guard showTitle, let title = rating.title else { return text }
        text = text + Text(verbatim: " · ").foregroundStyle(tint)
        if rating.codeforcesRank == .legendaryGrandmaster && !monochrome {
            let first = String(title.prefix(1))
            let rest = String(title.dropFirst())
            text = text
                + Text(verbatim: first).foregroundStyle(onDark ? Color.white : Color.black)
                + Text(verbatim: rest).foregroundStyle(tint)
        } else {
            text = text + Text(verbatim: title).foregroundStyle(tint)
        }
        return text
    }

    private var accessibilityText: String {
        if let title = rating.title { return "Rating \(rating.rating), \(title)" }
        return "Rating \(rating.rating)"
    }
}

/// A small colored dot plus the site name.
public struct SourceLabel: View {
    private let source: Source
    private let short: Bool

    public init(_ source: Source, short: Bool = false) {
        self.source = source
        self.short = short
    }

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(SourceStyle.color(source))
                .frame(width: 7, height: 7)
            Text(short ? source.shortName : source.displayName)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(source.displayName)
    }
}
