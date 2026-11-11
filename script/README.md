# Scripts

Local dev and release helpers. Run from the repository root.

## Local development

```bash
# Build Debug and launch the app
./script/run.sh

# Build Release DMG into release/ (optional version override for About)
./script/build.sh [vX.Y.Z]

# Same lint + build as CI — run before pushing (optional tag check)
./script/ci-local.sh [vX.Y.Z]
```

Install SwiftLint first if needed: `brew install swiftlint`.

## BarMan Pill regression checks

```bash
swift script/tests/item-discovery.swift
swift script/tests/pill-position.swift
swift script/tests/ax-item-press.swift
swift script/tests/ax-activation.swift
swift script/tests/trailing-pill.swift
```

These checks compile and execute the cache/positioning methods from the current
source with controlled WindowServer and screen inputs. They cover missing
dividers, retries with unchanged window IDs, and positioning without a window
ID. They need Xcode's Swift toolchain, but no privacy grants or running BarMan app.
They do not replace testing Accessibility discovery and icon clicks in the app.

The AX check executes the discovery and press implementation against an in-memory
Accessibility tree. It verifies selection for anonymous or identically named
siblings, changing titles, stale elements, and denied permission without clicking
the real menu bar.

The activation check runs the BarMan Pill click handler and temporary-reveal lifecycle
against a controlled menu server: originals must be shown before pressing, menus
must remain visible until closed, and cleanup must preserve newer user choices.
It also executes the section's hide/start/stop-rehide methods to check compact
popups, submenu dismissal, automatic rehide suppression and restart after a fired
timer, and explicit hiding while activation is in progress.

The trailing-pill check runs the split shape's measurement helpers: a sweep
that still sees a hidden icon right after a collapse must not widen the pill
again, frames as wide as half the display never count as icons, and the
item-list fallback reads only icons drawn on the measured display.

## After installing a build

```bash
# Clear stale TCC entries so Accessibility / Screen Recording can be re-granted
./script/fix-permissions.sh [/path/to/BarMan.app]
```

Ad-hoc signed builds are pinned to a `cdhash` that changes with every build, so the grant recorded for the previous binary stops matching — System Settings shows the toggle on while the app is denied. Releases are signed with the stable `BarMan Release` certificate instead, so this is only needed when switching from an ad-hoc build. See [Permissions](../README.md#permissions).

## Release signing certificate (one time)

```bash
./script/create-release-cert.sh --import   # writes ~/.barman-signing/barman-release.p12 + password
base64 -i ~/.barman-signing/barman-release.p12 | gh secret set MACOS_CERT_P12 -R skiduss/barman
gh secret set MACOS_CERT_PASSWORD -R skiduss/barman < ~/.barman-signing/barman-release.password
```

`release.yml` refuses to publish without these secrets. Back up `~/.barman-signing` — a new certificate makes every user re-grant permissions once.

## Every release (2 commands)

Automated releases so users get Sparkle update notifications — no manual version edits.

```bash
# 1. Commit your code, then create + push the tag (lints/builds first, version comes from the tag name)
./script/release.sh vX.Y.Z

# 2. CI builds the release and publishes the appcast (job `update-appcast`).
#    Only if that job fails or the secrets are missing, publish it by hand:
./script/update-appcast.sh vX.Y.Z
```

The `update-appcast` CI job needs two repo secrets: `SPARKLE_PRIVATE_KEY` (contents of
`~/.sparkle/sparkle-priv.pem`) and `MACOS_APP_RELEASES_DEPLOY_KEY` (private half of a write deploy key on
`skiduss/macos-app-releases`).

The feed lives in `barman/appcast.xml` of `skiduss/macos-app-releases`, shared with other apps. `LEGACY_REPO` in
`update-appcast.sh` stays empty: BarMan has no older feed to mirror.

After step 2, open `https://skiduss.github.io/macos-app-releases/barman/appcast.xml` — if the new tag is listed, you're done.

## Tag rules

* Format `vX.Y.Z` (e.g. `v0.11.14`) and **greater** than the version users have — Sparkle ignores older builds.
* Never re-tag an old number. No need to touch the version in Xcode — CI injects `MARKETING_VERSION` from the tag name.
* `release.sh` refuses a dirty tree — commit + push first.

## What `update-appcast.sh` needs

* `gh` logged in (`gh auth login`) and the `generate_appcast` tool (from the Sparkle 2.x dist).
* The private key matching `SUPublicEDKey` in `BarMan/Info.plist`: uses the Keychain key by default;
  pass `--key ~/.sparkle/sparkle-priv.pem` (or export `SPARKLE_PRIVATE_KEY`) if the key lives in a file.
* Push access to `skiduss/macos-app-releases` (served by GitHub Pages).

## No update showing? Check

1. Is the new tag in `appcast.xml` (link above)?
2. Does the user's app have **Automatically check for updates** on (default for fresh installs: on)?
3. Was the installed app signed with the same key — builds signed with the old upstream key need one manual download.
