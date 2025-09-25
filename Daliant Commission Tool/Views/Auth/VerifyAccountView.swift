//
//  VerifyAccountView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/13/25.
//

import SwiftUI
import FirebaseAuth

/// Full-screen gate that keeps the user here until verified.
/// Email path is implemented; phone path is added in 12d-2.
struct VerifyAccountView: View {
    var onVerified: (() -> Void)? = nil
    @State private var showPhoneSheet = false
    @State private var isSending = false
    @State private var sendError: String?
    @State private var cooldown = 0
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var emailText: String {
        Auth.auth().currentUser?.email ?? "—"
    }
    @Environment(\.dismiss) private var dismissVerify

    private func signOutAndClose() {
        showPhoneSheet = false
        do { try Auth.auth().signOut() } catch {
            #if DEBUG
            print("[Verify] signOut error: \(error)")
            #endif
        }
        // Close the gate; the root auth observer will show the sign-in screen.
        dismissVerify()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 18) {
                Text("Verify your account")
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                statusRow(
                    "Email",
                    value: emailText,
                    ok: AuthState.shared.isEmailVerified
                )

                statusRow(
                    "Phone",
                    value: Auth.auth().currentUser?.phoneNumber ?? "Not linked",
                    ok: AuthState.shared.hasPhoneCredential
                )

                Button(action: sendVerificationEmail) {
                    HStack {
                        Image(systemName: "envelope")
                        Text(cooldown > 0
                             ? "Resend email (\(cooldown)s)"
                             : "Send verification email")
                    }
                }
                .buttonStyle(DSUI.PrimaryButtonStyle(tint: .blue))
                .disabled(isSending || cooldown > 0)

                Button("I verified — Refresh status", action: refreshStatus)
                    .buttonStyle(DSUI.OutlineButtonStyle(tint: .blue))
                
                Text("After you send the verification email, open your email app and tap the link. Or verify by phone — iOS will suggest the SMS code above the keyboard.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                if let sendError {
                    Text(sendError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                }

                Spacer()

                Button {
                    showPhoneSheet = true
                } label: {
                    HStack {
                        Image(systemName: "phone")
                        Text("Verify phone")
                    }
                }
                .buttonStyle(DSUI.OutlineButtonStyle(tint: .blue))

                .sheet(isPresented: $showPhoneSheet) {
                    PhoneVerifySheet { _ in
                        // After linking, reload + notify parent to dismiss the gate if now verified
                        Task { @MainActor in
                            try? await AuthState.shared.reloadCurrentUser()
                            if AuthState.shared.isVerified {
                                onVerified?()
                            }
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Account verification")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Use different email") {
                        signOutAndClose()
                    }
                    .accessibilityIdentifier("verify_useDifferentEmail")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") {
                        signOutAndClose()
                    }
                    .accessibilityIdentifier("verify_signOut")
                }
            }

        }
        .onReceive(tick) { _ in
            if cooldown > 0 { cooldown -= 1 }
        }
        .onAppear {
            #if DEBUG
            print("[Verify] appear: emailVerified=\(AuthState.shared.isEmailVerified) phoneLinked=\(AuthState.shared.hasPhoneCredential)")
            #endif
        }
    }

    private func sendVerificationEmail() {
        guard cooldown == 0 else { return }
        isSending = true
        sendError = nil

        Task { @MainActor in
            do {
                try await AuthState.shared.sendEmailVerification()
                cooldown = 30
                #if DEBUG
                print("[Verify] verification email sent; cooldown started")
                #endif
            } catch {
                sendError = error.localizedDescription
                #if DEBUG
                print("[Verify] send email error: \(error)")
                #endif
            }
            isSending = false
        }
    }

    private func refreshStatus() {
        Task { @MainActor in
            do {
                try await AuthState.shared.reloadCurrentUser()
                if AuthState.shared.isVerified {
                    #if DEBUG
                    print("[Verify] now verified; dismissing gate")
                    #endif
                    onVerified?()
                } else {
                    #if DEBUG
                    print("[Verify] still not verified")
                    #endif
                }
            } catch {
                sendError = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func statusRow(_ title: String, value: String, ok: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Label(ok ? "Verified" : "Not verified",
                      systemImage: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(ok ? .green : .orange)
            }
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

#Preview("Verify Gate") {
    VerifyAccountView()
}
