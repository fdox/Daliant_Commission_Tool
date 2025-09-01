//
//  CloudStore.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/1/25.
//

// Cloud/CloudStore.swift
// Step 10d — S1: minimal sync scaffold (manual push/pull; no CKSyncEngine yet)
//Added to new repo

#if canImport(CloudKit)
import CloudKit
import SwiftData
import Foundation

@MainActor
final class CloudStore: ObservableObject {
    static let shared = CloudStore()
    private init() {}

    // MARK: Public entry points

    /// Push all local Projects + Fixtures to the Org zone.
    func pushAll(context: ModelContext) async -> String {
        let acct = AccountPrefs.load()
        guard let orgID = acct.orgID else { return "No Org selected." }
        guard acct.mode != .guestLocal else { return "Guest mode: push disabled." }

        let zoneID = CloudIDs.orgZoneID(for: orgID)
        let db = database(for: acct.mode)

        // Owner ensures the zone exists; member assumes it’s shared to them.
        if acct.mode == .orgOwner {
            do { _ = try await OrgZone.ensureZone(orgID: orgID) } catch {
                return "Zone ensure failed: \(error.localizedDescription)"
            }
        }

        // Collect records
        do {
            let projects = try context.fetch(FetchDescriptor<Item>())
            var records: [CKRecord] = []
            for p in projects {
                records.append(CloudMapper.projectRecord(from: p, in: zoneID))
                for f in p.fixtures {
                    records.append(CloudMapper.fixtureRecord(from: f, project: p, in: zoneID))
                }
            }

            if records.isEmpty { return "Nothing to push." }

            // Save in batches to be friendly
            let batchSize = 200
            var savedCount = 0
            for chunk in records.chunked(into: batchSize) {
                let (s, err) = await modifyRecords(chunk, in: db)
                savedCount += s
                if let err { return "Push error: \(err.localizedDescription) (saved \(savedCount))" }
            }
            return "Pushed \(savedCount) records to \(acct.mode == .orgOwner ? "Private" : "Shared") DB."
        } catch {
            return "Local fetch failed: \(error.localizedDescription)"
        }
    }

    /// Pull all Projects + Fixtures in the Org zone and merge into SwiftData.
    func pullAll(context: ModelContext) async -> String {
        let acct = AccountPrefs.load()
        guard let orgID = acct.orgID else { return "No Org selected." }
        guard acct.mode != .guestLocal else { return "Guest mode: pull disabled." }

        let zoneID = CloudIDs.orgZoneID(for: orgID)
        let db = database(for: acct.mode)

        do {
            let projectRecs = try await fetchAllRecords(ofType: CloudSchema.RecordType.project, in: zoneID, db: db)
            let fixtureRecs = try await fetchAllRecords(ofType: CloudSchema.RecordType.fixture, in: zoneID, db: db)

            // Merge: projects by UUID; fixtures by serial OR shortAddress.
            var mergedProjects = 0
            for r in projectRecs {
                if merge(projectRecord: r, into: context) { mergedProjects += 1 }
            }

            var mergedFixtures = 0
            for r in fixtureRecs {
                if merge(fixtureRecord: r, into: context) { mergedFixtures += 1 }
            }

            try? context.save()
            return "Pulled \(projectRecs.count) projects / \(fixtureRecs.count) fixtures. Merged \(mergedProjects)+\(mergedFixtures)."
        } catch {
            return "Pull failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Mapping-driven merge

    private func merge(projectRecord rec: CKRecord, into ctx: ModelContext) -> Bool {
        // UUID from field or recordName "project-<uuid>"
        let id: UUID? = {
            if let s = rec[CloudSchema.ProjectKeys.id] as? String, let u = UUID(uuidString: s) { return u }
            let rn = rec.recordID.recordName
            if rn.hasPrefix("project-"), let u = UUID(uuidString: String(rn.dropFirst("project-".count))) { return u }
            return nil
        }()
        guard let projectID = id else { return false }

        // Fetch or create
        var fetch = FetchDescriptor<Item>(predicate: #Predicate<Item> { $0.id == projectID })
        fetch.fetchLimit = 1
        let existing = (try? ctx.fetch(fetch))?.first

        let item = existing ?? Item(title: rec[CloudSchema.ProjectKeys.title] as? String ?? "Untitled")
        if existing == nil { item.id = projectID; ctx.insert(item) }

        // Assign fields
        if let s = rec[CloudSchema.ProjectKeys.title] as? String { item.title = s }
        if let d = rec[CloudSchema.ProjectKeys.createdAt] as? Date { item.createdAt = d }
        if let s = rec[CloudSchema.ProjectKeys.contactFirstName] as? String { item.contactFirstName = s }
        if let s = rec[CloudSchema.ProjectKeys.contactLastName]  as? String { item.contactLastName  = s }
        if let s = rec[CloudSchema.ProjectKeys.siteAddress]      as? String { item.siteAddress      = s }
        if let s = rec[CloudSchema.ProjectKeys.controlSystemRaw] as? String { item.controlSystemRaw = s }
        return true
    }

    private func merge(fixtureRecord rec: CKRecord, into ctx: ModelContext) -> Bool {
        // Which project?
        guard
            let pref = rec[CloudSchema.FixtureKeys.projectRef] as? CKRecord.Reference
        else { return false }

        // Parse "project-<uuid>"
        let prn = pref.recordID.recordName
        guard prn.hasPrefix("project-"), let projectID = UUID(uuidString: String(prn.dropFirst("project-".count)))
        else { return false }

        // Load project
        var fetchP = FetchDescriptor<Item>(predicate: #Predicate<Item> { $0.id == projectID })
        fetchP.fetchLimit = 1
        guard let project = (try? ctx.fetch(fetchP))?.first else { return false }

        // Find fixture by serial or shortAddress
        let serial = rec[CloudSchema.FixtureKeys.serial] as? String
        let shortAddr = (rec[CloudSchema.FixtureKeys.shortAddress] as? NSNumber)?.intValue ?? -1

        let fixture: Fixture = {
            if let s = serial, let found = project.fixtures.first(where: { $0.serial == s }) { return found }
            if shortAddr >= 0, let found = project.fixtures.first(where: { $0.shortAddress == shortAddr }) { return found }
            let f = Fixture(label: rec[CloudSchema.FixtureKeys.label] as? String ?? "Fixture",
                            shortAddress: max(0, shortAddr), groups: 0)
            project.fixtures.append(f)
            return f
        }()

        // Assign fields
        if let s = rec[CloudSchema.FixtureKeys.label] as? String { fixture.label = s }
        if shortAddr >= 0 { fixture.shortAddress = shortAddr }
        if let n = rec[CloudSchema.FixtureKeys.groups] as? NSNumber { fixture.groups = UInt16(truncatingIfNeeded: n.intValue) }
        if let s = rec[CloudSchema.FixtureKeys.room] as? String { fixture.room = s }
        if let s = serial { fixture.serial = s }
        if let s = rec[CloudSchema.FixtureKeys.dtTypeRaw] as? String { fixture.dtTypeRaw = s }
        if let d = rec[CloudSchema.FixtureKeys.commissionedAt] as? Date { fixture.commissionedAt = d }
        if let s = rec[CloudSchema.FixtureKeys.notes] as? String { fixture.notes = s }
        return true
    }

    // MARK: - Ops

    private func database(for mode: AccountMode) -> CKDatabase {
        switch mode {
        case .orgOwner:  return CloudConfig.privateDB
        case .orgMember: return CloudConfig.sharedDB
        case .guestLocal: return CloudConfig.privateDB // unused
        }
    }

    private func modifyRecords(_ toSave: [CKRecord], in db: CKDatabase) async -> (saved: Int, error: Error?) {
        await withCheckedContinuation { cont in
            let op = CKModifyRecordsOperation(recordsToSave: toSave, recordIDsToDelete: nil)
            op.savePolicy = .changedKeys
            op.isAtomic = false
            var saved = 0
            op.perRecordCompletionBlock = { _, err in if err == nil { saved += 1 } }
            op.modifyRecordsCompletionBlock = { _, _, error in
                cont.resume(returning: (saved, error))
            }
            db.add(op)
        }
    }

    private func fetchAllRecords(ofType type: String, in zoneID: CKRecordZone.ID, db: CKDatabase) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { cont in
            var results: [CKRecord] = []
            let pred = NSPredicate(value: true)
            let query = CKQuery(recordType: type, predicate: pred)

            let op = CKQueryOperation(query: query)
            op.zoneID = zoneID
            op.resultsLimit = 200

            op.recordFetchedBlock = { rec in
                results.append(rec)
            }
            op.queryCompletionBlock = { cursor, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else if let cursor = cursor {
                    // Handle pagination with another op
                    self.fetchWithCursor(cursor, accum: results, db: db, cont: cont)
                } else {
                    cont.resume(returning: results)
                }
            }
            db.add(op)
        }
    }

    private func fetchWithCursor(_ cursor: CKQueryOperation.Cursor, accum: [CKRecord], db: CKDatabase, cont: CheckedContinuation<[CKRecord], Error>) {
        var results = accum
        let op = CKQueryOperation(cursor: cursor)
        op.resultsLimit = 200
        op.recordFetchedBlock = { rec in results.append(rec) }
        op.queryCompletionBlock = { nextCursor, error in
            if let error = error {
                cont.resume(throwing: error)
            } else if let next = nextCursor {
                self.fetchWithCursor(next, accum: results, db: db, cont: cont)
            } else {
                cont.resume(returning: results)
            }
        }
        db.add(op)
    }
}

// Small utility
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var out: [[Element]] = []
        out.reserveCapacity((count + size - 1) / size)
        var i = 0
        while i < count {
            let j = Swift.min(i + size, count)
            out.append(Array(self[i..<j]))
            i = j
        }
        return out
    }
}
#endif
