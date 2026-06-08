//
//  ReleaseTimelineGenerator.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Generates a timeline visualization SVG of a project's releases.
public struct ReleaseTimelineGenerator: InfographicGenerator, Sendable {

    /// Creates a new ReleaseTimelineGenerator instance.
    public init() {}

    /// Generates a release timeline SVG from the given project card.
    public func generate(from card: ProjectCard) throws -> String {
        let width = 600
        let height = 180
        let bgColor = "#1a1a2e"
        let lineColor = "#0f3460"
        let dotColor = "#00d4ff"
        let tagColor = "#e0e0e0"
        let titleColor = "#e0e0e0"
        let labelColor = "#8892b0"

        let releases = card.git.releaseHistory

        var svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)">
          <rect x="0" y="0" width="\(width)" height="\(height)" rx="10" ry="10" fill="\(bgColor)"/>
          <text x="\(width / 2)" y="32" font-family="sans-serif" font-size="16" font-weight="bold" fill="\(titleColor)" text-anchor="middle">\(escapeXML(card.projectName)) — Releases</text>
        """

        guard !releases.isEmpty else {
            svg += """

              <text x="\(width / 2)" y="\(height / 2 + 10)" font-family="sans-serif" font-size="13" fill="\(labelColor)" text-anchor="middle">No releases yet</text>
            </svg>
            """
            return svg
        }

        let timelineY = height / 2 + 10
        let leftMargin = 60
        let rightMargin = 60
        let lineWidth = width - leftMargin - rightMargin

        // Draw timeline line
        svg += """

          <line x1="\(leftMargin)" y1="\(timelineY)" x2="\(leftMargin + lineWidth)" y2="\(timelineY)" stroke="\(lineColor)" stroke-width="3" stroke-linecap="round"/>
        """

        let spacing: Int
        if releases.count == 1 {
            spacing = 0
        } else {
            spacing = lineWidth / (releases.count - 1)
        }

        for (index, release) in releases.enumerated() {
            let x: Int
            if releases.count == 1 {
                x = leftMargin + lineWidth / 2
            } else {
                x = leftMargin + spacing * index
            }

            // Dot
            svg += """

              <circle cx="\(x)" cy="\(timelineY)" r="6" fill="\(dotColor)"/>
              <circle cx="\(x)" cy="\(timelineY)" r="3" fill="\(bgColor)"/>
            """

            // Tag label — alternate above and below for readability
            let isAbove = index % 2 == 0
            let tagY = isAbove ? timelineY - 18 : timelineY + 28

            svg += """

              <text x="\(x)" y="\(tagY)" font-family="sans-serif" font-size="12" font-weight="bold" fill="\(tagColor)" text-anchor="middle">\(escapeXML(release.tag))</text>
            """

            // Date label (if available)
            if let date = release.date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let dateStr = formatter.string(from: date)
                let dateY = isAbove ? tagY - 14 : tagY + 14

                svg += """

                <text x="\(x)" y="\(dateY)" font-family="sans-serif" font-size="9" fill="\(labelColor)" text-anchor="middle">\(dateStr)</text>
                """
            }
        }

        svg += """

        </svg>
        """

        return svg
    }

    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
