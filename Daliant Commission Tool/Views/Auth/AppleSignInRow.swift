//
//  AppleSignInRow.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/10/25.
//

import SwiftUI
import AuthenticationServices

/// A compact, reusable Apple sign-in row that drives Firebase via AuthState.linkOrSignIn(...)
struct AppleSignInRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentNonce: String?
    @State private var isWorking = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 8) {
            SignInWithAppleButton(.continue) { request in
                // Prepare a fresh nonce for this attempt
                let raw = AppleNonce.random()
                currentNonce = raw
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleNonce.sha256(raw)
                isWorking = true
                errorText = nil
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    guard
                        let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                        let raw = currentNonce
                    else {
                        errorText = "Missing Apple credential."
                        isWorking = false
                        return
                    }
                    Task { @MainActor in
                        do {
                            // Link if already signed-in, else sign-in. AuthState notifies listeners.
                            _ = try await AuthState.shared.linkOrSignIn(withApple: credential, rawNonce: raw)
                        } catch {
                            errorText = error.localizedDescription
                        }
                        isWorking = false
                        currentNonce = nil
                    }
                case .failure(let error):
                    // Ignore user-cancel; show other errors succinctly
                    if (error as? ASAuthorizationError)?.code != .canceled {
                        errorText = error.localizedDescription
                    }
                    isWorking = false
                    currentNonce = nil
                }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 44)

            if isWorking { ProgressView().controlSize(.small) }

            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Continue with Apple")
    }
}
