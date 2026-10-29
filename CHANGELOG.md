# Changelog

All notable changes to Auxo are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- Which accounts a Stacked widget shows is now set in the app under Settings, not in each widget.
- Settings is shorter: explanatory footers removed.

### Fixed
- Clicking a widget on macOS could open several app windows. The app now uses a single window.

## [1.0.0] - 2026-10-27

### Added
- GitHub, LeetCode and Codeforces sources with daily activity heatmaps.
- Codeforces rating, max rating, rank title and contest count, colored by the official rank ladder.
- LeetCode contest rating, Knight and Guardian badges, and global top percentage.
- macOS desktop and iOS/iPadOS home-screen widgets in small, medium, large and extra-large sizes.
- Single, Stacked and Combined widget layouts with per-widget account selection.
- Interactive refresh button on widgets.
- Dashboard with per-account cards, a combined heatmap and show/hide filters.
- Share cards (1200×630) with an optional username.
- Themes: Per source, Classic, Ocean, Ember, Mono and Custom.
- GitHub sign-in via OAuth device flow or a personal access token stored in the Keychain.
- Cached-data fallback when a source is unavailable.
