//
//  ConcealedBarManIconPanel.swift
//  BarMan
//

import Cocoa
import Combine
import Security

/// Displays a lightweight clickable BarMan icon overlay in the menu bar while
/// ``MenuBarConcealer`` is actively concealing items on non-Developer-ID builds.
///
/// On macOS 27 when an external display without a notch is attached, `MenuBarAgent`
/// drops status items belonging to non-Developer-ID apps (including BarMan itself
/// during ad-hoc/local builds) while an assessment assertion is active. This overlay
/// keeps the BarMan icon visible and interactive so the user can still click it
/// to reveal or configure menu bar sections.
@MainActor
final class ConcealedBarManIconOverlay {
    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()
    private var panels = [CGDirectDisplayID: ConcealedBarManIconPanel]()
    private var positionTask: Task<Void, Never>?
    private var lastIsConcealing = false
    private var lastConcealedBundleIDs = Set<String>()

    private static let iconWidth: CGFloat = 28

    /// Returns `true` when the running bundle is ad-hoc signed, unsigned, or not
    /// signed with an Apple Developer ID Application certificate (meaning
    /// `MenuBarAgent` hides BarMan's native `NSStatusItem` during concealment).
    static let needsFallbackIcon: Bool = {
        var code: SecCode?
        guard SecCodeCopySelf(SecCSFlags(), &code) == errSecSuccess, let code else {
            return true
        }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, SecCSFlags(), &staticCode) == errSecSuccess, let staticCode else {
            return true
        }
        var rawInfo: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &rawInfo
        ) == errSecSuccess, let info = rawInfo as? [String: Any] else {
            return true
        }
        let flags = info[kSecCodeInfoFlags as String] as? UInt32 ?? 0
        if (flags & SecCodeSignatureFlags.adhoc.rawValue) != 0 {
            return true
        }
        guard
            let team = info[kSecCodeInfoTeamIdentifier as String] as? String,
            !team.isEmpty
        else {
            return true
        }
        let certificates = info[kSecCodeInfoCertificates as String] as? [SecCertificate] ?? []
        let hasDeveloperID = certificates.contains { cert in
            (SecCertificateCopySubjectSummary(cert) as String?)?.hasPrefix("Developer ID Application") == true
        }
        return !hasDeveloperID
    }()

    /// Configures observers so the overlay stays synchronized with user preferences
    /// and display changes.
    func performSetup(with appState: AppState) {
        self.appState = appState
        var c = Set<AnyCancellable>()

        let general = appState.settingsManager.generalSettingsManager
        let refresh: () -> Void = { [weak self] in
            guard let self else {
                return
            }
            update(isConcealing: lastIsConcealing, concealedBundleIDs: lastConcealedBundleIDs)
        }

        Publishers.MergeMany([
            general.$showBarManIcon.mapToVoid().eraseToAnyPublisher(),
            general.$barManIcon.mapToVoid().eraseToAnyPublisher(),
            general.$reverseBarManIcon.mapToVoid().eraseToAnyPublisher(),
            general.$customBarManIconIsTemplate.mapToVoid().eraseToAnyPublisher(),
            appState.menuBarManager.$isMenuBarHiddenBySystem.mapToVoid().eraseToAnyPublisher(),
        ])
        .receive(on: DispatchQueue.main)
        .sink { _ in
            refresh()
        }
        .store(in: &c)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                refresh()
            }
            .store(in: &c)

        cancellables = c
    }

    /// Shows or hides the fallback BarMan icon across screens based on the active
    /// concealment state.
    func update(isConcealing: Bool, concealedBundleIDs: Set<String>) {
        lastIsConcealing = isConcealing
        lastConcealedBundleIDs = concealedBundleIDs

        guard
            Self.needsFallbackIcon,
            isConcealing,
            let appState,
            appState.settingsManager.generalSettingsManager.showBarManIcon,
            !appState.menuBarManager.isMenuBarHiddenBySystem
        else {
            positionTask?.cancel()
            positionTask = nil
            for panel in panels.values {
                panel.orderOut(nil)
            }
            return
        }

        let visibleControlItem = appState.menuBarManager.section(withName: .visible)?.controlItem
        let image = visibleControlItem?.barManIconImage()
        let activeScreens = screensWithMenuBar()
        let activeDisplayIDs = Set(activeScreens.map(\.displayID))

        for screen in activeScreens {
            let displayID = screen.displayID
            let panel = panels[displayID] ?? {
                let created = ConcealedBarManIconPanel()
                panels[displayID] = created
                return created
            }()

            let frame = initialPanelFrame(for: screen)
            panel.setFrame(frame, display: true)
            panel.updateContent(image: image, controlItem: visibleControlItem)
            panel.orderFrontRegardless()
        }

        for displayID in Array(panels.keys) where !activeDisplayIDs.contains(displayID) {
            panels[displayID]?.orderOut(nil)
            panels.removeValue(forKey: displayID)
        }

        positionTask?.cancel()
        positionTask = Task { [weak self] in
            // Allow MenuBarAgent a brief moment to finish laying out the concealed bar.
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else {
                return
            }
            await self?.refinePositions(concealedBundleIDs: concealedBundleIDs)
        }
    }

    private func screensWithMenuBar() -> [NSScreen] {
        if NSScreen.screensHaveSeparateSpaces {
            return NSScreen.screens
        }
        return NSScreen.screens.first.map { [$0] } ?? []
    }

    private func initialPanelFrame(for screen: NSScreen) -> CGRect {
        let menuBarDelta = screen.frame.maxY - screen.visibleFrame.maxY
        let barHeight = menuBarDelta > 0 ? max(24, menuBarDelta) : 28
        let trailingWidth = MenuBarOverlayPanelContentView.currentTrailingVisibleWidth(for: screen.displayID)
        let rawX: CGFloat = if let trailingWidth, trailingWidth > 0 {
            screen.frame.maxX - trailingWidth - Self.iconWidth - 6
        } else {
            screen.frame.maxX - 300 - Self.iconWidth
        }
        let clampedX = clampX(rawX, on: screen)
        return CGRect(
            x: clampedX,
            y: screen.frame.maxY - barHeight,
            width: Self.iconWidth,
            height: barHeight
        )
    }

    private func clampX(_ rawX: CGFloat, on screen: NSScreen) -> CGFloat {
        let minAllowedX = screen.auxiliaryTopRightArea?.minX.advanced(by: 4) ?? (screen.frame.minX + 260)
        let maxAllowedX = screen.frame.maxX - Self.iconWidth - 4
        guard minAllowedX <= maxAllowedX else {
            return maxAllowedX
        }
        return min(max(rawX, minAllowedX), maxAllowedX)
    }

    private func refinePositions(concealedBundleIDs: Set<String>) async {
        guard MenuBarItemAXDiscovery.isTrusted() else {
            return
        }
        let ownBundleID = Bundle.main.bundleIdentifier
        let visiblePIDs = NSWorkspace.shared.runningApplications.compactMap { app -> pid_t? in
            guard
                let bundleID = app.bundleIdentifier,
                bundleID != ownBundleID,
                !concealedBundleIDs.contains(bundleID)
            else {
                return nil
            }
            return app.processIdentifier
        }

        let itemFrames = await Task.detached(priority: .userInitiated) {
            MenuBarItemAXDiscovery.itemFrames(ofProcesses: visiblePIDs)
        }.value

        guard !Task.isCancelled, lastIsConcealing else {
            return
        }

        for screen in screensWithMenuBar() {
            let displayID = screen.displayID
            guard let panel = panels[displayID] else {
                continue
            }
            let bounds = CGDisplayBounds(displayID)
            let leftmostMinX = itemFrames
                .lazy
                .filter { _, frame in
                    let center = CGPoint(x: frame.midX, y: frame.midY)
                    return frame.width > 0
                        && bounds.contains(center)
                        && center.y < bounds.minY + 45
                }
                .map(\.frame.minX)
                .min()

            guard let leftmostMinX else {
                continue
            }
            let refinedX = clampX(leftmostMinX - Self.iconWidth - 6, on: screen)
            var frame = panel.frame
            if abs(frame.origin.x - refinedX) >= 1 {
                frame.origin.x = refinedX
                panel.setFrame(frame, display: true)
            }
        }
    }
}

// MARK: - ConcealedBarManIconPanel

@MainActor
private final class ConcealedBarManIconPanel: NSPanel {
    private let iconView = ConcealedBarManIconView()

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        contentView = iconView
    }

    func updateContent(image: NSImage?, controlItem: ControlItem?) {
        iconView.update(image: image, controlItem: controlItem)
    }
}

// MARK: - ConcealedBarManIconView

@MainActor
private final class ConcealedBarManIconView: NSView {
    private let imageView = NSImageView()
    private weak var controlItem: ControlItem?
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isPressed = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        imageView.imageAlignment = .alignCenter
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -4),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, constant: -4),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        return bounds.contains(localPoint) ? self : nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if isPressed || isHovered {
            let pillRect = bounds.insetBy(dx: 2, dy: 3)
            let alpha: CGFloat = isPressed ? 0.22 : 0.14
            NSColor.labelColor.withAlphaComponent(alpha).setFill()
            NSBezierPath(roundedRect: pillRect, xRadius: 5, yRadius: 5).fill()
        } else {
            // Paint a nearly invisible alpha so WindowServer consistently delivers
            // mouse events across the entire button bounds instead of passing through.
            NSColor.black.withAlphaComponent(0.004).setFill()
            bounds.fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
        if event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            let modifiers = event.modifierFlags.intersection([.option, .control, .shift, .command])
            controlItem?.triggerLeftClickAction(modifiers: modifiers)
        }
        isPressed = false
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isPressed = false
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
        showContextMenu()
        isPressed = false
        needsDisplay = true
    }

    func update(image: NSImage?, controlItem: ControlItem?) {
        self.controlItem = controlItem
        imageView.image = image
        imageView.contentTintColor = image?.isTemplate == true ? .labelColor : nil
        needsDisplay = true
    }

    private func showContextMenu() {
        guard let menu = controlItem?.createContextMenu() else {
            return
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: -4), in: self)
    }
}
