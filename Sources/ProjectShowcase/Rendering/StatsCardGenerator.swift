//
//  StatsCardGenerator.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Generates a compact GitHub-style stats badge SVG from a ``ProjectCard``.
public struct StatsCardGenerator: InfographicGenerator, Sendable {

    /// Creates a new StatsCardGenerator instance.
    public init() {}

    /// Generates a stats badge SVG from the given project card.
    public func generate(from card: ProjectCard) throws -> String {
        let width = 460
        let height = 220

        let commitCount = card.git.commitCount
        let releaseCount = card.git.releaseHistory.count
        let testCount = card.tests?.testCount
        let platformCount = card.packageManifest?.platforms.count

        // Each stat takes the next series colour, so a card's colours follow what it shows.
        var statEntries: [(label: String, value: String)] = [("Commits", "\(commitCount)")]
        if let tests = testCount {
            statEntries.append(("Tests", "\(tests)"))
        }
        statEntries.append(("Releases", "\(releaseCount)"))
        if let platforms = platformCount {
            statEntries.append(("Platforms", "\(platforms)"))
        }

        let margin = 24
        let colWidth = (width - 2 * margin) / max(statEntries.count, 1)

        var svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)">
        \(InfographicTheme.styleElement)
          <rect class="bg" x="0" y="0" width="\(width)" height="\(height)"/>
          <rect class="frame" x="0.5" y="0.5" width="\(width - 1)" height="\(height - 1)"/>
          <rect class="rule" x="0" y="0" width="\(width)" height="3"/>
          <text class="label" x="\(margin)" y="44" font-size="20" font-weight="700" letter-spacing="-0.4">\(escapeXML(card.projectName))</text>
          <line class="hair" x1="\(margin)" y1="62" x2="\(width - margin)" y2="62"/>
        """

        let baseY = 124
        for (index, entry) in statEntries.enumerated() {
            let x = margin + colWidth * index
            let seriesClass = "s\(index % 4 + 1)"
            svg += """

              <rect class="\(seriesClass)" x="\(x)" y="\(baseY - 44)" width="24" height="3"/>
              <text class="label" x="\(x)" y="\(baseY)" font-size="28" font-weight="700" letter-spacing="-0.6">\(entry.value)</text>
              <text class="muted" x="\(x)" y="\(baseY + 22)" font-size="11" font-weight="600" letter-spacing="0.9">\(entry.label.uppercased())</text>
            """
        }

        // Contributor line at bottom
        let contributorText = card.git.contributorCount == 1 ? "1 contributor" : "\(card.git.contributorCount) contributors"
        svg += """

          <text class="muted" x="\(margin)" y="\(height - 22)" font-size="11">\(contributorText)</text>
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
