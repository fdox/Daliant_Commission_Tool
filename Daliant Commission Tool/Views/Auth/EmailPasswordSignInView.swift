import SwiftUI

struct EmailPasswordSignInView: View {
    @ObservedObject private var auth = AuthState.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var error: String?

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
                    
                    // 12b-6: Apple sign-in
                    AppleSignInRow()
                        .padding(.top, 8)
                    // 12c-5: Google sign-in
                    GoogleSignInRow()
                        .padding(.top, 4)

                    Button {
                        Task { await handleCreate() }
                    } label: {
                        if isBusy { ProgressView() } else { Text("Create Account") }
                    }
                    .disabled(isBusy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.count < 6)
                    
                    Button("Forgot password?") {
                        Task {
                            do {
                                let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !e.isEmpty else { errorMessage = "Enter your email first."; return }
                                try await auth.sendPasswordReset(email: e)
                                errorMessage = "Password reset email sent (check your inbox)."
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .font(.footnote)

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
