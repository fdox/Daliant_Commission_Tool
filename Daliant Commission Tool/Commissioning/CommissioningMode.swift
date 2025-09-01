//
//  CommissioningMode.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/27/25.
//

import Foundation

/// App‑wide commissioning mode. Backed by a String so it works cleanly with @AppStorage.
enum CommissioningMode: String, CaseIterable, Identifiable, Codable {
    case simulated
    case ble

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simulated: return "Simulated"
        case .ble: return "BLE"
        }
    }
}
