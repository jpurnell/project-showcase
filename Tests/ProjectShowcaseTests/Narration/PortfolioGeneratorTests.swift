import Testing
import Foundation
@testable import ProjectShowcase

@Suite("PortfolioGenerator Tests")
struct PortfolioGeneratorTests {

    static let card1 = ProjectCard(
        projectName: "BusinessMath",
        projectPath: "/Users/test/BusinessMath",
        gatheredAt: Date(timeIntervalSince1970: 1_700_000_000),
        git: GitFacts(
            commitCount: 549,
            releaseHistory: [
                Release(tag: "v2.1.5", date: Date(timeIntervalSince1970: 1_700_000_000))
            ],
            branchCount: 13,
            firstCommitDate: Date(timeIntervalSince1970: 1_600_000_000),
            latestCommitDate: Date(timeIntervalSince1970: 1_700_000_000),
            contributorCount: 1
        ),
        packageManifest: PackageManifestFacts(
            language: .swift,
            toolsVersion: "5.9",
            dependencies: ["swift-numerics", "swift-collections"],
            targets: ["BusinessMath", "BusinessMathTests"],
            platforms: ["macOS", "iOS", "visionOS"]
        ),
        tests: TestFacts(testCount: 4944, suiteCount: 400, passRate: 1.0),
        quality: nil,
        insights: InsightsSummary(
            sessionCount: 13,
            totalCommits: 37,
            totalMessages: 183,
            frictionCategories: ["buggy_code": 11],
            outcomeDistribution: ["fully_achieved": 6],
            toolUsageProfile: ["Edit": 245],
            sessionTypes: ["multi_task": 9]
        ),
        designArtifacts: DesignArtifactFacts(
            designProposalCount: 60,
            architectureNotes: ["Key Rules"],
            hasDesignFirstWorkflow: true,
            hasClaudeMD: true
        )
    )

    static let card2 = ProjectCard(
        projectName: "SwiftCLIKit",
        projectPath: "/Users/test/SwiftCLIKit",
        gatheredAt: Date(timeIntervalSince1970: 1_700_000_000),
        git: GitFacts(
            commitCount: 120,
            releaseHistory: [
                Release(tag: "v1.0.0", date: Date(timeIntervalSince1970: 1_695_000_000))
            ],
            branchCount: 4,
            firstCommitDate: Date(timeIntervalSince1970: 1_680_000_000),
            latestCommitDate: Date(timeIntervalSince1970: 1_700_000_000),
            contributorCount: 1
        ),
        packageManifest: PackageManifestFacts(
            language: .swift,
            toolsVersion: "5.9",
            dependencies: ["swift-argument-parser"],
            targets: ["SwiftCLIKit", "SwiftCLIKitTests"],
            platforms: ["macOS"]
        ),
        tests: TestFacts(testCount: 195, suiteCount: 20, passRate: 1.0),
        quality: nil,
        insights: nil,
        designArtifacts: nil
    )

    @Test("Builds portfolio summary prompt with aggregate stats")
    func portfolioSummaryPrompt() throws {
        let builder = PortfolioPromptBuilder()
        let prompt = try builder.buildUserPrompt(from: [Self.card1, Self.card2])

        #expect(prompt.contains("BusinessMath"))
        #expect(prompt.contains("SwiftCLIKit"))
        #expect(prompt.contains("669"))  // 549 + 120 total commits
        #expect(prompt.contains("2 projects"))
    }

    @Test("System prompt references portfolio overview")
    func portfolioSystemPrompt() throws {
        let builder = PortfolioPromptBuilder()
        let prompt = try builder.buildSystemPrompt(audience: .hiringManager)

        #expect(prompt.contains("portfolio"))
        #expect(prompt.contains("hiring manager"))
    }

    @Test("Aggregates test counts across projects")
    func aggregatesTestCounts() throws {
        let builder = PortfolioPromptBuilder()
        let prompt = try builder.buildUserPrompt(from: [Self.card1, Self.card2])

        #expect(prompt.contains("5139"))  // 4944 + 195 total tests
    }

    @Test("Handles single-project portfolio gracefully")
    func singleProjectPortfolio() throws {
        let builder = PortfolioPromptBuilder()
        let prompt = try builder.buildUserPrompt(from: [Self.card1])

        #expect(prompt.contains("1 project"))
        #expect(prompt.contains("BusinessMath"))
    }

    @Test("Includes design artifact summary when present")
    func includesDesignArtifacts() throws {
        let builder = PortfolioPromptBuilder()
        let prompt = try builder.buildUserPrompt(from: [Self.card1, Self.card2])

        #expect(prompt.contains("60 design proposals"))
        #expect(prompt.contains("design-first workflow"))
    }
}
