//
//  CommissioningClient.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/27/25.
//

import Foundation

/// A lightweight representation of a device we can discover during commissioning.
/// Matches your model fields used in Scan:
/// - name (e.g. "Pod4 D4i")
/// - dtTypeRaw: "DT6" | "DT8" | "D4i"
/// - serial: vendor/device serial text
/// - rssi: signal strength (dBm)
public struct DiscoveredDevice: Identifiable, Equatable, Hashable {
    public var id: String            // stable identifier (e.g. peripheral UUID or synthetic)
    public var name: String
    public var dtTypeRaw: String?
    public var serial: String?
    public var rssi: Int

    public init(id: String, name: String, dtTypeRaw: String?, serial: String?, rssi: Int) {
        self.id = id
        self.name = name
        self.dtTypeRaw = dtTypeRaw
        self.serial = serial
        self.rssi = rssi
    }
}

/// Abstraction for commissioning backends (simulated vs. BLE).
/// Implementations will publish device list changes themselves (we won't require ObservableObject here).
@MainActor
protocol CommissioningClient: AnyObject {
    /// Current snapshot of discovered devices.
    var devices: [DiscoveredDevice] { get }

    /// Begin discovering devices.
    func startScan()

    /// Stop discovering devices.
    func stopScan()

    /// Trigger a brief identify/flash on the device (if supported).
    func identify(_ id: String)
}
