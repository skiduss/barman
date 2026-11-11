//
//  BarManPillColorManager.swift
//  BarMan
//

import Cocoa
import Combine

final class BarManPillColorManager: ObservableObject {
    @Published private(set) var colorInfo: MenuBarAverageColorInfo?

    private weak var barManPillPanel: BarManPillPanel?

    private var windowImage: CGImage?

    private var cancellables = Set<AnyCancellable>()

    init(barManPillPanel: BarManPillPanel) {
        self.barManPillPanel = barManPillPanel
        configureCancellables()
    }

    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        if let barManPillPanel {
            barManPillPanel.publisher(for: \.screen)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] screen in
                    guard
                        let self,
                        let screen,
                        screen == .main
                    else {
                        return
                    }
                    updateWindowImage(for: screen)
                }
                .store(in: &c)

            Publishers.CombineLatest(
                barManPillPanel.publisher(for: \.frame),
                barManPillPanel.publisher(for: \.isVisible)
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frame, isVisible in
                guard
                    let self,
                    let screen = barManPillPanel.screen,
                    isVisible,
                    screen == .main
                else {
                    return
                }
                updateColorInfo(with: frame, screen: screen)
            }
            .store(in: &c)

            Publishers.Merge4(
                NSWorkspace.shared.notificationCenter
                    .publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
                    .mapToVoid(),
                NotificationCenter.default
                    .publisher(for: NSApplication.didChangeScreenParametersNotification)
                    .mapToVoid(),
                DistributedNotificationCenter.default()
                    .publisher(for: DistributedNotificationCenter.interfaceThemeChangedNotification)
                    .mapToVoid(),
                Timer.publish(every: 5, on: .main, in: .default)
                    .autoconnect()
                    .mapToVoid()
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak barManPillPanel] in
                guard
                    let self,
                    let barManPillPanel,
                    let screen = barManPillPanel.screen,
                    screen == .main
                else {
                    return
                }
                updateWindowImage(for: screen)
                if barManPillPanel.isVisible {
                    updateColorInfo(with: barManPillPanel.frame, screen: screen)
                }
            }
            .store(in: &c)
        }

        cancellables = c
    }

    private func updateWindowImage(for screen: NSScreen) {
        let displayID = screen.displayID
        if
            let window = WindowInfo.getMenuBarWindow(for: displayID),
            let image = ScreenCapture.captureWindow(window.windowID, option: .nominalResolution)
        {
            windowImage = image
        } else {
            windowImage = nil
        }
    }

    private func updateColorInfo(with frame: CGRect, screen: NSScreen) {
        guard let windowImage else {
            colorInfo = nil
            return
        }

        let imageBounds = CGRect(x: 0, y: 0, width: windowImage.width, height: windowImage.height)
        let insetScreenFrame = screen.frame.insetBy(dx: frame.width / 2, dy: 0)
        let percentage = ((frame.midX - insetScreenFrame.minX) / insetScreenFrame.width).clamped(to: 0...1)
        let cropRect = CGRect(x: imageBounds.width * percentage, y: 0, width: 0, height: 1)
            .insetBy(dx: -50, dy: 0)
            .intersection(imageBounds)

        guard
            let croppedImage = windowImage.cropping(to: cropRect),
            let averageColor = croppedImage.averageColor()
        else {
            colorInfo = nil
            return
        }

        colorInfo = MenuBarAverageColorInfo(color: averageColor, source: .menuBarWindow)
    }

    func updateAllProperties(with frame: CGRect, screen: NSScreen) {
        updateWindowImage(for: screen)
        updateColorInfo(with: frame, screen: screen)
    }
}
