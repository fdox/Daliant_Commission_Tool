//
//  JSONRoundTripPreview.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/28/25.
//

import SwiftUI
import SwiftData
import Foundation

/// A tiny harness you can open in Canvas to verify JSON Export → Import → Merge.
///
/// It uses an in‑memory SwiftData container (no disk writes except a temp .json file),
/// seeds a sample project + fixtures, exports to JSON, imports into a *new* project,
/// verifies field equality, then modifies the DTO and merges back into the original
/// (expecting 1 update + 1 addition).
struct JSONRoundTripPreview: View {
    private let result: RoundTripResult

    init() {
        self.result = JSONRoundTripTester.run()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("JSON Round‑Trip (Export → Create → Merge)")
                .font(.headline)

            Group {
                HStack {
                    Label("Export file", systemImage: "square.and.arrow.up")
                    Text(result.filename)
                        .font(.system(.footnote, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack {
                    Label("Create new project", systemImage: "doc.badge.plus")
                    Text("Added \(result.createSummary.created) • Updated \(result.createSummary.updated) • Skipped \(result.createSummary.skipped)")
                }
                HStack {
                    Label("Merge into original", systemImage: "arrow.triangle.2.circlepath")
                    Text("Added \(result.mergeSummary.created) • Updated \(result.mergeSummary.updated) • Skipped \(result.mergeSummary.skipped)")
                }
            }

            Divider().padding(.vertical, 6)

            HStack(spacing: 8) {
                Image(systemName: result.allChecksPass ? "checkmark.seal.fill" : "xmark.seal.fill")
                Text(result.allChecksPass ? "All equality checks passed" : "Some checks failed")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(result.allChecksPass ? .green : .red)

            ForEach(result.checkDetails, id: \.self) { msg in
                Text("• \(msg)")
                    .font(.callout)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

#Preview("JSON Round‑Trip (Preview Harness)") {
    JSONRoundTripPreview()
}

// MARK: - Test Runner

private struct RoundTripResult {
    var filename: String
    var createSummary: ImportSummary
    var mergeSummary: ImportSummary
    var allChecksPass: Bool
    var checkDetails: [String]
}

private enum JSONRoundTripTester {

    static func run() -> RoundTripResult {
        // In‑memory container (safe for previews)
        let schema = Schema([Item.self, Fixture.self])
        let container = try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        // Seed an original project with 3 fixtures
        let original = Item(title: "RoundTrip Sample")
        original.createdAt = Date(timeIntervalSince1970: 1_700_000_000) // fixed for determinism
        original.contactFirstName = "Alex"
        original.contactLastName = "Smith"
        original.siteAddress = "123 Preview St"
        original.controlSystemRaw = "TestCtrl"

        let f1 = Fixture(label: "Kitchen 1", shortAddress: 1, groups: 0b0001 as UInt16)
        f1.room = "Kitchen"; f1.serial = "SER-001"; f1.dtTypeRaw = "D4i"

        let f2 = Fixture(label: "Living 2", shortAddress: 2, groups: 0b0010 as UInt16)
        f2.room = "Living"; f2.serial = "SER-002"; f2.dtTypeRaw = "DT8"

        let f3 = Fixture(label: "Hall 3", shortAddress: 3, groups: 0b0100 as UInt16)
        f3.room = "Hall"; f3.serial = nil; f3.dtTypeRaw = "DT6"

        f1.project = original
        f2.project = original
        f3.project = original

        context.insert(original)
        context.insert(f1)
        context.insert(f2)
        context.insert(f3)
        try? context.save()

        var filename = ""
        var createSummary = ImportSummary(created: 0, updated: 0, skipped: 0)
        var mergeSummary = ImportSummary(created: 0, updated: 0, skipped: 0)
        var details: [String] = []
        var allOK = true

        do {
            // Export
            let url = try JSONExporter.exportProject(original)
            filename = url.lastPathComponent

            // Import (create new project)
            let dto = try JSONImporter.loadProjectDTO(from: url)
            let created = try JSONImporter.createProject(from: dto, in: context)
            createSummary = created.summary

            // Verify scalar fields + every fixture matches (by serial else address)
            let equalityOK = verifyEquality(dto: dto, project: created.project, details: &details)
            allOK = allOK && equalityOK

            // Modify DTO to force one UPDATE (by serial) and one ADD
            var dto2 = dto
            if !dto2.fixtures.isEmpty {
                dto2.fixtures[0].label += " (UPDATED)"
            }
            dto2.fixtures.append(
                FixtureDTO(
                    label: "Garage 5",
                    shortAddress: 5,
                    groups: 0b1000 as UInt16,
                    room: "Garage",
                    serial: "SER-005",
                    dtTypeRaw: "D4i",
                    commissionedAt: nil,
                    notes: nil
                )
            )

            // Merge changes back into the original project
            mergeSummary = try JSONImporter.merge(dto: dto2, into: original, in: context)

            // Optional: sanity checks on merge expectations
            if mergeSummary.updated >= 1 {
                details.append("✅ Merge updated at least one fixture (expected).")
            } else {
                details.append("❌ Merge did not update any fixtures (unexpected).")
                allOK = false
            }
            if mergeSummary.created >= 1 {
                details.append("✅ Merge added at least one new fixture (expected).")
            } else {
                details.append("❌ Merge did not add any fixtures (unexpected).")
                allOK = false
            }

        } catch {
            filename = "ERROR: \(error.localizedDescription)"
            details.append("❌ Error: \(error.localizedDescription)")
            allOK = false
        }

        return RoundTripResult(
            filename: filename,
            createSummary: createSummary,
            mergeSummary: mergeSummary,
            allChecksPass: allOK,
            checkDetails: details
        )
    }

    // MARK: - Verification helpers

    private static func verifyEquality(dto: ProjectDTO, project: Item, details: inout [String]) -> Bool {
        var ok = true
        func assert(_ cond: Bool, _ msg: String) {
            if cond { details.append("✅ \(msg)") } else { details.append("❌ \(msg)"); ok = false }
        }

        assert(project.title == dto.title, "Title matches")
        assert(project.contactFirstName == dto.contactFirstName, "Contact first name matches")
        assert(project.contactLastName == dto.contactLastName, "Contact last name matches")
        assert(project.siteAddress == dto.siteAddress, "Site address matches")
        assert(project.controlSystemRaw == dto.controlSystemRaw, "Control system matches")
        assert(project.fixtures.count == dto.fixtures.count, "Fixture count matches")

        let createdFixtures = project.fixtures
        for d in dto.fixtures {
            guard let fx = matchFixture(in: createdFixtures, dto: d) else {
                assert(false, "Fixture “\(d.label)” found in created project")
                continue
            }
            let fieldsOK =
                fx.label == d.label &&
                fx.shortAddress == d.shortAddress &&
                fx.groups == d.groups &&
                fx.room == d.room &&
                fx.serial == d.serial &&
                fx.dtTypeRaw == d.dtTypeRaw &&
                fx.commissionedAt == d.commissionedAt &&
                fx.notes == d.notes
            assert(fieldsOK, "Fixture “\(d.label)” fields match")
        }

        return ok
    }

    private static func matchFixture(in fixtures: [Fixture], dto: FixtureDTO) -> Fixture? {
        if let s = dto.serial?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !s.isEmpty
        {
            if let bySerial = fixtures.first(where: {
                ($0.serial?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) == s
            }) {
                return bySerial
            }
        }
        return fixtures.first(where: { $0.shortAddress == dto.shortAddress })
    }
}
