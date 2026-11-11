<div align="center">
    <h1>BarMan</h1>
</div>

BarMan is a maintained fork of [Ice](https://github.com/jordanbaird/Ice) that keeps
the menu bar manager working on macOS 27 and later. Ice's last stable release was
0.11.12 in October 2024, and macOS 27 replaced the per-item windows Ice relied on
with a single bar drawn by `MenuBarAgent`. BarMan merges the community work that
restores it.

> [!IMPORTANT]
> BarMan is not affiliated with, endorsed by, or supported by Jordan Baird, and it
> is not an official Ice release. Please do not report BarMan problems to the Ice
> issue tracker.

## What this fork changes

- Restores hiding, revealing, the BarMan Bar (formerly the Ice Bar) and the Menu
  Bar Layout editor on macOS 27, from Ice PR
  [#995](https://github.com/jordanbaird/Ice/pull/995). Behaviour on macOS 26 and
  earlier is unchanged.
- Rebranded as BarMan: product name, bundle identifiers
  (`com.macutils.barman`), and user-facing strings.
- Version reset to 1.0.0. The upstream Sparkle appcast is deliberately not used.

## Install

Prebuilt releases are not published yet, so build from source:

```sh
git clone https://github.com/skiduss/barman.git
cd barman
xcodebuild -project Ice.xcodeproj -scheme BarMan -configuration Release \
  build CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" CODE_SIGN_STYLE=Manual
```

The app lands in
`~/Library/Developer/Xcode/DerivedData/Ice-*/Build/Products/Release/BarMan.app`.
Move it to `/Applications`, launch it, and grant Accessibility and Screen
Recording when asked.

Because the build is ad-hoc signed, macOS forgets those permissions every time
the app is rebuilt.

## Tests

The macOS 27 logic is unit tested without launching the app:

```sh
swift test
```

## Features/Roadmap

### Menu bar item management

- [x] Hide menu bar items
- [x] "Always-hidden" menu bar section
- [x] Show hidden menu bar items when hovering over the menu bar
- [x] Show hidden menu bar items when an empty area in the menu bar is clicked
- [x] Show hidden menu bar items by scrolling or swiping in the menu bar
- [x] Automatically rehide menu bar items
- [x] Hide application menus when they overlap with shown menu bar items
- [x] Drag and drop interface to arrange individual menu bar items
- [x] Display hidden menu bar items in a separate bar (e.g. for MacBooks with the notch)
- [x] Search menu bar items
- [x] Menu bar item spacing (BETA)
- [ ] Profiles for menu bar layout
- [ ] Individual spacer items
- [ ] Menu bar item groups
- [ ] Show menu bar items when trigger conditions are met

### Menu bar appearance

- [x] Menu bar tint (solid and gradient)
- [x] Menu bar shadow
- [x] Menu bar border
- [x] Custom menu bar shapes (rounded and/or split)
- [ ] Remove background behind menu bar
- [ ] Rounded screen corners
- [ ] Different settings for light/dark mode

### Hotkeys

- [x] Toggle individual menu bar sections
- [x] Show the search panel
- [x] Enable/disable the BarMan Bar
- [x] Show/hide section divider icons
- [x] Toggle application menus
- [ ] Enable/disable auto rehide
- [ ] Temporarily show individual menu bar items

### Other

- [x] Launch at login
- [ ] Automatic updates (Sparkle is built in but dormant: this fork ships no appcast yet, so the updater never starts)
- [ ] Menu bar widgets

## Why does BarMan support only macOS 14 and later?

BarMan inherits Ice's use of system APIs that are available starting in macOS 14,
so there are no plans to support earlier versions of macOS either. macOS 27
support itself comes from Ice PR [#995](https://github.com/jordanbaird/Ice/pull/995).

## Gallery

#### Show hidden menu bar items below the menu bar

![BarMan Bar](https://github.com/user-attachments/assets/f1429589-6186-4e1b-8aef-592219d49b9b)

#### Drag-and-drop interface to arrange menu bar items

![Menu Bar Layout](https://github.com/user-attachments/assets/095442ba-f2d0-4bb4-9632-91e26ef8d45b)

#### Customize the menu bar's appearance

![Menu Bar Appearance](https://github.com/user-attachments/assets/8c22c185-c3d2-49bb-971e-e1fc17df04b3)

#### Menu bar item search

![Menu Bar Item Search](https://github.com/user-attachments/assets/d1a7df3a-4989-4077-a0b1-8e7d5a1ba5b8)

#### Custom menu bar item spacing

![Menu Bar Item Spacing](https://github.com/user-attachments/assets/b196aa7e-184a-4d4c-b040-502f4aae40a6)

## License

BarMan is distributed under the [GPL-3.0 license](LICENSE), the same license as
Ice. It is a modified version of Ice, Copyright © 2025 Jordan Baird and
contributors. macOS 27 support comes from Ice PR #995 by RabenkoYevhenii.

See [NOTICE](NOTICE) for the attribution and the full list of changes made in
this fork, as required by GPL-3.0 §5(a).

Corresponding source: <https://github.com/skiduss/barman> (GPL-3.0 §6).
