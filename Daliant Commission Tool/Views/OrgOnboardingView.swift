import SwiftUI
import SwiftData

struct OrgOnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var name: String = ""

    var body: some View {
        Form {
            Section("Organization") {
                TextField("Organization name", text: $name)
            }
            Section {
                Button("Create Organization") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    context.insert(Org(name: trimmed))
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Welcome")
    }
}