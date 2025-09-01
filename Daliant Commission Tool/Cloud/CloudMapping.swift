//
//  CloudMapping.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/31/25.
//

// Cloud/CloudMapping.swift
// Step 10a — compile‑only mapping (DTOs ↔ CKRecord), no entitlements, no behavior change.

#if canImport(CloudKit)
import CloudKit
import Foundation
import SwiftData

extension CloudMapper {
    /// Convenience: build a Project record straight from a SwiftData `Item`.
    static func projectRecord(from model: Item, in zoneID: CKRecordZone.ID) -> CKRecord {
        let rec = CKRecord(recordType: CloudSchema.RecordType.project,
                           recordID: CloudIDs.projectRecordID(model.id, in: zoneID))
        rec[CloudSchema.ProjectKeys.id] = model.id.uuidString as CKRecordValue
        rec[CloudSchema.ProjectKeys.title] = model.title as CKRecordValue
        if let d = model.createdAt { rec[CloudSchema.ProjectKeys.createdAt] = d as CKRecordValue }
        if let v = model.contactFirstName { rec[CloudSchema.ProjectKeys.contactFirstName] = v as CKRecordValue }
        if let v = model.contactLastName  { rec[CloudSchema.ProjectKeys.contactLastName]  = v as CKRecordValue }
        if let v = model.siteAddress      { rec[CloudSchema.ProjectKeys.siteAddress]      = v as CKRecordValue }
        if let v = model.controlSystemRaw { rec[CloudSchema.ProjectKeys.controlSystemRaw] = v as CKRecordValue }
        return rec
    }

    /// Convenience: build a Fixture record straight from a SwiftData `Fixture`.
    static func fixtureRecord(from model: Fixture, project: Item, in zoneID: CKRecordZone.ID) -> CKRecord {
        let rec = CKRecord(recordType: CloudSchema.RecordType.fixture,
                           recordID: CloudIDs.fixtureRecordID(projectID: project.id,
                                                              serial: model.serial,
                                                              shortAddress: model.shortAddress,
                                                              in: zoneID))
        rec[CloudSchema.FixtureKeys.label] = model.label as CKRecordValue
        rec[CloudSchema.FixtureKeys.shortAddress] = NSNumber(value: model.shortAddress)
        rec[CloudSchema.FixtureKeys.groups] = NSNumber(value: Int(model.groups))
        if let v = model.room           { rec[CloudSchema.FixtureKeys.room]           = v as CKRecordValue }
        if let v = model.serial         { rec[CloudSchema.FixtureKeys.serial]         = v as CKRecordValue }
        if let v = model.dtTypeRaw      { rec[CloudSchema.FixtureKeys.dtTypeRaw]      = v as CKRecordValue }
        if let v = model.commissionedAt { rec[CloudSchema.FixtureKeys.commissionedAt] = v as CKRecordValue }
        if let v = model.notes          { rec[CloudSchema.FixtureKeys.notes]          = v as CKRecordValue }
        let pref = CKRecord.Reference(recordID: CloudIDs.projectRecordID(project.id, in: zoneID), action: .none)
        rec[CloudSchema.FixtureKeys.projectRef] = pref
        return rec
    }
}

// MARK: - Record/field constants

enum CloudSchema {
    enum RecordType {
        static let project = "Project"
        static let fixture = "Fixture"
    }

    enum ProjectKeys {
        static let id = "id"
        static let title = "title"
        static let createdAt = "createdAt"
        static let contactFirstName = "contactFirstName"
        static let contactLastName  = "contactLastName"
        static let siteAddress = "siteAddress"
        static let controlSystemRaw = "controlSystemRaw"
        // No fixtures array on the record; fixtures are separate records with a reference.
    }

    enum FixtureKeys {
        static let projectRef = "project"   // CKRecord.Reference → Project
        static let label = "label"
        static let shortAddress = "shortAddress"
        static let groups = "groups"        // stored as Int
        static let room = "room"
        static let serial = "serial"
        static let dtTypeRaw = "dtTypeRaw"
        static let commissionedAt = "commissionedAt"
        static let notes = "notes"
    }
}

// MARK: - Zone & ID helpers (deterministic)

enum CloudIDs {
    /// Zone ID: Org-<orgUUID.lowercased()>
    static func orgZoneID(for orgID: UUID) -> CKRecordZone.ID {
        let zoneName = "Org-\(orgID.uuidString.lowercased())"
        return CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    /// Record name: project-<projectUUID.lowercased()>
    static func projectRecordName(_ projectID: UUID) -> String {
        "project-\(projectID.uuidString.lowercased())"
    }

    /// Record name:
    ///   fixture-<projectUUID>-ser-<serialSlug>
    ///   OR fixture-<projectUUID>-addr-<shortAddress>
    static func fixtureRecordName(projectID: UUID, serial: String?, shortAddress: Int) -> String {
        let base = "fixture-\(projectID.uuidString.lowercased())"
        if let s = serial?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            return base + "-ser-" + serialSlug(s)
        } else {
            return base + "-addr-\(shortAddress)"
        }
    }

    static func projectRecordID(_ projectID: UUID, in zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: projectRecordName(projectID), zoneID: zoneID)
    }

    static func fixtureRecordID(projectID: UUID, serial: String?, shortAddress: Int, in zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: fixtureRecordName(projectID: projectID, serial: serial, shortAddress: shortAddress),
                    zoneID: zoneID)
    }

    /// Lowercase; keep [a-z0-9-]; collapse others to single '-'; trim '-'.
    static func serialSlug(_ raw: String) -> String {
        let lower = raw.lowercased()
        var out = [Character]()
        var lastWasDash = false
        for ch in lower {
            if ch.isNumber || (ch >= "a" && ch <= "z") {
                out.append(ch); lastWasDash = false
            } else if ch == "-" {
                out.append(ch); lastWasDash = false
            } else if !lastWasDash {
                out.append("-"); lastWasDash = true
            }
        }
        // trim leading/trailing '-'
        while out.first == "-" { out.removeFirst() }
        while out.last  == "-" { out.removeLast() }
        return String(out)
    }
}

// MARK: - Mapper (DTOs ↔ CKRecord)

enum CloudMapper {
    // MARK: DTO → CKRecord

    /// Build a Project CKRecord in the given Org zone.
    static func projectRecord(from dto: ProjectDTO, in zoneID: CKRecordZone.ID) -> CKRecord {
        let rec = CKRecord(recordType: CloudSchema.RecordType.project,
                           recordID: CloudIDs.projectRecordID(dto.id, in: zoneID))
        rec[CloudSchema.ProjectKeys.id] = dto.id.uuidString as CKRecordValue
        rec[CloudSchema.ProjectKeys.title] = dto.title as CKRecordValue
        if let d = dto.createdAt { rec[CloudSchema.ProjectKeys.createdAt] = d as CKRecordValue }
        if let v = dto.contactFirstName { rec[CloudSchema.ProjectKeys.contactFirstName] = v as CKRecordValue }
        if let v = dto.contactLastName  { rec[CloudSchema.ProjectKeys.contactLastName]  = v as CKRecordValue }
        if let v = dto.siteAddress      { rec[CloudSchema.ProjectKeys.siteAddress]      = v as CKRecordValue }
        if let v = dto.controlSystemRaw { rec[CloudSchema.ProjectKeys.controlSystemRaw] = v as CKRecordValue }
        return rec
    }

    /// Build a Fixture CKRecord with a reference to its parent Project.
    static func fixtureRecord(from dto: FixtureDTO, project: ProjectDTO, in zoneID: CKRecordZone.ID) -> CKRecord {
        let rec = CKRecord(recordType: CloudSchema.RecordType.fixture,
                           recordID: CloudIDs.fixtureRecordID(projectID: project.id,
                                                              serial: dto.serial,
                                                              shortAddress: dto.shortAddress,
                                                              in: zoneID))

        // Required
        rec[CloudSchema.FixtureKeys.label] = dto.label as CKRecordValue
        rec[CloudSchema.FixtureKeys.shortAddress] = NSNumber(value: dto.shortAddress)
        rec[CloudSchema.FixtureKeys.groups] = NSNumber(value: Int(dto.groups))

        // Optionals
        if let v = dto.room            { rec[CloudSchema.FixtureKeys.room]           = v as CKRecordValue }
        if let v = dto.serial          { rec[CloudSchema.FixtureKeys.serial]         = v as CKRecordValue }
        if let v = dto.dtTypeRaw       { rec[CloudSchema.FixtureKeys.dtTypeRaw]      = v as CKRecordValue }
        if let v = dto.commissionedAt  { rec[CloudSchema.FixtureKeys.commissionedAt] = v as CKRecordValue }
        if let v = dto.notes           { rec[CloudSchema.FixtureKeys.notes]          = v as CKRecordValue }

        // Reference to Project
        let pref = CKRecord.Reference(recordID: CloudIDs.projectRecordID(project.id, in: zoneID), action: .none)
        rec[CloudSchema.FixtureKeys.projectRef] = pref
        return rec
    }

    // MARK: CKRecord → DTO  (compile-only, via JSON shim to avoid relying on DTO memberwise init)

    static func projectDTO(from record: CKRecord) -> ProjectDTO? {
        guard record.recordType == CloudSchema.RecordType.project else { return nil }

        // id can come from field or be parsed from recordName
        let uuid: UUID? = {
            if let s = record[CloudSchema.ProjectKeys.id] as? String, let u = UUID(uuidString: s) { return u }
            let rn = record.recordID.recordName
            if rn.hasPrefix("project-"), let u = UUID(uuidString: String(rn.dropFirst("project-".count))) { return u }
            return nil
        }()

        guard let id = uuid,
              let title = record[CloudSchema.ProjectKeys.title] as? String
        else { return nil }

        // Build a JSON object matching ProjectDTO's keys.
        var obj: [String: Any] = [
            "id": id.uuidString,
            "title": title
        ]
        if let d = record[CloudSchema.ProjectKeys.createdAt] as? Date {
            obj["createdAt"] = ISO8601DateFormatter().string(from: d)
        }
        if let v = record[CloudSchema.ProjectKeys.contactFirstName] as? String { obj["contactFirstName"] = v }
        if let v = record[CloudSchema.ProjectKeys.contactLastName]  as? String { obj["contactLastName"]  = v }
        if let v = record[CloudSchema.ProjectKeys.siteAddress]      as? String { obj["siteAddress"]      = v }
        if let v = record[CloudSchema.ProjectKeys.controlSystemRaw] as? String { obj["controlSystemRaw"] = v }

        // Fixtures are separate records; ensure key exists if DTO expects it
        if obj["fixtures"] == nil { obj["fixtures"] = [] }

        return decodeDTO(ProjectDTO.self, fromJSONObject: obj)
    }

    static func fixtureDTO(from record: CKRecord) -> FixtureDTO? {
        guard record.recordType == CloudSchema.RecordType.fixture,
              let label = record[CloudSchema.FixtureKeys.label] as? String
        else { return nil }

        var obj: [String: Any] = ["label": label]

        // Required numeric fields
        if let n = record[CloudSchema.FixtureKeys.shortAddress] as? NSNumber {
            obj["shortAddress"] = n.intValue
        } else { return nil }

        if let n = record[CloudSchema.FixtureKeys.groups] as? NSNumber {
            obj["groups"] = n.intValue
        } else {
            obj["groups"] = 0
        }

        // Optionals
        if let v = record[CloudSchema.FixtureKeys.room]           as? String { obj["room"]           = v }
        if let v = record[CloudSchema.FixtureKeys.serial]         as? String { obj["serial"]         = v }
        if let v = record[CloudSchema.FixtureKeys.dtTypeRaw]      as? String { obj["dtTypeRaw"]      = v }
        if let d = record[CloudSchema.FixtureKeys.commissionedAt] as? Date   { obj["commissionedAt"] = ISO8601DateFormatter().string(from: d) }
        if let v = record[CloudSchema.FixtureKeys.notes]          as? String { obj["notes"]          = v }

        return decodeDTO(FixtureDTO.self, fromJSONObject: obj)
    }

    // MARK: Private JSON decode shim for DTOs (Codable)
    private static func decodeDTO<T: Decodable>(_ type: T.Type, fromJSONObject obj: [String: Any]) -> T? {
        guard JSONSerialization.isValidJSONObject(obj),
              let data = try? JSONSerialization.data(withJSONObject: obj, options: [])
        else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(T.self, from: data)
    }
}
#endif
