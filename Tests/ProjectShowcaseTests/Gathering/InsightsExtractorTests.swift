//
//  InsightsExtractorTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("InsightsExtractor Tests")
struct InsightsExtractorTests {

    let fixtureDir: URL = {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("showcase-insights-\(UUID().uuidString)")
    }()

    init() throws {
        let fm = FileManager.default
        let facetsDir = fixtureDir.appendingPathComponent("facets")
        let sessionDir = fixtureDir.appendingPathComponent("session-meta")
        try fm.createDirectory(at: facetsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: sessionDir, withIntermediateDirectories: true)

        let facet1 = """
        {
          "underlying_goal": "Build a financial math library",
          "goal_categories": { "feature_implementation": 6, "bug_fixing": 2 },
          "outcome": "fully_achieved",
          "user_satisfaction_counts": { "satisfied": 3 },
          "claude_helpfulness": "essential",
          "session_type": "iterative_refinement",
          "friction_counts": { "buggy_code": 2 },
          "primary_success": "multi_file_changes",
          "brief_summary": "Built financial math functions.",
          "session_id": "session-001"
        }
        """

        let facet2 = """
        {
          "underlying_goal": "Fix CI pipeline",
          "goal_categories": { "bug_fixing": 3 },
          "outcome": "mostly_achieved",
          "user_satisfaction_counts": { "likely_satisfied": 2 },
          "claude_helpfulness": "very_helpful",
          "session_type": "exploration",
          "friction_counts": { "wrong_approach": 1 },
          "primary_success": "fast_accurate_search",
          "brief_summary": "Debugged CI failures.",
          "session_id": "session-002"
        }
        """

        let meta1 = """
        {
          "session_id": "session-001",
          "project_path": "/Users/test/BusinessMath",
          "start_time": "2026-04-15T01:58:43.124Z",
          "duration_minutes": 120,
          "user_message_count": 30,
          "assistant_message_count": 60,
          "tool_counts": { "Edit": 50, "Bash": 30, "Agent": 10 },
          "languages": {},
          "git_commits": 15,
          "git_pushes": 2,
          "input_tokens": 100,
          "output_tokens": 5000,
          "first_prompt": "Let's implement the NPV function",
          "lines_added": 500,
          "lines_removed": 100,
          "files_modified": 20
        }
        """

        let meta2 = """
        {
          "session_id": "session-002",
          "project_path": "/Users/test/BusinessMath",
          "start_time": "2026-04-16T10:00:00.000Z",
          "duration_minutes": 45,
          "user_message_count": 10,
          "assistant_message_count": 20,
          "tool_counts": { "Bash": 15, "Read": 10 },
          "languages": {},
          "git_commits": 3,
          "git_pushes": 1,
          "input_tokens": 50,
          "output_tokens": 2000,
          "first_prompt": "CI is failing",
          "lines_added": 50,
          "lines_removed": 20,
          "files_modified": 5
        }
        """

        try facet1.write(to: facetsDir.appendingPathComponent("session-001.json"), atomically: true, encoding: .utf8)
        try facet2.write(to: facetsDir.appendingPathComponent("session-002.json"), atomically: true, encoding: .utf8)
        try meta1.write(to: sessionDir.appendingPathComponent("session-001.json"), atomically: true, encoding: .utf8)
        try meta2.write(to: sessionDir.appendingPathComponent("session-002.json"), atomically: true, encoding: .utf8)
    }

    @Test("Parses session count from facets directory")
    func sessionCount() async throws {
        let extractor = InsightsExtractor()
        let summary = try await extractor.extract(from: fixtureDir)

        #expect(summary.sessionCount == 2)
    }

    @Test("Aggregates commit count from session-meta")
    func totalCommits() async throws {
        let extractor = InsightsExtractor()
        let summary = try await extractor.extract(from: fixtureDir)

        #expect(summary.totalCommits == 18)
    }

    @Test("Aggregates message count from session-meta")
    func totalMessages() async throws {
        let extractor = InsightsExtractor()
        let summary = try await extractor.extract(from: fixtureDir)

        #expect(summary.totalMessages == 40)
    }

    @Test("Aggregates friction categories across sessions")
    func frictionCategories() async throws {
        let extractor = InsightsExtractor()
        let summary = try await extractor.extract(from: fixtureDir)

        #expect(summary.frictionCategories["buggy_code"] == 2)
        #expect(summary.frictionCategories["wrong_approach"] == 1)
    }

    @Test("Aggregates outcome distribution")
    func outcomeDistribution() async throws {
        let extractor = InsightsExtractor()
        let summary = try await extractor.extract(from: fixtureDir)

        #expect(summary.outcomeDistribution["fully_achieved"] == 1)
        #expect(summary.outcomeDistribution["mostly_achieved"] == 1)
    }

    @Test("Aggregates tool usage profile across sessions")
    func toolUsageProfile() async throws {
        let extractor = InsightsExtractor()
        let summary = try await extractor.extract(from: fixtureDir)

        #expect(summary.toolUsageProfile["Edit"] == 50)
        #expect(summary.toolUsageProfile["Bash"] == 45)
        #expect(summary.toolUsageProfile["Agent"] == 10)
        #expect(summary.toolUsageProfile["Read"] == 10)
    }

    @Test("Aggregates session types")
    func sessionTypes() async throws {
        let extractor = InsightsExtractor()
        let summary = try await extractor.extract(from: fixtureDir)

        #expect(summary.sessionTypes["iterative_refinement"] == 1)
        #expect(summary.sessionTypes["exploration"] == 1)
    }

    @Test("Returns nil for directory without insights data")
    func missingInsightsDirectory() async throws {
        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-insights-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

        let extractor = InsightsExtractor()
        let summary = try await extractor.extractOptional(from: emptyDir)

        #expect(summary == nil)
    }
}
