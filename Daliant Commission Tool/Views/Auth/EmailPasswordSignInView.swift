import SwiftUI

struct EmailPasswordSignInView: View {
    @ObservedObject private var auth = AuthState.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Daliant Account") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password (min 6)", text: $password)
                }

                Section {
                    Button {
                        Task { await handleSignIn() }
                    } label: {
                        if isBusy { ProgressView() } else { Text("Sign In") }
                    }
                    .disabled(isBusy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)

                    Button {
                        Task { await handleCreate() }
                    } label: {
                        if isBusy { ProgressView() } else { Text("Create Account") }
                    }
                    .disabled(isBusy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.count < 6)
                }

                if let msg = errorMessage, !msg.isEmpty {
                    Section { Text(msg).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("Sign In")
        }
    }

    private func handleSignIn() async {
        await run {
            try await auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
        }
    }

    private func handleCreate() async {
        await run {
            try await auth.createAccount(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
        }
    }

    private func run(_ op: @escaping () async throws -> Void) async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        do { try await op() }
        catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("[Auth] Error: \(error.localizedDescription)")
            #endif
        }
    }

}

#Preview {
    EmailPasswordSignInView()
}
