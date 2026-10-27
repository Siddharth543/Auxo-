import SwiftUI
import AuxoCore
import AuxoUI

struct AccountCardView: View {
    let account: Account
    let snapshot: AccountSnapshot?
    let settings: AppSettings
    let onShare: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var series: ActivitySeries { snapshot?.series ?? ActivitySeries() }

    var body: some View {
        let today = LocalDay.today()
        let stats = StreakStats.compute(series, today: today)
        let levels = Palette.levels(for: account.source, settings: settings)
        let weeks = HeatmapLayout.weeks(count: 53, today: today,
                                        weekStartsOnMonday: settings.weekStartsOnMonday, series: series)
        let unit = account.source.unit(codeforcesAcceptedOnly: settings.codeforcesAcceptedOnly)
        let onDark = colorScheme == .dark

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                SourceLabel(account.source)
                if let rating = snapshot?.rating {
                    RankText(rating, onDark: onDark)
                        .font(.callout.weight(.bold))
                }
                Spacer(minLength: 8)
                StatusPill(snapshot: snapshot)
                Button("Share", action: onShare)
            }

            if let error = snapshot?.lastError {
                Text(snapshot?.lastSuccess == nil ? error : "\(error) Showing data from the last successful sync.")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) { statItems(stats: stats, unit: unit, onDark: onDark) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 10) {
                    statItems(stats: stats, unit: unit, onDark: onDark)
                }
            }

            YearHeatmap(weeks: weeks,
                        weekStartsOnMonday: settings.weekStartsOnMonday,
                        summary: "\(account.source.displayName) heatmap. \(stats.activeDays) active days in the past year, current streak \(stats.current) days.") { cell in
                levels[account.source.level(for: cell.count)]
            }
            .opacity(snapshot?.hasError == true ? 0.5 : 1)
        }
        .card()
        .contextMenu {
            if let url = account.source.profileURL(handle: account.handle) {
                Link("Open \(account.source.displayName) profile", destination: url)
            }
        }
    }

    @ViewBuilder
    private func statItems(stats: StreakStats, unit: String, onDark: Bool) -> some View {
        StatItem(label: "Current streak", value: "\(stats.current) days")
        StatItem(label: "Longest streak", value: "\(stats.longest) days")
        StatItem(label: "Past year", value: "\(stats.total.formatted()) \(unit)")
        StatItem(label: "Active days", value: "\(stats.activeDays)")
        if let rating = snapshot?.rating {
            switch rating.kind {
            case .codeforces:
                StatItem(label: "Rating", value: "\(rating.rating)",
                         tint: RankStyle.color(for: rating, onDark: onDark))
                if let max = rating.maxRating {
                    StatItem(label: "Max rating", value: "\(max) · \(CodeforcesRank(rating: max).title)",
                             tint: Color(hex: RankStyle.hex(for: CodeforcesRank(rating: max), onDark: onDark)))
                }
                if let contests = rating.contests {
                    StatItem(label: "Contests", value: "\(contests)")
                }
            case .leetcode:
                StatItem(label: "Contest rating", value: "\(rating.rating)",
                         tint: RankStyle.color(for: rating, onDark: onDark))
                if let top = rating.topPercentage {
                    StatItem(label: "Global standing", value: "top \(String(format: "%.1f", top))%")
                }
                if let contests = rating.contests {
                    StatItem(label: "Contests", value: "\(contests)")
                }
            }
        }
    }
}
