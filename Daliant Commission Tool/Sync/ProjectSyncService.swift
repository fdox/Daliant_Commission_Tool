//
//  ProjectSyncService.swift
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

@MainActor
final class ProjectSyncService {
    static let shared = ProjectSyncService()

    // MARK: Pull all projects for current user
    func pullAllForCurrentUser(context: ModelContext) async throws {
        guard FeatureFlags.firebaseEnabled else { return }
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "Auth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "No signed-in user"])
        }

        let db = Firestore.firestore()
        let coll = db.collection("projects")
        let query = coll.whereField("ownerUid", isEqualTo: user.uid)

        let snapshot: QuerySnapshot = try await withCheckedThrowingContinuation { cont in
            query.getDocuments { snap, err in
                if let err { cont.resume(throwing: err) }
                else if let snap { cont.resume(returning: snap) }
                else {
                    cont.resume(throwing: NSError(domain: "Firestore", code: -1,
                                                  userInfo: [NSLocalizedDescriptionKey: "No snapshot"]))
                }
            }
        }

        // Upsert by stable UUID
        var allLocal = try context.fetch(FetchDescriptor<Item>())
        for doc in snapshot.documents {
            guard let remote = ProjectDoc.make(from: doc),
                  let uuid = UUID(uuidString: remote.id) else { continue }

            if let local = allLocal.first(where: { $0.id == uuid }) {
                // Last-writer-wins: apply server if newer
                if shouldApplyServer(localUpdatedAt: local.updatedAt, serverUpdatedAt: remote.updatedAt) {
                    apply(doc: remote, to: local)
                }
            } else {
                let item = Item(id: uuid,
                                title: remote.title,
                                createdAt: remote.createdAt,
                                updatedAt: remote.updatedAt)
                apply(doc: remote, to: item)
                context.insert(item)
                allLocal.append(item)
            }
        }
        // 11f fix: save changes (no per-project stamping here)
        try context.save()

        #endif
    }

    // MARK: Push one project
    func push(_ item: Item, context: ModelContext) async throws {
        guard FeatureFlags.firebaseEnabled else { return }
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "Auth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "No signed-in user"])
        }

        let db = Firestore.firestore()
        let coll = db.collection("projects")
        let docId = item.id.uuidString.lowercased()
        let ref = coll.document(docId)

        // Bump local updatedAt so UI feels immediate
        item.updatedAt = Date()
        #if canImport(FirebaseAuth)
        item.updatedBy = Auth.auth().currentUser?.uid
        #endif
        try context.save()

        var data: [String: Any] = [
            "id": docId,
            "ownerUid": user.uid,
            "title": item.title,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        data["updatedBy"] = user.uid
        // 11g: carry soft‑delete state
        if let a = item.archivedAt {
            data["archivedAt"] = Timestamp(date: a)
        } else {
            data["archivedAt"] = FieldValue.delete() // clear field when restoring
        }


        if let c = item.createdAt {
            data["createdAt"] = Timestamp(date: c)
        } else {
            data["createdAt"] = FieldValue.serverTimestamp()
        }

        if let f = item.contactFirstName, !f.isEmpty { data["contactFirstName"] = f }
        if let l = item.contactLastName,  !l.isEmpty { data["contactLastName"]  = l }
        if let a = item.siteAddress,      !a.isEmpty { data["siteAddress"]      = a }
        if let cs = item.controlSystemRaw,!cs.isEmpty{ data["controlSystemRaw"] = cs }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ref.setData(data, merge: true) { err in
                if let err { cont.resume(throwing: err) } else { cont.resume(returning: ()) }
            }
        }
        #endif
    }
    
    // MARK: Delete (purge)
    func delete(_ item: Item, context: ModelContext) async throws {
        // Always remove local first in case Firebase is off
        context.delete(item)
        try context.save()

        guard FeatureFlags.firebaseEnabled else { return }

        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let ref = db.collection("projects").document(item.id.uuidString.lowercased())
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ref.delete { err in
                if let err { cont.resume(throwing: err) } else { cont.resume(returning: ()) }
            }
        }
        #endif
    }

    // MARK: Helpers

    private func shouldApplyServer(localUpdatedAt: Date?, serverUpdatedAt: Date?) -> Bool {
        guard let s = serverUpdatedAt else { return false } // nothing to apply
        guard let l = localUpdatedAt else { return true }
        return s > l
    }

    private func apply(doc: ProjectDoc, to item: Item) {
        item.title = doc.title
        item.createdAt = doc.createdAt ?? item.createdAt
        item.updatedAt = doc.updatedAt ?? item.updatedAt
        item.updatedBy = doc.updatedBy
        item.archivedAt = doc.archivedAt
        item.contactFirstName = doc.contactFirstName
        item.contactLastName  = doc.contactLastName
        item.siteAddress      = doc.siteAddress
        item.controlSystemRaw = doc.controlSystemRaw
    }
}

// A unique, file-private document mapper to avoid name collisions
fileprivate struct ProjectDoc {
    let id: String
    let ownerUid: String
    let title: String
    let createdAt: Date?
    let updatedAt: Date?
    let updatedBy: String?
    let archivedAt: Date?
    let contactFirstName: String?
    let contactLastName: String?
    let siteAddress: String?
    let controlSystemRaw: String?

    static func make(from snapshot: DocumentSnapshot) -> ProjectDoc? {
        guard let data = snapshot.data() else { return nil }
        let id = (data["id"] as? String) ?? snapshot.documentID
        let ownerUid = data["ownerUid"] as? String ?? ""
        let title = data["title"] as? String ?? "Untitled"
        let createdAt: Date? = (data["createdAt"] as? Timestamp)?.dateValue()
        let updatedAt: Date? = (data["updatedAt"] as? Timestamp)?.dateValue()
        let updatedBy = data["updatedBy"] as? String
        let archivedAt: Date? = (data["archivedAt"] as? Timestamp)?.dateValue()
        let f = data["contactFirstName"] as? String
        let l = data["contactLastName"]  as? String
        let a = data["siteAddress"]      as? String
        let cs = data["controlSystemRaw"] as? String

        if id.isEmpty || ownerUid.isEmpty { return nil }
        return ProjectDoc(id: id, ownerUid: ownerUid, title: title,
                          createdAt: createdAt, updatedAt: updatedAt, updatedBy: updatedBy, archivedAt: archivedAt,
                          contactFirstName: f, contactLastName: l,
                          siteAddress: a, controlSystemRaw: cs)
    }
}
