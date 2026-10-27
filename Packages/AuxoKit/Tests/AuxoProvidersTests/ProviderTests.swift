import XCTest
import AuxoCore
@testable import AuxoProviders

/// Feeds recorded responses to providers; no network involved.
final class MockTransport: HTTPTransport, @unchecked Sendable {
    private let handler: (URLRequest) throws -> (String, Int)
    private let lock = NSLock()
    private(set) var requests: [URLRequest] = []

    init(_ handler: @escaping (URLRequest) throws -> (String, Int)) {
        self.handler = handler
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.lock()
        requests.append(request)
        lock.unlock()
        let (body, status) = try handler(request)
        let response = HTTPURLResponse(url: request.url ?? URL(string: "https://example.com")!,
                                       statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

private func timestamp(_ day: LocalDay, hour: Int = 12) -> Int {
    Int(Calendar.utc.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour))!
        .timeIntervalSince1970)
}

private func bodyString(_ request: URLRequest) -> String {
    request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
}

final class CodeforcesProviderTests: XCTestCase {
    let since = LocalDay(year: 2026, month: 1, day: 1)
    let options = FetchOptions(codeforcesAcceptedOnly: true, calendar: .utc)

    func testParsesRatingAndAcceptedSubmissions() async throws {
        let d1 = LocalDay(year: 2026, month: 6, day: 1)
        let d2 = LocalDay(year: 2026, month: 6, day: 2)
        let old = LocalDay(year: 2025, month: 12, day: 30)
        let transport = MockTransport { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("user.info") {
                return (#"{"status":"OK","result":[{"handle":"Tourist","rating":3500,"maxRating":3979,"rank":"legendary grandmaster"}]}"#, 200)
            }
            if path.hasSuffix("user.rating") {
                return (#"{"status":"OK","result":[{"contestId":1},{"contestId":2},{"contestId":3}]}"#, 200)
            }
            if path.hasSuffix("user.status") {
                return ("""
                {"status":"OK","result":[
                  {"creationTimeSeconds":\(timestamp(d2)),"verdict":"OK"},
                  {"creationTimeSeconds":\(timestamp(d2, hour: 13)),"verdict":"WRONG_ANSWER"},
                  {"creationTimeSeconds":\(timestamp(d1)),"verdict":"OK"},
                  {"creationTimeSeconds":\(timestamp(d1, hour: 14)),"verdict":"OK"},
                  {"creationTimeSeconds":\(timestamp(old)),"verdict":"OK"}
                ]}
                """, 200)
            }
            XCTFail("Unexpected request \(path)")
            return ("{}", 500)
        }
        let provider = CodeforcesProvider(transport: transport, limiter: RateLimiter(interval: 0))
        let result = try await provider.fetch(handle: "tourist", since: since, options: options)

        XCTAssertEqual(result.canonicalHandle, "Tourist")
        XCTAssertEqual(result.rating, RatingInfo(kind: .codeforces, rating: 3500, maxRating: 3979, contests: 3))
        XCTAssertEqual(result.series[d1], 2)
        XCTAssertEqual(result.series[d2], 1, "wrong answers don't count in accepted-only mode")
        XCTAssertEqual(result.series[old], 0, "submissions before the window are ignored")
    }

    func testAllSubmissionsModeCountsEverything() async throws {
        let d = LocalDay(year: 2026, month: 6, day: 2)
        let transport = MockTransport { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("user.info") { return (#"{"status":"OK","result":[{"handle":"newbie1"}]}"#, 200) }
            return ("""
            {"status":"OK","result":[
              {"creationTimeSeconds":\(timestamp(d)),"verdict":"OK"},
              {"creationTimeSeconds":\(timestamp(d, hour: 13)),"verdict":"TIME_LIMIT_EXCEEDED"}
            ]}
            """, 200)
        }
        let provider = CodeforcesProvider(transport: transport, limiter: RateLimiter(interval: 0))
        let result = try await provider.fetch(handle: "newbie1", since: since,
                                              options: FetchOptions(codeforcesAcceptedOnly: false, calendar: .utc))
        XCTAssertNil(result.rating, "unrated users have no rating")
        XCTAssertEqual(result.series[d], 2)
        XCTAssertFalse(transport.requests.contains { $0.url?.path.hasSuffix("user.rating") == true })
    }

    func testUnknownHandle() async {
        let transport = MockTransport { _ in
            (#"{"status":"FAILED","comment":"handles: User with handle nobody_x not found"}"#, 400)
        }
        let provider = CodeforcesProvider(transport: transport, limiter: RateLimiter(interval: 0))
        do {
            _ = try await provider.fetch(handle: "nobody_x", since: since, options: options)
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? ProviderError, .notFound("nobody_x"))
        }
    }

    func testMaintenancePageIsUnavailable() async {
        let transport = MockTransport { _ in ("<html>Codeforces is temporarily unavailable</html>", 200) }
        let provider = CodeforcesProvider(transport: transport, limiter: RateLimiter(interval: 0))
        do {
            _ = try await provider.fetch(handle: "tourist", since: since, options: options)
            XCTFail("expected an error")
        } catch let error as ProviderError {
            if case .unavailable = error {} else { XCTFail("got \(error)") }
        } catch {
            XCTFail("got \(error)")
        }
    }
}

final class LeetCodeProviderTests: XCTestCase {
    let since = LocalDay(year: 2026, month: 1, day: 1)

    func testParsesCalendarAndContestRating() async throws {
        let d1 = LocalDay(year: 2026, month: 3, day: 4)
        let d2 = LocalDay(year: 2026, month: 3, day: 5)
        let old = LocalDay(year: 2025, month: 6, day: 1)
        let calendar = "{\\\"\(timestamp(d1, hour: 0))\\\": 3, \\\"\(timestamp(d2, hour: 0))\\\": 1, \\\"\(timestamp(old, hour: 0))\\\": 7}"
        let transport = MockTransport { request in
            let body = bodyString(request)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Referer"), "https://leetcode.com/u/lee215/")
            if body.contains("userProfileCalendar") {
                return (#"{"data":{"matchedUser":{"username":"lee215","userCalendar":{"submissionCalendar":"\#(calendar)"}}}}"#, 200)
            }
            return (#"{"data":{"userContestRanking":{"attendedContestsCount":42,"rating":2251.6,"topPercentage":1.2,"badge":{"name":"Guardian"}}}}"#, 200)
        }
        let result = try await LeetCodeProvider(transport: transport)
            .fetch(handle: "lee215", since: since, options: FetchOptions())

        XCTAssertEqual(result.canonicalHandle, "lee215")
        XCTAssertEqual(result.series[d1], 3)
        XCTAssertEqual(result.series[d2], 1)
        XCTAssertEqual(result.series[old], 0)
        XCTAssertEqual(result.rating, RatingInfo(kind: .leetcode, rating: 2252, contests: 42, badge: "Guardian", topPercentage: 1.2))
    }

    func testNoContestsMeansNoRating() async throws {
        let transport = MockTransport { request in
            if bodyString(request).contains("userProfileCalendar") {
                return (#"{"data":{"matchedUser":{"username":"fresh","userCalendar":{"submissionCalendar":"{}"}}}}"#, 200)
            }
            return (#"{"data":{"userContestRanking":null}}"#, 200)
        }
        let result = try await LeetCodeProvider(transport: transport).fetch(handle: "fresh", since: since, options: FetchOptions())
        XCTAssertNil(result.rating)
        XCTAssertTrue(result.series.isEmpty)
    }

    func testRatingFailureKeepsHeatmap() async throws {
        let d = LocalDay(year: 2026, month: 3, day: 4)
        let calendar = "{\\\"\(timestamp(d, hour: 0))\\\": 2}"
        let transport = MockTransport { request in
            if bodyString(request).contains("userProfileCalendar") {
                return (#"{"data":{"matchedUser":{"username":"x","userCalendar":{"submissionCalendar":"\#(calendar)"}}}}"#, 200)
            }
            return ("not json", 500)
        }
        let result = try await LeetCodeProvider(transport: transport).fetch(handle: "x", since: since, options: FetchOptions())
        XCTAssertNil(result.rating)
        XCTAssertEqual(result.series[d], 2)
    }

    func testUnknownUser() async {
        let transport = MockTransport { _ in
            (#"{"errors":[{"message":"That user does not exist."}],"data":{"matchedUser":null}}"#, 200)
        }
        do {
            _ = try await LeetCodeProvider(transport: transport).fetch(handle: "ghost", since: since, options: FetchOptions())
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? ProviderError, .notFound("ghost"))
        }
    }

    func testBlockedRequestIsUnavailable() async {
        let transport = MockTransport { _ in ("<html>Just a moment...</html>", 403) }
        do {
            _ = try await LeetCodeProvider(transport: transport).fetch(handle: "x", since: since, options: FetchOptions())
            XCTFail("expected an error")
        } catch let error as ProviderError {
            if case .unavailable = error {} else { XCTFail("got \(error)") }
        } catch {
            XCTFail("got \(error)")
        }
    }
}

final class GitHubProviderTests: XCTestCase {
    let since = LocalDay(year: 2026, month: 1, day: 1)

    func testParsesContributionCalendar() async throws {
        let transport = MockTransport { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "bearer t0k3n")
            return ("""
            {"data":{"user":{"login":"Octocat","contributionsCollection":{"contributionCalendar":{"weeks":[
              {"contributionDays":[{"date":"2025-12-31","contributionCount":5},{"date":"2026-01-01","contributionCount":0}]},
              {"contributionDays":[{"date":"2026-01-02","contributionCount":7},{"date":"2026-01-03","contributionCount":1}]}
            ]}}}}}
            """, 200)
        }
        let result = try await GitHubProvider(transport: transport)
            .fetch(handle: "octocat", since: since, options: FetchOptions(githubToken: "t0k3n"))

        XCTAssertEqual(result.canonicalHandle, "Octocat")
        XCTAssertNil(result.rating)
        XCTAssertEqual(result.series[LocalDay(year: 2026, month: 1, day: 2)], 7)
        XCTAssertEqual(result.series[LocalDay(year: 2026, month: 1, day: 3)], 1)
        XCTAssertEqual(result.series[LocalDay(year: 2025, month: 12, day: 31)], 0, "before the window")
    }

    func testNeedsToken() async {
        let transport = MockTransport { _ in
            XCTFail("must not call the network without a token")
            return ("{}", 200)
        }
        do {
            _ = try await GitHubProvider(transport: transport).fetch(handle: "octocat", since: since, options: FetchOptions())
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? ProviderError, .signInRequired)
        }
    }

    func testUnknownUserAndBadToken() async {
        let notFound = MockTransport { _ in
            (#"{"data":{"user":null},"errors":[{"type":"NOT_FOUND","message":"Could not resolve to a User with the login of 'zz'."}]}"#, 200)
        }
        do {
            _ = try await GitHubProvider(transport: notFound).fetch(handle: "zz", since: since, options: FetchOptions(githubToken: "t"))
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? ProviderError, .notFound("zz"))
        }

        let badToken = MockTransport { _ in (#"{"message":"Bad credentials"}"#, 401) }
        do {
            _ = try await GitHubProvider(transport: badToken).fetch(handle: "zz", since: since, options: FetchOptions(githubToken: "t"))
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? ProviderError, .unauthorized)
        }
    }
}

final class SyncServiceTests: XCTestCase {
    struct StubProvider: ActivityProvider {
        let source: Source
        let outcome: Result<ProviderResult, ProviderError>
        func fetch(handle: String, since: LocalDay, options: FetchOptions) async throws -> ProviderResult {
            try outcome.get()
        }
    }

    func testFailureKeepsPreviousDataAndRecordsError() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SharedStore(directory: dir)
        let good = Account(source: .codeforces, handle: "a")
        let bad = Account(source: .leetcode, handle: "b")

        var oldSeries = ActivitySeries()
        oldSeries[LocalDay(year: 2026, month: 1, day: 1)] = 3
        store.saveSnapshot(AccountSnapshot(accountID: bad.id, series: oldSeries))

        var fresh = ActivitySeries()
        fresh[LocalDay.today()] = 1
        let service = SyncService(store: store, providerFor: { source in
            source == .codeforces
                ? StubProvider(source: source, outcome: .success(ProviderResult(series: fresh, rating: nil, canonicalHandle: "a")))
                : StubProvider(source: source, outcome: .failure(.unavailable("LeetCode is down")))
        }, tokenProvider: { nil })

        let results = await service.sync([good, bad], force: true)

        XCTAssertEqual(results[good.id]?.series, fresh)
        XCTAssertNil(results[good.id]?.lastError)
        XCTAssertEqual(results[bad.id]?.series, oldSeries, "a failed sync must not wipe the heatmap")
        XCTAssertEqual(results[bad.id]?.lastError, "LeetCode is down")
        XCTAssertEqual(store.snapshot(for: bad.id)?.lastError, "LeetCode is down")
    }

    func testFreshAccountsAreSkippedUnlessForced() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SharedStore(directory: dir)
        let account = Account(source: .codeforces, handle: "a")
        store.saveSnapshot(AccountSnapshot(accountID: account.id, lastAttempt: Date()))

        let service = SyncService(store: store, providerFor: { source in
            StubProvider(source: source, outcome: .failure(.rateLimited))
        }, tokenProvider: { nil })

        XCTAssertFalse(service.needsSync(account))
        _ = await service.sync([account])
        XCTAssertNil(store.snapshot(for: account.id)?.lastError, "not fetched: snapshot was fresh")
        _ = await service.sync([account], force: true)
        XCTAssertNotNil(store.snapshot(for: account.id)?.lastError)
    }
}
