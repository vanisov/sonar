# Versioning and releases

## Versioning

Sonar follows [Semantic Versioning](https://semver.org): `MAJOR.MINOR.PATCH`.

| Bump | When | Example |
|---|---|---|
| **MAJOR** | A change that breaks how people already use Sonar: dropping a macOS version, removing a feature, resetting settings | 1.4.0 → 2.0.0 |
| **MINOR** | New features or visible behavior changes that keep everything working | 1.1.0 → 1.2.0 |
| **PATCH** | Bug fixes and performance work with no new features | 1.2.0 → 1.2.1 |

Changes that don't touch the app (docs, CI, repo config) don't get a release.

The **git tag is the single source of truth** for the version. `bundle.sh` reads the latest `vX.Y.Z` tag
and writes it into the app's `Info.plist`, so there's no version number to edit by hand.

## Every change that ships gets a release

If a change reaches `main` and affects the app, it ships in a release. Nothing sits unreleased on `main`
for long; users download from the Releases page, not from source.

## How to release

1. Make sure `main` is green in CI.
2. In `CHANGELOG.md`, rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD`, add a fresh empty
   `## [Unreleased]` above it, and update the compare links at the bottom.
3. Commit: `git commit -am "Release X.Y.Z"`.
4. Tag and push:
   ```bash
   git tag vX.Y.Z
   git push origin main vX.Y.Z
   ```
5. The [release workflow](../.github/workflows/release.yml) builds `Sonar.zip` on a clean macOS runner
   and publishes the GitHub release, using that version's changelog section as the release notes.
6. Check the release page, download the zip, and make sure it opens.

## Before tagging, check

- `./perf.sh` stays within budget with the panel closed (after opening and closing the panel and dashboard once).
- The panel, settings, and dashboard open and close cleanly.
- New user-facing behavior is in the changelog.
