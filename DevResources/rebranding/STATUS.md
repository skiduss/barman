# BarMan status

Last updated: 2026-11-11 · Branch: `barman` (based on upstream `main` + Ice PR #995)

## Decisions

| Question | Decision |
| --- | --- |
| Purpose | Personal use now, free distribution later |
| Name | BarMan |
| Bundle identifier | `com.macutils.barman` / `com.macutils.barman.MenuBarItemService` |
| Version | 1.0.0 (1) |
| macOS support | macOS 26 and 27 (macOS 14+ still compiles) |
| macOS 27 code source | Ice PR #995, credited in `NOTICE` |
| Updates | No appcast yet; Sparkle starts only when `SUFeedURL` exists |
| Upstream issues | Do not touch Ice's 454 open issues; make a decision before announcing |

## Done

1. `762165f5` — merged PR #995 "Restore hiding, the Ice Bar and the layout editor
   on macOS 27" by RabenkoYevhenii onto `main`. Merge was clean: the PR only sat
   two documentation commits behind.
2. Rebranded as BarMan:
   - `PRODUCT_NAME = BarMan`, product now builds as `BarMan.app`.
   - Bundle identifiers changed, plus `Shared/Services/MenuBarItemService.swift`
     so the XPC service name still matches its new bundle identifier.
   - `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION = 1`.
   - `NSHumanReadableCopyright` names both copyright holders.
   - `Ice.xcscheme` → `BarMan.xcscheme`.
   - 32 user-facing "Ice" strings replaced across 15 files (settings panes,
     permissions window, right-click menus, window titles, BarMan Bar).
     Functional identifiers were intentionally kept: `Ice.ControlItem.*`, asset
     names, persisted control-item image names, and the `Ice/ItemImages` cache.
3. Licensing: `NOTICE` added (GPL-3.0 §5(a) change log and attribution), README
   rewritten (attribution, build instructions), in-app "Based on Ice" credit.
4. Sparkle: upstream appcast removed from `Ice/Resources/Info.plist` and the
   updater is gated on `SUFeedURL`, so BarMan never offers upstream Ice builds.

## Verified

```
xcodebuild -project Ice.xcodeproj -scheme BarMan -configuration Debug build \
  CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" CODE_SIGN_STYLE=Manual   # succeeds
swift test                                                           # 186 tests, 35 suites, pass
```

Built product (`DerivedData/Ice-*/Build/Products/Debug/BarMan.app`):

```
CFBundleName              = BarMan
CFBundleIdentifier        = com.macutils.barman
CFBundleShortVersionString= 1.0.0
CFBundleVersion           = 1
SUFeedURL                 = absent
XPCServices/MenuBarItemService.xpc = com.macutils.barman.MenuBarItemService
```

Notes on the build environment:

- Upstream signing settings point at Jordan Baird's team (`K2ATHQPJDP`), so a
  plain `xcodebuild` fails with "No signing certificate". The overrides above
  build ad-hoc, which is enough to run locally. Ad-hoc signing means macOS drops
  Accessibility/Screen Recording every rebuild.
- PR #995 bumps CompactSlider 1.1.6 → 2.1.0, Ifrit 2.0.6, Sparkle 2.8.0 and adds
  Semaphore, so the old CompactSlider compile break is gone; no patching needed.
- If SPM caches from the old lockfile are present, build fails with stale
  explicit-module errors. Fix: delete `~/Library/Developer/Xcode/DerivedData/Ice-*/Build`
  and `SourcePackages/repositories/Semaphore-*`.
- First launch of an ad-hoc build crashed in dyld with "Library not loaded:
  @rpath/Sparkle.framework/Versions/B/Sparkle ... different Team IDs". Ad-hoc
  signatures carry no team ID, and hardened runtime only loads libraries that
  share the process's team ID, so `Ice/Resources/BarMan.entitlements` now sets
  `com.apple.security.cs.disable-library-validation`. Verified: the Release build
  launches, stays up, and writes no crash report.

## Still open

- [x] **Publish the source repository.** <https://github.com/skiduss/barman>
      (forked from `jordanbaird/Ice`, `main` fast-forwards to this work).
      `NOTICE`, the README, and the About pane's `sourceURL` all point at it.
      Pushed 2026-11-11: `origin/main` = `a310f166`; `origin` is the fork,
      `upstream` is `jordanbaird/Ice`.
- [ ] **Icon.** `Ice/Assets.xcassets/AppIcon` is still Jordan Baird's artwork.
      Replace before distributing (trademark is not covered by the GPL).
- [ ] **Sparkle appcast** for BarMan releases, plus a new EdDSA key pair
      (`SUPublicEDKey` is still upstream's public key).
- [ ] **Rename the project/target from `Ice`** (optional; `PRODUCT_NAME` is enough
      for the app to be called BarMan, but the Xcode project is still `Ice.xcodeproj`).
- [ ] **Manual smoke test on macOS 27.2**: launch `BarMan.app`, grant
      Accessibility and Screen Recording, confirm hiding, revealing, the BarMan
      Bar, and the Menu Bar Layout editor all work. Also confirm on macOS 26.
- [ ] **CI build gate**: build + `swift test` on every push.
- [ ] Decide whether the 454 upstream Ice issues matter for this fork.

## Build commands

```sh
# app
xcodebuild -project Ice.xcodeproj -scheme BarMan -configuration Release \
  build CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" CODE_SIGN_STYLE=Manual

# tests (no app launch, no permissions needed)
swift test
```
