import XCTest
@testable import AuxoCore

final class LocalDayTests: XCTestCase {
    let utc = Calendar.utc

    func testStringRoundTrip() {
        let day = LocalDay(year: 2026, month: 3, day: 7)
        XCTAssertEqual(day.string, "2026-03-07")
        XCTAssertEqual(LocalDay(string: "2026-03-07"), day)
    }

    func testRejectsMalformedStrings() {
        XCTAssertNil(LocalDay(string: "2026-3-7"))
        XCTAssertNil(LocalDay(string: "2026-13-01"))
        XCTAssertNil(LocalDay(string: "hello"))
        XCTAssertNil(LocalDay(string: ""))
    }

    func testAddingDaysCrossesMonthAndYear() {
        let day = LocalDay(year: 2025, month: 12, day: 31)
        XCTAssertEqual(day.adding(days: 1, calendar: utc), LocalDay(year: 2026, month: 1, day: 1))
        XCTAssertEqual(LocalDay(year: 2024, month: 3, day: 1).adding(days: -1, calendar: utc),
                       LocalDay(year: 2024, month: 2, day: 29))
    }

    func testOrdering() {
        XCTAssertLessThan(LocalDay(year: 2025, month: 12, day: 31), LocalDay(year: 2026, month: 1, day: 1))
        XCTAssertLessThan(LocalDay(year: 2026, month: 1, day: 9), LocalDay(year: 2026, month: 1, day: 10))
    }

    func testWeekday() {
        // 2026-10-27 is a Tuesday.
        XCTAssertEqual(LocalDay(year: 2026, month: 10, day: 27).weekday(calendar: utc), 3)
    }

    func testCodableUsesPlainString() throws {
        let data = try JSONEncoder().encode([LocalDay(year: 2026, month: 1, day: 2)])
        XCTAssertEqual(String(data: data, encoding: .utf8), "[\"2026-01-02\"]")
        XCTAssertEqual(try JSONDecoder().decode([LocalDay].self, from: data), [LocalDay(year: 2026, month: 1, day: 2)])
    }
}

final class StreakStatsTests: XCTestCase {
    let utc = Calendar.utc
    let today = LocalDay(year: 2026, month: 10, day: 27)

    private func series(_ offsets: [Int: Int]) -> ActivitySeries {
        var s = ActivitySeries()
        for (offset, count) in offsets {
            s[today.adding(days: -offset, calendar: utc)] = count
        }
        return s
    }

    func testCurrentStreakIncludesToday() {
        let stats = StreakStats.compute(series([0: 1, 1: 2, 2: 1, 4: 1]), today: today, calendar: utc)
        XCTAssertEqual(stats.current, 3)
    }

    func testStreakSurvivesUntilTodayEnds() {
        // Nothing yet today, but yesterday and the day before: the streak is still 2.
        let stats = StreakStats.compute(series([1: 1, 2: 1]), today: today, calendar: utc)
        XCTAssertEqual(stats.current, 2)
    }

    func testBrokenStreakIsZero() {
        let stats = StreakStats.compute(series([2: 1, 3: 1]), today: today, calendar: utc)
        XCTAssertEqual(stats.current, 0)
    }

    func testTotalsLongestAndActiveDays() {
        let stats = StreakStats.compute(series([0: 2, 10: 1, 11: 3, 12: 1, 13: 1, 400: 9]), today: today, calendar: utc)
        XCTAssertEqual(stats.total, 8, "the day 400 days ago is outside the 365-day window")
        XCTAssertEqual(stats.activeDays, 5)
        XCTAssertEqual(stats.longest, 4)
    }

    func testEmptySeries() {
        XCTAssertEqual(StreakStats.compute(ActivitySeries(), today: today, calendar: utc), .zero)
    }

    func testCombinedCountsSourcesNotSubmissions() {
        let day = LocalDay(year: 2026, month: 5, day: 1)
        var a = ActivitySeries(); a[day] = 30
        var b = ActivitySeries(); b[day] = 2
        var c = ActivitySeries(); c[day.adding(days: 1, calendar: utc)] = 1
        let combined = ActivitySeries.combined([a, b, c])
        XCTAssertEqual(combined[day], 2)
        XCTAssertEqual(combined[day.adding(days: 1, calendar: utc)], 1)
    }

    func testSeriesDropsZeroCounts() {
        var s = ActivitySeries(counts: ["2026-01-01": 0, "2026-01-02": 3])
        XCTAssertEqual(s.counts.count, 1)
        s[LocalDay(year: 2026, month: 1, day: 2)] = 0
        XCTAssertTrue(s.isEmpty)
    }
}

final class RatingTests: XCTestCase {
    func testCodeforcesThresholds() {
        let cases: [(Int, CodeforcesRank)] = [
            (0, .newbie), (1199, .newbie), (1200, .pupil), (1399, .pupil), (1400, .specialist),
            (1600, .expert), (1899, .expert), (1900, .candidateMaster), (2100, .master),
            (2300, .internationalMaster), (2400, .grandmaster), (2600, .internationalGrandmaster),
            (2999, .internationalGrandmaster), (3000, .legendaryGrandmaster), (3900, .legendaryGrandmaster),
        ]
        for (rating, rank) in cases {
            XCTAssertEqual(CodeforcesRank(rating: rating), rank, "rating \(rating)")
        }
    }

    func testTitles() {
        XCTAssertEqual(RatingInfo(kind: .codeforces, rating: 1834).title, "Expert")
        XCTAssertEqual(RatingInfo(kind: .leetcode, rating: 1900, badge: "Knight").title, "Knight")
        XCTAssertNil(RatingInfo(kind: .leetcode, rating: 1500).title)
        XCTAssertEqual(RatingInfo(kind: .codeforces, rating: 1500, maxRating: 1950).maxCodeforcesRank, .candidateMaster)
    }
}

final class SourceTests: XCTestCase {
    func testHandleValidation() {
        XCTAssertTrue(Source.github.isValidHandle("octo-cat"))
        XCTAssertFalse(Source.github.isValidHandle("-octocat"))
        XCTAssertFalse(Source.github.isValidHandle("octo_cat"))
        XCTAssertTrue(Source.codeforces.isValidHandle("tourist"))
        XCTAssertFalse(Source.codeforces.isValidHandle("ab"))
        XCTAssertTrue(Source.leetcode.isValidHandle("lee_215"))
        XCTAssertFalse(Source.leetcode.isValidHandle("has space"))
    }

    func testLevels() {
        XCTAssertEqual(Source.github.level(for: 0), 0)
        XCTAssertEqual(Source.github.level(for: 1), 1)
        XCTAssertEqual(Source.github.level(for: 3), 2)
        XCTAssertEqual(Source.github.level(for: 6), 3)
        XCTAssertEqual(Source.github.level(for: 20), 4)
        XCTAssertEqual(Source.codeforces.level(for: 5), 4)
    }
}

final class StorageTests: XCTestCase {
    func testSettingsDecodeToleratesMissingAndUnknownValues() throws {
        let json = #"{"theme":"neon","weekStartsOnMonday":true}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.theme, .perSource)
        XCTAssertTrue(settings.weekStartsOnMonday)
        XCTAssertTrue(settings.codeforcesAcceptedOnly)
    }

    func testSharedStoreRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SharedStore(directory: dir)

        XCTAssertEqual(store.accounts(), [])
        let account = Account(source: .codeforces, handle: "tourist")
        store.saveAccounts([account])
        XCTAssertEqual(store.accounts(), [account])

        var settings = AppSettings()
        settings.theme = .ocean
        store.saveSettings(settings)
        XCTAssertEqual(store.settings().theme, .ocean)

        var series = ActivitySeries()
        series[LocalDay(year: 2026, month: 1, day: 1)] = 4
        let snapshot = AccountSnapshot(accountID: account.id, series: series,
                                       rating: RatingInfo(kind: .codeforces, rating: 3500, maxRating: 3900, contests: 300),
                                       lastSuccess: Date(timeIntervalSince1970: 1_700_000_000))
        store.saveSnapshot(snapshot)
        XCTAssertEqual(store.snapshot(for: account.id), snapshot)

        store.removeSnapshot(for: account.id)
        XCTAssertNil(store.snapshot(for: account.id))
    }
}
