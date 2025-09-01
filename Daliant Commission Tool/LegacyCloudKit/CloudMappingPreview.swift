//
//  CloudMappingPreview.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/31/25.
//

// Cloud/CloudMappingPreview.swift
// Step 10a — preview: DTOs → CKRecords → DTOs; prints green checks.

#if canImport(CloudKit)
import SwiftUI
import CloudKit
import Foundation

private func decodeDTO<T: Decodable>(_ type: T.Type, _ obj: [String: Any]) -> T {
    let data = try! JSONSerialization.data(withJSONObject: obj, options: [])
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    return try! dec.decode(T.self, from: data)
}

private func makeSampleDTOs() -> (ProjectDTO, [FixtureDTO], UUID) {
    // Stable IDs for deterministic record names
    let orgID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
    let projectID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    // Project
    let projObj: [String: Any] = [
        "id": projectID.uuidString,
        "title": "Smith Residence",
        "createdAt": ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_723_000_000)), // fixed
        "contactFirstName": "Alex",
        "contactLastName": "Smith",
        "siteAddress": "123 Ocean Ave",
        "controlSystemRaw": "Lutron QS",
        "fixtures": [] // DTO-friendly
    ]
    let project: ProjectDTO = decodeDTO(ProjectDTO.self, projObj)

    // Fixtures
    let fx1Obj: [String: Any] = [
        "label": "Kitchen Cans",
        "shortAddress": 3,
        "groups": 1,
        "room": "Kitchen",
        "serial": "SN-001/ABC",
        "dtTypeRaw": "DT8",
        "commissionedAt": ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_723_100_000)),
        "notes": "dimmable"
    ]
    let fx2Obj: [String: Any] = [
        "label": "Dining Pendants",
        "shortAddress": 7,
        "groups": 2
    ]
    let f1: FixtureDTO = decodeDTO(FixtureDTO.self, fx1Obj)
    let f2: FixtureDTO = decodeDTO(FixtureDTO.self, fx2Obj)

    return (project, [f1, f2], orgID)
}

struct Line: Identifiable { var id = UUID(); var text: String }

struct CloudMappingPreview10a: View {
    let lines: [Line]

    init() {
        var out = [String]()
        let (project, fixtures, orgID) = makeSampleDTOs()
        let zone = CloudIDs.orgZoneID(for: orgID)

        // Encode
        let projRec = CloudMapper.projectRecord(from: project, in: zone)
        let fxRecs  = fixtures.map { CloudMapper.fixtureRecord(from: $0, project: project, in: zone) }

        // Decode
        let projBack = CloudMapper.projectDTO(from: projRec)
        let fxBack   = fxRecs.compactMap { CloudMapper.fixtureDTO(from: $0) }

        let expectedZoneName = "Org-\(orgID.uuidString.lowercased())"
        let expectedProjName = CloudIDs.projectRecordName(project.id)
        let expectedFx1Name  = CloudIDs.fixtureRecordName(projectID: project.id, serial: fixtures[0].serial, shortAddress: fixtures[0].shortAddress)
        let expectedFx2Name  = CloudIDs.fixtureRecordName(projectID: project.id, serial: fixtures[1].serial, shortAddress: fixtures[1].shortAddress)

        func check(_ label: String, _ ok: Bool, detail: String? = nil) {
            out.append("\(ok ? "✅" : "❌") \(label)\(detail.map { " — \($0)" } ?? "")")
        }

        // Zone & IDs
        check("Zone ID name matches", zone.zoneName == expectedZoneName, detail: zone.zoneName)

        // Project record shape
        check("Project recordName", projRec.recordID.recordName == expectedProjName, detail: projRec.recordID.recordName)

        // Fixture record shapes
        check("Fixture[0] recordName", fxRecs[0].recordID.recordName == expectedFx1Name, detail: fxRecs[0].recordID.recordName)
        check("Fixture[1] recordName", fxRecs[1].recordID.recordName == expectedFx2Name, detail: fxRecs[1].recordID.recordName)

        // Round‑trip DTO field checks
        check("Project id round‑trip", projBack?.id == project.id)
        check("Project title round‑trip", projBack?.title == project.title)
        check("Fixture[0] label round‑trip", fxBack[safe: 0]?.label == fixtures[0].label)
        check("Fixture[0] shortAddress round‑trip", fxBack[safe: 0]?.shortAddress == fixtures[0].shortAddress)
        check("Fixture[0] groups round‑trip", fxBack[safe: 0]?.groups == fixtures[0].groups)

        self.lines = out.map { Line(text: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(lines) { Text($0.text).font(.system(.body, design: .monospaced)) }
            }
            .padding()
        }
    }
}

// Convenience: safe index
private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview("Cloud Mapping (10a)") { CloudMappingPreview10a() }
#endif
