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
    hasDevGuidelines: Bool = false
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
