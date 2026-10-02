//
//  NarrativeGeneratorTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("NarrativeGenerator Tests")
struct NarrativeGeneratorTests {

    static let sampleCard = ProjectCard(
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
        packageManifest: PackageManifestFacts(
            language: .swift,
            toolsVersion: "5.9",
            dependencies: ["swift-numerics", "swift-collections"],
            targets: ["BusinessMath", "BusinessMathTests"],
            platforms: ["macOS", "iOS", "visionOS"]
        ),
        tests: TestFacts(testCount: 4944, suiteCount: 400, passRate: 1.0),
        quality: QualityFacts(violationCount: 0, checkerCategories: ["safety": 0]),
        insights: InsightsSummary(
            sessionCount: 52,
            totalCommits: 251,
            totalMessages: 1221,
            frictionCategories: ["buggy_code": 44],
            outcomeDistribution: ["fully_achieved": 30],
            toolUsageProfile: ["Edit": 500, "Agent": 297],
            sessionTypes: ["iterative_refinement": 20]
        ),
        designArtifacts: DesignArtifactFacts(
            designProposalCount: 8,
            architectureNotes: ["Key Rules", "Architecture"],
            hasDesignFirstWorkflow: true,
            hasClaudeMD: true
        )
    )

    @Test("Builds correct system prompt for hiring manager audience")
    func systemPromptHiringManager() throws {
        let builder = PromptBuilder()
        let prompt = try builder.buildSystemPrompt(audience: .hiringManager, style: .caseStudy)

        #expect(prompt.contains("hiring manager"))
        #expect(prompt.contains("case study"))
    }

    @Test("Builds correct system prompt for open source audience")
    func systemPromptOpenSource() throws {
        let builder = PromptBuilder()
        let prompt = try builder.buildSystemPrompt(audience: .openSourceContributor, style: .projectCard)

        #expect(prompt.contains("open source"))
    }

    @Test("Builds user prompt from ProjectCard with all sections")
    func userPromptFromFullCard() throws {
        let builder = PromptBuilder()
        let prompt = try builder.buildUserPrompt(from: Self.sampleCard)

        #expect(prompt.contains("BusinessMath"))
        #expect(prompt.contains("250 commits"))
        #expect(prompt.contains("4944 tests"))
        #expect(prompt.contains("swift-numerics"))
        #expect(prompt.contains("8 design proposals"))
        #expect(prompt.contains("52 sessions"))
    }

    @Test("Builds user prompt from minimal card gracefully")
    func userPromptMinimalCard() throws {
        let card = ProjectCard(
            projectName: "TinyRepo",
            projectPath: "/tmp/tiny",
            gatheredAt: Date(),
            git: GitFacts(
                commitCount: 5,
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

        let builder = PromptBuilder()
        let prompt = try builder.buildUserPrompt(from: card)

        #expect(prompt.contains("TinyRepo"))
        #expect(prompt.contains("5 commits"))
        #expect(!prompt.contains("tests"))
        #expect(!prompt.contains("design proposals"))
    }

    @Test("Card hash is stable for same input")
    func cardHashStability() throws {
        let builder = PromptBuilder()
        let hash1 = try builder.cardHash(for: Self.sampleCard)
        let hash2 = try builder.cardHash(for: Self.sampleCard)

        #expect(hash1 == hash2)
    }

    @Test("Card hash differs for different cards")
    func cardHashDiffers() throws {
        let differentCard = ProjectCard(
            projectName: "DifferentProject",
            projectPath: Self.sampleCard.projectPath,
            gatheredAt: Self.sampleCard.gatheredAt,
            git: Self.sampleCard.git,
            packageManifest: Self.sampleCard.packageManifest,
            tests: Self.sampleCard.tests,
            quality: Self.sampleCard.quality,
            insights: Self.sampleCard.insights,
            designArtifacts: Self.sampleCard.designArtifacts
        )

        let builder = PromptBuilder()
        let hash1 = try builder.cardHash(for: Self.sampleCard)
        let hash2 = try builder.cardHash(for: differentCard)

        #expect(hash1 != hash2)
    }

    @Test("User prompt includes project description when present")
    func userPromptIncludesProjectDescription() throws {
        let card = ProjectCard(
            projectName: "iConquer",
            projectPath: "/Users/test/iConquer",
            gatheredAt: Date(timeIntervalSince1970: 1_700_000_000),
            git: GitFacts(
                commitCount: 50,
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
            designArtifacts: DesignArtifactFacts(
                designProposalCount: 0,
                architectureNotes: [],
                hasDesignFirstWorkflow: false,
                hasClaudeMD: false,
                projectDescription: "Mission: A modern Swift port of iConquer, a Risk-style strategy game."
            )
        )

        let builder = PromptBuilder()
        let prompt = try builder.buildUserPrompt(from: card)

        #expect(prompt.contains("Project Description"))
        #expect(prompt.contains("Risk-style strategy game"))
        #expect(prompt.contains("MASTER_PLAN"))
    }

    @Test("User prompt omits project description when nil")
    func userPromptOmitsNilProjectDescription() throws {
        let builder = PromptBuilder()
        let prompt = try builder.buildUserPrompt(from: Self.sampleCard)

        #expect(!prompt.contains("Project Description"))
    }

    @Test("System prompt instructs to respect project description")
    func systemPromptRespectsProjectDescription() throws {
        let builder = PromptBuilder()
        let prompt = try builder.buildSystemPrompt(audience: .hiringManager, style: .caseStudy)

        #expect(prompt.contains("Project Description"))
        #expect(prompt.contains("authoritative"))
    }

    @Test("Parses narrative response from Claude API format")
    func parsesResponse() throws {
        let rawResponse = """
        # BusinessMath: Precision Financial Mathematics

        > A Swift library providing financial math primitives with rigorous testing.

        ## Problem

        Financial calculations need precision and reliability.

        ## Approach

        Design-first TDD with strict concurrency compliance.
        """

        let parser = NarrativeResponseParser()
        let result = try parser.parse(
            response: rawResponse,
            projectName: "BusinessMath",
            audience: .hiringManager,
            style: .caseStudy,
            cardHash: "abc123"
        )

        #expect(result.projectName == "BusinessMath")
        #expect(result.title.contains("BusinessMath"))
        #expect(!result.summary.isEmpty)
        #expect(result.body.contains("## Problem"))
    }
}

/// Which hosts receive the API key.
///
/// The check was `host.hasSuffix("anthropic.com")`, which also admits `evilanthropic.com` — and
/// the request carries the key in `x-api-key`. The base URL comes from configuration.
@Suite("Narrative endpoint allowlist")
struct NarrativeEndpointAllowlistTests {

    @Test("Anthropic's host and its subdomains are allowed over HTTPS", arguments: [
        "https://api.anthropic.com/v1/messages",
        "https://anthropic.com/v1/messages",
        "http://localhost:8080/v1/messages",
    ])
    func allowed(url: String) throws {
        // SECURITY: test fixtures parsed to check the allowlist; no request is ever made here
        #expect(NarrativeGenerator.isAllowedEndpoint(try #require(URL(string: url))), "\(url)")
    }

    @Test("A lookalike host, plain HTTP, or another host is refused", arguments: [
        "https://evilanthropic.com/v1/messages",
        "https://api.anthropic.com.evil.example/v1/messages",
        // SECURITY: a plain-HTTP fixture that must be refused; it is parsed, never fetched
        "http://api.anthropic.com/v1/messages",
        "https://example.com/v1/messages",
    ])
    func refused(url: String) throws {
        // SECURITY: test fixtures parsed to check the allowlist; no request is ever made here
        #expect(!NarrativeGenerator.isAllowedEndpoint(try #require(URL(string: url))), "\(url)")
    }
}
