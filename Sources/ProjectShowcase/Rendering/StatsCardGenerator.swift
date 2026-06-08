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
        let bgColor = "#1a1a2e"
        let cardColor = "#16213e"
        let accentColor = "#0f3460"
        let textColor = "#e0e0e0"
        let highlightColor = "#00d4ff"
        let labelColor = "#8892b0"

        let commitCount = card.git.commitCount
        let releaseCount = card.git.releaseHistory.count
        let testCount = card.tests?.testCount
        let platformCount = card.packageManifest?.platforms.count

        var statEntries: [(label: String, value: String, color: String)] = [
            ("Commits", "\(commitCount)", highlightColor)
        ]

        if let tests = testCount {
            statEntries.append(("Tests", "\(tests)", "#50fa7b"))
        }

        statEntries.append(("Releases", "\(releaseCount)", "#ff79c6"))

        if let platforms = platformCount {
            statEntries.append(("Platforms", "\(platforms)", "#ffb86c"))
        }

        let colWidth = (width - 60) / max(statEntries.count, 1)

        var svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)">
          <rect x="0" y="0" width="\(width)" height="\(height)" rx="12" ry="12" fill="\(bgColor)"/>
          <rect x="10" y="10" width="\(width - 20)" height="\(height - 20)" rx="8" ry="8" fill="\(cardColor)"/>
          <rect x="10" y="10" width="\(width - 20)" height="50" rx="8" ry="8" fill="\(accentColor)"/>
          <text x="\(width / 2)" y="42" font-family="sans-serif" font-size="20" font-weight="bold" fill="\(highlightColor)" text-anchor="middle">\(escapeXML(card.projectName))</text>
        """

        let baseY = 100
        for (index, entry) in statEntries.enumerated() {
            let x = 30 + (colWidth * index) + colWidth / 2
            svg += """

              <text x="\(x)" y="\(baseY)" font-family="sans-serif" font-size="28" font-weight="bold" fill="\(entry.color)" text-anchor="middle">\(entry.value)</text>
              <text x="\(x)" y="\(baseY + 24)" font-family="sans-serif" font-size="12" fill="\(labelColor)" text-anchor="middle">\(entry.label)</text>
            """
        }

        // Contributor line at bottom
        let contributorText = card.git.contributorCount == 1 ? "1 contributor" : "\(card.git.contributorCount) contributors"
        svg += """

          <text x="\(width / 2)" y="\(height - 25)" font-family="sans-serif" font-size="11" fill="\(textColor)" text-anchor="middle" opacity="0.6">\(contributorText)</text>
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
