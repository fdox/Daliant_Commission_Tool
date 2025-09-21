//
//  PasswordSignInView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/21/25.
//

import SwiftUI

struct PasswordSignInView: View {
    let email: String

    @State private var password = ""
    @State private var reveal = false
    @State private var isLoading = false
    @State private var message: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Verify Your Daliant Password")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 16)


            VStack(alignment: .leading, spacing: 8) {
                Text("Enter your password")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    if reveal {
                        TextField("Password", text: $password)
                            .textContentType(.password)
                    } else {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    }
                    Button {
                        reveal.toggle()
                    } label: {
                        Image(systemName: reveal ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? .black : .gray.opacity(0.3), lineWidth: 1)
                )
                .focused($isFocused)

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                }

                Button("Forgot your password?") {
                    Task {
                        do {
                            try await AuthService.sendPasswordReset(email: email)
                            message = "Password reset email sent."
                        } catch {
                            message = friendlyAuthMessage(error)
                        }
                    }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.top, 8)
            }

            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                Button(isLoading ? "Logging In…" : "Log In") {
                    Task {
                        isLoading = true
                        defer { isLoading = false }
                        do {
                            try await AuthService.signIn(email: email, password: password)
                            // Success: AuthGateView flips to signed-in automatically.
                        } catch {
                            message = friendlyAuthMessage(error)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .font(.headline)
                .foregroundColor(.white)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .disabled(password.isEmpty || isLoading)
                .opacity((password.isEmpty || isLoading) ? 0.5 : 1)
                .padding(.bottom, 8)
            }
            .background(.ultraThinMaterial)
        }

        .padding(.horizontal, 20)
        .onAppear { isFocused = true }
        .navigationBarBackButtonHidden(false)
    }

    private func friendlyAuthMessage(_ error: Error) -> String {
        let ns = error as NSError
        switch (ns.domain, ns.code) {
        case ("FIRAuthErrorDomain", 17004): return "Incorrect password."
        case ("FIRAuthErrorDomain", 17008): return "That email looks invalid."
        case ("FIRAuthErrorDomain", 17009): return "Incorrect email or password."
        case ("FIRAuthErrorDomain", 17010): return "Too many attempts. Please wait."
        case ("FIRAuthErrorDomain", 17011): return "No account found for that email."
        default: return ns.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        PasswordSignInView(email: "someone@example.com")
    }
}
