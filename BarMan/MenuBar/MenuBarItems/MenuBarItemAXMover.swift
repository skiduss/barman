//
//  MenuBarItemAXMover.swift
//  BarMan
//

import Carbon.HIToolbox
import Cocoa
import os

/// Moves a menu bar item by simulating the user's Command-drag.
///
/// BarMan's old move pipeline needed a CGS window (windowID, ownerPID, frame change),
/// so it no longer works on macOS 27. This approach only needs the icon's
/// on-screen position plus Accessibility permission — exactly what the user
/// would do by hand, so the system still honors it.
///
/// Quartz coordinates (origin top-left, same system as `CGEvent.location`,
/// `WindowInfo.frame`, and `AXUIElement` frames) — do NOT use Cocoa coordinates
/// (origin bottom-left) here; mixing them up drops the item in the wrong spot
/// and a rescan then shows the old position (looking like it "snapped back").
enum MenuBarItemAXMover {
    /// Drags from `source` to `destination` while holding Command.
    ///
    /// Quartz coordinates (origin top-left). Runs in the background, takes well
    /// under a second. The cursor stays visible and is returned to its original
    /// spot; the Command key is always released (even if event creation fails
    /// midway).
    static func commandDrag(from source: CGPoint, to destination: CGPoint) async {
        await Task.detached(priority: .userInitiated) {
            // Created here (not captured) so the detached task stays free of
            // captured non-Sendable state.
            let logger = os.Logger(subsystem: Constants.bundleIdentifier, category: "MenuBarItemAXMover")
            logger.debug("Mover: post-event access=\(CGPreflightPostEventAccess(), privacy: .public)")

            guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
                logger.debug("Mover: no event source")
                return
            }

            let suppressionStates: [CGEventSuppressionState] = [
                .eventSuppressionStateRemoteMouseDrag,
                .eventSuppressionStateSuppressionInterval,
            ]
            let permittedMask: CGEventFilterMask = [
                .permitLocalMouseEvents,
                .permitLocalKeyboardEvents,
                .permitSystemDefinedEvents,
            ]
            for state in suppressionStates {
                eventSource.setLocalEventsFilterDuringSuppressionState(permittedMask, state: state)
            }
            eventSource.localEventsSuppressionInterval = 0
            if let sessionSource = CGEventSource(stateID: .combinedSessionState) {
                for state in suppressionStates {
                    sessionSource.setLocalEventsFilterDuringSuppressionState(permittedMask, state: state)
                }
                sessionSource.localEventsSuppressionInterval = 0
            }

            // Remember the old cursor position to restore after the drag. Don't hide
            // the cursor: a disappearing cursor makes users think the app hung.
            let originalLocation = CGEvent(source: nil)?.location
            defer {
                if let originalLocation {
                    CGWarpMouseCursorPosition(originalLocation)
                }
            }

            var lastPoint = source
            func post(_ type: CGEventType, at point: CGPoint, flags: CGEventFlags) {
                guard
                    let event = CGEvent(
                        mouseEventSource: eventSource,
                        mouseType: type,
                        mouseCursorPosition: point,
                        mouseButton: .left
                    )
                else {
                    return
                }
                let dx = Int64((point.x - lastPoint.x).rounded())
                let dy = Int64((point.y - lastPoint.y).rounded())
                event.setIntegerValueField(.mouseEventDeltaX, value: dx)
                event.setIntegerValueField(.mouseEventDeltaY, value: dy)
                event.flags = flags
                event.post(tap: .cghidEventTap)
                lastPoint = point
            }

            // A mouse event can't be a flagsChanged event (creating one returns
            // nil), so Command goes down and up as the real key.
            func postCommand(down: Bool) {
                guard
                    let event = CGEvent(
                        keyboardEventSource: eventSource,
                        virtualKey: CGKeyCode(kVK_Command),
                        keyDown: down
                    )
                else {
                    return
                }
                event.type = .flagsChanged
                event.flags = down ? .maskCommand : []
                event.post(tap: .cghidEventTap)
            }

            // Release Command on exit no matter what happens below.
            var didPressCommand = false
            defer {
                if didPressCommand {
                    postCommand(down: false)
                }
            }

            // Move the cursor onto the icon first so the system "sees" the start point.
            CGWarpMouseCursorPosition(source)
            post(.mouseMoved, at: source, flags: [])
            try? await Task.sleep(for: .milliseconds(80))
            logger.debug(
                "Mover: cursor=\(String(describing: CGEvent(source: nil)?.location), privacy: .public) source=\(String(describing: source), privacy: .public) destination=\(String(describing: destination), privacy: .public)"
            )

            // Hold Command, as the user would.
            postCommand(down: true)
            didPressCommand = true
            try? await Task.sleep(for: .milliseconds(60))

            post(.leftMouseDown, at: source, flags: .maskCommand)
            try? await Task.sleep(for: .milliseconds(100))

            let dxTotal = destination.x - source.x
            let dyTotal = destination.y - source.y
            let distance = hypot(dxTotal, dyTotal)

            // Initial small nudge so MenuBarAgent engages the status-item drag
            // session before the pointer travels across neighbouring slots.
            if distance > 4 {
                let signX: CGFloat = dxTotal >= 0 ? 1 : -1
                let pickupPoint = CGPoint(x: source.x + signX * 3, y: source.y)
                post(.leftMouseDragged, at: pickupPoint, flags: .maskCommand)
                try? await Task.sleep(for: .milliseconds(60))
            }

            // Distance-proportional steps (~5pt per hop): coarse jumps skip over
            // entire ~24pt icons in a single frame and cause MenuBarAgent to drop
            // the reorder partway through a long move.
            let steps = max(20, min(140, Int((distance / 5).rounded(.up))))
            for index in 1...steps {
                let progress = CGFloat(index) / CGFloat(steps)
                let point = CGPoint(
                    x: source.x + dxTotal * progress,
                    y: source.y + dyTotal * progress
                )
                post(.leftMouseDragged, at: point, flags: .maskCommand)
                try? await Task.sleep(for: .milliseconds(8))
            }

            // Rest on the drop point before releasing: the insertion is only
            // committed while the pointer sits in the target slot. Releasing
            // straight after the last step leaves the icon where it was
            // picked up, which looks like "the move did nothing".
            for _ in 0..<6 {
                post(.leftMouseDragged, at: destination, flags: .maskCommand)
                try? await Task.sleep(for: .milliseconds(45))
            }

            post(.leftMouseUp, at: destination, flags: .maskCommand)
            try? await Task.sleep(for: .milliseconds(150))
            logger.debug(
                "Mover: after mouseUp cursor=\(String(describing: CGEvent(source: nil)?.location), privacy: .public)"
            )

            // Release Command and wait for the system to commit the new position
            // before restoring the cursor.
            postCommand(down: false)
            didPressCommand = false
            try? await Task.sleep(for: .milliseconds(250))
        }.value
    }
}
