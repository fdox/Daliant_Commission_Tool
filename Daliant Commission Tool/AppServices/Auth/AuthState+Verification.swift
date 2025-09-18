//
//  AuthState+Verification.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/13/25.
//

import Foundation
import FirebaseAuth

extension AuthState {

    /// True if current user has verified email or a linked phone credential.
    var isVerified: Bool { isEmailVerified || hasPhoneCredential }

    var isEmailVerified: Bool {
        Auth.auth().currentUser?.isEmailVerified ?? false
    }

    var hasPhoneCredential: Bool {
        let user = Auth.auth().currentUser
        if let phone = user?.phoneNumber, !phone.isEmpty { return true }
        // ProviderID "phone" when a phone credential is linked.
        return user?.providerData.contains(where: { $0.providerID == "phone" }) ?? false
    }

    @MainActor
    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthState", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "No current user"])
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            user.sendEmailVerification { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: ()) }
            }
        }
    }

    @MainActor
    func reloadCurrentUser() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            user.reload { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: ()) }
            }
        }
    }
    
    // MARK: - Phone linking

    @MainActor
    func linkWithPhone(verificationID: String, code: String) async throws -> User {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthState", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "No current user"])
        }
        let credential = PhoneAuthProvider.provider()
            .credential(withVerificationID: verificationID, verificationCode: code)

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<User, Error>) in
            user.link(with: credential) { result, error in
                if let error = error as NSError? {
                    // If phone already linked to this account, treat as success.
                    if error.code == AuthErrorCode.providerAlreadyLinked.rawValue {
                        cont.resume(returning: user)
                        return
                    }
                    cont.resume(throwing: error)
                    return
                }
                if let linkedUser = result?.user {
                    cont.resume(returning: linkedUser)
                } else {
                    cont.resume(throwing: NSError(domain: "AuthState", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Link result missing user"]))
                }
            }
        }
    }
    @MainActor
    func refreshProviderIDsFromAuth() async throws {
        try await UserProfileService.shared.refreshProviderIDsFromAuth()
    }
}
