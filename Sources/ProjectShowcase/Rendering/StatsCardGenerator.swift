//
//  StatsCardGenerator.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Generates a compact stats card SVG from a ``ProjectCard``.
public struct StatsCardGenerator: InfographicGenerator, Sendable {

    /// Creates a new StatsCardGenerator instance.
    public init() {}

    /// Generates a stats card SVG from the given project card.
    public func generate(from card: ProjectCard) throws -> String {
        let height = 164
        let margin = InfographicChrome.margin

        // Each stat takes the next series colour, so a card's colours follow what it shows.
        var entries: [(label: String, value: String)] = [("Commits", "\(card.git.commitCount)")]
        if let tests = card.tests?.testCount {
            entries.append(("Tests", "\(tests)"))
        }
        entries.append(("Releases", "\(card.git.releaseHistory.count)"))
        if let platforms = card.packageManifest?.platforms.count {
            entries.append(("Platforms", "\(platforms)"))
        }

        var svg = InfographicChrome.opening(
            height: height, label: "\(card.projectName) statistics", title: card.projectName)

        let columnWidth = InfographicChrome.contentWidth / max(entries.count, 1)
        for (index, entry) in entries.enumerated() {
            let x = margin + columnWidth * index
            svg += """

              <rect class="ig-s\(index % 4 + 1)" x="\(x)" y="68" width="24" height="3"/>
              <text class="ig-label" x="\(x)" y="106" font-size="30" font-weight="700" letter-spacing="-0.6">\(entry.value)</text>
              <text class="ig-muted" x="\(x)" y="126" font-size="11" font-weight="600" letter-spacing="0.9">\(entry.label.uppercased())</text>
            """
        }

        let contributors = card.git.contributorCount == 1 ? "1 contributor" : "\(card.git.contributorCount) contributors"
        svg += """

          <text class="ig-muted" x="\(margin)" y="\(height - 14)" font-size="11">\(contributors)</text>
        </svg>
        """
        return svg
    }
}
