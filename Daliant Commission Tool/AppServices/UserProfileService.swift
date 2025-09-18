//
//  UserProfileService.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/8/25.
//

//
//  UserProfileService.swift
//  Daliant Commission Tool
//

import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// 12b-4: After auth events, mirror providerIDs (and identity) to /users/{uid}
@MainActor
func refreshProviderIDsFromAuth() async throws {
    #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseCore)
    guard FirebaseApp.app() != nil else { return }
    guard let u = Auth.auth().currentUser else { return }

    let providerIDs = u.providerData.map { $0.providerID }

    var payload: [String: Any] = [
        "providerIDs": providerIDs,
        "updatedAt": FieldValue.serverTimestamp()
    ]
    if let email = u.email { payload["email"] = email }
    if let name = u.displayName { payload["displayName"] = name }
    if let phone = u.phoneNumber { payload["phone"] = phone }

    try await Firestore.firestore()
        .collection("users")
        .document(u.uid)
        .setData(payload, merge: true)
    #endif
}

final class UserProfileService {
    static let shared = UserProfileService()
    private init() {}

    /// Idempotent: creates/updates /users/{uid} for the signed-in user.
    /// Skips silently in Previews (no Firebase) or when not signed in.
    func ensureProfile() async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseCore)
        // Skip if Firebase isn’t configured (Canvas/Previews)
        guard FirebaseApp.app() != nil else { return }
        guard let user = Auth.auth().currentUser else { return }

        let db = Firestore.firestore()
        let ref = db.collection("users").document(user.uid)

        do {
            // We can safely pre-read here because your /users rules authorize by uid (not resource fields).
            let snap = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<DocumentSnapshot, Error>) in
                ref.getDocument { snap, err in
                    if let err { cont.resume(throwing: err) }
                    else { cont.resume(returning: snap!) }
                }
            }

            var data: [String: Any] = [
                "uid": user.uid,
                "email": user.email as Any? ?? NSNull(),
                "displayName": user.displayName as Any? ?? NSNull(),
                "phone": user.phoneNumber as Any? ?? NSNull(),
                "providerIDs": user.providerData.map { $0.providerID },
                "updatedAt": FieldValue.serverTimestamp()
            ]
            if snap.exists == false {
                data["createdAt"] = FieldValue.serverTimestamp()
            }

            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                ref.setData(data, merge: true) { err in
                    if let err { cont.resume(throwing: err) } else { cont.resume(returning: ()) }
                }
            }
        } catch {
            #if DEBUG
            print("[UserProfile] ensureProfile failed: \(error.localizedDescription)")
            #endif
        }
        #else
        // Non-Firebase builds (Canvas) do nothing.
        #endif
    }
    @MainActor
    func setPhone(_ phone: String?) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Firestore.firestore().collection("users").document(uid)
        var data: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let phone, !phone.isEmpty {
            data["phone"] = phone
        } else {
            data["phone"] = FieldValue.delete()
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            ref.setData(data, merge: true) { error in
                #if DEBUG
                if let error { print("[UserProfile] setPhone error: \(error)") }
                else { print("[UserProfile] phone updated") }
                #endif
                cont.resume()
            }
        }
    }

}

// MARK: - Provider IDs sync (12b-4)
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif

extension UserProfileService {
    /// Mirror providerIDs (and identity fields) from Firebase Auth into `/users/{uid}`.
    @MainActor
    func refreshProviderIDsFromAuth() async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else { return }
        guard let u = Auth.auth().currentUser else { return }

        let providerIDs = u.providerData.map { $0.providerID }

        var payload: [String: Any] = [
            "providerIDs": providerIDs,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let email = u.email { payload["email"] = email }
        if let name = u.displayName { payload["displayName"] = name }
        if let phone = u.phoneNumber { payload["phone"] = phone }

        try await Firestore.firestore()
            .collection("users")
            .document(u.uid)
            .setData(payload, merge: true)
        #endif
    }
}
