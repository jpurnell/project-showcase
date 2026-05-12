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
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: narrative.generatedAt)

        var output = "---\n"
        output += "title: \"\(escapeYAML(narrative.title))\"\n"
        output += "description: \"\(escapeYAML(narrative.summary))\"\n"
        output += "date: \(dateString)\n"
        output += "tags: [\"portfolio\", \"\(narrative.projectName.lowercased())\", \"\(narrative.audience.rawValue)\"]\n"
        output += "style: \(narrative.style.rawValue)\n"
        output += "project: \(narrative.projectName)\n"
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

    private func escapeYAML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
