import Foundation
import SwiftData

/// Keep using `Item` as the Project model for now (to avoid Xcode project file edits)
@Model
final class Item {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date?

    // NEW: last-writer-wins + sync decisions
    var updatedAt: Date? = Date()
    /// 11f: who made the last edit (uid or nil for local/offline)
    var updatedBy: String?
    /// 11g: soft‑delete marker; `nil` = active, non‑nil = archived
    var archivedAt: Date?

    /// Convenience (not persisted)
    var isArchived: Bool { archivedAt != nil }


    // Phase 2b additions (kept from your file)
    var contactFirstName: String?
    var contactLastName: String?
    var siteAddress: String?
    var controlSystemRaw: String?   // "control4" | "crestron" | "lutron"

    // Relation
    var fixtures: [Fixture] = []

    init(title: String, createdAt: Date = .now) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = Date()
    }
}

// Convenience initializer for remote upserts (lets us set a known UUID)
extension Item {
    convenience init(id: UUID, title: String, createdAt: Date?, updatedAt: Date?) {
        self.init(title: title, createdAt: createdAt ?? .now)
        self.id = id
        self.updatedAt = updatedAt ?? Date()
    }
}
