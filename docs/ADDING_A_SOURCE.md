# Adding a source

Adding a site such as AtCoder, CodeChef or HackerRank touches five places. Everything else, including the widgets, dashboard, share cards and themes, picks the new source up automatically.

## 1. Add a case to `Source`

`Packages/AuxoKit/Sources/AuxoCore/Model/Source.swift`

Add the case and fill in every `switch` the compiler flags:

- `displayName` and `shortName`
- `unit(…)`
- `handleLabel` and `handleHint`
- `levelThresholds`: the counts at which a day moves to shades 1, 2 and 3
- `isValidHandle`
- `profileURL`
- `hasRating`

## 2. Write the provider

Create `Packages/AuxoKit/Sources/AuxoProviders/<Name>/<Name>Provider.swift`:

```swift
public struct AtCoderProvider: ActivityProvider {
    public let source: Source = .atcoder
    private let transport: HTTPTransport

    public init(transport: HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    public func fetch(handle: String, since: LocalDay, options: FetchOptions) async throws -> ProviderResult {
        // 1. Request data through `transport` (never URLSession directly, so tests can mock it).
        // 2. Convert each day to a LocalDay (pick the right calendar: the user's, or UTC).
        // 3. Ignore days before `since`.
        // 4. Return the series, an optional RatingInfo, and the handle as the site spells it.
    }
}
```

Rules:

- **Map failures to `ProviderError`.** Use `.notFound(handle)` for an unknown user, `.rateLimited` when the site throttles you, and `.unavailable("…")` for anything else. Write the `unavailable` message for the user to read.
- **Respect rate limits.** If the site has one, add a shared `RateLimiter`, as `CodeforcesProvider` does.
- **Keep rating best-effort.** If a separate rating call fails, return the heatmap without a rating rather than failing the whole fetch.
- **Mark unofficial endpoints.** If you're using an endpoint that isn't a documented API, say so in a doc comment and in the README's data-source table.

If the site has a rating, add a `RatingInfo.Kind` case. Then handle it in `RatingInfo.title`, `RankStyle.hex(for:onDark:)` and the switches the compiler flags.

## 3. Register it

Add a case to `ProviderRegistry.provider(for:)`.

## 4. Add colors

In `Packages/AuxoKit/Sources/AuxoUI/Palette.swift`:

- add 5 shades to `Palette.sourceLevels`, darkest first, with the first one close to `#161B22`
- add a dot color to `SourceStyle.hex`

## 5. Add tests

In `Packages/AuxoKit/Tests/AuxoProvidersTests/`, add tests that use `MockTransport` with recorded responses. Cover at least:

- a normal profile: counts per day, days before `since` ignored, rating if any
- an unknown user, which must throw `.notFound`
- a malformed or blocked response, which must throw `.unavailable`

Run the tests with:

```bash
swift test --package-path Packages/AuxoKit
```

Finally, add the source to the README's data-source table and to `CHANGELOG.md`.
