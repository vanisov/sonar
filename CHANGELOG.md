# Changelog

All notable changes to Sonar are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and Sonar follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
See [docs/RELEASING.md](docs/RELEASING.md) for how versions are chosen and shipped.

## [Unreleased]

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

[Unreleased]: https://github.com/vanisov/sonar/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/vanisov/sonar/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/vanisov/sonar/releases/tag/v1.0.0
