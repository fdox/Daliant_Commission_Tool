//
//  OrgService.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/4/25.
//

import Foundation
import SwiftData

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
final class OrgService {
    static let shared = OrgService()

    func ensureAndSeedLocalOrg(context: ModelContext) async throws {
        // Skip network work in previews or if Firebase is disabled.
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" || !FeatureFlags.firebaseEnabled {
            try ensureLocalIfNeeded(context: context, name: "My Organization")
            return
        }

        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "Auth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "No signed-in user"])
        }

        let db = Firestore.firestore()
        let coll = db.collection("orgs")
        let query = coll.whereField("ownerUid", isEqualTo: user.uid).limit(to: 1)

        // --- Read (bridged to async) ---
        let snap: QuerySnapshot = try await withCheckedThrowingContinuation { cont in
            query.getDocuments { snapshot, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let snapshot = snapshot else {
                    cont.resume(throwing: NSError(domain: "Firestore", code: -1,
                                                  userInfo: [NSLocalizedDescriptionKey: "No snapshot returned"]))
                    return
                }
                cont.resume(returning: snapshot)
            }
        }

        var orgName: String
        if let doc = snap.documents.first {
            orgName = (doc.data()["name"] as? String) ?? defaultName(for: user.email)
            #if DEBUG
            print("[Org] Remote org exists: \(orgName)")
            #endif
        } else {
            // --- Create (bridged to async) ---
            let orgId = user.uid         // single-org: key by owner uid
            orgName = defaultName(for: user.email)
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                coll.document(orgId).setData([
                    "id": orgId,
                    "name": orgName,
                    "ownerUid": user.uid,
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true) { error in
                    if let error = error { cont.resume(throwing: error) }
                    else { cont.resume(returning: ()) }
                }
            }

            #if DEBUG
            print("[Org] Created remote org: \(orgName)")
            #endif
        }

        // Mirror to local SwiftData: keep exactly one Org
        try replaceLocalOrg(withName: orgName, context: context)

        #else
        try ensureLocalIfNeeded(context: context, name: "My Organization")
        #endif
    }

    // MARK: - Local helpers (keep your existing ones; shown for completeness)
    private func replaceLocalOrg(withName name: String, context: ModelContext) throws {
        let all = try context.fetch(FetchDescriptor<Org>())
        for o in all { context.delete(o) }
        context.insert(Org(name: name))
        try context.save()
    }
    private func ensureLocalIfNeeded(context: ModelContext, name: String) throws {
        let all = try context.fetch(FetchDescriptor<Org>())
        if all.isEmpty {
            context.insert(Org(name: name))
            try context.save()
        }
    }
    private func defaultName(for email: String?) -> String {
        guard let email, let handle = email.split(separator: "@").first else { return "My Organization" }
        return handle.capitalized + " Org"
    }
    
    // MARK: - Business Info Sync
    
    /// Syncs business information from local Org to Firestore
    func syncBusinessInfoToFirestore(org: Org) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else { return }
        guard let ownerUid = org.ownerUid else { return }
        
        let db = Firestore.firestore()
        let orgRef = db.collection("orgs").document(ownerUid)
        
        var businessData: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        // Add business fields if they exist
        if let businessName = org.businessName { businessData["businessName"] = businessName }
        if let addressLine1 = org.addressLine1 { businessData["addressLine1"] = addressLine1 }
        if let addressLine2 = org.addressLine2 { businessData["addressLine2"] = addressLine2 }
        if let city = org.city { businessData["city"] = city }
        if let state = org.state { businessData["state"] = state }
        if let zipCode = org.zipCode { businessData["zipCode"] = zipCode }
        
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            orgRef.setData(businessData, merge: true) { error in
                if let error = error { cont.resume(throwing: error) }
                else { cont.resume(returning: ()) }
            }
        }
        #endif
    }
    
    /// Loads business information from Firestore to local Org
    func loadBusinessInfoFromFirestore(org: Org) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else { return }
        guard let ownerUid = org.ownerUid else { return }
        
        let db = Firestore.firestore()
        let orgRef = db.collection("orgs").document(ownerUid)
        
        let doc = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<DocumentSnapshot, Error>) in
            orgRef.getDocument { doc, error in
                if let error = error { cont.resume(throwing: error) }
                else { cont.resume(returning: doc!) }
            }
        }
        
        if let data = doc.data() {
            org.businessName = data["businessName"] as? String
            org.addressLine1 = data["addressLine1"] as? String
            org.addressLine2 = data["addressLine2"] as? String
            org.city = data["city"] as? String
            org.state = data["state"] as? String
            org.zipCode = data["zipCode"] as? String
        }
        #endif
    }
}
