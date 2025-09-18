//
//  AuthState.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/2/25.
//

import Foundation
import SwiftUI

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

@MainActor
final class AuthState: ObservableObject {
    static let shared = AuthState()

    enum Status: Equatable { case loading, signedOut, signedIn(user: DUser) }
    struct DUser: Equatable { let uid: String; let email: String? }

    @Published private(set) var status: Status = .loading
    #if canImport(FirebaseAuth)
    private var handle: AuthStateDidChangeListenerHandle?
    #endif

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private init() { start() }

    func start() {
        // Skip Firebase in previews or when disabled
        if isPreview || !FeatureFlags.firebaseEnabled {
            status = .signedOut; return
        }
        #if canImport(FirebaseAuth)
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let u = user {
                    #if DEBUG
                    print("[Auth] Signed in (listener): \(u.uid) \(u.email ?? "")")
                    #endif
                    self?.status = .signedIn(user: .init(uid: u.uid, email: u.email))
                } else {
                    #if DEBUG
                    print("[Auth] Signed out (listener)")
                    #endif
                    self?.status = .signedOut
                }
            }
        }
        #else
        status = .signedOut
        #endif
    }

    func signIn(email: String, password: String) async throws {
        guard FeatureFlags.firebaseEnabled, !isPreview else { throw AuthError.disabled }
        #if canImport(FirebaseAuth)
        let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<AuthDataResult, Error>) in
            Auth.auth().signIn(withEmail: email, password: password) { res, err in
                if let err = err { cont.resume(throwing: err); return }
                cont.resume(returning: res!)
            }
        }
        #if DEBUG
        print("[Auth] SignIn success: \(result.user.uid) \(result.user.email ?? "")")
        #endif
        // Force UI gate to flip immediately (listener will also fire)
        status = .signedIn(user: .init(uid: result.user.uid, email: result.user.email))
        #else
        throw AuthError.unavailable
        #endif
    }

    func createAccount(email: String, password: String) async throws {
        guard FeatureFlags.firebaseEnabled, !isPreview else { throw AuthError.disabled }
        #if canImport(FirebaseAuth)
        let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<AuthDataResult, Error>) in
            Auth.auth().createUser(withEmail: email, password: password) { res, err in
                if let err = err { cont.resume(throwing: err); return }
                cont.resume(returning: res!)
            }
        }
        #if DEBUG
        print("[Auth] CreateAccount success: \(result.user.uid) \(result.user.email ?? "")")
        #endif
        status = .signedIn(user: .init(uid: result.user.uid, email: result.user.email))
        #else
        throw AuthError.unavailable
        #endif
    }

    func signOut() throws {
        guard FeatureFlags.firebaseEnabled, !isPreview else { status = .signedOut; return }
        #if canImport(FirebaseAuth)
        try Auth.auth().signOut()
        #if DEBUG
        print("[Auth] SignOut invoked")
        #endif
        status = .signedOut
        #endif
    }
    
    func sendPasswordReset(email: String) async throws {
        guard FeatureFlags.firebaseEnabled,
              !ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"].map({ $0 == "1" })! else {
            throw AuthError.disabled
        }
        #if canImport(FirebaseAuth)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            Auth.auth().sendPasswordReset(withEmail: email) { error in
                if let error = error { cont.resume(throwing: error) }
                else { cont.resume(returning: ()) }
            }
        }
        #endif
    }

    enum AuthError: LocalizedError {
        case disabled, unavailable
        var errorDescription: String? {
            switch self {
            case .disabled: return "Auth is disabled in this build."
            case .unavailable: return "FirebaseAuth is unavailable."
            }
        }
    }
}

// 12b-3: Apple link-or-sign-in for Firebase, attached to AuthState
#if canImport(FirebaseAuth) && canImport(AuthenticationServices)
extension AuthState {

    enum LinkOrSignInResult { case linked, signedIn }

    /// Converts an Apple credential into a Firebase credential and either links to the current user
    /// or signs in if no user is present. On success, mirrors providerIDs to /users/{uid}.
    @MainActor
    func linkOrSignIn(withApple appleCredential: ASAuthorizationAppleIDCredential, rawNonce: String) async throws -> LinkOrSignInResult {
        guard
            let tokenData = appleCredential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw NSError(domain: "AuthState", code: -10, userInfo: [NSLocalizedDescriptionKey: "Missing Apple identityToken"])
        }

        let oauth = OAuthProvider.appleCredential(withIDToken: idToken,
                                                  rawNonce: rawNonce,
                                                  fullName: appleCredential.fullName)

        return try await linkOrSignIn(with: oauth)
    }

    /// Generic helper we’ll reuse for Google in 12c.
    @MainActor
    func linkOrSignIn(with oauth: AuthCredential) async throws -> LinkOrSignInResult {
        if let user = Auth.auth().currentUser {
            do {
                _ = try await user.link(with: oauth)
                try await UserProfileService.shared.refreshProviderIDsFromAuth()
                return .linked
            } catch let err as NSError
                    where err.domain == AuthErrorDomain &&
                          err.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                // That credential is tied to a different account; sign into that account instead.
                _ = try await Auth.auth().signIn(with: oauth)
                try await UserProfileService.shared.refreshProviderIDsFromAuth()
                return .signedIn
            }
        } else {
            _ = try await Auth.auth().signIn(with: oauth)
            try await UserProfileService.shared.refreshProviderIDsFromAuth()
            return .signedIn
        }
    }
    // 12c-3: Google link-or-sign-in using tokens
    @MainActor
    func linkOrSignInWithGoogle(idToken: String, accessToken: String) async throws -> LinkOrSignInResult {
        let cred = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        return try await linkOrSignIn(with: cred)
    }

}
#endif
