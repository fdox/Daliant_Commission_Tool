// Cloud/OrgZone.swift
// Step 10c — Create/find the Org zone and its single zone‑wide share.
// Uses closure-based CloudKit APIs wrapped in async helpers for broad SDK compatibility.

#if canImport(CloudKit)
import CloudKit
import Foundation

enum OrgZone {
    // Reuse deterministic zone ID from 10a
    static func zoneID(for orgID: UUID) -> CKRecordZone.ID {
        CloudIDs.orgZoneID(for: orgID)
    }

    /// Ensure the custom Org zone exists in the owner's private DB.
    static func ensureZone(orgID: UUID) async throws -> CKRecordZone {
        let id = zoneID(for: orgID)

        // Try fetch first
        do {
            return try await fetchZone(withID: id)
        } catch {
            // If not found, create; on any save race, fetch again.
            if let ck = error as? CKError, ck.code == .zoneNotFound {
                do {
                    return try await saveZone(CKRecordZone(zoneID: id))
                } catch {
                    // Race condition: zone may have been created in the meantime.
                    if let z = try? await fetchZone(withID: id) { return z }
                    throw error
                }
            }
            throw error
        }
    }

    /// Fetch the zone‑wide share if it already exists (1 per zone).
    static func existingShare(for zoneID: CKRecordZone.ID) async throws -> CKShare? {
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        do {
            let rec = try await fetchRecord(withID: shareID)
            return rec as? CKShare
        } catch {
            if let ck = error as? CKError, ck.code == .unknownItem { return nil }
            throw error
        }
    }

    /// Ensure a **zone‑wide** CKShare exists for this zone.
    static func ensureShare(
        for zone: CKRecordZone,
        title: String? = nil,
        publicPermission: CKShare.ParticipantPermission = .readWrite
    ) async throws -> CKShare {
        if let existing = try await existingShare(for: zone.zoneID) {
            return existing
        }

        let share = CKShare(recordZoneID: zone.zoneID)
        share.publicPermission = publicPermission
        if let t = title {
            share[CKShare.SystemFieldKey.title] = t as CKRecordValue
        }

        let saved = try await saveRecord(share)
        // CKShare is a CKRecord subclass; cast is safe here.
        return saved as! CKShare
    }
}

// MARK: - Async wrappers over closure-based CloudKit APIs

private func fetchZone(withID id: CKRecordZone.ID) async throws -> CKRecordZone {
    try await withCheckedThrowingContinuation { cont in
        CloudConfig.privateDB.fetch(withRecordZoneID: id) { zone, error in
            if let z = zone { cont.resume(returning: z) }
            else if let error = error { cont.resume(throwing: error) }
            else {
                cont.resume(throwing: NSError(domain: "OrgZone", code: -1,
                                              userInfo: [NSLocalizedDescriptionKey: "Unknown zone fetch error"]))
            }
        }
    }
}

private func saveZone(_ zone: CKRecordZone) async throws -> CKRecordZone {
    try await withCheckedThrowingContinuation { cont in
        CloudConfig.privateDB.save(zone) { saved, error in
            if let z = saved { cont.resume(returning: z) }
            else if let error = error { cont.resume(throwing: error) }
            else {
                cont.resume(throwing: NSError(domain: "OrgZone", code: -2,
                                              userInfo: [NSLocalizedDescriptionKey: "Unknown zone save error"]))
            }
        }
    }
}

private func fetchRecord(withID id: CKRecord.ID) async throws -> CKRecord {
    try await withCheckedThrowingContinuation { cont in
        CloudConfig.privateDB.fetch(withRecordID: id) { record, error in
            if let r = record { cont.resume(returning: r) }
            else if let error = error { cont.resume(throwing: error) }
            else {
                cont.resume(throwing: NSError(domain: "OrgZone", code: -3,
                                              userInfo: [NSLocalizedDescriptionKey: "Unknown record fetch error"]))
            }
        }
    }
}

private func saveRecord(_ record: CKRecord) async throws -> CKRecord {
    try await withCheckedThrowingContinuation { cont in
        CloudConfig.privateDB.save(record) { saved, error in
            if let r = saved { cont.resume(returning: r) }
            else if let error = error { cont.resume(throwing: error) }
            else {
                cont.resume(throwing: NSError(domain: "OrgZone", code: -4,
                                              userInfo: [NSLocalizedDescriptionKey: "Unknown record save error"]))
            }
        }
    }
}
#endif
