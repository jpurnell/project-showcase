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

        let releases = card.git.releaseHistory

        var svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)">
        \(InfographicTheme.styleElement)
          <rect class="bg" x="0" y="0" width="\(width)" height="\(height)"/>
          <rect class="frame" x="0.5" y="0.5" width="\(width - 1)" height="\(height - 1)"/>
          <rect class="rule" x="0" y="0" width="\(width)" height="3"/>
          <text class="label" x="60" y="34" font-size="16" font-weight="700" letter-spacing="-0.3">\(escapeXML(card.projectName)) — Releases</text>
        """

        guard !releases.isEmpty else {
            svg += """

              <text x="\(width / 2)" y="\(height / 2 + 10)" class="muted" font-size="13" text-anchor="middle">No releases yet</text>
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

          <line class="hair" x1="\(leftMargin)" y1="\(timelineY)" x2="\(leftMargin + lineWidth)" y2="\(timelineY)"/>
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

              <circle class="dot" cx="\(x)" cy="\(timelineY)" r="6"/>
              <circle class="hole" cx="\(x)" cy="\(timelineY)" r="3"/>
            """

            // Tag label — alternate above and below for readability
            let isAbove = index % 2 == 0
            let tagY = isAbove ? timelineY - 18 : timelineY + 28

            svg += """

              <text x="\(x)" y="\(tagY)" class="label" font-size="12" font-weight="700" text-anchor="middle">\(escapeXML(release.tag))</text>
            """

            // Date label (if available)
            if let date = release.date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let dateStr = formatter.string(from: date)
                let dateY = isAbove ? tagY - 14 : tagY + 14

                svg += """

                <text x="\(x)" y="\(dateY)" class="muted" font-size="9" text-anchor="middle">\(dateStr)</text>
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
