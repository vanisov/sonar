# Changelog

All notable changes to Sonar are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and Sonar follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
See [docs/RELEASING.md](docs/RELEASING.md) for how versions are chosen and shipped.

## [Unreleased]

## [1.9.0] - 2026-10-08

### Changed
- Sonar is now signed with its own certificate instead of ad hoc, so macOS remembers the permissions you
  grant (like access to Desktop, Documents and Downloads for the storage breakdown) across updates. This update
  asks one last time.
- The newest column in every graph is no longer orange; columns simply brighten toward now. The orange dot still
  marks the peak.

### Added
- Hover the "Where memory goes" bar on the Memory page, or the storage bar on the Disk page, to see what each part is,
  its size and share. App memory lists the apps using the most, and System Data its biggest parts. Hovering a row in
  the list below highlights its part of the bar.

### Fixed
- A fan whose speed reading failed for a moment showed as "0 RPM · stopped" and drew a false zero into its graph.
  It now keeps its last speed.

### Security
- The updater installs a download only if it's signed with Sonar's certificate. A release uploaded by anyone
  else, even with access to the GitHub repository, is refused.

## [1.8.0] - 2026-10-08

### Changed
- The dashboard uses the panel's column graphs on every page: one column per slice of time holding that slice's
  peak, brightest toward now, temperature as a dashed line on the CPU and GPU graphs, and an 80% line on
  percentage graphs. Network and disk activity show download and read above the line, upload and write below.
- Hover any dashboard graph to read the exact time and values.
- Sensors show their recent history as small column graphs.
- Removed the chart style setting (filled or line), since graphs are now columns.
- Dashboard graphs no longer use Swift Charts, which was one of the costliest parts of the app to draw.

## [1.7.0] - 2026-10-05

### Changed
- A new panel design, Sonar's own:
  - CPU, GPU, memory and network are full-width column graphs, drawn like the app icon, with the newest column in
    orange.
  - CPU and GPU show their temperature as a dashed line on the same graph, mark the 2-minute peak, and draw a line
    at 80%. Hover a graph to see the exact time and value.
  - Network shows download above the line and upload below, on a log scale.
  - Disk and fans sit side by side with a short caption, and the apps using the most are listed underneath.
  - Dashboard, Settings and Quit are small round buttons next to your Mac's name, replacing the footer.
- Settings → Panel: "Sparkline length" is now "Graph length" and "Top apps" is "Apps listed".

### Fixed
- Network and disk charts no longer spike to absurd values when a drive is ejected, a dock or adapter is
  unplugged, or a reading fails.
- Disk read and write rates were up to 5× too high while the panel and dashboard were closed.
- Fan speeds no longer shift to the wrong fan when one reading fails.
- End and Force End can't hit a different process that reused the PID while a confirmation was open, and a new
  process no longer shows the previous one's name or CPU.
- Clean Up checks again, at the moment you click Move to Trash, that nothing was written in the last hour.
- Updates: a beta can no longer replace the release it precedes, the download must be exactly the advertised
  version of Sonar from GitHub, GitHub rate limits get a clear message, and the app relaunches reliably.
- The Network and This Mac pages no longer re-read interfaces and battery info on every update.
- VoiceOver reads the panel's Settings and Quit buttons by name.
- `--snapshot` images were washed out on HDR displays.

## [1.6.0] - 2026-10-01

### Added
- The Disk page shows what's using your storage, in the categories System Settings uses: Applications, Documents,
  Photos, Music, Movies, iCloud Drive, Developer, macOS and System Data, as a colored bar with a legend. The first
  calculation asks for access to Desktop, Documents and Downloads. A full pass reads every file in your home folder,
  so it runs in the background at low priority, is kept across launches, and is redone at most once a day, or when
  you click Recalculate.
- System Data is broken down too: app data, caches, hidden folders in your home, apps and tools for all users,
  downloaded system assets, system files, macOS support volumes, and snapshots and other space Sonar can't
  attribute. Used and Capacity moved up next to the available space.

## [1.5.0] - 2026-10-01

### Added
- Clean Up, a tab on the Disk page: finds app caches, logs and crash reports, package manager caches (Homebrew,
  npm, Yarn, pip, CocoaPods, Go, Bun, pnpm), Xcode build data and device support files, with the size of each and
  every item inside. What you pick moves to the Trash, so nothing is gone until you empty it. It only lists things
  that are rebuilt or downloaded again automatically, and skips caches of running apps, Apple's own caches, and
  anything written to in the last hour. It scans only your home folder, and only when you click Scan.

## [1.4.1] - 2026-09-30

### Fixed
- The newest time label on dashboard charts was cut off at the right edge. Charts also use their full width again.

## [1.4.0] - 2026-09-30

### Added
- Processes in the dashboard: every app and background process with CPU, memory, threads, PID and user,
  sortable, with All / Applications / Background tabs. Search filters it by name or PID.
- Select one or more processes and use the control bar above the table to Quit or Force Quit apps, End or Force
  End background processes, show them in Finder, or see details (⌘I or double-click). ⌘⌫ quits, ⌥⌘⌫ forces; forceful actions
  ask first (Settings → Dashboard). Right-click works too.
- Other users' and system processes are listed but locked, and so is `loginwindow`, which would log you out.
- Settings warns when a keyboard shortcut is already used by macOS, like ⌥⌘D for Dock hiding.

### Changed
- Apps in the dashboard sidebar are now called Processes.

## [1.3.2] - 2026-09-30

### Changed
- The "sonar" wordmark in the dashboard sidebar is easier to read in light and dark mode.

## [1.3.1] - 2026-09-30

### Changed
- The dashboard sidebar uses standard macOS rows: accent-colored icons, live values as badges, a slightly smaller
  row size, more space under the logo, and more room after the Overview chevron.
- CPU core bars and usage bars glide to each new value. The animation runs in the window server, so it costs
  Sonar almost nothing.

## [1.3.0] - 2026-09-30

### Added
- A redesigned dashboard: a sidebar with every metric under Overview, and a page for each one.
  - CPU: usage and temperature charts, every core (performance and efficiency), load average, top apps.
  - GPU, memory (app, wired, compressed, cached, swap), disk (space and read/write activity), network
    (interfaces, totals since boot), sensors and fans.
  - This Mac: model, chip, cores, displays, macOS build, uptime, battery health, storage, and Copy Specs.
- Pick the time range for every chart: 1 minute, 5, 15, 30 minutes, or 1 hour, with min, average and max.
- Search apps, sensors and sections from the dashboard toolbar.
- A Settings window (⌘,) with General, Menu Bar, Panel, Dashboard, Units and About tabs:
  - Reorder menu bar stats, choose icon/value per stat, decimal places, and warning colors.
  - Choose and reorder the panel's cards, the number of top apps and the sparkline length.
  - Default time range, chart style, temperature overlay, and average or hottest CPU temperature.
  - Storage in GB or GiB, network in bytes or bits.
  - A global keyboard shortcut to open the dashboard.
  - Appearance (system, light, dark) and Restore Defaults.
- Optional update checks against GitHub releases, with install and relaunch. Off by default.
- New icon, logo and colors.

### Changed
- CPU and GPU temperature sensors are read less often when only the menu bar needs them.

## [1.2.1] - 2026-09-29

### Fixed
- Dashboard charts drew outside their cards and across the sidebar after the Mac had slept,
  and joined the samples before and after sleep with long straight lines.

## [1.2.0] - 2026-09-29

### Added
- Click any card in the panel to open the dashboard at that section.
- Temperatures in °C or °F (Settings → General). Defaults to your region's unit.
- Sonar shows in the Dock while the dashboard is open.
- Hover highlights on the panel's buttons and cards.

### Changed
- The panel starts straight with your Mac's stats; the Sonar header is gone.
- Each menu bar stat has its own icon. The Sonar logo appears only when no stats are shown.
- Numbers update in place without the rolling animation.

### Fixed
- `--snapshot` rendered an empty image.

## [1.1.0] - 2026-09-29

### Changed
- Idle cost is down to about 0.3% of one core and ~20 MB, with no idle wake-ups
  (was up to 30% CPU and 360 MB after running for a while).
- Expensive readings (GPU, temperatures, fans, per-app usage) only run while a view is open
  or the menu bar shows them; otherwise every 10 seconds.
- The dashboard window only exists while it's open.

### Fixed
- Disk space and non-CPU/GPU sensors stopped updating after an hour.
- Fans stopped by macOS at idle showed as "Manual".
- Open dashboard left the panel stuck open.

## [1.0.0] - 2026-09-29

### Added
- Menu bar panel with CPU, GPU, memory, disk, network, fans, temperatures and top apps.
- Choice of stats in the menu bar, and launch at login.
- Dashboard with an hour of history, every temperature sensor, and all running apps.

[Unreleased]: https://github.com/vanisov/sonar/compare/v1.9.0...HEAD
[1.9.0]: https://github.com/vanisov/sonar/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/vanisov/sonar/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/vanisov/sonar/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/vanisov/sonar/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/vanisov/sonar/compare/v1.4.1...v1.5.0
[1.4.1]: https://github.com/vanisov/sonar/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/vanisov/sonar/compare/v1.3.2...v1.4.0
[1.3.2]: https://github.com/vanisov/sonar/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/vanisov/sonar/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/vanisov/sonar/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/vanisov/sonar/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/vanisov/sonar/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/vanisov/sonar/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/vanisov/sonar/releases/tag/v1.0.0
