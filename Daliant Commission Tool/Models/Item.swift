import Foundation
import SwiftData

/// Keep using `Item` as the Project model for now (to avoid Xcode project file edits)
@Model
final class Item {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date?

    // MARK: - Phase 2b additions
    var contactFirstName: String?
    var contactLastName: String?
    var siteAddress: String?
    var controlSystemRaw: String?   // "control4" | "crestron" | "lutron"

    // Step 5a — relation (NO @Relationship attribute here; let SwiftData infer)
    var fixtures: [Fixture] = []

    init(title: String, createdAt: Date = .now) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
    }
}
