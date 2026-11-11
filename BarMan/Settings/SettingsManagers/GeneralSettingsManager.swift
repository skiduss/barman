//
//  GeneralSettingsManager.swift
//  BarMan
//

import Combine
import Foundation

@MainActor
final class GeneralSettingsManager: ObservableObject {
    /// A Boolean value that indicates whether the BarMan icon
    /// should be shown.
    @Published var showBarManIcon = true

    /// An icon to show in the menu bar, with a different image
    /// for when items are visible or hidden.
    @Published var barManIcon: ControlItemImageSet = .defaultBarManIcon

    /// A Boolean value that indicates whether the BarMan icon's
    /// hidden and visible images should be swapped, so the
    /// arrow points the opposite way when hidden.
    @Published var reverseBarManIcon = false

    /// The last user-selected custom BarMan icon.
    @Published var lastCustomBarManIcon: ControlItemImageSet?

    /// A Boolean value that indicates whether custom BarMan icons
    /// should be rendered as template images.
    @Published var customBarManIconIsTemplate = false

    /// A Boolean value that indicates whether to show hidden items
    /// in a separate bar below the menu bar.
    @Published var useBarManPill = false

    /// The location where the BarMan Pill appears.
    @Published var barManPillLocation: BarManPillLocation = .dynamic

    /// A Boolean value that indicates whether the hidden section
    /// should be shown when the mouse pointer clicks in an empty
    /// area of the menu bar.
    @Published var showOnClick = true

    /// A Boolean value that indicates whether the hidden section
    /// should be shown when the mouse pointer hovers over an
    /// empty area of the menu bar.
    @Published var showOnHover = false

    /// A Boolean value that indicates whether the hidden section
    /// should be shown or hidden when the user scrolls in the
    /// menu bar.
    @Published var showOnScroll = true

    /// The offset to apply to the menu bar item spacing and padding.
    @Published var itemSpacingOffset: Double = 0

    /// A Boolean value that indicates whether the hidden section
    /// should automatically rehide.
    @Published var autoRehide = true

    /// A strategy that determines how the auto-rehide feature works.
    @Published var rehideStrategy: RehideStrategy = .smart

    /// A time interval for the auto-rehide feature when its rule
    /// is ``RehideStrategy/timed``.
    @Published var rehideInterval: TimeInterval = 15

    /// Encoder for properties.
    private let encoder = JSONEncoder()

    /// Decoder for properties.
    private let decoder = JSONDecoder()

    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()

    /// The shared app state.
    private(set) weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    func performSetup() {
        loadInitialState()
        configureCancellables()
        // The $itemSpacingOffset sink only fires on change, and loading runs
        // before it subscribes — sync once so spacingManager never starts at
        // a stale 0 while a stored offset exists.
        appState?.spacingManager.offset = Int(itemSpacingOffset)
    }

    private func loadInitialState() {
        Defaults.ifPresent(key: .showBarManIcon, assign: &showBarManIcon)
        Defaults.ifPresent(key: .reverseBarManIcon, assign: &reverseBarManIcon)
        Defaults.ifPresent(key: .customBarManIconIsTemplate, assign: &customBarManIconIsTemplate)
        Defaults.ifPresent(key: .useBarManPill, assign: &useBarManPill)
        Defaults.ifPresent(key: .showOnClick, assign: &showOnClick)
        Defaults.ifPresent(key: .showOnHover, assign: &showOnHover)
        Defaults.ifPresent(key: .showOnScroll, assign: &showOnScroll)
        Defaults.ifPresent(key: .itemSpacingOffset, assign: &itemSpacingOffset)
        Defaults.ifPresent(key: .autoRehide, assign: &autoRehide)
        Defaults.ifPresent(key: .rehideInterval, assign: &rehideInterval)

        Defaults.ifPresent(key: .barManPillLocation) { rawValue in
            if let location = BarManPillLocation(rawValue: rawValue) {
                barManPillLocation = location
            }
        }
        Defaults.ifPresent(key: .rehideStrategy) { rawValue in
            if let strategy = RehideStrategy(rawValue: rawValue) {
                rehideStrategy = strategy
            }
        }

        if let data = Defaults.data(forKey: .barManIcon) {
            do {
                barManIcon = try decoder.decode(ControlItemImageSet.self, from: data)
            } catch {
                Logger.generalSettingsManager.error("Error decoding BarMan icon: \(error)")
            }
            if case .custom = barManIcon.name {
                lastCustomBarManIcon = barManIcon
            }
        }
    }

    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        $showBarManIcon
            .receive(on: DispatchQueue.main)
            .sink { showBarManIcon in
                Defaults.set(showBarManIcon, forKey: .showBarManIcon)
            }
            .store(in: &c)

        $barManIcon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] barManIcon in
                guard let self else {
                    return
                }
                if case .custom = barManIcon.name {
                    lastCustomBarManIcon = barManIcon
                }
                do {
                    let data = try encoder.encode(barManIcon)
                    Defaults.set(data, forKey: .barManIcon)
                } catch {
                    Logger.generalSettingsManager.error("Error encoding BarMan icon: \(error)")
                }
            }
            .store(in: &c)

        $customBarManIconIsTemplate
            .receive(on: DispatchQueue.main)
            .sink { isTemplate in
                Defaults.set(isTemplate, forKey: .customBarManIconIsTemplate)
            }
            .store(in: &c)

        $reverseBarManIcon
            .receive(on: DispatchQueue.main)
            .sink { reverseBarManIcon in
                Defaults.set(reverseBarManIcon, forKey: .reverseBarManIcon)
            }
            .store(in: &c)

        $useBarManPill
            .receive(on: DispatchQueue.main)
            .sink { useBarManPill in
                Defaults.set(useBarManPill, forKey: .useBarManPill)
            }
            .store(in: &c)

        $barManPillLocation
            .receive(on: DispatchQueue.main)
            .sink { location in
                Defaults.set(location.rawValue, forKey: .barManPillLocation)
            }
            .store(in: &c)

        $showOnClick
            .receive(on: DispatchQueue.main)
            .sink { showOnClick in
                Defaults.set(showOnClick, forKey: .showOnClick)
            }
            .store(in: &c)

        $showOnHover
            .receive(on: DispatchQueue.main)
            .sink { showOnHover in
                Defaults.set(showOnHover, forKey: .showOnHover)
            }
            .store(in: &c)

        $showOnScroll
            .receive(on: DispatchQueue.main)
            .sink { showOnScroll in
                Defaults.set(showOnScroll, forKey: .showOnScroll)
            }
            .store(in: &c)

        $itemSpacingOffset
            .receive(on: DispatchQueue.main)
            .sink { [weak appState] offset in
                Defaults.set(offset, forKey: .itemSpacingOffset)
                appState?.spacingManager.offset = Int(offset)
            }
            .store(in: &c)

        $autoRehide
            .receive(on: DispatchQueue.main)
            .sink { autoRehide in
                Defaults.set(autoRehide, forKey: .autoRehide)
            }
            .store(in: &c)

        $rehideStrategy
            .receive(on: DispatchQueue.main)
            .sink { strategy in
                Defaults.set(strategy.rawValue, forKey: .rehideStrategy)
            }
            .store(in: &c)

        $rehideInterval
            .receive(on: DispatchQueue.main)
            .sink { interval in
                Defaults.set(interval, forKey: .rehideInterval)
            }
            .store(in: &c)

        cancellables = c
    }
}

// MARK: GeneralSettingsManager: BindingExposable
extension GeneralSettingsManager: BindingExposable { }

// MARK: - Logger
private extension Logger {
    static let generalSettingsManager = Logger(category: "GeneralSettingsManager")
}
