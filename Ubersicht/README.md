# Auxo for Übersicht (no Xcode)

A free alternative for Mac users who don't want to build the native app. It shows the same GitHub, LeetCode and Codeforces heatmaps, streaks and ratings on the desktop, using [Übersicht](https://tracesof.net/uebersicht/), a free ~10 MB app that runs desktop widgets.

| | Native app (Xcode) | Übersicht widget |
|---|---|---|
| Needs Xcode | Yes (~15 GB+) | **No** |
| Needs an Apple Developer account | For iPhone/iPad widgets | **No** |
| iPhone / iPad | Yes | No |
| Share cards, in-app themes | Yes | No |
| Setup time | ~20 min | **~2 min** |

## Install

1. Install Übersicht from [tracesof.net/uebersicht](https://tracesof.net/uebersicht/) and open it.
2. Click the Übersicht menu bar icon, then **Open Widgets Folder**.
3. Copy the `auxo.widget` folder from this repo into it.
4. Open `auxo.widget/index.jsx` in any text editor and edit the `ACCOUNTS` list:

   ```js
   const ACCOUNTS = [
     { source: "codeforces", handle: "your_cf_handle" },
     { source: "leetcode",   handle: "your_leetcode_name" },
     { source: "github",     handle: "your_github_login" },
   ];
   ```

5. Save. The widget reloads on its own. Delete any line to hide that streak.

## GitHub token

GitHub only serves contribution calendars to signed-in requests. Create a [fine-grained token](https://github.com/settings/personal-access-tokens/new) with public repository access and **no permissions**, then paste it into `GITHUB_TOKEN`. It stays in that file on your Mac. Skip this if you don't use GitHub.

## Options

| Setting | Values | Default |
|---|---|---|
| `LAYOUT` | `"stacked"` or `"combined"` | `"stacked"` |
| `SHOW_HANDLES` | `true` / `false` | `false` |
| `CELL`, `GAP`, `WEEKS` | pixel sizes / weeks shown | `10`, `3`, `53` |

Move the widget by changing `top` and `left` in `className`. It refreshes every 30 minutes.

## Notes

- Codeforces ranks use the official colors. LeetCode shows its contest rating and badge.
- LeetCode has no public API, so that heatmap can break when LeetCode changes its site. If one source fails, the others keep working and the failed one keeps its last data.
- Handles may only contain letters, digits, `_`, `.` and `-`. Anything else is ignored.
