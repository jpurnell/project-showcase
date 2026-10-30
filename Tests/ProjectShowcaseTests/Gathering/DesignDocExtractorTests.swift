//
//  DesignDocExtractorTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

private func createProjectFixture(
    claudeMD: String? = nil,
    proposalCount: Int = 0,
    hasDevGuidelines: Bool = false,
    masterPlanContent: String? = nil
) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("showcase-docs-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    if let content = claudeMD {
        try content.write(
            to: dir.appendingPathComponent("CLAUDE.md"),
            atomically: true, encoding: .utf8
        )
    }

    if proposalCount > 0 {
        let proposalDir = dir
            .appendingPathComponent("development-guidelines")
            .appendingPathComponent("02_IMPLEMENTATION_PLANS")
            .appendingPathComponent("PROPOSALS")
        try FileManager.default.createDirectory(at: proposalDir, withIntermediateDirectories: true)

        for i in 1...proposalCount {
            try "# Proposal \(i)".write(
                to: proposalDir.appendingPathComponent("Proposal\(i).md"),
                atomically: true, encoding: .utf8
            )
        }
    }

    if hasDevGuidelines {
        let guidelinesDir = dir.appendingPathComponent("development-guidelines")
        try FileManager.default.createDirectory(at: guidelinesDir, withIntermediateDirectories: true)

        let workflowContent = """
        # Session Workflow
        0. DESIGN → Propose architecture
        1. RED → Write failing tests
        """
        let coreRules = guidelinesDir.appendingPathComponent("00_CORE_RULES")
        try FileManager.default.createDirectory(at: coreRules, withIntermediateDirectories: true)
        try workflowContent.write(
            to: coreRules.appendingPathComponent("07_SESSION_WORKFLOW.md"),
            atomically: true, encoding: .utf8
        )
    }

    if let masterPlan = masterPlanContent {
        let coreRulesDir = dir
            .appendingPathComponent("development-guidelines")
            .appendingPathComponent("00_CORE_RULES")
        try FileManager.default.createDirectory(at: coreRulesDir, withIntermediateDirectories: true)
        try masterPlan.write(
            to: coreRulesDir.appendingPathComponent("00_MASTER_PLAN.md"),
            atomically: true, encoding: .utf8
        )
    }

    return dir
}

@Suite("DesignDocExtractor Tests")
struct DesignDocExtractorTests {

    @Test("Detects CLAUDE.md presence")
    func detectsClaudeMD() async throws {
        let dir = try createProjectFixture(claudeMD: "# My Project\nSome instructions.")
        let extractor = DesignDocExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.hasClaudeMD)
    }

    @Test("Reports no CLAUDE.md when absent")
    func noClaudeMD() async throws {
        let dir = try createProjectFixture()
        let extractor = DesignDocExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(!facts.hasClaudeMD)
    }

    @Test("Counts design proposals in development-guidelines")
    func countsProposals() async throws {
        let dir = try createProjectFixture(proposalCount: 3)
        let extractor = DesignDocExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.designProposalCount == 3)
    }

    @Test("Zero proposals when directory doesn't exist")
    func zeroProposals() async throws {
        let dir = try createProjectFixture()
        let extractor = DesignDocExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.designProposalCount == 0)
    }

    @Test("Detects design-first workflow from development-guidelines")
    func detectsDesignFirstWorkflow() async throws {
        let dir = try createProjectFixture(hasDevGuidelines: true)
        let extractor = DesignDocExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.hasDesignFirstWorkflow)
    }

    @Test("Reports no design-first workflow when guidelines absent")
    func noDesignFirstWorkflow() async throws {
        let dir = try createProjectFixture()
        let extractor = DesignDocExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(!facts.hasDesignFirstWorkflow)
    }

    @Test("Extracts project description from filled MASTER_PLAN.md")
    func extractsProjectDescription() async throws {
        let masterPlan = """
        # MyProject Master Plan

        ## Project Overview

        ### Mission
        A Swift library that solves complex math problems with precision.

        ### Target Users
        - Developers building financial applications
        - Data scientists needing Swift-native numerics

        ### Key Differentiators
        - Battle-tested with 5000+ tests
        - Pure Swift, no C dependencies

        ---

        ## Architecture
        """
        let dir = try createProjectFixture(masterPlanContent: masterPlan)
        let extractor = DesignDocExtractor()
        let facts = try await extractor.extract(from: dir)

        let description = try #require(facts.projectDescription)
        #expect(description.contains("complex math problems"))
        #expect(description.contains("financial applications"))
        #expect(description.contains("Battle-tested"))
    }

    @Test("Returns nil for unfilled MASTER_PLAN.md template")
    func nilForUnfilledTemplate() async throws {
        let template = """
        # [PROJECT_NAME] Master Plan

        ## Project Overview

        ### Mission
        [Describe the core mission of this project - what problem does it solve?]

        ### Target Users
        - [User type 1]
        """
        let dir = try createProjectFixture(masterPlanContent: template)
        let extractor = DesignDocExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.projectDescription == nil)
    }

    @Test("Returns nil when no MASTER_PLAN.md exists")
    func nilWhenNoMasterPlan() async throws {
        let dir = try createProjectFixture()
        let extractor = DesignDocExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.projectDescription == nil)
    }

    @Test("Extracts partial description when only Mission is filled")
    func partialDescriptionMissionOnly() async throws {
        let masterPlan = """
        # MyProject Master Plan

        ## Project Overview

        ### Mission
        A tool for automated deployment of Swift packages.

        ---

        ## Architecture
        """
        let dir = try createProjectFixture(masterPlanContent: masterPlan)
        let extractor = DesignDocExtractor()
        let facts = try await extractor.extract(from: dir)

        let description = try #require(facts.projectDescription)
        #expect(description.contains("automated deployment"))
    }

    @Test("Extracts architecture notes from CLAUDE.md headings")
    func extractsArchitectureNotes() async throws {
        let content = """
        # MyProject

        ## Key Rules
        - TDD approach
        - Strict concurrency

        ## Architecture
        Protocol-oriented design with generic numerics.
        """
        let dir = try createProjectFixture(claudeMD: content)
        let extractor = DesignDocExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(!facts.architectureNotes.isEmpty)
    }
}

@Suite("DesignDocExtractor v2 Master Plan Location")
struct DesignDocExtractorV2LocationTests {

    static let plan = """
    # Core Master Plan

    ## Project Overview

    ### Mission
    A pure-Swift headless rules engine for a Risk-style strategy game.

    ### Target Consumers
    - The iconquer app

    ### Key Differentiators
    - Deterministic seeded RNG

    ---

    ## Architecture
    """

    private func fixture(planAt relativePath: String, content: String = plan) throws -> URL {
        let dir = try makeFixtureDirectory(prefix: "showcase-v2plan")
        try runGit(["init", "-q"], in: dir)
        let file = dir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: file, atomically: true, encoding: .utf8)
        return dir
    }

    @Test("Reads project/master_plan.md, the v2 location")
    func readsV2Location() async throws {
        let dir = try fixture(planAt: "project/master_plan.md")
        let facts = try await DesignDocExtractor().extract(from: dir)
        let description = try #require(facts.projectDescription, "a v2 plan must ground the narrative")
        #expect(description.contains("headless rules engine"))
    }

    @Test("Accepts Target Consumers as the audience heading")
    func targetConsumers() async throws {
        let dir = try fixture(planAt: "project/master_plan.md")
        let description = try #require(try await DesignDocExtractor().extract(from: dir).projectDescription)
        #expect(description.contains("iconquer app"))
        #expect(description.contains("Deterministic seeded RNG"))
    }

    @Test("Reads a root MASTER_PLAN.md")
    func readsRootPlan() async throws {
        let dir = try fixture(planAt: "MASTER_PLAN.md")
        let description = try #require(try await DesignDocExtractor().extract(from: dir).projectDescription)
        #expect(description.hasPrefix("Mission: A pure-Swift headless rules engine"))
    }

    @Test("An unfilled v2 template still yields no description")
    func templateRejected() async throws {
        let template = "## Project Overview\n\n### Mission\n[Describe the core mission of this project]\n"
        let dir = try fixture(planAt: "project/master_plan.md", content: template)
        #expect(try await DesignDocExtractor().extract(from: dir).projectDescription == nil)
    }
}

@Suite("DesignDocExtractor Plan Containment")
struct DesignDocExtractorContainmentTests {

    @Test("A master plan that is a symlink out of the project is ignored")
    func symlinkEscape() async throws {
        let outside = try makeFixtureDirectory(prefix: "showcase-outside")
        try writeFixtureFile("## Project Overview\n\n### Mission\nSomeone else's project.\n", named: "plan.md", in: outside)
        let project = try makeFixtureDirectory(prefix: "showcase-inside")
        try runGit(["init", "-q"], in: project)
        try FileManager.default.createDirectory(at: project.appendingPathComponent("project"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: project.appendingPathComponent("project/master_plan.md"),
            withDestinationURL: outside.appendingPathComponent("plan.md"))
        let facts = try await DesignDocExtractor().extract(from: project)
        #expect(facts.projectDescription == nil)
    }
}
