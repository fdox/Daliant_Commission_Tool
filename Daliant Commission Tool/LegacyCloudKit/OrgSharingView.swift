//
//  OrgSharingView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/31/25.
//

// Views/OrgSharingView.swift
// Step 10c — Owner can create/get a zone‑wide share; Tech can paste a link to join.

#if canImport(CloudKit)
import SwiftUI
import CloudKit
import UIKit

struct OrgSharingView: View {
    // Pass these from your UI (Projects home, Settings, etc.)
    let orgID: UUID
    let orgName: String

    @State private var isBusy = false
    @State private var status: String?
    @State private var errorText: String?

    // Share presentation
    @State private var showShareSheet = false
    @State private var currentShare: CKShare?

    // Join flow (paste a URL)
    @State private var joinURLString: String = ""

    var body: some View {
        Form {
            Section("Organization") {
                LabeledContent("Org") { Text(orgName).bold() }
                LabeledContent("Zone ID") { Text(CloudIDs.orgZoneID(for: orgID).zoneName).font(.footnote) }
            }

            Section("Owner") {
                Button {
                    Task { await createOrOpenShare() }
                } label: {
                    if isBusy { ProgressView() } else { Text("Share Organization…") }
                }
                .disabled(isBusy)
                .buttonStyle(.borderedProminent)

                if let s = currentShare?.url {
                    LabeledContent("Share URL") { Text(s.absoluteString).textSelection(.enabled) }
                }
            }

            Section("Technician") {
                TextField("Paste share URL here", text: $joinURLString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.URL)

                Button("Accept & Join") {
                    Task { await acceptShareFromPastedURL() }
                }
                .disabled(isBusy || joinURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let status = status {
                Section { Text(status).font(.footnote).foregroundStyle(.secondary) }
            }
            if let err = errorText {
                Section { Text("Error: \(err)").font(.footnote).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Organization Sharing")
        .sheet(isPresented: $showShareSheet) {
            if let share = currentShare {
                ZoneShareController(share: share)
            } else {
                ProgressView().padding()
            }
        }
    }

    // MARK: Actions

    @MainActor
    private func createOrOpenShare() async {
        isBusy = true; errorText = nil; status = "Preparing zone…"
        do {
            let zone = try await OrgZone.ensureZone(orgID: orgID)
            status = "Ensuring share…"
            let share = try await OrgZone.ensureShare(for: zone, title: orgName, publicPermission: .readWrite)
            currentShare = share
            status = "Share ready. Use the system sheet to invite others."
            showShareSheet = true
        } catch {
            errorText = error.localizedDescription
        }
        isBusy = false
    }

    @MainActor
    private func acceptShareFromPastedURL() async {
        isBusy = true; errorText = nil; status = "Fetching invitation…"
        do {
            guard let url = URL(string: joinURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw NSError(domain: "OrgSharing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }

            // Fetch metadata, then accept. (Async conveniences in modern CloudKit.)
            let metadata = try await CloudConfig.container.shareMetadata(for: url)
            _ = try await CloudConfig.container.accept([metadata])

            status = "Joined! The shared zone is now visible in your Shared DB."
        } catch {
            errorText = error.localizedDescription
        }
        isBusy = false
    }
}

// MARK: - UICloudSharingController wrapper (zone‑wide share)
private struct ZoneShareController: UIViewControllerRepresentable {
    let share: CKShare

    func makeUIViewController(context: Context) -> UICloudSharingController {
        // Present Apple's sharing UI for the zone‑wide CKShare.
        let c = UICloudSharingController(share: share, container: CloudConfig.container)
        c.modalPresentationStyle = .formSheet
        // Optional: allow read/write for invitees (the share itself already has publicPermission).
        c.availablePermissions = [.allowReadWrite]
        return c
    }
    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) { }
}

// MARK: - Previews (UI only; no live CloudKit calls are made here)
#Preview("Org Sharing (UI)") {
    NavigationStack {
        OrgSharingView(
            orgID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            orgName: "Daliant Test Org"
        )
    }
}
#endif
