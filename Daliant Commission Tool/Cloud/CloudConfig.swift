//
//  CloudConfig.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/31/25.
//

// Cloud/CloudConfig.swift
// Step 10b — central container accessor (uses default unless overridden)

#if canImport(CloudKit)
import CloudKit
import Foundation

enum CloudConfig {
    /// If you later choose a non-default container, set it here.
    /// Example: "iCloud.com.yourcompany.daliant"
    static let containerIdentifier: String? = nil

    /// Resolved CKContainer (default if `containerIdentifier` is nil).
    static var container: CKContainer {
        if let id = containerIdentifier, !id.isEmpty {
            return CKContainer(identifier: id)
        } else {
            return CKContainer.default()
        }
    }

    /// Convenience databases (not all used yet, but handy going forward).
    static var privateDB: CKDatabase { container.privateCloudDatabase }
    static var sharedDB:  CKDatabase { container.sharedCloudDatabase }
    static var publicDB:  CKDatabase { container.publicCloudDatabase } // likely unused

    /// Human-readable description of the active container.
    static var containerLabel: String {
        containerIdentifier ?? "(default container)"
    }
}
#endif
