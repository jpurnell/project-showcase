//
//  InfographicWriter.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-10-30.
//

import Foundation

/// Writes a page's three infographics under the names the site's layout requests.
///
/// The showcase layout loads `/images/showcase/<slug>-stats.svg`, `-commits.svg` and
/// `-releases.svg`, keyed by the page's own file stem. Naming them after the project instead
/// would leave a page whose slug differs from its project name with three broken images.
public enum InfographicWriter {

    private static let kinds = ["stats", "commits", "releases"]

    /// Writes the stats card, commit timeline and release timeline for `card`.
    ///
    /// - Returns: The files written.
    /// - Throws: ``ShowcaseError/renderingFailed(message:)`` for a slug that is not a plain file
    ///   stem, before anything is written.
    @discardableResult
    public static func write(card: ProjectCard, slug: String, to directory: URL) throws -> [URL] {
        guard SyncManifest.isSafeSlug(slug) else {
            throw ShowcaseError.renderingFailed(message: "Slug '\(slug)' is not a plain file stem.")
        }
        let generators: [(String, any InfographicGenerator)] = [
            ("stats", StatsCardGenerator()),
            ("commits", CommitTimelineGenerator()),
            ("releases", ReleaseTimelineGenerator())
        ]
        // Generate everything first, so a failure leaves no half-written set.
        let svgs = try generators.map { ($0.0, try $0.1.generate(from: card)) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var written: [URL] = []
        for (kind, svg) in svgs {
            let url = directory.appendingPathComponent("\(slug)-\(kind).svg")
            try svg.write(to: url, atomically: true, encoding: .utf8)
            written.append(url)
        }
        return written
    }

    /// Deletes a page's infographics. A page that has none is not an error.
    public static func remove(slug: String, from directory: URL) throws {
        guard SyncManifest.isSafeSlug(slug) else { return }
        for kind in kinds {
            let url = directory.appendingPathComponent("\(slug)-\(kind).svg")
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
    }
}
