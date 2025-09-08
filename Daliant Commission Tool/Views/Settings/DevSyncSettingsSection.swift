//
//  DevSyncSettingsSection.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/5/25.
//

import SwiftUI
import SwiftData

/// 11e-2: Dev-only tools for manual sync and listener restart.
/// Drop this into SettingsView under a `#if DEBUG` guard.
struct DevSyncSettingsSection: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        #if DEBUG
        if FeatureFlags.firebaseEnabled {
            Section("Developer") {
                Button("Sync Now (Dev)") {
                    Task { @MainActor in
                        do {
                            try await ProjectSyncService.shared.pullAllForCurrentUser(context: context)
                            try await FixtureSyncService.shared.pullAllForCurrentUser(context: context)
                            print("[DevSync] Manual pull finished")
                        } catch {
                            print("[DevSync] Manual pull error: \(error)")
                        }
                    }
                }
                Button("Restart Live Listeners") {
                    LiveSyncCenter.shared.stop()
                    LiveSyncCenter.shared.start(context: context)
                }
            }
        }
        #else
        EmptyView()
        #endif
    }
}
