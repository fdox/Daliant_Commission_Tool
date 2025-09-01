//
//  JSONExporter.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/28/25.
//

import Foundation
import SwiftData

/// Minimal helper to encode a Project (Item) to a JSON file and return its URL.
enum JSONExporter {
    /// Encodes the given project (including fixtures) to a JSON file in the temporary directory.
    /// - Returns: File URL of the written JSON.
    static func exportProject(_ project: Item) throws -> URL {
        let dto = project.toDTO(includeFixtures: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(dto)
        let filename = makeFilename(for: project.title)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Filename helpers

    private static func makeFilename(for title: String) -> String {
        let slug = slugify(title)
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyyMMdd-HHmm"
        let stamp = df.string(from: Date())
        return "Project-\(slug.isEmpty ? "Untitled" : slug)-\(stamp).json"
    }

    private static func slugify(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let dashed = trimmed.replacingOccurrences(of: " ", with: "-")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let mapped = dashed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let cleaned = String(mapped)
        let condensed = cleaned.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        return condensed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
