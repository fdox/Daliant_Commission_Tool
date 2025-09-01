//
//  BLECommissioningClient.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/27/25.
//

import Foundation
#if canImport(CoreBluetooth)
import CoreBluetooth
#endif

@MainActor
final class BLECommissioningClient: CommissioningClient {
    // Protocol requirement
    private(set) var devices: [DiscoveredDevice] = []

    func startScan() {
        // 7a stub: no real BLE yet; keep list empty.
        // (We gate real scanning in a later step; Simulator won't scan anyway.)
        #if targetEnvironment(simulator)
        print("BLECommissioningClient: scanning unavailable in Simulator (stub).")
        #endif
        devices = []
    }

    func stopScan() {
        // 7a stub: nothing to stop yet.
    }

    func identify(_ id: String) {
        // 7a stub: no-op.
    }
}
