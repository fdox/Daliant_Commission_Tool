//
//  GoogleSignInRow.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/13/25.
//

import SwiftUI

/// Compact Google sign-in row that drives Firebase via AuthState.linkOrSignInWithGoogle(...)
struct GoogleSignInRow: View {
    @State private var isWorking = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 6) {
            Button {
                startGoogle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                    Text("Continue with Google")
                    Spacer()
                }
            }
            .buttonStyle(.bordered)
            .disabled(isWorking)

            if isWorking { ProgressView().controlSize(.small) }

            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Continue with Google")
    }

    private func startGoogle() {
        guard !isWorking else { return }
        isWorking = true
        errorText = nil

        let coordinator = GoogleSignInCoordinator()
        coordinator.onComplete = { tokens in
            #if DEBUG
            print("[GoogleSignIn] received tokens; linking/signing in…")
            #endif
            Task { @MainActor in
                do {
                    _ = try await AuthState.shared.linkOrSignInWithGoogle(
                        idToken: tokens.idToken,
                        accessToken: tokens.accessToken
                    )
                } catch {
                    #if DEBUG
                    print("[GoogleSignIn] Firebase link/sign-in error: \(error)")
                    #endif
                    self.errorText = error.localizedDescription
                }
                self.isWorking = false
            }
        }
        coordinator.onCancel = {
            #if DEBUG
            print("[GoogleSignIn] cancelled")
            #endif
            Task { @MainActor in self.isWorking = false }
        }
        coordinator.onError = { err in
            #if DEBUG
            print("[GoogleSignIn] error: \(err)")
            #endif
            Task { @MainActor in
                self.errorText = err.localizedDescription
                self.isWorking = false
            }
        }
        coordinator.start()
    }
}
