//
//  AppNavigationState.swift
//  BarMan
//

import Combine

/// The model for app-wide navigation.
@MainActor
final class AppNavigationState: ObservableObject {
    @Published var isAppFrontmost = false
    @Published var isSettingsPresented = false
    @Published var isBarManPillPresented = false
    @Published var settingsNavigationIdentifier: SettingsNavigationIdentifier = .general
}
