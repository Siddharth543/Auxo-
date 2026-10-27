# Architecture

Auxo is a SwiftUI app plus a WidgetKit extension, built for macOS and iOS from the same sources. All logic lives in a local Swift package, `AuxoKit`, so it can be unit-tested without the app.

```
┌────────────── App (macOS / iOS) ──────────────┐   ┌──── Widget extension ────┐
│ Dashboard · Accounts · Settings · Share sheet │   │ Single · Stacked · Combined│
│               AppModel (@MainActor)           │   │ AuxoTimelineProvider       │
└───────────────────────┬───────────────────────┘   └─────────────┬─────────────┘
                        │                                         │
                ┌───────▼─────────────── AuxoKit ─────────────────▼───────┐
                │ AuxoUI        HeatmapView · RankText · Palette · ShareCard │
                │ AuxoProviders SyncService · GitHub · LeetCode · Codeforces │
                │ AuxoCore      Account · ActivitySeries · StreakStats       │
                │               SharedStore (App Group) · TokenStore (Keychain)│
                └────────────────────────────────────────────────────────────┘
```

## Data flow

1. The user adds an account in the app. `AppModel.addAccount` fetches it once through `SyncService.fetch`, which validates the handle, gets its exact spelling and loads the first data. Then it saves the account and a snapshot.
2. `SharedStore` writes JSON files into the **App Group** container:
   - `accounts.json` and `settings.json` are written only by the app.
   - `snapshots/<id>.json` is written by whichever process synced last.

   Separate files mean the app and the widget never overwrite each other's changes.
3. The widget's `AuxoTimelineProvider` reads the accounts the widget is configured for. It syncs them if their data is older than 25 minutes, then renders. It asks to be refreshed again in 30 minutes, or just after midnight, whichever comes first.
4. The ↻ button runs `RefreshIntent` inside the widget process. It force-syncs, and WidgetKit then reloads the widget.

## Days and time zones

Every site defines "a day" differently. Each provider converts to `LocalDay` (year, month, day, with no time zone), and everything downstream works with plain days:

- **GitHub** returns dates.
- **LeetCode** returns UTC-midnight timestamps, read as UTC days.
- **Codeforces** returns exact submission times, bucketed in the user's own time zone.

Streak rule: the current streak counts back from today. If there's no activity yet today, it counts back from yesterday, because the day isn't over.

## Failure handling

- Providers throw `ProviderError`, which covers not found, sign-in required, unauthorized, rate limited and unavailable.
- `SyncService` syncs each account independently. On failure it keeps the previous series, sets `lastError` and saves.
- The UI shows cached data at reduced opacity with an "Unavailable" / "cached" label.
- LeetCode's contest-rating call is best-effort. If it fails, the heatmap still updates.

## Rate limits

- **Codeforces** allows about one call every two seconds. `CodeforcesProvider.sharedLimiter` (a `RateLimiter` actor) spaces calls within a process. A sync takes three calls plus one per 1,000 submissions.
- **GitHub** GraphQL allows 5,000 points per hour per token; one sync costs one point.
- **LeetCode** gets two calls per sync.

## Combined heatmap

`ActivitySeries.combined` counts **how many accounts were active** each day, rather than summing raw counts. Sources measure different things (commits, submissions, accepted problems), and summing would let the noisiest one dominate.

## Themes and colors

- `Palette` maps a theme and a source to 5 shades. The combined view uses 4 shades (0, 1, 2, 3+ accounts).
- `RankStyle` holds Codeforces and LeetCode colors. They are deliberately independent of the theme.
- When macOS dims desktop widgets, or iOS tints the home screen, `widgetRenderingMode` is no longer `.fullColor`. The widget then switches to white shades.

## Security

- The GitHub token is stored with `TokenStore` in the Keychain, using the App Group as its access group so the widget can read it.
- The token needs no scopes.
- No other secrets exist, and there are no servers.
