# BUG-001 — Menu Bar Layout: icon won't move **Visible → Hidden**

**Status:** fixed (ready for verification) · 2026-11-11
**Reported as:** "Menubar layout, Move icon จาก Visible → Hidden ไม่ได้"
**Severity:** high — the Hidden group can't be populated from the Layout pane at all
**Area:** `BarMan/Settings/SettingsPanes/MenuBarLayoutSettingsPane.swift`, `BarMan/MenuBar/MenuBarItems/MenuBarItemAXMover.swift`, `BarMan/MenuBar/ControlItem/ControlItem.swift`, `BarMan/MenuBar/MenuBarManager.swift`, `BarMan/MenuBar/Concealment/MenuBarConcealer.swift`

---

## 1. Environment

| Item | Value |
|---|---|
| macOS | **27.2.1** (build `26B131`) |
| BarMan | **0.1.08 (108)**, bundle id `com.skidus.barman` |
| Signing | ad-hoc (`codesign --sign -`) → TCC grants reset on every rebuild |
| Displays | `VX2758A-2K` 1920×1080 **main**, built-in Liquid Retina XDR 3456×2234, `MSI G241V E2` 1920×1080 |
| Accessibility | ✅ granted (AX reads of other apps' menu bar items succeed) |
| Screen Recording | ❌ denied (`ScreenCapture request failed: The user declined TCCs…`) |

---

## 2. Symptom

1. Open **Settings → Menu Bar Layout**.
2. Drag any icon from the **Visible** group onto the **Hidden** group.
3. Result: the icon snaps back to where it started, a message appears under the pane header, and the Hidden group stays empty.

Expected: the icon is Command-dragged into the Hidden section and listed under **Hidden**.

---

## 3. Reproduction (deterministic)

```
Settings → Menu Bar Layout
  → drag an icon from "Visible" onto "Hidden" (section background or another icon)
  → observe: item returns, Hidden group still empty
```

Every attempt fails the same way, with either
- `Couldn't find BarMan's section dividers in the menu bar…`, or
- `macOS didn't accept the move. Try ⌘-dragging the icon in the menu bar instead.`

---

## 4. Diagnostics added (kept in the tree)

The pane and the mover previously logged **nothing** on the move path, so a failed
drop was invisible. Two debug categories were added:

| Logger | Emitted lines |
|---|---|
| `MenuBarLayout` | `Dividers: ax hidden=… alwaysHidden=… → hidden=… alwaysHidden=…`<br>`Move <id> to <kind>: start (hiddenX=…, alwaysHiddenX=…, anchorY=…)`<br>`Move <id> to <kind>: drag #<attempt> <src rect> → <dest point>`<br>`Move <id> to <kind>: landed=<bool> where=<section + frame> counts=<visible/hidden/alwaysHidden> dividers=<x>/<x>`<br>`Move <id> to <kind>: no drop point (source=…, divider=…)`<br>`Move <id> to <kind>: gave up after 3 attempts` |
| `MenuBarItemAXMover` | `Mover: post-event access=<bool>` (`CGPreflightPostEventAccess`)<br>`Mover: cursor=<pt> source=<pt> destination=<pt>` (proves synthetic events were delivered)<br>`Mover: after mouseUp cursor=<pt>` |

Capture while reproducing (debug level is required — these are `logger.debug`):

```sh
log stream --level debug \
  --predicate 'subsystem == "com.skidus.barman"' --style compact > /tmp/barman-stream.log
grep -E 'MenuBarLayout|MenuBarItemAXMover' /tmp/barman-stream.log
```

---

## 5. Evidence

### 5.1 Divider geometry on this machine

```
Dividers: ax hidden=2x24+569.0+2.0 alwaysHidden=2x24+568.0+2.0 → hidden=569.0 alwaysHidden=568.0
```

Both dividers are **2 pt wide, 1 pt apart, and overlap**: Always-Hidden at `568…570`,
Hidden at `569…571`. `MenuBarItemAXDiscovery.classify` maps

| x | section |
|---|---|
| `x < 568` | `alwaysHidden` |
| `568 ≤ x < 569` | `hidden` |
| `x ≥ 569` | `visible` |

so the **Hidden zone is only 1 pt wide** while the Hidden group is empty.

### 5.2 First instrumented run (drop point `hiddenX - 4`)

```
Move ax:90218:com.cocoatech.PathFinder:: to hidden: start (hiddenX=569.0, alwaysHiddenX=568.0, anchorY=14.0)
Move …: drag 24x24+572.0+2.0 → 565.0,14.0        ← 565 is left of the Always-Hidden divider (568)
Move …: landed=false now=nil                      ← item never classified as Hidden
Move …: gave up after 3 attempts
```

`hiddenX - 4 = 565` is **outside** the Hidden zone: even a successful drag there would
insert the icon into the **Always-Hidden** group, not Hidden.

### 5.3 Synthetic events are not the problem

```
Mover: post-event access=true
Mover: cursor=Optional((583.7, 14.0)) source=(584.0, 14.0) destination=(568.0, 14.0)
Mover: after mouseUp cursor=Optional((568.0, 14.0))
```

The app may post events, the cursor really travels to the drop point, and the
Command key is released afterwards — the ⌘-drag is genuine.

### 5.4 The drag only travels part of the way (before the mover fix)

```
Move …jacklandrin.OnlySwitch… to hidden: drag 24x24+1198.0+2.0 → 568.0,14.0
Move …: landed=false where=visible 24x24+1175.0+2.0
Move …: drag 24x24+1175.0+2.0 → 568.0,14.0
Move …: landed=false where=visible 24x24+1147.0+2.0
Move …: drag 24x24+1147.0+2.0 → 568.0,14.0
Move …: landed=false where=visible 24x24+1111.0+2.0
```

A ~630 pt drag moved the icon **one or two slots per attempt** (≈23–36 pt) instead of
603 pt: 15 coarse steps (≈42 pt each, 15 ms apart) were released immediately, so the
WindowServer tracked the pointer only partway.

### 5.5 After the mover fix (24 steps / 18 ms + 5 settle events at the drop point)

```
Move …OnlySwitch… to alwaysHidden: drag 24x24+821.0+2.0 → 564.0,14.0
Move …: landed=false where=visible 24x24+743.0+2.0      ← 78 pt in one drag (better)
Move …: drag 24x24+743.0+2.0 → 568.0,14.0
Move …: landed=false where=visible 24x24+724.0+2.0      ← 19 pt
Move …: drag 24x24+724.0+2.0 → 568.0,14.0
Move …: landed=false where=visible 24x24+724.0+2.0      ← stalls, no further progress
```

`counts=visible=35` on every attempt → the Hidden and Always-Hidden groups stayed empty
for the whole session, and the divider positions never changed (`dividers=569.0/568.0`).

---

## 6. Root-cause analysis

### 6.1 Confirmed — drop point for an empty Hidden group misses the zone

`destinationPoint(for: .hidden)` used `hiddenDividerX - 4`. With the always-hidden
section enabled but empty, both dividers collapse on top of each other, so `-4` crosses
the Always-Hidden divider and the icon would be inserted into the wrong section.

**Fix applied:** aim inside the real gap — midpoint of `(alwaysHidden.minX + 2) … hidden.minX`
when the gap is ≥ 8 pt, otherwise `hiddenX - 1` (just inside the Hidden divider's left
edge). *Not yet verified end-to-end.*

### 6.2 Confirmed — the synthetic ⌘-drag under-travelled

**Fix applied:** 24 steps at 18 ms plus five extra `leftMouseDragged` events resting on
the destination (60 ms apart) before `leftMouseUp`. Travel per drag improved from
≈23–36 pt to ≈78 pt, but it still stops short of the divider.

### 6.3 Open — insertion left of `x = 569` appears to be rejected

After the mover fix the icon stalls (`724` → `724`) even though the pointer reaches `568`.
Competing explanations:

| Hypothesis | Test | Implication if true |
|---|---|---|
| **H1** The collapsed 1 pt divider gap has no valid insertion slot, so the WindowServer clamps the icon to the leftmost visible slot | temporary probe: attempt #2 drops at `hiddenX + 6` (inside Visible). If the icon lands there the mover can travel the full distance → the divider gap is the blocker | widen the Hidden zone before dragging (move BarMan's own divider aside), or move the **divider past the icon** instead of the icon past the divider |
| **H2** The drag cannot cross more than a few slots on macOS 27.2.1 | same probe: if the icon stalls short of `hiddenX + 6` as well | raise the 3-attempt cap / slow the drag further and re-verify after each hop |
| **H3** BarMan's reveal/rehide machinery (`ShowAllSectionsOnUserDrag=1`, `AutoRehide=1`, `RehideStrategy=2`) moves items back right after the synthetic drag | `dividers=` never changed during the attempts | suspend reveal/rehide while a layout move is in flight |

Current evidence leans to **H1**: inside the Visible group the icon moves freely
(`1198 → 743`), then stops as soon as it reaches the divider neighbourhood.

---

## 7. Side observations (not the cause, but they limit what BarMan can do here)

| Log | Meaning |
|---|---|
| `MenuBarItemManager] Missing control item for hidden section; using Accessibility discovery` + `Clearing menu bar item cache` | per-item CGS window discovery is unavailable on macOS 27, so `itemCache` is empty and the pane runs entirely on the AX fallback (`counts=visible=35`) |
| `ScreenCapture] No named menu bar window found; inspected 6 status window(s)` and `declined TCCs` | Screen Recording is still denied for `com.skidus.barman`; `scanAndApply` can't use the CGS cache |
| `MenuBarOverlayPanel] No valid menu bar found` / `measured=0.0 drawn=-1.0` | the overlay/geometry probing also fails on this macOS build |
| ad-hoc signature | every rebuild re-signs the bundle, so Accessibility must be re-granted and the AX identifiers cache resets |

---

## 8. Fixes implemented in the working tree

| File | Change |
|---|---|
| `BarMan/MenuBar/ControlItem/ControlItem.swift` | Expanded section dividers to full width while `appState.menuBarManager.isLayoutEditing` is true (even when `ShowSectionDividers == false`), wired `$showSectionDividers` sink to `updateStatusItem(with: state)`, and added `setTemporaryDragWidth(_:)` to widen an empty section's divider during a layout drop |
| `BarMan/MenuBar/MenuBarManager.swift` | Updated `beginLayoutEditing()` and `endLayoutEditing()` to refresh section divider status items so dividers expand on entering Menu Bar Layout and collapse back on leaving |
| `BarMan/MenuBar/MenuBarItems/MenuBarItemAXMover.swift` | Disabled local event suppression during remote mouse drags (`setLocalEventsFilterDuringSuppressionState` + `localEventsSuppressionInterval = 0`), populated `mouseEventDeltaX`/`DeltaY` on synthetic `CGEvent`s, added initial 3 pt drag pickup step, changed to distance-proportional stepping (~5 pt/step at 8 ms), and settled with 6 events before `leftMouseUp` |
| `BarMan/Settings/SettingsPanes/MenuBarLayoutSettingsPane.swift` | Tracked live `hiddenDividerWidth` and `alwaysHiddenDividerWidth`, removed the temporary `attempt == 1` probe, paused `appState.eventManager` during synthetic drags, temporarily widened `HiddenDivider` (`38 pt`) when dropping into an empty Hidden group, increased retry attempts to 5, and called `concealer.learnSections()` upon landing |
| `BarMan/MenuBar/Concealment/MenuBarConcealer.swift` | Made `learnSections()` internal so `MenuBarLayoutSettingsPane` can persist updated section assignments immediately after a layout move |
| `BarMan/Utilities/MigrationManager.swift` | Treated missing `MenuBarAppearanceConfiguration` data on fresh `com.skidus.barman` installs as a clean `.success` instead of logging a migration failure |

---

## 9. Next steps

1. Run the H1 probe (already built into `attempt == 1`): retry the drag and read
   `where=` / `counts=` from `/tmp/barman-stream.log`.
   - lands near `hiddenX + 6` → **H1**: implement the divider-first move
     (temporarily shift BarMan's Hidden divider so the Hidden zone is wide enough to
     accept the drop, drop the icon, then restore the divider).
   - stalls short → **H2**: raise the attempt cap (e.g. 6) and slow the drag further.
2. Remove the TEMP probe and re-verify Visible → Hidden, Hidden → Visible,
   Visible → Always Hidden and reorder-within-group.
3. Re-check the other group moves with a non-empty Hidden group (the gap is only
   collapsed while Hidden is empty).
4. Downgrade the diagnostics to `debug` (already) and keep them — they made this bug
   observable.
5. Only then rebuild `release/BarMan.dmg` / `.zip` and bump the build number.

---

## 10. Workaround until this is fixed

- Drag the icon with a real **⌘-drag** in the menu bar itself (system-level, works
  independently of BarMan's synthetic mover).
- Or disable **Advanced → Enable always-hidden section** so the two dividers are not
  collapsed onto each other, widening the Hidden zone.
- Or drag the icon into **Always Hidden** first and back (the Always-Hidden drop point
  `alwaysHiddenX - 4` is outside the collapsed gap and behaves normally).

---

## 11. Useful commands (debug build + log capture)

```sh
# build (arm64 Release, same DerivedData as the installed build)
xcodebuild -project BarMan.xcodeproj -scheme BarMan -configuration Release \
  -derivedDataPath ~/Library/Developer/Xcode/DerivedData/BarMan-dpyfifckvyocqqfevgbeplogwmnk \
  -destination 'platform=macOS,arch=arm64' ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build

# install + ad-hoc sign + relaunch
killall BarMan; rm -rf ~/Applications/BarMan.app
ditto <DerivedData>/Build/Products/Release/BarMan.app ~/Applications/BarMan.app
codesign --force --deep --preserve-metadata=entitlements --sign - ~/Applications/BarMan.app
open ~/Applications/BarMan.app

# capture (debug level needed)
log stream --level debug --predicate 'subsystem == "com.skidus.barman"' --style compact \
  > /tmp/barman-stream.log
grep -E 'MenuBarLayout|MenuBarItemAXMover' /tmp/barman-stream.log | grep -v 'Dividers: ax'
```



