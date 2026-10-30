//
//  SyncState.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-10-29.
//

import Foundation

/// What a page was last generated from.
public struct SyncRecord: Codable, Sendable, Equatable {
    /// The source repository's `HEAD` commit when the page was generated.
    public let head: String
    /// When the page was generated.
    public let generatedAt: Date

    /// Creates a record.
    public init(head: String, generatedAt: Date) {
        self.head = head
        self.generatedAt = generatedAt
    }
}

/// The last-generated commit for each slug, kept beside the manifest.
///
/// Staleness is decided by comparing commit ids rather than dates, so a commit made on the
/// same day as the last run still counts.
public struct SyncState: Codable, Sendable, Equatable {
    /// Records keyed by slug.
    public var records: [String: SyncRecord]

    /// Creates a state, empty by default.
    public init(records: [String: SyncRecord] = [:]) {
        self.records = records
    }

    /// Loads state from `url`. A file that does not exist is an empty state.
    ///
    /// - Throws: Any read or decode error for a file that exists but cannot be used. A corrupt
    ///   state is never silently reset, because that would regenerate every page.
    public static func load(from url: URL) throws -> SyncState {
        guard FileManager.default.fileExists(atPath: url.path) else { return SyncState() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SyncState.self, from: Data(contentsOf: url))
    }

    /// A copy without the records for `slugs`.
    public func removing(_ slugs: [String]) -> SyncState {
        SyncState(records: records.filter { !slugs.contains($0.key) })
    }

    /// Writes the state to `url`.
    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
