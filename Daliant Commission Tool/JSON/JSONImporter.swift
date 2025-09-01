//
//  JSONImporter.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/28/25.
//

import Foundation
import SwiftData

// MARK: - Import summary

struct ImportSummary: Hashable {
    var created: Int
    var updated: Int
    var skipped: Int
}

// MARK: - JSONImporter

enum JSONImporter {

    // Load & decode a ProjectDTO from a file URL (handles security-scoped URLs).
    static func loadProjectDTO(from url: URL) throws -> ProjectDTO {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProjectDTO.self, from: data)
    }

    /// Create a brand-new project from DTO and insert all fixtures.
    @discardableResult
    static func createProject(from dto: ProjectDTO, in context: ModelContext)
        throws -> (project: Item, summary: ImportSummary)
    {
        let project = Item(from: dto) // from 9a (DTOs.swift)
        context.insert(project)

        var created = 0
        for f in dto.fixtures {
            let fixture = Fixture(from: f)
            fixture.project = project
            context.insert(fixture)
            created += 1
        }

        try context.save()
        return (project, ImportSummary(created: created, updated: 0, skipped: 0))
    }

    /// Merge fixtures from DTO into an existing project with simple dedupe.
    /// Dedupe rule: match by .serial (normalized) first; if none, by .shortAddress.
    /// On match → update fields; else → create new.
    @discardableResult
    static func merge(dto: ProjectDTO, into project: Item, in context: ModelContext)
        throws -> ImportSummary
    {
        // Build quick lookup maps from existing fixtures.
        var bySerial: [String: Fixture] = [:]
        var byAddress: [Int: Fixture] = [:]

        for fx in project.fixtures {
            if let key = normalizedSerial(fx.serial), bySerial[key] == nil {
                bySerial[key] = fx
            }
            if byAddress[fx.shortAddress] == nil {
                byAddress[fx.shortAddress] = fx
            }
        }

        var created = 0, updated = 0, skipped = 0

        for dtoFx in dto.fixtures {
            // Prefer serial match if available; otherwise fall back to address.
            let target: Fixture? = {
                if let key = normalizedSerial(dtoFx.serial), let hit = bySerial[key] {
                    return hit
                }
                return byAddress[dtoFx.shortAddress]
            }()

            if let existing = target {
                if apply(dtoFx, to: existing) {
                    updated += 1
                } else {
                    skipped += 1  // nothing changed
                }
            } else {
                let newFx = Fixture(from: dtoFx)
                newFx.project = project
                context.insert(newFx)

                // Update maps in case the incoming JSON has duplicate lines.
                if let key = normalizedSerial(newFx.serial) { bySerial[key] = newFx }
                byAddress[newFx.shortAddress] = newFx
                created += 1
            }
        }

        try context.save()
        return ImportSummary(created: created, updated: updated, skipped: skipped)
    }

    // MARK: - Helpers

    private static func normalizedSerial(_ s: String?) -> String? {
        guard let s, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Apply DTO values to an existing Fixture; returns true if anything changed.
    private static func apply(_ dto: FixtureDTO, to fixture: Fixture) -> Bool {
        var changed = false

        func assign<T: Equatable>(_ kp: ReferenceWritableKeyPath<Fixture, T>, _ value: T) {
            if fixture[keyPath: kp] != value { fixture[keyPath: kp] = value; changed = true }
        }
        func assignOpt<T: Equatable>(_ kp: ReferenceWritableKeyPath<Fixture, T?>, _ value: T?) {
            if fixture[keyPath: kp] != value { fixture[keyPath: kp] = value; changed = true }
        }

        assign(\.label, dto.label)
        assign(\.shortAddress, dto.shortAddress)
        assign(\.groups, dto.groups)
        assignOpt(\.room, dto.room)
        assignOpt(\.serial, dto.serial)
        assignOpt(\.dtTypeRaw, dto.dtTypeRaw)
        assignOpt(\.commissionedAt, dto.commissionedAt)
        assignOpt(\.notes, dto.notes)

        return changed
    }
}
