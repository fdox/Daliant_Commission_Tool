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
        var businessData: [String: Any] = [:]
        if let doc = snap.documents.first {
            let data = doc.data()
            orgName = (data["name"] as? String) ?? defaultName(for: user.email)
            businessData = data
            #if DEBUG
            print("[Org] Remote org exists: \(orgName)")
            #endif
        } else {
            // --- Create (bridged to async) ---
            let orgId = generateShortOrgId()
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
            print("[Org] Created remote org: \(orgName) with ID: \(orgId)")
            #endif
        }

        // Mirror to local SwiftData: keep exactly one Org
        try replaceLocalOrg(withName: orgName, ownerUid: user.uid, businessData: businessData, context: context)

        #else
        try ensureLocalIfNeeded(context: context, name: "My Organization")
        #endif
    }

    // MARK: - Local helpers (keep your existing ones; shown for completeness)
    private func replaceLocalOrg(withName name: String, ownerUid: String? = nil, businessData: [String: Any] = [:], context: ModelContext) throws {
        let all = try context.fetch(FetchDescriptor<Org>())
        for o in all { context.delete(o) }
        let newOrg = Org(name: name)
        newOrg.ownerUid = ownerUid
        
        // Set business data from Firestore
        newOrg.shortId = businessData["id"] as? String
        newOrg.businessName = businessData["businessName"] as? String
        newOrg.addressLine1 = businessData["addressLine1"] as? String
        newOrg.addressLine2 = businessData["addressLine2"] as? String
        newOrg.city = businessData["city"] as? String
        newOrg.state = businessData["state"] as? String
        newOrg.zipCode = businessData["zipCode"] as? String
        
        context.insert(newOrg)
        try context.save()
    }
    private func ensureLocalIfNeeded(context: ModelContext, name: String, ownerUid: String? = nil) throws {
        let all = try context.fetch(FetchDescriptor<Org>())
        if all.isEmpty {
            let newOrg = Org(name: name)
            newOrg.ownerUid = ownerUid
            context.insert(newOrg)
            try context.save()
        }
    }
    private func defaultName(for email: String?) -> String {
        guard let email, let handle = email.split(separator: "@").first else { return "My Organization" }
        return handle.capitalized + " Org"
    }
    
    /// Generates a short, unique organization ID (6 characters)
    private func generateShortOrgId() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
    
    // MARK: - Business Info Sync
    
    /// Syncs business information from local Org to Firestore
    func syncBusinessInfoToFirestore(org: Org) async throws {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else { return }
        guard let ownerUid = org.ownerUid else { return }
        
        let db = Firestore.firestore()
        let coll = db.collection("orgs")
        let query = coll.whereField("ownerUid", isEqualTo: ownerUid).limit(to: 1)
        
        // Find the organization document
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
        
        guard let doc = snap.documents.first else {
            throw NSError(domain: "OrgService", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Organization not found"])
        }
        
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
            doc.reference.setData(businessData, merge: true) { error in
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
        let coll = db.collection("orgs")
        let query = coll.whereField("ownerUid", isEqualTo: ownerUid).limit(to: 1)
        
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
        
        if let doc = snap.documents.first, let data = doc.data() {
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
