//
//  PortfolioRendererTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-10-29.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("PortfolioRenderer Tests")
struct PortfolioRendererTests {

    static func card(_ name: String, commits: Int) -> ProjectCard {
        ProjectCard(
            projectName: name, projectPath: "/p/\(name)", gatheredAt: Date(timeIntervalSince1970: 0),
            git: GitFacts(commitCount: commits, releaseHistory: [], branchCount: 1, firstCommitDate: nil, latestCommitDate: nil, contributorCount: 1),
            packageManifest: nil, tests: nil, quality: nil, insights: nil, designArtifacts: nil)
    }

    @Test("Frontmatter counts projects and sums commits")
    func frontmatter() {
        let out = PortfolioRenderer.render(
            text: "Body.", cards: [Self.card("A", commits: 3), Self.card("B", commits: 4)],
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(out.contains("title: Developer Portfolio Overview\n"))
        #expect(out.contains("covering 2 projects and 7 total commits."))
        #expect(out.contains("date: 2023-11-14 22:13\n"))
        #expect(out.contains("lastModified: 2023-11-14\n"))
        #expect(out.contains("projects: A, B\n"))
        #expect(out.hasSuffix("Body.\n"))
    }

    @Test("Output is independent of the machine's time zone and locale")
    func pinned() {
        let out = PortfolioRenderer.render(text: "x", cards: [], generatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(out.contains("date: 2023-11-14 22:13\n"))
    }
}
