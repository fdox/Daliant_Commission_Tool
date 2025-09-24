//
//  AuthService.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/20/25.
//

//
//  AuthService.swift
//  Daliant Commission Tool
//
//  Phase 14 / Step‑7: Shell service (no Firebase calls here yet).
//

import Foundation
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif


@MainActor
enum AuthService {
    // Anchor: AUTH_SERVICE_CREATE_ACCOUNT
    static func createAccount(email: String, password: String) async throws {
        // For now, delegate to existing AuthState (which already guards previews/flags).
        // In the next patch we’ll keep this facade and expand error mapping here.
        try await AuthState.shared.createAccount(email: email, password: password)
    }

    // Anchor: AUTH_SERVICE_SIGN_IN
    static func signIn(email: String, password: String) async throws {
        try await AuthState.shared.signIn(email: email, password: password)
    }

    // Anchor: AUTH_SERVICE_RESET
    static func sendPasswordReset(email: String) async throws {
        try await AuthState.shared.sendPasswordReset(email: email)
    }
    // Anchor: AUTH_SERVICE_EMAIL_CHECK
    /// Returns true if Firebase has any sign‑in methods for the email (i.e., an account exists).
    static func isEmailInUse(_ email: String) async throws -> Bool {
#if canImport(FirebaseAuth)
let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
return try await withCheckedThrowingContinuation { cont in
    FirebaseAuth.Auth.auth().fetchSignInMethods(forEmail: cleaned) { methods, error in
        if let error { cont.resume(throwing: error); return }
        cont.resume(returning: !(methods ?? []).isEmpty)
    }
}
#else
// If FirebaseAuth isn't in this target, fall back to "not in use"
return false
#endif

    }

}
