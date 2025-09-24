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
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseCore)
import FirebaseCore
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
#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

// Check if Firebase is configured
#if canImport(FirebaseCore)
guard FirebaseApp.app() != nil else {
    #if DEBUG
    print("[AuthService] Firebase not configured")
    #endif
    return false
}
#endif

// First try Firebase Auth's fetchSignInMethods
do {
    let authMethods = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[String], Error>) in
        Auth.auth().fetchSignInMethods(forEmail: cleaned) { methods, error in
            if let error { cont.resume(throwing: error); return }
            cont.resume(returning: methods ?? [])
        }
    }
    if !authMethods.isEmpty {
        return true
    }
} catch {
    // If Auth check fails, continue to Firestore check
    #if DEBUG
    print("[AuthService] Auth fetchSignInMethods failed: \(error)")
    print("[AuthService] Auth error details: \(error.localizedDescription)")
    #endif
}

// If no Auth methods found, check Firestore users collection
do {
    let db = Firestore.firestore()
    let query = db.collection("users").whereField("email", isEqualTo: cleaned).limit(to: 1)
    
    let snapshot = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<QuerySnapshot, Error>) in
        query.getDocuments { snapshot, error in
            if let error { cont.resume(throwing: error); return }
            cont.resume(returning: snapshot!)
        }
    }
    
    return !snapshot.documents.isEmpty
} catch {
    #if DEBUG
    print("[AuthService] Firestore email check failed: \(error)")
    print("[AuthService] Firestore error details: \(error.localizedDescription)")
    #endif
    throw error
}
#else
// If Firebase isn't available, fall back to "not in use"
return false
#endif
    }

}
