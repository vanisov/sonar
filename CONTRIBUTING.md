# Contributing to Sonar

Thanks for helping. Sonar is small on purpose, so a few rules keep it that way.

## Principles

- **Lightweight first.** Sonar should cost about nothing when you're not looking at it. Every change is
  checked against the idle budget in [`perf.sh`](perf.sh): ≤ 0.75% of one core, ≤ 80 MB after every window has been used once, and under one idle wake-up a second.
- **Native and minimal.** SwiftUI, AppKit and Apple frameworks only. No third-party dependencies.
- **Read-only by default.** Sonar never changes system settings. Actions that affect other apps
  (like ending a process) need a clear, deliberate click.
- **Private.** No network access, no telemetry, no analytics.

## Setup

You need Xcode 26 or later (SwiftUI's macros ship with Xcode, not the Command Line Tools) and an Apple silicon Mac.

```bash
git clone https://github.com/vanisov/sonar
cd sonar
swift run              # run from source
./bundle.sh install    # build Sonar.app and install it to /Applications
```

## Before you open a PR

```bash
xcrun swift-format format --in-place --recursive Sources
xcrun swift-format lint --strict --recursive Sources
swift build -c release
./perf.sh               # with Sonar.app running and the panel closed
```

CI runs the lint and the build on every PR.

## Pull requests

- One change per PR. Small PRs get reviewed faster.
- Describe what changed and why, and attach a screenshot for anything visible.
- If it's user-facing, add a line under `## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md). CI fails a PR that
  changes `Sources/` without touching the changelog; add the `skip-changelog` label for changes users won't notice.
- Performance changes: include `./perf.sh` output from before and after.

## Code style

- Formatting is whatever `swift-format` produces with the repo's [`.swift-format`](.swift-format).
- Match the surrounding code. Comments explain *why*, not *what*.
- Prefer deleting code to adding it. No abstractions for a single use.

## Reporting bugs

Use the [bug report form](https://github.com/vanisov/sonar/issues/new?template=bug_report.yml).
For temperature or fan problems, include the output of:

```bash
/Applications/Sonar.app/Contents/MacOS/Sonar --snapshot ~/Desktop/sonar.png
```

## Releases

See [docs/RELEASING.md](docs/RELEASING.md).
