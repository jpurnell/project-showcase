//
//  PortfolioRenderer.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-10-29.
//

import Foundation

/// Wraps a generated portfolio overview in the frontmatter the site expects.
public enum PortfolioRenderer {

    /// Renders the overview page.
    ///
    /// - Parameters:
    ///   - text: The generated overview body.
    ///   - cards: The projects the overview covers.
    ///   - generatedAt: Stamped into `lastModified`, and into `date` unless `publishedDate` is given, in UTC.
    ///   - publishedDate: The page's original `date:`, kept so a regeneration is not presented as new.
    public static func render(
        text: String,
        cards: [ProjectCard],
        generatedAt: Date,
        publishedDate: String? = nil
    ) -> String {
        let utc = TimeZone(identifier: "GMT") ?? TimeZone(secondsFromGMT: 0) ?? .current
        let posix = Locale(identifier: "en_US_POSIX")

        let dateTime = DateFormatter()
        dateTime.locale = posix
        dateTime.timeZone = utc
        dateTime.dateFormat = "yyyy-MM-dd HH:mm"

        let shortDate = DateFormatter()
        shortDate.locale = posix
        shortDate.timeZone = utc
        shortDate.dateFormat = "yyyy-MM-dd"

        let totalCommits = cards.reduce(0) { $0 + $1.git.commitCount }
        let projectList = cards.map(\.projectName).joined(separator: ", ")

        var markdown = "---\n"
        markdown += "title: Developer Portfolio Overview\n"
        markdown += "description: Cross-project portfolio covering \(cards.count) projects and \(totalCommits) total commits.\n"
        markdown += "date: \(publishedDate ?? dateTime.string(from: generatedAt))\n"
        markdown += "lastModified: \(shortDate.string(from: generatedAt))\n"
        markdown += "tags: showcase, portfolio, overview\n"
        markdown += "layout: ShowcaseLayout\n"
        markdown += "projects: \(projectList)\n"
        markdown += "published: true\n"
        markdown += "---\n\n"
        markdown += text
        markdown += "\n"
        return markdown
    }
}
