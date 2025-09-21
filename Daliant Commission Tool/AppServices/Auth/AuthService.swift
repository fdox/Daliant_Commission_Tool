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
}
