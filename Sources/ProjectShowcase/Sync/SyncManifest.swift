//
//  SyncManifest.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-10-29.
//

import Foundation

/// One page the site shows, and the source repository it is generated from.
public struct SyncEntry: Codable, Sendable, Equatable {
    /// File stem of the page in the content directory (`<slug>.md`).
    public let slug: String
    /// Path of the source repository. Absolute, or relative to the manifest's `sourceRoot`.
    public let path: String
    /// Display name handed to the narrative, when the directory name would mislead.
    public let name: String?
    /// Value of the page's `project:` grouping label.
    public let group: String?
    /// The page's `tags:` list, which is curated by hand and so must survive regeneration.
    public let tags: [String]?
    /// Audience the narrative is written for.
    public let audience: Audience
    /// Narrative style.
    public let style: NarrativeStyle

    /// Creates an entry.
    public init(
        slug: String,
        path: String,
        name: String?,
        group: String?,
        tags: [String]?,
        audience: Audience,
        style: NarrativeStyle
    ) {
        self.slug = slug
        self.path = path
        self.name = name
        self.group = group
        self.tags = tags
        self.audience = audience
        self.style = style
    }
}

/// The list of pages `showcase sync` keeps current.
///
/// The manifest is what the May batch lacked: a record of which repository produced which page,
/// with the audience, style, grouping and tags each was published with.
public struct SyncManifest: Codable, Sendable, Equatable {
    /// Directory source paths are relative to, itself relative to the manifest's directory.
    public let sourceRoot: String
    /// Directory the pages are written to, relative to the manifest's directory.
    public let contentDirectory: String
    /// The pages to keep current.
    public let entries: [SyncEntry]

    /// Creates a manifest.
    public init(sourceRoot: String, contentDirectory: String, entries: [SyncEntry]) {
        self.sourceRoot = sourceRoot
        self.contentDirectory = contentDirectory
        self.entries = entries
    }

    /// Decodes and validates a manifest.
    ///
    /// - Throws: ``ShowcaseError/invalidConfiguration(message:)`` for a duplicate slug or a slug
    ///   that is empty, hidden, or contains a path separator; a `DecodingError` for an unknown
    ///   audience or style, which fails rather than defaulting.
    public static func decode(from data: Data) throws -> SyncManifest {
        let manifest = try JSONDecoder().decode(SyncManifest.self, from: data)
        var seen = Set<String>()
        for entry in manifest.entries {
            guard isSafeSlug(entry.slug) else {
                throw ShowcaseError.invalidConfiguration(message: "Manifest slug '\(entry.slug)' is not a plain file stem.")
            }
            guard seen.insert(entry.slug).inserted else {
                throw ShowcaseError.invalidConfiguration(message: "Manifest slug '\(entry.slug)' appears more than once.")
            }
        }
        return manifest
    }

    /// Resolves an entry's source directory.
    public func sourceURL(for entry: SyncEntry, manifestDirectory: URL) -> URL {
        if entry.path.hasPrefix("/") {
            return URL(fileURLWithPath: entry.path, isDirectory: true).standardizedFileURL
        }
        let root = URL(fileURLWithPath: sourceRoot, isDirectory: true, relativeTo: manifestDirectory)
        return URL(fileURLWithPath: entry.path, isDirectory: true, relativeTo: root).standardizedFileURL
    }

    /// Resolves the content directory.
    public func contentURL(manifestDirectory: URL) -> URL {
        URL(fileURLWithPath: contentDirectory, isDirectory: true, relativeTo: manifestDirectory).standardizedFileURL
    }

    /// Whether `slug` is a plain file stem that cannot name anything outside a directory.
    static func isSafeSlug(_ slug: String) -> Bool {
        guard !slug.isEmpty, !slug.hasPrefix(".") else { return false }
        return !slug.contains("/") && !slug.contains("\\")
    }
}
