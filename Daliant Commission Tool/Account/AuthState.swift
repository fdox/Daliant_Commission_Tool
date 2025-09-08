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
