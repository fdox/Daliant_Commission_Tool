//
//  DTOs.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/28/25.
//

import Foundation
import SwiftData

// MARK: - FixtureDTO

/// Transport object for `Fixture`
/// 1:1 with your model fields (no derived/computed additions).
public struct FixtureDTO: Codable, Hashable {
    public var label: String
    public var shortAddress: Int
    public var groups: UInt16
    public var room: String?
    public var serial: String?
    public var dtTypeRaw: String?   // "DT6" | "DT8" | "D4i"
    public var commissionedAt: Date?
    public var notes: String?

    public init(
        label: String,
        shortAddress: Int,
        groups: UInt16,
        room: String? = nil,
        serial: String? = nil,
        dtTypeRaw: String? = nil,
        commissionedAt: Date? = nil,
        notes: String? = nil
    ) {
        self.label = label
        self.shortAddress = shortAddress
        self.groups = groups
        self.room = room
        self.serial = serial
        self.dtTypeRaw = dtTypeRaw
        self.commissionedAt = commissionedAt
        self.notes = notes
    }
}

// MARK: - ProjectDTO

/// Transport object for `Item` (Project)
/// Includes nested fixtures for export/import.
public struct ProjectDTO: Codable, Identifiable, Hashable {
    public var id: UUID
    public var title: String
    public var createdAt: Date?
    public var contactFirstName: String?
    public var contactLastName: String?
    public var siteAddress: String?
    public var controlSystemRaw: String?
    public var fixtures: [FixtureDTO]

    public init(
        id: UUID,
        title: String,
        createdAt: Date? = nil,
        contactFirstName: String? = nil,
        contactLastName: String? = nil,
        siteAddress: String? = nil,
        controlSystemRaw: String? = nil,
        fixtures: [FixtureDTO] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.contactFirstName = contactFirstName
        self.contactLastName = contactLastName
        self.siteAddress = siteAddress
        self.controlSystemRaw = controlSystemRaw
        self.fixtures = fixtures
    }
}

// MARK: - Mapping: Fixture <-> FixtureDTO

extension Fixture {
    /// Convert a model `Fixture` to its DTO.
    func toDTO() -> FixtureDTO {
        FixtureDTO(
            label: label,
            shortAddress: shortAddress,
            groups: groups,
            room: room,
            serial: serial,
            dtTypeRaw: dtTypeRaw,
            commissionedAt: commissionedAt,
            notes: notes
        )
    }

    /// Convenience initializer to create a model `Fixture` from its DTO.
    /// Note: does not set `project` here; caller can attach it after creation.
    convenience init(from dto: FixtureDTO) {
        self.init(
            label: dto.label,
            shortAddress: dto.shortAddress,
            groups: dto.groups
        )
        self.room = dto.room
        self.serial = dto.serial
        self.dtTypeRaw = dto.dtTypeRaw
        self.commissionedAt = dto.commissionedAt
        self.notes = dto.notes
    }
}

// MARK: - Mapping: Item (Project) <-> ProjectDTO

extension Item {
    /// Convert a model `Item` (Project) to its DTO.
    /// - Parameter includeFixtures: When true, includes nested fixtures (sorted by shortAddress for stability).
    func toDTO(includeFixtures: Bool = true) -> ProjectDTO {
        let fixtureDTOs: [FixtureDTO] = includeFixtures
            ? fixtures.sorted(by: { $0.shortAddress < $1.shortAddress }).map { $0.toDTO() }
            : []

        return ProjectDTO(
            id: id,
            title: title,
            createdAt: createdAt,
            contactFirstName: contactFirstName,
            contactLastName: contactLastName,
            siteAddress: siteAddress,
            controlSystemRaw: controlSystemRaw,
            fixtures: fixtureDTOs
        )
    }

    /// Convenience initializer to create a model `Item` from its DTO.
    /// ⚠️ Intentionally does **not** override `id` here to avoid conflicts if `id` is immutable in your model.
    ///    We can revisit preserving IDs in 9c if needed for merging.
    convenience init(from dto: ProjectDTO) {
        self.init(title: dto.title)
        self.createdAt = dto.createdAt
        self.contactFirstName = dto.contactFirstName
        self.contactLastName = dto.contactLastName
        self.siteAddress = dto.siteAddress
        self.controlSystemRaw = dto.controlSystemRaw
        // Fixtures will be created and attached by the importer (9c).
    }
}
