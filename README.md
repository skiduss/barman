<div align="center">
    <img src="BarMan/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width=200 height=200>
    <h1>BarMan — Free & Open-Source Menu Bar Manager for macOS</h1>
    <p>Hide and organize menu bar icons on your Mac. The best <strong>free Bartender alternative</strong> — also a great <strong>Hidden Bar</strong> and <strong>Vanilla alternative</strong> — focused on stability and a smooth, distraction-free experience.<br>✅ <strong>Fully supports macOS 27</strong></p>
</div>

![BarMan menu bar manager for macOS — hide and organize menu bar icons](./Resources/Image/banner.png)

<div align="center">

[![Download](https://img.shields.io/badge/download-latest-brightgreen?style=flat-square)](https://github.com/skiduss/barman/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/skiduss/barman/total?style=flat-square)](https://github.com/skiduss/barman/releases)
![Platform](https://img.shields.io/badge/platform-macOS-blue?style=flat-square)
![Requirements](https://img.shields.io/badge/requirements-macOS%2014%2B-fa4e49?style=flat-square)
![macOS 27](https://img.shields.io/badge/macOS_27-fully_supported-brightgreen?style=flat-square)
[![GitHub stars](https://img.shields.io/github/stars/skiduss/barman?style=flat-square)](https://github.com/skiduss/barman/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/skiduss/barman?style=flat-square)](https://github.com/skiduss/barman/network/members)
[![Website](https://img.shields.io/badge/Website-015FBA?style=flat-square)](https://skidus.dev)
[![License](https://img.shields.io/github/license/skiduss/barman?style=flat-square)](LICENSE)

<br>

</a>

</div>

> [!NOTE]
> BarMan is in active development. Grab the latest build from the [releases page](https://github.com/skiduss/barman/releases/latest).

> [!TIP]
> ✅ **Fully supports macOS 27** — tested and ready for the latest macOS, all the way back to macOS 14 Sonoma.

## Install

**Homebrew** (recommended — updates with `brew upgrade`):

```bash
brew tap skiduss/tap
brew install skiduss/tap/barman
```

**Manual:**

1. Download `BarMan.zip` from the [latest release](https://github.com/skiduss/barman/releases/latest).
2. Unzip it and move `BarMan.app` into `/Applications`.
3. Clear the quarantine flag — releases are self-signed and not notarized, so Gatekeeper would otherwise block the first launch:

```bash
xattr -d com.apple.quarantine /Applications/BarMan.app
```

Then open BarMan and grant **Accessibility** and **Screen Recording** in System Settings (see [Permissions](#permissions)).

For local development, see [script/README.md](script/README.md).

## Permissions

BarMan needs **Accessibility** and **Screen Recording** (System Settings → Privacy & Security). Grant them once: every release is signed with the same certificate, so updates keep them.

If you are updating from a release older than the switch to the stable certificate, grant them one last time. If a toggle shows on but BarMan still asks, run `./script/fix-permissions.sh`, or remove BarMan from both lists and add it again.

## Uninstall

**Homebrew:**

```bash
brew uninstall --cask skiduss/tap/barman
```


```bash
brew uninstall --cask --zap skiduss/tap/barman
```

**Manual:** quit BarMan, then drag `BarMan.app` out of `/Applications` to the Trash. To also remove preferences, delete `~/Library/Preferences/com.skidus.barman.plist`.


## Gallery

**Always-Hidden section demo — hide menu bar icons and reveal on hover**

![Demo of BarMan always-hidden menu bar section on macOS](Resources/vid/demo-ah.gif)

**Show and hide menu bar icons demo**

![Demo showing and hiding Mac menu bar icons with BarMan](Resources/vid/demo.gif)

**Fullscreen settings**

![BarMan fullscreen settings window on macOS](Resources/Image/fullscreen.png)


| BarMan Pill — second menu bar for notched MacBooks                                                   | Drag-and-drop menu bar layout                                                                   |
| ------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| ![BarMan Pill second menu bar for MacBook notch](https://github.com/user-attachments/assets/f1429589-6186-4e1b-8aef-592219d49b9b) | ![Drag and drop menu bar layout editor](./Resources/Image/MenuBarLayout.png) |

| Menu bar appearance and theme settings                                                                  | Menu bar item spacing                                                                                       |
| ------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| ![Menu bar appearance theme settings](./Resources/Image/MenuBarAppearance.png) | ![Menu bar icon spacing settings](https://github.com/user-attachments/assets/b196aa7e-184a-4d4c-b040-502f4aae40a6) |


> ✅ **macOS 27 fully supported** — works on macOS 14 Sonoma and later, including Sequoia, Tahoe, and macOS 27. If you need a similar tool for macOS 13 Ventura or earlier, check out [Ice 0.11.x](https://github.com/jordanbaird/Ice/releases).


## Contributing

Contributions are welcome! Please read the [contribution guidelines](./Resources/document/CONTRIBUTING.md) before submitting a pull request.

## Contributors

Thanks to everyone who has contributed to this fork:

<a href="https://github.com/skiduss"><img src="https://github.com/skiduss.png?size=64" width="64" height="64" alt="skiduss" title="skiduss" style="border-radius:50%"></a>
<a href="https://github.com/pythongod"><img src="https://github.com/pythongod.png?size=64" width="64" height="64" alt="pythongod" title="pythongod" style="border-radius:50%"></a>
<a href="https://github.com/WuColin-1"><img src="https://github.com/WuColin-1.png?size=64" width="64" height="64" alt="WuColin-1" title="WuColin-1" style="border-radius:50%"></a>

## Support

</a>

<a href="https://www.paypal.com/paypalme/nnkhanh29" target="_blank">
    <img src="https://www.paypalobjects.com/webstatic/en_US/i/buttons/PP_logo_h_200x51.png" alt="Donate with PayPal" style="height: 36px !important;">
</a>

## Acknowledgments

A fork of [Ice](https://github.com/jordanbaird/Ice) by [Jordan Baird](https://github.com/jordanbaird) — huge thanks for the original work this project builds on.

## License

[GPL-3.0](LICENSE) — BarMan is and will always remain open-source and free.

## Star History

<a href="https://star-history.com/#skiduss/barman&Date">
    <img src="https://api.star-history.com/svg?repos=skiduss/barman&type=Date" alt="Star History Chart" width="500">
</a>
