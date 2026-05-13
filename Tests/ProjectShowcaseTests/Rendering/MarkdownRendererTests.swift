//
//  MarkdownRendererTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("MarkdownRenderer Tests")
struct MarkdownRendererTests {

    static let sampleNarrative = NarrativeResult(
        projectName: "BusinessMath",
        audience: .hiringManager,
        style: .caseStudy,
        title: "BusinessMath: A Financial Mathematics Library Built with Design-First TDD",
        summary: "A Swift library providing financial math primitives with 4,900+ tests.",
        body: """
        ## Problem

        Financial calculations need precision and reliability.

        ## Approach

        Design-first TDD with strict concurrency compliance.

        ## Results

        4,944 tests across 400 suites, shipping as v2.1.5.
        """,
        generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        cardHash: "abc123"
    )

    @Test("Renders valid YAML frontmatter")
    func rendersFrontmatter() throws {
        let renderer = MarkdownRenderer()
        let output = try renderer.render(narrative: Self.sampleNarrative)

        #expect(output.hasPrefix("---\n"))
        #expect(output.contains("title:"))
        #expect(output.contains("date:"))
        #expect(output.contains("tags:"))
        let parts = output.split(separator: "---", maxSplits: 2)
        #expect(parts.count >= 2, "Should have frontmatter delimiters")
    }

    @Test("Includes project name in frontmatter title")
    func includesProjectName() throws {
        let renderer = MarkdownRenderer()
        let output = try renderer.render(narrative: Self.sampleNarrative)

        #expect(output.contains("BusinessMath"))
    }

    @Test("Body content appears after frontmatter")
    func bodyAfterFrontmatter() throws {
        let renderer = MarkdownRenderer()
        let output = try renderer.render(narrative: Self.sampleNarrative)

        let sections = output.components(separatedBy: "---\n")
        guard sections.count >= 3 else {
            Issue.record("Expected frontmatter + body sections")
            return
        }
        let body = sections[2...].joined(separator: "---\n")
        #expect(body.contains("## Problem"))
        #expect(body.contains("4,944 tests"))
    }

    @Test("Renders to file in output directory")
    func rendersToFile() throws {
        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("showcase-render-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let renderer = MarkdownRenderer()
        let filePath = try renderer.renderToFile(
            narrative: Self.sampleNarrative,
            outputDirectory: outputDir
        )

        #expect(FileManager.default.fileExists(atPath: filePath.path))
        #expect(filePath.pathExtension == "md")

        let content = try String(contentsOf: filePath, encoding: .utf8)
        #expect(content.contains("BusinessMath"))
    }

    @Test("Summary appears in frontmatter as description")
    func summaryInFrontmatter() throws {
        let renderer = MarkdownRenderer()
        let output = try renderer.render(narrative: Self.sampleNarrative)

        #expect(output.contains("description:"))
    }

    // MARK: - Ignite-compatible frontmatter tests

    @Test("Date format matches Ignite parser")
    func dateFormatMatchesIgnite() throws {
        let renderer = MarkdownRenderer()
        let output = try renderer.render(narrative: Self.sampleNarrative)

        // Ignite parses "yyyy-MM-dd HH:mm", not ISO8601 with T and Z
        let lines = output.components(separatedBy: "\n")
        let dateLine = lines.first(where: { $0.hasPrefix("date:") })
        #expect(dateLine != nil, "Should have a date: line")
        #expect(dateLine?.contains("T") == false, "Date should not contain ISO8601 T separator")
        #expect(dateLine?.contains("Z") == false, "Date should not contain Z suffix")
        // The sample date is 2023-11-14 (epoch 1_700_000_000)
        #expect(dateLine?.contains("2023-11-14") == true, "Date should contain yyyy-MM-dd")
    }

    @Test("Tags are comma-separated without brackets")
    func tagsCommaSeparatedNoBrackets() throws {
        let renderer = MarkdownRenderer()
        let output = try renderer.render(narrative: Self.sampleNarrative)

        let lines = output.components(separatedBy: "\n")
        let tagsLine = lines.first(where: { $0.hasPrefix("tags:") })
        #expect(tagsLine != nil, "Should have a tags: line")
        #expect(tagsLine?.contains("[") == false, "Tags should not contain opening bracket")
        #expect(tagsLine?.contains("]") == false, "Tags should not contain closing bracket")
        #expect(tagsLine?.contains("showcase, project, businessmath, hiringManager") == true,
                "Tags should be comma-separated with showcase and project")
    }

    @Test("Layout key is present")
    func layoutKeyPresent() throws {
        let renderer = MarkdownRenderer()
        let output = try renderer.render(narrative: Self.sampleNarrative)

        #expect(output.contains("layout: ShowcaseLayout"))
    }

    @Test("Published key is present")
    func publishedKeyPresent() throws {
        let renderer = MarkdownRenderer()
        let output = try renderer.render(narrative: Self.sampleNarrative)

        #expect(output.contains("published: true"))
    }

    @Test("Title is not quoted")
    func titleNotQuoted() throws {
        let renderer = MarkdownRenderer()
        let output = try renderer.render(narrative: Self.sampleNarrative)

        let lines = output.components(separatedBy: "\n")
        let titleLine = lines.first(where: { $0.hasPrefix("title:") })
        #expect(titleLine != nil, "Should have a title: line")
        #expect(titleLine?.contains("title: \"") == false,
                "Title value should not be wrapped in quotes")
    }

    @Test("LastModified key is present")
    func lastModifiedPresent() throws {
        let renderer = MarkdownRenderer()
        let output = try renderer.render(narrative: Self.sampleNarrative)

        #expect(output.contains("lastModified: 2023-11-14"))
    }
}
