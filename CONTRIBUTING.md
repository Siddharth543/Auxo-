# Contributing to Auxo

Thanks for helping. Bug reports, fixes and new sources are all welcome.

## Setup

1. Follow **Build and run** in the [README](README.md).
2. Run the tests: `swift test --package-path Packages/AuxoKit`.

All logic lives in `Packages/AuxoKit`, so most changes can be developed and tested without running the app.

## Ground rules

- **Keep `project.yml` as the source of truth.** The `.xcodeproj` is generated and git-ignored. If you add files under `App/`, `Widget/` or the package, XcodeGen picks them up automatically.
- **Add tests for logic changes.** Provider tests use recorded JSON through `MockTransport`; never hit the network in tests.
- **One failing source must never break the others.** Providers throw `ProviderError`; `SyncService` records the error and keeps the last good data.
- **No servers, analytics or third-party SDKs.** Auxo talks only to the sites it reads from.
- **Rank colors are not themeable.** Codeforces and LeetCode colors carry meaning, so they always follow the official ladder.
- CI must pass: package tests, plus macOS and iOS builds.

## Adding a source

See [docs/ADDING_A_SOURCE.md](docs/ADDING_A_SOURCE.md). In short: add a case to `Source`, write a provider that implements `ActivityProvider`, register it in `ProviderRegistry`, add colors in `Palette`, and add tests with recorded responses.

## When a source breaks

LeetCode's endpoint is unofficial and may change. If the LeetCode heatmap shows "Unavailable":

1. Open the "Source broke" issue template with the error text shown in the app.
2. If you can, compare the request in `LeetCodeProvider.swift` with what leetcode.com's profile page currently sends (browser dev tools, Network tab).

## Pull requests

- Keep PRs focused, one change per PR.
- Describe what you tested. For UI changes, include a screenshot of the widget or app.
- Use clear commit messages ("Add AtCoder source", "Fix streak at midnight in UTC+14").

By contributing, you agree that your contributions are licensed under the MIT License.
