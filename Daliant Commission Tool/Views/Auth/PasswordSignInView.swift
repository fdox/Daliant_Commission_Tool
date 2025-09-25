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
                    .font(DS.Font.title)
                    .foregroundStyle(.primary)
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
                .font(DS.Font.caption.weight(.semibold))
                .foregroundStyle(.blue)
                .padding(.top, 8)
            }

            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom) {
            DSUI.StickyCtaBar(
                title: isLoading ? "Logging In…" : "Log In",
                isEnabled: !password.isEmpty && !isLoading,
                useBackground: false,
                tint: .black
            ) {
                Task {
                    isLoading = true
                    defer { isLoading = false }
                    do {
                        try await AuthService.signIn(email: email, password: password)
                    } catch {
                        message = friendlyAuthMessage(error)
                    }
                }
            }
        }

        .padding(.horizontal, DS.Spacing.xl)
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
