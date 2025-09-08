import Foundation
import SwiftData

@Model
final class Fixture {
    var label: String
    var shortAddress: Int            // 0…63
    var groups: UInt16               // bitmask for groups 0…15
    var room: String?
    var serial: String?
    var dtTypeRaw: String?           // "DT6" | "DT8" | "D4i"
    var commissionedAt: Date?
    var notes: String?

    /// NEW (11e-1): last-writer-wins + sync decisions
    var updatedAt: Date? = Date()
    /// 11f: who made the last edit (uid or nil for local/offline)
    var updatedBy: String?


    // Let SwiftData infer inverse to Item.fixtures
    var project: Item?

    init(
        label: String,
        shortAddress: Int,
        groups: UInt16 = 0,
        room: String? = nil,
        serial: String? = nil,
        dtTypeRaw: String? = nil,
        commissionedAt: Date? = nil,
        notes: String? = nil,
        project: Item? = nil
    ) {
        self.label = label
        self.shortAddress = shortAddress
        self.groups = groups
        self.room = room
        self.serial = serial
        self.dtTypeRaw = dtTypeRaw
        self.commissionedAt = commissionedAt
        self.notes = notes
        self.project = project
        self.updatedAt = Date()
    }
}
