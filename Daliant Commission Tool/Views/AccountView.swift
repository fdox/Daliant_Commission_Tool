//
//  AccountView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/31/25.
//

// Views/AccountView.swift
// Shows current account mode + actions: Use as Guest, Share Org (owner), Join via URL (member).

import SwiftUI
#if canImport(CloudKit)
import CloudKit
#endif

struct AccountView: View {
    @State private var state = AccountPrefs.load()

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("Mode") { Text(label(for: state.mode)).bold() }
                    if let name = state.orgName { LabeledContent("Organization") { Text(name) } }
                    if let id = state.orgID { LabeledContent("Org ID") { Text(id.uuidString.lowercased()).font(.footnote) } }
                }

                Section("Quick Actions") {
                    Button("Use as Guest (Local Only)") {
                        AccountPrefs.setGuest()
                        state = AccountPrefs.load()
                        
                    }
#if canImport(CloudKit)
                    if let orgID = state.orgID, let orgName = state.orgName {
                        NavigationLink("Share Organization…") {
                            OrgSharingView(orgID: orgID, orgName: orgName)
                        }
                    } else {
                        NavigationLink("Share Organization…") {
                            // Owner path: user will create an org first (your existing Org onboarding).
                            OrgOwnerHandOffView()
                        }
                    }
                    NavigationLink("Join Organization…") {
                        JoinOrgHandOffView()
                    }
#endif
#if canImport(CloudKit)
NavigationLink("Cloud Sync (10d)") { CloudSyncDebugView() }
#endif
                }

#if canImport(CloudKit)
                Section {
                    // Helpful status (from 10b)
                    CloudStatusView(simulatedStatus: nil)
                }
#endif
            }
            .navigationTitle("Account")
        }
    }

    private func label(for mode: AccountMode) -> String {
        switch mode {
        case .guestLocal: return "Guest (Local Only)"
        case .orgOwner:   return "Org Owner"
        case .orgMember:  return "Org Member"
        }
    }
}

// Simple hand-off stubs to keep compilation clean without wiring anything else yet.
// You can replace these with links from your Projects Home / Settings.
struct OrgOwnerHandOffView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Owner path").font(.headline)
            Text("Create an Organization with your existing Org onboarding, then come back here to share it.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
        }.padding()
    }
}

struct JoinOrgHandOffView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Join path").font(.headline)
            Text("Paste a share link in “Organization Sharing” to join. After joining, the app will switch to Org Member mode.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
        }.padding()
    }
}

#Preview("Account") { AccountView() }
