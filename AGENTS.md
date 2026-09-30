# Instructions for AI agents

Read [CONTRIBUTING.md](CONTRIBUTING.md) first. It applies to you too.

## Project map

| File | What it does |
|---|---|
| `Sources/Sonar/SonarApp.swift` | App entry, menu bar label, `--snapshot` debug flag |
| `Sources/Sonar/Monitor.swift` | All sampling (CPU, GPU, memory, disk, network, sensors, apps) and history |
| `Sources/Sonar/SMC.swift` | Read-only SMC client for temperatures and fans |
| `Sources/Sonar/PanelView.swift` | The menu bar panel |
| `Sources/Sonar/DashboardView.swift` | The dashboard window |
| `Sources/Sonar/SettingsView.swift` | Settings inside the panel |
| `Icon/make-icon.swift` | Draws the app icon and builds `Icon/Sonar.icns` |
| `bundle.sh` | Builds `Sonar.app` / `Sonar.zip`; `install` copies to /Applications |
| `perf.sh` | Checks the running app against its idle budget |

## Rules

- **Measure performance, don't guess.** Run `./perf.sh` after any change to sampling or views, with the panel
  closed *after* opening and closing the panel and dashboard once. Hidden SwiftUI views that keep observing
  `Monitor` have caused 20–30% CPU regressions before.
- **Views must not update while hidden.** The panel renders a placeholder while closed and the dashboard window
  is torn down on close. Keep it that way.
- **No repeating or long-running animations**, and no `ImageRenderer` on a timer.
- **No new dependencies.**
- Verify UI changes by running the app and looking at it, not only by building.
- Format and lint with `swift-format` (see CONTRIBUTING.md) before committing.
- Don't bump versions or edit tags by hand outside the process in [docs/RELEASING.md](docs/RELEASING.md).
