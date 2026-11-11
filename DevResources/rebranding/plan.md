# BarMan — Rebranding Plan (`Ice` → `BarMan`)

**Status:** approved · 2026-11-11
**Branch:** `rebrand/barman` (base `ade745ac`; noise fix `21c5cbde`)
**Mode:** full rename (fork detaches from upstream `cavaldos/Ice`)

---

## 1. Locked decisions

| Item | Value |
|---|---|
| App / product name | **BarMan** |
| Bundle identifier | **com.skidus.barman** |
| Target / module / folder | **BarMan** |
| Copyright | `Copyright © 2026 skidus` |
| Website | **skidus.dev** |
| Main repo | **https://git.gkx-ds920.synology.me/Utility-and-Tools-Apps/Menubar-Manager.git** (remote `origin`; GitHub `skiduss/barman` kept as remote `github`) |
| Sparkle auto-update | **disabled** (no feed published yet) |
| App icon | keep existing Ice icon for now (swap later) |
| "Ice Bar" feature | **"BarMan Pill"** |

---

## 2. Naming map

| Old | New |
|---|---|
| `Ice.xcodeproj`, target/module/folder `Ice` | `BarMan.xcodeproj`, `BarMan` |
| `PRODUCT_BUNDLE_IDENTIFIER = com.jordanbaird.Ice` | `com.skidus.barman` |
| `INFOPLIST_KEY_NSHumanReadableCopyright` | `Copyright © 2026 skidus` |
| `Ice/Ice.entitlements` | `BarMan/BarMan.entitlements` |
| `@main struct IceApp` | `BarManApp` |
| UI components `IceSection/IceForm/IcePicker/IceSlider/IceGroupBox/IceLabeledContent/IceButtonStyle/IceFormToggleStyle/IceMenu` | `BarManSection/BarManForm/…` |
| Feature `IceBar*` ("Ice Bar") | `BarManPill*` ("BarMan Pill") |
| Defaults keys `ShowIceIcon`, `IceIcon`, `ReverseIceIcon`, `CustomIceIconIsTemplate`, `UseIceBar` | `ShowBarManIcon`, `BarManIcon`, `ReverseBarManIcon`, `CustomBarManIconIsTemplate`, `UseBarManPill` |
| `"Ice.TrailingWidths.v3"` | `"BarMan.TrailingWidths.v3"` |
| Logger subsystem `com.jordanbaird.Ice` | `com.skidus.barman` |
| AX identifier prefix `"Ice"` | `"BarMan"` |
| Status item AX IDs `IceHiddenDivider`, `IceAlwaysHiddenDivider`, `IceSpacerExtension` | `BarManHiddenDivider`, `BarManAlwaysHiddenDivider`, `BarManSpacerExtension` |
| Autosave `SItem` / `HItem` / `AHItem` | keep (already generic) |
| ImageSet `iceCube = "Ice Cube"` | `barMan = "BarMan"` (same catalog assets for now) |
| Strings `"Ice Settings…"`, `"Quit Ice"`, `NSMenu(title: "Ice")`, About/Permissions/StarRequest/Appearance | `"BarMan …"` |
| `SUFeedURL` (cavaldos) | `https://skiduss.github.io/macos-app-releases/barman/appcast.xml` |
| `script/*` `REPO="cavaldos/Ice"`, `ice/appcast.xml` | `skiduss/barman`, `barman/appcast.xml` |
| git remote `origin` | `https://github.com/skiduss/barman.git` |

---

## 3. Phases

### P0 — Branch ✅
- `git checkout -b rebrand/barman`
- pending noise fix committed as `21c5cbde`

### P1 — Identity / build
- `git mv Ice BarMan`; `Ice.entitlements → BarMan.entitlements`; `Ice.xcodeproj → BarMan.xcodeproj`; scheme `Ice.xcscheme → BarMan.xcscheme`
- pbxproj: bundle id, target `name`/`productName`, `path = BarMan`, `INFOPLIST_FILE`, `CODE_SIGN_ENTITLEMENTS`, copyright
- scheme: `BuildableName`, `BlueprintName`, container
- `Info.plist`: `SUEnableAutomaticChecks=false`, feed → skiduss/barman
- logger subsystem → `com.skidus.barman`
- **Verify:** `xcodebuild build` OK, `codesign -d` shows `com.skidus.barman`, product `BarMan.app`

### P2 — User-visible strings
- `ControlItem` menu (`"Ice Settings…"`, `"Quit Ice"`), `MenuBarManager` `NSMenu(title:)`
- About pane (`Text("Ice")`), PermissionsView ×3, StarRequestPrompt, MenuBarAppearanceEditor, GeneralSettingsPane
- remove/disable "Check for Updates…" entry points while the feed is off
- **Verify:** `grep -rn '"Ice' BarMan/` → 0

### P3 — Internal identifiers
- `IceApp` → `BarManApp`; `Ice*` UI components → `BarMan*`; `IceBar*` → `BarManPill*`
- Defaults keys, `Ice.TrailingWidths.v3`, AX prefix `"Ice"`, status item AX IDs, ImageSet case/label
- **Verify:** `grep -rn '\bIce\b' BarMan/` → 0 (file headers optional)

### P4 — Docs / scripts / repo
- README: name, links, `skidus.dev`, `skiduss/barman`
- `script/create-release-cert.sh`: `NAME="BarMan Release"`, `~/.barman-signing`, `barman-release.p12`, `REPO=skiduss/barman`, identifier `com.skidus.barman`
- `script/update-appcast.sh`: `RELEASES_REPO`, `APPCAST="barman/appcast.xml"`, `FEED_URL`, `gh release download -R skiduss/barman -p 'BarMan.zip'`, legacy repo `""`
- `.github/workflows/*.yml`: `-project BarMan.xcodeproj -scheme BarMan`, `BarMan.app`, `BarMan.zip`, cask
- `git remote set-url origin https://github.com/skiduss/barman.git`

### P5 — Migration / ship
- (optional) one-time defaults migration `com.jordanbaird.Ice` → `com.skidus.barman`; otherwise settings start fresh
- build Debug → quit Ice → `ditto` to `~/Applications/BarMan.app`
- `tccutil reset Accessibility com.skidus.barman` / `ScreenCapture` → re-grant
- **Verify:** About = BarMan, menus = BarMan, "BarMan Pill" toggles, status items work, no `Ice` in UI

---

## 4. Risks / notes

- **TCC:** bundle id change resets Accessibility + Screen Recording grants — unavoidable; re-grant once.
- **Defaults domain change:** existing preferences are orphaned under `com.jordanbaird.Ice`. Settings start at defaults unless a migration is added.
- **Folder rename is low risk:** the target uses `PBXFileSystemSynchronizedRootGroup` (single `path = Ice`), so no per-file references needed fixing.
- **Icon deferred:** `AppIcon` + `IceCube*` catalog assets stay; only the picker label changes.
- **Sparkle:** updater still starts (needs `SUPublicEDKey`); automatic checks off. Regenerate an EdDSA key pair before publishing a BarMan appcast.
- **Known unrelated bug still open:** `Migration failed: Missing menu bar appearance configuration` (V1→V2 appearance migration); overlay pill falls back to defaults.

---

## 5. Verification checklist

- [ ] `xcodebuild -project BarMan.xcodeproj -scheme BarMan build` succeeds
- [ ] `codesign -d --entitlements - BarMan.app` → `com.skidus.barman`
- [ ] About pane: name = BarMan, copyright = skidus, version intact
- [ ] Menu: "BarMan Settings…", "Quit BarMan"
- [ ] Feature: "BarMan Pill" toggle works, pill panel shows
- [ ] Status items: conceal/reveal + spacer extensions still work
- [ ] `grep -rn '\bIce\b' BarMan/ .github/ script/ README.md` → 0

---

## 6. Progress log

**P0–P4 executed on branch `rebrand/barman`**

- Project/target/module/folder renamed: `BarMan.xcodeproj`, `BarMan/`, scheme `BarMan.xcscheme`
- pbxproj identity: `com.skidus.barman`, `PRODUCT_NAME = $(TARGET_NAME)` → `BarMan.app`, copyright `skidus`
- ~95 Swift edits: `BarMan*` UI components (`BarManSection/Form/Picker/Slider/GroupBox/LabeledContent/Menu/ButtonStyle/FormToggleStyle`), feature `BarManPill*` (+ files/folders renamed), defaults keys, AX identifiers, logger subsystem, `BarManApp`
- `Info.plist`: feed → `https://skiduss.github.io/macos-app-releases/barman/appcast.xml`, `SUEnableAutomaticChecks=false`
- README, `script/*.sh`, `script/README.md`, `.github/workflows/*`, issue templates, `FUNDING.yml`, `CONTRIBUTING.md`
- `script/tests/ice-bar-position.swift` → `pill-position.swift`; all 6 regression scripts pass
- `git remote origin` → `https://github.com/skiduss/barman.git` (superseded, see below)
- remotes re-pointed: **`origin`** = `https://git.gkx-ds920.synology.me/Utility-and-Tools-Apps/Menubar-Manager.git` (main, Gitea), **`github`** = `https://github.com/skiduss/barman.git` (kept as fallback/mirror)
- in-app and documentation links intentionally stay on `github.com/skiduss/barman`; release/appcast pipeline stays on GitHub Actions
- Verified: `xcodebuild -scheme BarMan` succeeds; built app reports `com.skidus.barman`, `BarMan.app`, `Copyright © 2026 skidus`

**Deliberately left**

- `IceCubeStroke` / `IceCubeFill` asset names (icon swap deferred)
- old `SUPublicEDKey` in `Info.plist` — regenerate before publishing an appcast
- upstream credits in README ("A fork of Ice …") and `CODE_OF_CONDUCT.md` contact email
- P5 (install to `~/Applications`, TCC re-grant) not executed yet

**Fixed along the way**

- `script/tests/ax-activation.swift` was already failing at `ade745ac` (fixture lacked `isLayoutEditing`); stub added


