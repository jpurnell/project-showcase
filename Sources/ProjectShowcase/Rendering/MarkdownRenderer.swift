//
//  MarkdownRenderer.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Renders NarrativeResult as generic markdown with YAML frontmatter.
public struct MarkdownRenderer: Sendable {

    /// Creates a new MarkdownRenderer instance.
    public init() {}

    /// Render a narrative to a markdown string with YAML frontmatter.
    ///
    /// - Parameters:
    ///   - narrative: The narrative to render.
    ///   - projectLabel: Replaces the `project:` value, which otherwise is the project name.
    ///   - tags: Replaces the derived `tags:` list, for pages whose tags are curated by hand.
    ///   - publishedDate: Replaces `date:`, so regenerating a page keeps its original publication
    ///     date. Feeds, sitemaps and index pages order by `date:`; stamping every regeneration
    ///     with the current time would present each as new content.
    public func render(
        narrative: NarrativeResult,
        projectLabel: String? = nil,
        tags: [String]? = nil,
        publishedDate: String? = nil
    ) throws -> String {
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        dateTimeFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = dateTimeFormatter.string(from: narrative.generatedAt)

        let shortDateFormatter = DateFormatter()
        shortDateFormatter.dateFormat = "yyyy-MM-dd"
        shortDateFormatter.timeZone = TimeZone(identifier: "UTC")
        let shortDateString = shortDateFormatter.string(from: narrative.generatedAt)

        let projectTag = narrative.projectName.lowercased()
        let audienceTag = narrative.audience.rawValue
        let tags = tags?.joined(separator: ", ") ?? "showcase, project, \(projectTag), \(audienceTag)"

        var output = "---\n"
        output += "title: \(narrative.title)\n"
        output += "description: \(narrative.summary)\n"
        output += "date: \(publishedDate ?? dateString)\n"
        output += "lastModified: \(shortDateString)\n"
        output += "tags: \(tags)\n"
        output += "layout: ShowcaseLayout\n"
        output += "style: \(narrative.style.rawValue)\n"
        output += "project: \(projectLabel ?? narrative.projectName)\n"
        output += "published: true\n"
        output += "---\n"

        output += "\n"
        output += "# \(narrative.title)\n"
        output += "\n"
        output += "> \(narrative.summary)\n"
        output += "\n"
        output += narrative.body
        output += "\n"

        return output
    }

    /// Render a narrative to a file in the given output directory.
    ///
    /// - Parameters:
    ///   - narrative: The narrative to render.
    ///   - outputDirectory: Directory the file is written into.
    ///   - slug: File stem to use instead of one derived from the project name.
    ///   - projectLabel: See ``render(narrative:projectLabel:tags:publishedDate:)``.
    ///   - tags: See ``render(narrative:projectLabel:tags:publishedDate:)``.
    ///   - publishedDate: See ``render(narrative:projectLabel:tags:publishedDate:)``.
    /// - Returns: URL of the written file.
    /// - Throws: ``ShowcaseError/renderingFailed(message:)`` for a slug that is not a plain file stem.
    public func renderToFile(
        narrative: NarrativeResult,
        outputDirectory: URL,
        slug: String? = nil,
        projectLabel: String? = nil,
        tags: [String]? = nil,
        publishedDate: String? = nil
    ) throws -> URL {
        let content = try render(narrative: narrative, projectLabel: projectLabel, tags: tags, publishedDate: publishedDate)
        let stem = slug ?? narrative.projectName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        guard SyncManifest.isSafeSlug(stem) else {
            throw ShowcaseError.renderingFailed(message: "Slug '\(stem)' is not a plain file stem.")
        }
        let fileName = "\(stem).md"
        let fileURL = outputDirectory.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
