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

You need Xcode 26 or later and an Apple silicon Mac. SwiftUI's macros ship with Xcode, not the Command Line Tools,
so make sure Xcode is the selected toolchain:

```bash
xcode-select -p        # should print /Applications/Xcode.app/Contents/Developer
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer   # if it prints CommandLineTools
```

If you'd rather not switch, prefix commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
Otherwise `swift build` fails with "plugin for module 'SwiftUIMacros' not found". `bundle.sh` handles this itself.

```bash
git clone https://github.com/vanisov/sonar
cd sonar
swift run              # run from source (or open Package.swift in Xcode)
swift test             # unit tests
./bundle.sh install    # build Sonar.app and install it to /Applications
```

## Before you open a PR

```bash
xcrun swift-format format --in-place --recursive Sources Tests
xcrun swift-format lint --strict --recursive Sources Tests
swift test
swift build -c release
./perf.sh               # with Sonar.app running and the panel closed
```

CI runs the lint, the tests and the build on every PR.

## Project layout

Code is grouped by feature, one main type per file, named after the type, like most Swift apps:

```
Sources/Sonar/
  app/          entry point, updater
  menubar/      menu bar label and its items
  panel/        the menu bar panel
  dashboard/    window, sidebar, search; pages/, charts/, components/
  processes/    the Processes page
  disk/         cleanup/ and storage/ (what's using space)
  settings/     the Settings window; panes/ holds one <Name>SettingsPane per tab
  monitoring/   Monitor (all sampling) and the values it produces
  system/       low-level readers: SMC, sysctl, Mac model, battery, network interfaces
  hotkeys/      global shortcuts and their recorder
  shared/       prefs keys, formatting, brand, small shared views
Tests/SonarTests/   unit tests for pure logic, mirroring the folders above
```

- Extensions that add a feature to a type live in `Type+Feature.swift` (e.g. `Monitor+Processes.swift`).
- Small helpers used by one file can stay in that file as `private`. Default to `private` until something else needs it.
- Add a test for logic that doesn't need a window: math, parsing, formatting, file scanning.

## Pull requests

- One change per PR. Small PRs get reviewed faster.
- Title the PR like a commit message (see below). Add the version for release PRs: `feat: processes page (1.4.0)`.
- Describe what changed and why, and attach a screenshot for anything visible.
- If it's user-facing, add a line under `## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md). CI fails a PR that
  changes `Sources/` without touching the changelog; add the `skip-changelog` label for changes users won't notice.
- Performance changes: include `./perf.sh` output from before and after.

## Commit messages and PR titles

Commits and PR titles follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/). PRs are
merged with merge commits, so every commit on your branch ends up on `main`.

```
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

- **Types:** `feat` (a new feature) and `fix` (a bug fix) come from the spec. We also use `perf`, `refactor`,
  `docs`, `test`, `ci`, `build` and `chore`, which the spec allows.
- **Scope** is optional and names the area in parentheses: `feat(disk): show what's using storage`.
- **Description:** lowercase, imperative, no trailing period: `fix: keep chart labels inside the card`.
- **Breaking changes** add `!` after the type or scope (`feat!: require macOS 15`), or a `BREAKING CHANGE:` footer.
- **Versions:** as in the spec, `fix` means a PATCH release, `feat` a MINOR one, and a breaking change a MAJOR one.
  See [docs/RELEASING.md](docs/RELEASING.md).

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
