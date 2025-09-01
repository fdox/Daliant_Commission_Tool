//
//  SimCommissioningClient.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/27/25.
//

import Foundation

@MainActor
final class SimCommissioningClient: CommissioningClient {
    private var isScanning = false
    private var timer: Timer?

    // Protocol requirement
    private(set) var devices: [DiscoveredDevice] = []

    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        devices.removeAll()

        // Deterministic sample set; RSSI varies a bit as they "arrive"
        let base: [DiscoveredDevice] = [
            DiscoveredDevice(id: "D4i-001", name: "Pod4 D4i", dtTypeRaw: "D4i", serial: "P4-0001", rssi: -52),
            DiscoveredDevice(id: "DT8-201", name: "DT8 TW",  dtTypeRaw: "DT8", serial: "TW-0201", rssi: -64),
            DiscoveredDevice(id: "DT6-101", name: "DT6 Dim", dtTypeRaw: "DT6", serial: "D6-0101", rssi: -71),
            DiscoveredDevice(id: "DT8-202", name: "DT8 RGB", dtTypeRaw: "DT8", serial: "RGB-0202", rssi: -58),
            DiscoveredDevice(id: "D4i-002", name: "Pod4 D4i", dtTypeRaw: "D4i", serial: "P4-0002", rssi: -61)
        ]

        var i = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] t in
            guard let self else { return }
            if i < base.count {
                // Add a tiny RSSI wobble to feel alive
                var d = base[i]
                d.rssi += Int.random(in: -2...2)
                self.devices.append(d)
                i += 1
            } else {
                t.invalidate()
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func stopScan() {
        isScanning = false
        timer?.invalidate()
        timer = nil
    }

    func identify(_ id: String) {
        // No-op for 7a: simulate a brief "blink" later if desired.
        #if DEBUG
        print("Sim identify → \(id)")
        #endif
    }
}
