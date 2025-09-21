
//  UserStore.swift
//  Daliant Commission Tool
//
//  Phase 14 / Step‑7: Shell store for /users/{uid} profile writes.
//  Next patch will call into UserProfileService to upsert first/last/displayName.
//

import Foundation

@MainActor
enum UserStore {
    // Anchor: USER_STORE_UPSERT_PROFILE
    static func upsertProfile(firstName: String, lastName: String) async throws {
        // Micro‑step 1: no‑op shell (compiles safely in previews).
        // Micro‑step 2 will implement by delegating to UserProfileService.shared.
        // try await UserProfileService.shared.upsertProfile(firstName: firstName, lastName: lastName)
    }
}
