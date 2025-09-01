//
//  CloudSyncDebugView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/1/25.
//

// Cloud/CloudSyncDebugView.swift
// Dev-only sync panel to exercise push/pull manually (10d — S1)

#if canImport(CloudKit)
import SwiftUI
import CloudKit
import SwiftData

struct CloudSyncDebugView: View {
    @Environment(\.modelContext) private var ctx
    @State private var status: String = "Idle"
    @State private var orgIDText: String = AccountPrefs.load().orgID?.uuidString.lowercased() ?? ""

    private var hasOrg: Bool { UUID(uuidString: orgIDText) != nil }
    private var mode: AccountMode { AccountPrefs.load().mode }

    var body: some View {
        Form {
            Section("Account") {
                LabeledContent("Mode") { Text(label(for: mode)).bold() }
                TextField("Org ID (UUID)", text: $orgIDText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .font(.system(.body, design: .monospaced))
                HStack {
                    Button("Save Org") {
                        if let id = UUID(uuidString: orgIDText.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            switch mode {
                            case .orgOwner:
                                AccountPrefs.setOwner(orgID: id, orgName: AccountPrefs.load().orgName ?? "Org")
                            case .orgMember:
                                AccountPrefs.setMember(orgID: id, orgName: AccountPrefs.load().orgName)
                            case .guestLocal:
                                // leave as guest; Save Org is a no-op in guest
                                break
                            }
                            status = "Saved Org \(id.uuidString.lowercased())."
                        } else {
                            status = "Invalid Org UUID."
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasOrg)
                    Spacer()
                    Button("Use Guest") {
                        AccountPrefs.setGuest()
                        status = "Switched to Guest."
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("Sync") {
                Button("Push Now") {
                    Task { status = await CloudStore.shared.pushAll(context: ctx) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasOrg || mode == .guestLocal)

                Button("Pull Now") {
                    Task { status = await CloudStore.shared.pullAll(context: ctx) }
                }
                .buttonStyle(.bordered)
                .disabled(!hasOrg || mode == .guestLocal)

                Button("Full Sync") {
                    Task {
                        let p = await CloudStore.shared.pushAll(context: ctx)
                        let g = await CloudStore.shared.pullAll(context: ctx)
                        status = "Push: \(p)\nPull: \(g)"
                    }
                }
                .disabled(!hasOrg || mode == .guestLocal)
            }

            Section("Status") { Text(status).font(.footnote).textSelection(.enabled) }
        }
        .navigationTitle("Cloud Sync (10d)")
    }

    private func label(for mode: AccountMode) -> String {
        switch mode {
        case .guestLocal: return "Guest (Local Only)"
        case .orgOwner:   return "Org Owner"
        case .orgMember:  return "Org Member"
        }
    }
}

#Preview("Cloud Sync (dev)") {
    NavigationStack { CloudSyncDebugView() }
}
#endif
