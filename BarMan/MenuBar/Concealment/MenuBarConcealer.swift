//
//  MenuBarConcealer.swift
//  BarMan
//
//  The assessment-mode assertion and the click bridge are adapted from
//  BarMan PR #995 and HiBar (https://github.com/3dot141/HiBar), which adapted
//  them from Barometer (https://github.com/mackid1993/Barometer) and Thaw's
//  PlatformRuntimeKit (https://github.com/thaw-app/Thaw). All are licensed
//  under the GNU GPLv3, like BarMan.
//

import Cocoa
import Combine

// MARK: - MenuBarConcealer

/// Hides sections on macOS 27 while a display without a notch is attached.
///
/// BarMan's spacer only hides on a display that moves its own overflow out of
/// sight, which a notched laptop on its own does. With a display without a
/// notch attached it breaks down: the spacer fits there, or squeezes the
/// active app's menus instead of overflowing, and the display Accessibility
/// reports follows the user's focus, so the spacer can't be placed reliably
/// (issues #12, #17, #24). In that case whole applications are hidden through
/// MenuBarAgent's assessment mode instead, on every display at once.
///
/// Trade-offs, measured on macOS 27.2 (and on 27.0 in BarMan PR #995):
/// - Hiding works per application: an app is hidden when none of its items
///   sits in the visible section.
/// - While anything is hidden, the bar also drops the items of apps that are
///   not Developer ID-signed (BarMan itself when built ad-hoc) and a few system
///   items such as Focus and Control Center controls.
/// - MenuBarAgent ignores clicks on its own items (clock, Wi-Fi, battery…)
///   while anything is hidden. Such a click is held back, hiding is lifted
///   for a moment, and the click is replayed.
@MainActor
final class MenuBarConcealer {
    /// How much of the hidden content is revealed.
    private enum RevealState {
        case allHidden
        case hiddenRevealed
        case allRevealed
    }

    /// Defaults key of the learned section of each application.
    private static let sectionsKey = "MacOS27AppSections"

    /// Defaults key that forces a backend: "spacer" or "assessment".
    private static let modeOverrideKey = "MacOS27HidingMode"

    /// Applications that are never hidden: BarMan itself (so it can always bring
    /// the others back) and the processes behind the system items.
    private static let neverHidden: Set<String> = [
        Bundle.main.bundleIdentifier ?? "com.skidus.barman",
        "com.apple.MenuBarAgent",
        "com.apple.controlcenter",
        "com.apple.systemuiserver",
        "com.apple.notificationcenterui",
        "com.apple.Spotlight",
    ]

    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    /// The live assertion and the applications it hides.
    private var live: (token: AnyObject, concealed: Set<String>, allowed: [String])?

    /// The update that is running; updates run one after another.
    private var applyTask: Task<Void, Never>?

    /// Counts updates, so one overtaken by a later one is skipped.
    private var updateGeneration = 0

    /// Fallback floating BarMan icon used when MenuBarAgent drops non-Developer-ID status items.
    private let fallbackIconOverlay = ConcealedBarManIconOverlay()

    /// Whether the last update ran with this backend in use.
    private var wasInUse = false

    /// Whether anything is hidden right now.
    var isConcealing: Bool {
        live != nil
    }

    /// Bundle identifiers of the applications hidden right now.
    ///
    /// Their items leave the bar but keep reporting their old frames through
    /// Accessibility (measured on macOS 27.2), so anything that measures the
    /// bar from the items' frames must skip them.
    var concealedBundleIDs: Set<String> {
        live?.concealed ?? []
    }

    /// Whether sections are hidden by the concealer rather than by spacers.
    static var isInUse: Bool {
        guard #available(macOS 27, *), AssessmentAssertion.isAvailable else {
            return false
        }
        switch UserDefaults.standard.string(forKey: modeOverrideKey) {
        case "spacer": return false
        case "assessment": return true
        default: return NSScreen.screens.contains { !$0.hasNotch }
        }
    }

    // MARK: Setup

    /// Starts following the sections' states.
    func performSetup(with appState: AppState) {
        self.appState = appState
        fallbackIconOverlay.performSetup(with: appState)
        guard #available(macOS 27, *), AssessmentAssertion.isAvailable else {
            return
        }
        var c = Set<AnyCancellable>()

        let manager = appState.menuBarManager
        let states = manager.sections
            .filter { $0.name != .visible }
            .map { $0.controlItem.$state.mapToVoid().eraseToAnyPublisher() }
        let visibility = manager.sections
            .filter { $0.name == .alwaysHidden }
            .map { $0.controlItem.$isVisible.mapToVoid().eraseToAnyPublisher() }
        // `@Published` sinks run before the new value is stored; update on the
        // next pass so the new state is read.
        Publishers.MergeMany(states + visibility)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.update()
            }
            .store(in: &c)

        // An assertion allows the applications running when it was made, so
        // one launched later would be hidden until the next update. Agents
        // (most menu bar apps) never post the launch notification, hence the
        // running applications themselves are observed.
        NSWorkspace.shared.publisher(for: \.runningApplications)
            .map { Set($0.compactMap(\.bundleIdentifier)) }
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.update()
            }
            .store(in: &c)

        // Attaching or removing a display switches between this backend and
        // the spacers. The dividers collapse first; wait for the bar to
        // settle so the sections can be read from it.
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(600), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.update()
            }
            .store(in: &c)

        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.releaseAll()
            }
            .store(in: &c)

        cancellables = c

        // Status items take a moment to be laid out after launch.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.update()
        }
    }

    // MARK: Update

    /// Hides what the sections' states call for.
    func update() {
        guard #available(macOS 27, *) else {
            return
        }
        updateGeneration += 1
        let generation = updateGeneration
        let previous = applyTask
        applyTask = Task { [weak self] in
            await previous?.value
            guard let self, generation == updateGeneration else {
                return
            }
            await apply()
        }
    }

    @available(macOS 27, *)
    private func apply() async {
        guard let appState, Self.isInUse else {
            if wasInUse {
                wasInUse = false
                releaseAll()
                Logger.concealer.info("Switched to spacer hiding")
            }
            return
        }
        if !wasInUse {
            wasInUse = true
            Logger.concealer.info("Switched to assessment-mode hiding")
        }
        let state = revealState(appState)
        // Nothing hidden means every item and BarMan's dividers are drawn: the
        // one moment the sections can be read from the bar.
        if live == nil, state != .allRevealed {
            await learnSections()
        }
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let concealed = concealedApps(for: state, alwaysHiddenEnabled: isAlwaysHiddenEnabled(appState))
            .intersection(running)
        guard !concealed.isEmpty else {
            releaseAll()
            return
        }
        let needed = running.subtracting(concealed)
        // Every change makes MenuBarAgent lay the bar out again. An app that
        // quit can stay allowed, so only a newly launched one needs a change.
        if let live, live.concealed == concealed, needed.isSubset(of: live.allowed) {
            return
        }
        let allowed = needed.sorted()
        do {
            // The new assertion goes live before the old one is released, so
            // an app hidden on both sides of the change never flickers.
            let token = try await AssessmentAssertion.activate(allowedBundleIDs: allowed)
            if let old = live {
                AssessmentAssertion.invalidate(old.token)
            }
            live = (token, concealed, allowed)
            fallbackIconOverlay.update(isConcealing: true, concealedBundleIDs: concealed)
            Logger.concealer.info("Hiding \(concealed.sorted())")
        } catch {
            Logger.concealer.error("Couldn't hide menu bar items: \(error)")
        }
    }

    /// Releases the live assertion, which brings every item back.
    private func releaseAll() {
        fallbackIconOverlay.update(isConcealing: false, concealedBundleIDs: [])
        guard let old = live else {
            return
        }
        live = nil
        if #available(macOS 27, *) {
            AssessmentAssertion.invalidate(old.token)
        }
    }

    // MARK: Sections

    private func revealState(_ appState: AppState) -> RevealState {
        let manager = appState.menuBarManager
        if
            let alwaysHidden = manager.section(withName: .alwaysHidden),
            alwaysHidden.isEnabled,
            alwaysHidden.controlItem.state == .showItems
        {
            return .allRevealed
        }
        if manager.section(withName: .hidden)?.controlItem.state == .showItems {
            return .hiddenRevealed
        }
        return .allHidden
    }

    private func isAlwaysHiddenEnabled(_ appState: AppState) -> Bool {
        appState.menuBarManager.section(withName: .alwaysHidden)?.isEnabled == true
    }

    /// The learned section of each application: 1 hidden, 2 always hidden.
    /// Applications missing from it are visible.
    private var savedSections: [String: Int] {
        get {
            UserDefaults.standard.dictionary(forKey: Self.sectionsKey) as? [String: Int] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.sectionsKey)
        }
    }

    /// The applications to hide in the given state.
    private func concealedApps(for state: RevealState, alwaysHiddenEnabled: Bool) -> Set<String> {
        let minimum: Int
        switch state {
        case .allHidden: minimum = 1
        // Without the always-hidden section its apps count as hidden.
        case .hiddenRevealed: minimum = alwaysHiddenEnabled ? 2 : 3
        case .allRevealed: minimum = 3
        }
        return Set(savedSections.filter { $0.value >= minimum }.keys).subtracting(Self.neverHidden)
    }

    /// Reads each application's section from where its items sit relative to
    /// BarMan's dividers, the way the spacers draw the sections.
    ///
    /// Only items drawn on the same display as the hidden divider count, so
    /// an item in overflow (no frame) keeps its last learned section. An app
    /// with items in several sections takes the most visible one, so nothing
    /// meant to stay visible is hidden with it.
    func learnSections() async {
        guard let appState else {
            return
        }
        let apps = NSWorkspace.shared.runningApplications
        let alwaysHiddenEnabled = isAlwaysHiddenEnabled(appState)
        let (frames, items) = await Task.detached(priority: .userInitiated) {
            (MenuBarItemAXDiscovery.ownElementFrames(), MenuBarItemAXDiscovery.discoverItems(in: apps))
        }.value
        guard
            let hidden = frames["BarManHiddenDivider"],
            let display = Self.menuBarDisplay(containing: hidden)
        else {
            return
        }
        let alwaysHidden = alwaysHiddenEnabled
            ? frames["BarManAlwaysHiddenDivider"].flatMap { Self.menuBarDisplay(containing: $0) == display ? $0 : nil }
            : nil
        var learned = [String: Int]()
        for item in items {
            guard
                let bundleID = item.bundleID,
                !Self.neverHidden.contains(bundleID),
                let frame = item.axFrame,
                frame.width > 0,
                Self.menuBarDisplay(containing: frame) == display
            else {
                continue
            }
            let section = if let alwaysHidden, frame.midX < alwaysHidden.midX {
                2
            } else if frame.midX < hidden.midX {
                1
            } else {
                0
            }
            learned[bundleID] = min(learned[bundleID] ?? section, section)
        }
        guard !learned.isEmpty else {
            return
        }
        var sections = savedSections
        for (bundleID, section) in learned {
            sections[bundleID] = section == 0 ? nil : section
        }
        if sections != savedSections {
            savedSections = sections
            Logger.concealer.info("Learned sections: \(sections)")
        }
    }

    /// The display whose menu bar strip holds a frame (AX coordinates).
    private static func menuBarDisplay(containing frame: CGRect) -> CGDirectDisplayID? {
        guard frame.minX.isFinite, frame.minY.isFinite, frame.width.isFinite else {
            return nil
        }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.lazy.map(\.displayID).first { displayID in
            let bounds = CGDisplayBounds(displayID)
            return bounds.contains(center) && center.y < bounds.minY + 40
        }
    }
}

// MARK: - AssessmentAssertion

/// MenuBarAgent's assessment mode (private `MenuBarClientCore`).
///
/// A configuration lists the numbered system items and the bundle identifiers
/// that stay on the bar. While an assertion is live, every other app's items
/// leave the bar on every display. It must be held by an app bundle: from a
/// command line tool the call succeeds and hides nothing. Ad-hoc signing is
/// enough (measured on macOS 27.2).
@available(macOS 27, *)
@MainActor
private enum AssessmentAssertion {
    enum Failure: Error, CustomStringConvertible {
        case unavailable
        case rejected(String)
        case timedOut

        var description: String {
            switch self {
            case .unavailable: "MenuBarClientCore is unavailable"
            case .rejected(let reason): "MenuBarAgent rejected the assertion: \(reason)"
            case .timedOut: "MenuBarAgent did not answer within 3 seconds"
            }
        }
    }

    /// Guards a continuation shared by a completion handler and a timeout.
    private final class OneShot: @unchecked Sendable {
        private let lock = NSLock()
        private var claimed = false

        func claim() -> Bool {
            lock.lock()
            defer {
                claimed = true
                lock.unlock()
            }
            return !claimed
        }
    }

    private static let frameworkPath = "/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore"
    private static let configureSelector = NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:")
    private static let activateSelector = NSSelectorFromString("activateWithConfiguration:completionHandler:")
    private static let invalidateSelector = NSSelectorFromString("invalidate")

    /// MenuBarAgent numbers its system items from 0 (0 through 8 on macOS
    /// 27.0); numbers with no item behind them are ignored, so later ones
    /// are allowed too.
    private static let systemItems = (0...63).map { NSNumber(value: $0) } as NSArray

    private static let classes: (configuration: AnyClass, assertion: AnyClass)? = {
        guard
            dlopen(frameworkPath, RTLD_NOW) != nil,
            let configuration = NSClassFromString("MBAssessmentModeConfiguration"),
            let assertion = NSClassFromString("MBAssessmentModeAssertion"),
            configuration.instancesRespond(to: configureSelector),
            assertion.instancesRespond(to: activateSelector),
            assertion.instancesRespond(to: invalidateSelector)
        else {
            return nil
        }
        return (configuration, assertion)
    }()

    /// Whether this macOS build offers the assertion.
    static var isAvailable: Bool {
        classes != nil
    }

    /// Activates an assertion that keeps only the given apps' items.
    static func activate(allowedBundleIDs: [String]) async throws -> AnyObject {
        guard
            let classes,
            let configuration = (classes.configuration.alloc() as AnyObject)
                .perform(configureSelector, with: systemItems, with: allowedBundleIDs as NSArray)?
                .takeUnretainedValue(),
            let assertion = (classes.assertion.alloc() as AnyObject)
                .perform(NSSelectorFromString("init"))?
                .takeUnretainedValue()
        else {
            throw Failure.unavailable
        }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let oneShot = OneShot()
                let completion: @convention(block) (Any?) -> Void = { error in
                    guard oneShot.claim() else {
                        return
                    }
                    if let error {
                        continuation.resume(throwing: Failure.rejected(String(describing: error)))
                    } else {
                        continuation.resume()
                    }
                }
                _ = assertion.perform(activateSelector, with: configuration, with: completion)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    guard oneShot.claim() else {
                        return
                    }
                    continuation.resume(throwing: Failure.timedOut)
                }
            }
        } catch {
            _ = assertion.perform(invalidateSelector)
            throw error
        }
        return assertion
    }

    /// Releases an assertion.
    static func invalidate(_ assertion: AnyObject) {
        _ = assertion.perform(invalidateSelector)
    }
}

// MARK: - Logger

private extension Logger {
    static let concealer = Logger(category: "Concealer")
}
