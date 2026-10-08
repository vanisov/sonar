# Versioning and releases

## Versioning

Sonar follows [Semantic Versioning](https://semver.org): `MAJOR.MINOR.PATCH`.

| Bump | When | Example |
|---|---|---|
| **MAJOR** | A change that breaks how people already use Sonar: dropping a macOS version, removing a feature, resetting settings | 1.4.0 → 2.0.0 |
| **MINOR** | New features or visible behavior changes that keep everything working | 1.1.0 → 1.2.0 |
| **PATCH** | Bug fixes and performance work with no new features | 1.2.0 → 1.2.1 |

Commit types ([Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)) map onto this: a breaking
change (`!` or `BREAKING CHANGE:`) means MAJOR, `feat` means MINOR, `fix` and `perf` mean PATCH. Changes that don't
touch the app (`docs`, `ci`, `chore`, repo config) don't get a release.

The **git tag is the single source of truth** for the version. `bundle.sh` reads the latest `vX.Y.Z` tag
and writes it into the app's `Info.plist`, so there's no version number to edit by hand.

## Every change that ships gets a release

If a change reaches `main` and affects the app, it ships in a release. Nothing sits unreleased on `main`
for long; users download from the Releases page, not from source.

## How to release

Releases happen by merging. No one tags by hand.

1. In the PR that should ship (or a separate one), rename `## [Unreleased]` in `CHANGELOG.md` to
   `## [X.Y.Z] - YYYY-MM-DD`, add a fresh empty `## [Unreleased]` above it, update the compare links at the
   bottom, and commit it as `chore: release X.Y.Z`.
2. Merge the PR once CI is green.
3. The [release workflow](../.github/workflows/release.yml) sees a changelog version that isn't tagged yet,
   builds `Sonar.zip` on a clean macOS runner, creates the `vX.Y.Z` tag on the merge commit, and publishes the
   GitHub release with that version's changelog section as the notes.
4. Check the release page, download the zip, and make sure it opens.

Merges without a new version section (everything else) build in CI but don't release anything.

If a release ever needs to be redone, push the tag yourself (`git tag vX.Y.Z && git push origin vX.Y.Z`);
the same workflow rebuilds and republishes it.

## Before merging a release, check

- `./perf.sh` stays within budget with the panel closed (after opening and closing the panel and dashboard once).
- The panel, settings, and dashboard open and close cleanly.
- New user-facing behavior is in the changelog.

## Code signing

Releases are signed with Sonar's own certificate, **Sonar Code Signing**. It's self-signed, so it's free, but
it never changes between builds. That stable identity does two jobs:

- **Permissions stick.** macOS remembers the folders people let Sonar read (Desktop, Documents, Downloads) by
  the app's signature. Ad-hoc builds get a new identity every time, so every update asked again.
- **Updates are verified.** The updater installs a download only if it's signed with the same certificate as
  the running app. A release uploaded by anyone else, even with a stolen GitHub token, is refused.

| | |
|---|---|
| Certificate root hash (what macOS and the updater check) | `483718b76021632ea75199da242e0a047fad2a9b` |
| SHA-256 fingerprint | `1BDB4AF199051C64889FD92BED21FD92ACE24959B02823595946A47034991369` |
| Expires | October 2036 |
| CI secrets | `SIGNING_CERT_P12` (the .p12, base64) and `SIGNING_CERT_PASSWORD` |
| Maintainer's copy | login keychain, plus a backup of the .p12 and its password in a password manager |

The release workflow imports it into a temporary keychain, signs with it, and refuses to publish if
`build/Sonar.app` isn't signed with it. `bundle.sh` uses it automatically when it's in your keychain and signs ad
hoc otherwise, so contributors don't need it.

**Never commit the certificate or its password.** Whoever has both can sign Sonar updates.

### If the certificate is lost, leaked or about to expire

Make a new one the same way (a self-signed code-signing certificate named "Sonar Code Signing"), update both
secrets, and update the root hash in `release.yml` and in the table above. The updater in existing installs
will refuse releases signed with the new certificate, so tell users in the release notes to download that one
release by hand. Every release after it updates normally again. If the old key leaked, do this right away.

