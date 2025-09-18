import SwiftUI
import SwiftData
#if canImport(CloudKit)
import CloudKit
#endif

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var orgs: [Org]
    @AppStorage("commissioningMode") private var commissioningMode: CommissioningMode = .simulated

    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Account") {
                let verified = AuthState.shared.isVerified
                Label {
                    Text(verified ? "Verified" : "Needs verification")
                        .font(.subheadline.weight(.semibold))
                } icon: {
                    Image(systemName: verified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(verified ? .green : .orange)
                }
                .accessibilityIdentifier("settings_account_status")
            }
            // Organization summary
            Section("Organization") {
                let org = orgs.first
                LabeledContent("Name") { Text(org?.name ?? "—").bold() }
                LabeledContent("Org ID") {
                    Text(org?.id.uuidString.lowercased() ?? "—")
                        .font(.footnote)
                        .textSelection(.enabled)
                }
            }

            // Single‑org mode: hide this whole section when multipleOrgsEnabled == false
            if FeatureFlags.multipleOrgsEnabled {
                Section("Active Organization") {
                    LabeledContent("Active") {
                        Text(ActiveOrgStore.shared.activeOrgName(in: context)).bold()
                    }
                    NavigationLink("Switch Active Org…") {
                        ActiveOrgPickerView()
                    }
                }
            }

            // Legacy CloudKit UI fully hidden unless explicitly enabled
            #if canImport(CloudKit)
            if FeatureFlags.cloudKitUIEnabled {
                Section("Account & Cloud (Legacy CK)") {
                    NavigationLink("Account") { AccountView() }
                    NavigationLink("Cloud Sync (10d)") { CloudSyncDebugView() }
                    CloudStatusView(simulatedStatus: nil)
                }
            }
            #endif

            // Sign out (Firebase + clear local orgs)
            Section {
                Button(role: .destructive) { signOut() } label: { Text("Sign out") }
            }

            #if DEBUG
            Section("Commissioning") {
                Picker("Mode", selection: $commissioningMode) {
                    ForEach(CommissioningMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text("BLE is a stub in 7a; behavior remains simulated until later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            #endif
            Section("Data") {
                NavigationLink("Archived Projects") {
                    ArchivedProjectsView()
                }
            }
#if DEBUG
            DevSyncSettingsSection()
#endif
        }
        .task {
            ActiveOrgStore.shared.ensureDefault(in: context)
            await UserProfileService.shared.ensureProfile()
        }
        .navigationTitle("Settings")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    // MARK: - Helpers
    private func signOut() {
        
        // 11e-2: stop live listeners before tearing down auth/local data
        LiveSyncCenter.shared.stop()
        
        // 1) Firebase sign‑out (safe even if already signed out)
        do { try AuthState.shared.signOut() }
        catch { errorMessage = "Sign out error: \(error.localizedDescription)" }

        // 2) Clear local Orgs and dismiss
        do {
            for o in try context.fetch(FetchDescriptor<Org>()) { context.delete(o) }
            try context.save()
            dismiss()
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }
}

#if DEBUG
private struct SettingsPreviewHost: View {
    @Environment(\.modelContext) private var ctx
    @Query private var orgs: [Org]
    var body: some View {
        NavigationStack { SettingsView() }
            .task { @MainActor in
                if orgs.isEmpty { ctx.insert(Org(name: "Daliant Test Org")); try? ctx.save() }
            }
    }
}

#Preview("Settings — Seeded") {
    SettingsPreviewHost()
        .modelContainer(for: [Org.self, Item.self, Fixture.self], inMemory: true)
}
#endif
