//
//  MarkdownRenderer.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Renders NarrativeResult as generic markdown with YAML frontmatter.
public struct MarkdownRenderer: Sendable {

    public init() {}

    /// Render a narrative to a markdown string with YAML frontmatter.
    public func render(narrative: NarrativeResult) throws -> String {
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
        let tags = "showcase, project, \(projectTag), \(audienceTag)"

        var output = "---\n"
        output += "title: \(narrative.title)\n"
        output += "description: \(narrative.summary)\n"
        output += "date: \(dateString)\n"
        output += "lastModified: \(shortDateString)\n"
        output += "tags: \(tags)\n"
        output += "layout: ShowcaseLayout\n"
        output += "style: \(narrative.style.rawValue)\n"
        output += "project: \(narrative.projectName)\n"
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
    /// - Returns: URL of the written file.
    public func renderToFile(
        narrative: NarrativeResult,
        outputDirectory: URL
    ) throws -> URL {
        let content = try render(narrative: narrative)
        let slug = narrative.projectName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        let fileName = "\(slug).md"
        let fileURL = outputDirectory.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
