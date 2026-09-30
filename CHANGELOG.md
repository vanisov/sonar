# Changelog

All notable changes to Sonar are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and Sonar follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
See [docs/RELEASING.md](docs/RELEASING.md) for how versions are chosen and shipped.

## [Unreleased]

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

[Unreleased]: https://github.com/vanisov/sonar/compare/v1.3.1...HEAD
[1.3.1]: https://github.com/vanisov/sonar/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/vanisov/sonar/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/vanisov/sonar/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/vanisov/sonar/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/vanisov/sonar/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/vanisov/sonar/releases/tag/v1.0.0
