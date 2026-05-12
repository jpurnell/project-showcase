//
//  ProjectCardTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("ProjectCard Model Tests")
struct ProjectCardTests {

    @Test("ProjectCard encodes to JSON and decodes back identically")
    func roundTripCodable() throws {
        let card = ProjectCard(
            projectName: "BusinessMath",
            projectPath: "/Users/test/BusinessMath",
            gatheredAt: Date(timeIntervalSince1970: 1_700_000_000),
            git: GitFacts(
                commitCount: 250,
                releaseHistory: [
                    Release(tag: "v2.1.5", date: Date(timeIntervalSince1970: 1_700_000_000))
                ],
                branchCount: 3,
                firstCommitDate: Date(timeIntervalSince1970: 1_600_000_000),
                latestCommitDate: Date(timeIntervalSince1970: 1_700_000_000),
                contributorCount: 1
            ),
            packageManifest: nil,
            tests: nil,
            quality: nil,
            insights: nil,
            designArtifacts: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(card)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ProjectCard.self, from: data)

        #expect(decoded.projectName == "BusinessMath")
        #expect(decoded.git.commitCount == 250)
        #expect(decoded.git.releaseHistory.count == 1)
        #expect(decoded.git.releaseHistory[0].tag == "v2.1.5")
        #expect(decoded.git.contributorCount == 1)
    }

    @Test("ProjectCard with all optional sections populated")
    func fullCard() throws {
        let card = ProjectCard(
            projectName: "FullProject",
            projectPath: "/tmp/full",
            gatheredAt: Date(timeIntervalSince1970: 1_700_000_000),
            git: GitFacts(
                commitCount: 500,
                releaseHistory: [],
                branchCount: 5,
                firstCommitDate: nil,
                latestCommitDate: nil,
                contributorCount: 3
            ),
            packageManifest: PackageManifestFacts(
                language: .swift,
                toolsVersion: "5.9",
                dependencies: ["swift-numerics", "swift-collections"],
                targets: ["BusinessMath", "BusinessMathTests"],
                platforms: ["macOS", "iOS", "visionOS"]
            ),
            tests: TestFacts(
                testCount: 4944,
                suiteCount: 400,
                passRate: 1.0
            ),
            quality: QualityFacts(
                violationCount: 0,
                checkerCategories: ["safety": 0, "concurrency": 0]
            ),
            insights: InsightsSummary(
                sessionCount: 52,
                totalCommits: 251,
                totalMessages: 1221,
                frictionCategories: ["buggy_code": 44, "wrong_approach": 36],
                outcomeDistribution: ["fully_achieved": 30, "mostly_achieved": 15],
                toolUsageProfile: ["Edit": 500, "Bash": 300, "Agent": 297],
                sessionTypes: ["iterative_refinement": 20, "exploration": 10]
            ),
            designArtifacts: DesignArtifactFacts(
                designProposalCount: 8,
                architectureNotes: ["Protocol-oriented design", "TDD workflow"],
                hasDesignFirstWorkflow: true,
                hasClaudeMD: true
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(card)
        let decoded = try JSONDecoder.iso8601Configured().decode(ProjectCard.self, from: data)

        #expect(decoded.packageManifest?.language == .swift)
        #expect(decoded.tests?.testCount == 4944)
        #expect(decoded.quality?.violationCount == 0)
        #expect(decoded.insights?.sessionCount == 52)
        #expect(decoded.designArtifacts?.designProposalCount == 8)
        #expect(decoded.designArtifacts?.hasDesignFirstWorkflow == true)
    }

    @Test("ProjectCard with minimal data — only git required")
    func minimalCard() {
        let card = ProjectCard(
            projectName: "TinyRepo",
            projectPath: "/tmp/tiny",
            gatheredAt: Date(),
            git: GitFacts(
                commitCount: 1,
                releaseHistory: [],
                branchCount: 1,
                firstCommitDate: nil,
                latestCommitDate: nil,
                contributorCount: 1
            ),
            packageManifest: nil,
            tests: nil,
            quality: nil,
            insights: nil,
            designArtifacts: nil
        )

        #expect(card.projectName == "TinyRepo")
        #expect(card.packageManifest == nil)
        #expect(card.tests == nil)
        #expect(card.insights == nil)
    }
}
