//
//  BarManPillLocation.swift
//  BarMan
//

import SwiftUI

/// Locations where the BarMan Pill can appear.
enum BarManPillLocation: Int, CaseIterable, Identifiable {
    /// The BarMan Pill will appear in different locations based on context.
    case dynamic = 0

    /// The BarMan Pill will appear centered below the mouse pointer.
    case mousePointer = 1

    /// The BarMan Pill will appear centered below the BarMan icon.
    case barManIcon = 2

    var id: Int { rawValue }

    /// Localized string key representation.
    var localized: LocalizedStringKey {
        switch self {
        case .dynamic: "Dynamic"
        case .mousePointer: "Mouse pointer"
        case .barManIcon: "BarMan icon"
        }
    }
}
