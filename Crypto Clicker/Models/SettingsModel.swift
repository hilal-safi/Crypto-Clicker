//
//  SettingsModel.swift
//  Crypto Clicker
//
//  Created by Hilal Safi on 2024-11-07.
//

import SwiftUI
import Combine

class SettingsModel: ObservableObject {
    @Published var enableSounds: Bool = false
    @Published var enableHaptics: Bool = true
    @Published var coinSize: Double = 2.0 // Default to "Medium"
}
