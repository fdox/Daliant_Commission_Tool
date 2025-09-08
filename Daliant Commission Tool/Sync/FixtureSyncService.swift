//
//  FixtureSyncService.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/5/25.
//

//
//  FixtureSyncService.swift
//  Daliant Commission Tool
//
//  11e-1: Minimal pull/push sync for fixtures by current user.
//  - Pulls all fixtures where ownerUid == current user
//  - Upserts into SwiftData under the matching local project
//  - Pushes a single fixture (bump local updatedAt first)
//  - Fully gated: safe in Previews and when Firebase is disabled
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
final class FixtureSyncService {
    static let shared = FixtureSyncService()
    private init() {}

    // MARK: Pull all fixtures for current user
    func pullAllForCurrentUser(context: ModelContext) async throws {
        guard FeatureFlags.firebaseEnabled, !Self.isPreview else { return }
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "Auth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "No signed-in user"])
        }

        let db = Firestore.firestore()
        let coll = db.collection("fixtures")
        let query = coll.whereField("ownerUid", isEqualTo: user.uid)

        #if DEBUG
        print("[FixSync] Pull start for uid=\(user.uid)")
        #endif

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

        var allProjects = try context.fetch(FetchDescriptor<Item>())
        for doc in snapshot.documents {
            guard let remote = FixtureDoc.make(from: doc) else { continue }
            guard let projectUUID = UUID(uuidString: remote.projectId),
                  let project = allProjects.first(where: { $0.id == projectUUID }) else {
                #if DEBUG
                print("[FixSync] Skipping fixture doc without local project: \(remote.projectId)")
                #endif
                continue
            }

            // Find a matching local fixture by serial (preferred) or shortAddress
            var local: Fixture?
            if let s = remote.serial?.lowercased(), !s.isEmpty {
                local = project.fixtures.first(where: { ($0.serial?.lowercased() ?? "") == s })
            }
            if local == nil {
                local = project.fixtures.first(where: { $0.shortAddress == remote.shortAddress })
            }

            if let local {
                if shouldApplyServer(localUpdatedAt: local.updatedAt, serverUpdatedAt: remote.updatedAt) {
                    apply(doc: remote, to: local)
                }
            } else {
                // Create new and attach to project
                let f = Fixture(
                    label: remote.label,
                    shortAddress: remote.shortAddress,
                    groups: UInt16(remote.groups ?? 0),
                    room: remote.room,
                    serial: remote.serial,
                    dtTypeRaw: remote.dtTypeRaw,
                    commissionedAt: remote.commissionedAt,
                    notes: remote.notes,
                    project: project
                )
                f.updatedAt = remote.updatedAt ?? Date()
                project.fixtures.append(f)
            }
        }

        // 11f: collapse any local duplicates by serial (project scope)
        for project in allProjects {
            dedupeSerials(in: project, context: context)
        }
        try context.save()
        #if DEBUG
        print("[FixSync] Pull finished. Applied \(snapshot.documents.count) docs.")
        #endif

        #endif
    }

    // MARK: Push one fixture
    func push(_ fixture: Fixture, context: ModelContext) async throws {
        guard FeatureFlags.firebaseEnabled, !Self.isPreview else { return }
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "Auth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "No signed-in user"])
        }
        guard let project = fixture.project else {
            throw NSError(domain: "FixtureSync", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Fixture has no project relationship"])
        }

        let db = Firestore.firestore()
        let coll = db.collection("fixtures")
        let docId = makeDocId(for: fixture, projectId: project.id)
        let ref = coll.document(docId)

        // Bump local updatedAt/updatedBy so UI feels immediate
        fixture.updatedAt = Date()
        #if canImport(FirebaseAuth)
        fixture.updatedBy = Auth.auth().currentUser?.uid
        #endif
        try context.save()


        var data: [String: Any] = [
            "id": docId,
            "ownerUid": user.uid,
            "projectId": project.id.uuidString.lowercased(),
            "label": fixture.label,
            "shortAddress": fixture.shortAddress,
            "groups": Int(fixture.groups),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        data["updatedBy"] = user.uid


        if let rm = fixture.room, !rm.isEmpty { data["room"] = rm }
        if let s = fixture.serial, !s.isEmpty { data["serial"] = s }
        if let dt = fixture.dtTypeRaw, !dt.isEmpty { data["dtTypeRaw"] = dt }
        if let c = fixture.commissionedAt { data["commissionedAt"] = Timestamp(date: c) }
        if let n = fixture.notes, !n.isEmpty { data["notes"] = n }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ref.setData(data, merge: true) { err in
                if let err { cont.resume(throwing: err) } else { cont.resume(returning: ()) }
            }
        }
        
#if DEBUG
print("[FixSync] Pushed fixture \(docId)")
#endif

        // 11f: addr→serial cleanup (if serial is present, remove the addr doc variant)
        let addrDocId = "fixture-\(project.id.uuidString.lowercased())-addr-\(fixture.shortAddress)"
        if addrDocId != docId {
            #if canImport(FirebaseFirestore)
            let addrRef = coll.document(addrDocId)
            _ = try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                addrRef.delete { _ in cont.resume(returning: ()) }  // ignore errors
            }
            #endif
        }

        // 11f: dedupe locally in case a duplicate object was created
        dedupeSerials(in: project, context: context)
        try? context.save()
//
        #endif
    }
    
    // MARK: Delete (hard)
    // Deletes locally first (so it works when Firebase is OFF), then best-effort removes remote doc(s).
    func delete(_ fixture: Fixture, context: ModelContext) async throws {
        // Capture IDs before we delete local
        let projectId = fixture.project?.id ?? UUID()
        let primaryId = makeDocId(for: fixture, projectId: projectId)
        let addrId = "fixture-\(projectId.uuidString.lowercased())-addr-\(fixture.shortAddress)"

        // Local remove
        context.delete(fixture)
        try context.save()

        guard FeatureFlags.firebaseEnabled else { return }
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        // Best effort: delete both primary and addr variant (covers addr→serial migrations)
        for id in Set([primaryId, addrId]) {
            let ref = db.collection("fixtures").document(id)
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                ref.delete { err in
                    if let err { cont.resume(throwing: err) } else { cont.resume(returning: ()) }
                }
            }
        }
        #endif
    }
    
    // MARK: Dedupe (local-only; project scope; serial-based)
    private func dedupeSerials(in project: Item, context: ModelContext) {
        var bySerial: [String: Fixture] = [:]
        var toDelete: [Fixture] = []

        for f in project.fixtures {
            guard let s = f.serial?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  !s.isEmpty else { continue }
            if let existing = bySerial[s] {
                let fTime = f.updatedAt?.timeIntervalSince1970 ?? 0
                let eTime = existing.updatedAt?.timeIntervalSince1970 ?? 0
                if fTime >= eTime {
                    toDelete.append(existing)
                    bySerial[s] = f
                } else {
                    toDelete.append(f)
                }
            } else {
                bySerial[s] = f
            }
        }

        for d in toDelete { context.delete(d) }
        if !toDelete.isEmpty {
            #if DEBUG
            print("[FixSync] Dedupe removed \(toDelete.count) duplicate fixture(s) in project \(project.id)")
            #endif
        }
    }

    // MARK: Helpers

    private func shouldApplyServer(localUpdatedAt: Date?, serverUpdatedAt: Date?) -> Bool {
        guard let s = serverUpdatedAt else { return false }
        guard let l = localUpdatedAt else { return true }
        // tolerate small clock drift; prefer server if strictly newer
        return s.timeIntervalSince1970 > l.timeIntervalSince1970 + 0.25
    }

    private func apply(doc: FixtureDoc, to item: Fixture) {
        item.label = doc.label
        item.shortAddress = doc.shortAddress
        item.groups = UInt16(doc.groups ?? Int(item.groups))
        item.room = doc.room
        item.serial = doc.serial
        item.dtTypeRaw = doc.dtTypeRaw
        item.commissionedAt = doc.commissionedAt
        item.notes = doc.notes
        item.updatedAt = doc.updatedAt ?? Date()
        item.updatedBy = doc.updatedBy

    }

    private static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private func makeDocId(for fixture: Fixture, projectId: UUID) -> String {
        let pid = projectId.uuidString.lowercased()
        if let s = fixture.serial?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            return "fixture-\(pid)-ser-\(slug(s))"
        } else {
            return "fixture-\(pid)-addr-\(fixture.shortAddress)"
        }
    }

    private func slug(_ s: String) -> String {
        let lowered = s.lowercased()
        let allowed = lowered.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(allowed))
    }
}

// A unique, file-private document mapper to avoid name collisions
fileprivate struct FixtureDoc {
    let id: String
    let ownerUid: String
    let projectId: String
    let label: String
    let shortAddress: Int
    let groups: Int?
    let room: String?
    let serial: String?
    let dtTypeRaw: String?
    let commissionedAt: Date?
    let notes: String?
    let updatedAt: Date?
    let updatedBy: String?


    #if canImport(FirebaseFirestore)
    static func make(from snapshot: DocumentSnapshot) -> FixtureDoc? {
        guard let data = snapshot.data() else { return nil }
        let id = (data["id"] as? String) ?? snapshot.documentID
        let ownerUid = data["ownerUid"] as? String ?? ""
        let projectId = (data["projectId"] as? String) ?? ""
        let label = (data["label"] as? String) ?? "Untitled"
        let shortAddress = (data["shortAddress"] as? Int)
            ?? (data["shortAddress"] as? NSNumber)?.intValue
            ?? 0
        let groups = (data["groups"] as? Int) ?? (data["groups"] as? NSNumber)?.intValue
        let room = data["room"] as? String
        let serial = data["serial"] as? String
        let dtTypeRaw = data["dtTypeRaw"] as? String
        let commissionedAt: Date? = (data["commissionedAt"] as? Timestamp)?.dateValue()
        let updatedAt: Date? = (data["updatedAt"] as? Timestamp)?.dateValue()
        let updatedBy = data["updatedBy"] as? String
        let notes = data["notes"] as? String

        if id.isEmpty || ownerUid.isEmpty || projectId.isEmpty { return nil }
        return FixtureDoc(id: id, ownerUid: ownerUid, projectId: projectId,
                          label: label, shortAddress: shortAddress, groups: groups,
                          room: room, serial: serial, dtTypeRaw: dtTypeRaw,
                          commissionedAt: commissionedAt, notes: notes, updatedAt: updatedAt, updatedBy: updatedBy)
    }
    #else
    static func make(from snapshot: Any) -> FixtureDoc? { nil }
    #endif
}
