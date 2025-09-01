import SwiftUI
import SwiftData

struct OrgOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var orgs: [Org]

    @State private var showingCreate = false
    @State private var name: String = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                if !orgs.isEmpty {
                    Section("Organization") {
                        // Tap existing org just to confirm what’s there (no-op; the gate is in ContentView)
                        ForEach(orgs, id: \.persistentModelID) { org in
                            HStack {
                                Text(org.name).font(.body)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { /* no-op; gate switches automatically */ }
                        }
                    }
                }

                Section {
                    Button("Create Organization…") { showingCreate = true }
                        .buttonStyle(.borderedProminent)
                } footer: {
                    Text("You need exactly one Organization to begin. You can rename it later in Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Welcome")
        }
        .sheet(isPresented: $showingCreate) {
            NavigationStack {
                Form {
                    Section("Organization Name") {
                        TextField("e.g. Dox Electronics, LLC", text: $name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled(true)
                    }
                }
                .navigationTitle("New Organization")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingCreate = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") { createOrg() }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .alert("Couldn’t Create Organization", isPresented: $showError, actions: {
                    Button("OK", role: .cancel) { }
                }, message: {
                    Text(errorMessage)
                })
            }
        }
    }

    // MARK: - Actions

    private func createOrg() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let org = Org(name: trimmed)
        modelContext.insert(org)
        do {
            try modelContext.save()
            name = ""
            showingCreate = false
            // ContentView’s gate will see orgs.count > 0 and switch to Projects.
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
