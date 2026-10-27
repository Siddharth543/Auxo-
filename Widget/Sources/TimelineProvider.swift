import WidgetKit
import AuxoCore
import AuxoProviders

struct WidgetItem: Identifiable {
    let account: Account
    let snapshot: AccountSnapshot?
    var id: String { account.id }
}

struct AuxoEntry: TimelineEntry {
    let date: Date
    let layout: WidgetLayout
    let items: [WidgetItem]
    let settings: AppSettings
    let today: LocalDay
}

struct AuxoTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> AuxoEntry {
        SampleData.entry(layout: .single)
    }

    func snapshot(for configuration: AuxoWidgetIntent, in context: Context) async -> AuxoEntry {
        // The widget gallery shows sample data until the user has added an account.
        if context.isPreview && SharedStore.shared.accounts().isEmpty {
            return SampleData.entry(layout: configuration.layout)
        }
        return await makeEntry(for: configuration, sync: false)
    }

    func timeline(for configuration: AuxoWidgetIntent, in context: Context) async -> Timeline<AuxoEntry> {
        let entry = await makeEntry(for: configuration, sync: true)
        let now = Date()
        let calendar = Calendar.current
        let inHalfAnHour = now.addingTimeInterval(30 * 60)
        // Also refresh just after midnight so "today" rolls over on time.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? inHalfAnHour
        let afterMidnight = tomorrow.addingTimeInterval(60)
        return Timeline(entries: [entry], policy: .after(min(inHalfAnHour, afterMidnight)))
    }

    private func makeEntry(for configuration: AuxoWidgetIntent, sync: Bool) async -> AuxoEntry {
        let all = SharedStore.shared.accounts()
        let chosen = Self.accounts(for: configuration, from: all)
        if sync && !chosen.isEmpty {
            await SyncService.shared.sync(chosen)
        }
        let items = chosen.map { WidgetItem(account: $0, snapshot: SharedStore.shared.snapshot(for: $0.id)) }
        return AuxoEntry(date: Date(),
                         layout: configuration.layout,
                         items: items,
                         settings: SharedStore.shared.settings(),
                         today: .today())
    }

    static func accounts(for configuration: AuxoWidgetIntent, from all: [Account]) -> [Account] {
        switch configuration.layout {
        case .single:
            if let picked = configuration.account, let match = all.first(where: { $0.id == picked.id }) {
                return [match]
            }
            return Array(all.prefix(1))
        case .stacked, .combined:
            let ids = configuration.accounts?.map(\.id) ?? []
            let picked = ids.compactMap { id in all.first { $0.id == id } }
            if !picked.isEmpty { return picked }
            return configuration.layout == .stacked ? Array(all.prefix(3)) : all
        }
    }
}

/// Deterministic example data for the widget gallery and Xcode previews.
enum SampleData {
    static func series(for source: Source, today: LocalDay) -> ActivitySeries {
        var series = ActivitySeries()
        var state: UInt64 = UInt64(source.rawValue.unicodeScalars.reduce(7) { $0 &* 31 &+ UInt64($1.value) })
        func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 33) / Double(UInt64(1) << 31)
        }
        let (idle, busy, maxCount): (Double, Double, Int) = {
            switch source {
            case .github: return (0.38, 0.82, 12)
            case .leetcode: return (0.26, 0.74, 7)
            case .codeforces: return (0.18, 0.66, 5)
            }
        }()
        var previous = true
        for offset in stride(from: 370, through: 0, by: -1) {
            let active = offset < 9 || next() < (previous ? busy : idle)
            if active {
                series[today.adding(days: -offset)] = 1 + Int(next() * next() * Double(maxCount))
            }
            previous = active
        }
        return series
    }

    static func entry(layout: WidgetLayout) -> AuxoEntry {
        let today = LocalDay.today()
        let ratings: [Source: RatingInfo] = [
            .codeforces: RatingInfo(kind: .codeforces, rating: 1834, maxRating: 1902, contests: 47),
            .leetcode: RatingInfo(kind: .leetcode, rating: 1921, contests: 31, badge: "Knight", topPercentage: 6.4),
        ]
        let items = Source.allCases.map { source -> WidgetItem in
            let account = Account(id: "sample-\(source.rawValue)", source: source, handle: "sample")
            let snapshot = AccountSnapshot(accountID: account.id,
                                           series: series(for: source, today: today),
                                           rating: ratings[source],
                                           lastSuccess: Date())
            return WidgetItem(account: account, snapshot: snapshot)
        }
        let shown: [WidgetItem]
        switch layout {
        case .single: shown = [items[2]]
        case .stacked, .combined: shown = items
        }
        return AuxoEntry(date: Date(), layout: layout, items: shown, settings: AppSettings(), today: today)
    }
}
