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

    @State private var newJoinCode: String = ""
    @State private var errorMessage: String?
    var currentOrg: Org? { orgs.first }

    var body: some View {
        Form {
            Section("Organization") {
                let org = orgs.first
                LabeledContent("Name") { Text(org?.name ?? "—").bold() }
                LabeledContent("Org ID") {
                    Text(org?.id.uuidString.lowercased() ?? "—")
                        .font(.footnote)
                        .textSelection(.enabled)
                }
            }
            Section("Account & Cloud") {
                NavigationLink("Account") { AccountView() }

                #if canImport(CloudKit)
                if let org = orgs.first {
                    // Owner: create or open the Org share
                    NavigationLink("Share Organization…") {
                        OrgSharingView(orgID: org.id, orgName: org.name)
                    }
                } else {
                    // If no org yet, keep the link but explain
                    NavigationLink("Share Organization…") { OrgOwnerHandOffView() }
                }

                // Dev tool: manual push/pull to verify sync in 10d
                NavigationLink("Cloud Sync (10d)") { CloudSyncDebugView() }

                // Helpful status (10b)
                CloudStatusView(simulatedStatus: nil)
                #endif
            }
            Section("Join different org") {
                TextField("Enter join code", text: $newJoinCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button("Join") { joinDifferentOrg() }
                    .disabled(newJoinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
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
        }
        .navigationTitle("Settings")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK", role: .cancel) { errorMessage = nil }
        }, message: { Text(errorMessage ?? "") })
    }

    // MARK: Helpers
    private func currentOrgName() -> String {
        guard let org = currentOrg else { return "—" }
        if let n = Mirror(reflecting: org).children.first(where: { $0.label == "name" })?.value as? String, !n.isEmpty { return n }
        return "—"
    }
    private func currentOrgJoinCode() -> String {
        guard let org = currentOrg else { return "—" }
        let m = Mirror(reflecting: org)
        if let c = m.children.first(where: { $0.label == "joinCode" })?.value as? String, !c.isEmpty { return c }
        if let c = m.children.first(where: { $0.label == "code" })?.value as? String, !c.isEmpty { return c }
        if let name = m.children.first(where: { $0.label == "name" })?.value as? String,
           let parsed = parseCodeFromName(name) { return parsed }
        return "—"
    }
    private func parseCodeFromName(_ name: String) -> String? {
        guard let open = name.lastIndex(of: "("),
              let close = name.lastIndex(of: ")"),
              close > open else { return nil }
        let code = name[name.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
        return code.isEmpty ? nil : code
    }
    private func joinDifferentOrg() {
        let code = newJoinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        do {
            let all = try context.fetch(FetchDescriptor<Org>())
            if let found = all.first(where: {
                let m = Mirror(reflecting: $0)
                let c1 = (m.children.first(where: { $0.label == "joinCode" })?.value as? String)
                let c2 = (m.children.first(where: { $0.label == "code" })?.value as? String)
                let name = (m.children.first(where: { $0.label == "name" })?.value as? String) ?? ""
                return c1?.caseInsensitiveCompare(code) == .orderedSame
                    || c2?.caseInsensitiveCompare(code) == .orderedSame
                    || name.localizedCaseInsensitiveContains("(\(code))")
            }) {
                for o in all where o != found { context.delete(o) }
                try context.save()
                newJoinCode = ""; return
            }
            for o in all { context.delete(o) }
            let newOrg = Org(name: "Org (\(code))") // fallback: encode code in name
            context.insert(newOrg)
            try context.save()
            newJoinCode = ""
        } catch {
            errorMessage = "Could not switch org: \(error.localizedDescription)"
        }
    }
    private func signOut() {
        do {
            for o in try context.fetch(FetchDescriptor<Org>()) { context.delete(o) }
            try context.save()
            dismiss()
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview helper
fileprivate enum SettingsPreviewFactory {
    @MainActor
    static func seeded() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Org.self, Item.self, configurations: config)
        let context = container.mainContext
        let org = Org(name: "Dox Electronics")
        context.insert(org)
        _ = try? context.save()
        return NavigationStack { SettingsView() }.modelContainer(container)
    }
}

#if DEBUG
private struct SettingsPreviewHost: View {
    @Environment(\.modelContext) private var ctx
    @Query private var orgs: [Org]

    var body: some View {
        NavigationStack { SettingsView() }
            .task { @MainActor in
                // Seed one Org so the view has data in Canvas
                if orgs.isEmpty {
                    ctx.insert(Org(name: "Daliant Test Org"))
                    try? ctx.save()
                }
            }
    }
}

#Preview("Settings — Seeded") {
    SettingsPreviewHost()
        // IMPORTANT: include ALL your models and keep this in-memory
        .modelContainer(for: [Org.self, Item.self, Fixture.self], inMemory: true)
}
#endif
