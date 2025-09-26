import Foundation
import SwiftData

@Model
final class Org {
    @Attribute(.unique) var id: UUID
    var shortId: String?  // Short 6-character ID for support
    var name: String
    var createdAt: Date
    var updatedAt: Date
    
    // Business Information
    var businessName: String?
    var addressLine1: String?
    var addressLine2: String?
    var city: String?
    var state: String?
    var zipCode: String?
    
    // Owner information
    var ownerUid: String?

    init(name: String, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}
