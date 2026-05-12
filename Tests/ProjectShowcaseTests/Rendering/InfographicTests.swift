//
//  InfographicTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("InfographicGenerator Tests")
struct InfographicTests {

    // MARK: - Shared Fixtures

    static let sampleCard = ProjectCard(
        projectName: "BusinessMath",
        projectPath: "/Users/test/BusinessMath",
        gatheredAt: Date(timeIntervalSince1970: 1_700_000_000),
        git: GitFacts(
            commitCount: 250,
            releaseHistory: [
                Release(tag: "v1.0.0", date: Date(timeIntervalSince1970: 1_620_000_000)),
                Release(tag: "v2.0.0", date: Date(timeIntervalSince1970: 1_660_000_000)),
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
        insights: nil,
        designArtifacts: nil
    )

    static let minimalCard = ProjectCard(
        projectName: "TinyRepo",
        projectPath: "/tmp/tiny",
        gatheredAt: Date(timeIntervalSince1970: 1_700_000_000),
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

    static let singleMonthCard = ProjectCard(
        projectName: "QuickProject",
        projectPath: "/tmp/quick",
        gatheredAt: Date(timeIntervalSince1970: 1_700_000_000),
        git: GitFacts(
            commitCount: 12,
            releaseHistory: [
                Release(tag: "v0.1.0", date: Date(timeIntervalSince1970: 1_700_000_000))
            ],
            branchCount: 1,
            firstCommitDate: Date(timeIntervalSince1970: 1_699_500_000),
            latestCommitDate: Date(timeIntervalSince1970: 1_700_000_000),
            contributorCount: 1
        ),
        packageManifest: nil,
        tests: nil,
        quality: nil,
        insights: nil,
        designArtifacts: nil
    )

    // MARK: - Protocol Conformance

    @Test("All generators conform to InfographicGenerator protocol")
    func protocolConformance() {
        let stats: any InfographicGenerator = StatsCardGenerator()
        let timeline: any InfographicGenerator = CommitTimelineGenerator()
        let releases: any InfographicGenerator = ReleaseTimelineGenerator()

        #expect(stats is any InfographicGenerator)
        #expect(timeline is any InfographicGenerator)
        #expect(releases is any InfographicGenerator)
    }

    // MARK: - StatsCardGenerator

    @Test("StatsCardGenerator produces valid SVG containing project name and commit count")
    func statsCardBasicContent() throws {
        let generator = StatsCardGenerator()
        let svg = try generator.generate(from: Self.sampleCard)

        #expect(svg.contains("<svg"))
        #expect(svg.contains("xmlns=\"http://www.w3.org/2000/svg\""))
        #expect(svg.contains("BusinessMath"))
        #expect(svg.contains("250"))
    }

    @Test("StatsCardGenerator includes test count when tests are available")
    func statsCardIncludesTestCount() throws {
        let generator = StatsCardGenerator()
        let svg = try generator.generate(from: Self.sampleCard)

        #expect(svg.contains("4944"))
    }

    @Test("StatsCardGenerator includes release count")
    func statsCardIncludesReleaseCount() throws {
        let generator = StatsCardGenerator()
        let svg = try generator.generate(from: Self.sampleCard)

        #expect(svg.contains("3"))
    }

    @Test("StatsCardGenerator includes platform count")
    func statsCardIncludesPlatformCount() throws {
        let generator = StatsCardGenerator()
        let svg = try generator.generate(from: Self.sampleCard)

        // 3 platforms: macOS, iOS, visionOS
        #expect(svg.contains("3"))
    }

    @Test("StatsCardGenerator handles minimal card without tests or releases")
    func statsCardMinimalCard() throws {
        let generator = StatsCardGenerator()
        let svg = try generator.generate(from: Self.minimalCard)

        #expect(svg.contains("<svg"))
        #expect(svg.contains("xmlns=\"http://www.w3.org/2000/svg\""))
        #expect(svg.contains("TinyRepo"))
        #expect(svg.contains("5"))
    }

    @Test("StatsCardGenerator produces SVG with valid dimensions")
    func statsCardDimensions() throws {
        let generator = StatsCardGenerator()
        let svg = try generator.generate(from: Self.sampleCard)

        #expect(svg.contains("width="))
        #expect(svg.contains("height="))
    }

    // MARK: - CommitTimelineGenerator

    @Test("CommitTimelineGenerator produces SVG with month labels")
    func commitTimelineMonthLabels() throws {
        let generator = CommitTimelineGenerator()
        let svg = try generator.generate(from: Self.sampleCard)

        #expect(svg.contains("<svg"))
        #expect(svg.contains("xmlns=\"http://www.w3.org/2000/svg\""))
        #expect(svg.contains("BusinessMath"))
        // Should contain rect elements for bars
        #expect(svg.contains("<rect"))
    }

    @Test("CommitTimelineGenerator handles single-month project")
    func commitTimelineSingleMonth() throws {
        let generator = CommitTimelineGenerator()
        let svg = try generator.generate(from: Self.singleMonthCard)

        #expect(svg.contains("<svg"))
        #expect(svg.contains("xmlns=\"http://www.w3.org/2000/svg\""))
        #expect(svg.contains("QuickProject"))
    }

    @Test("CommitTimelineGenerator includes project name in SVG")
    func commitTimelineProjectName() throws {
        let generator = CommitTimelineGenerator()
        let svg = try generator.generate(from: Self.sampleCard)

        #expect(svg.contains("BusinessMath"))
    }

    @Test("CommitTimelineGenerator produces SVG with valid dimensions")
    func commitTimelineDimensions() throws {
        let generator = CommitTimelineGenerator()
        let svg = try generator.generate(from: Self.sampleCard)

        #expect(svg.contains("width="))
        #expect(svg.contains("height="))
    }

    // MARK: - ReleaseTimelineGenerator

    @Test("ReleaseTimelineGenerator produces SVG with release tags")
    func releaseTimelineIncludesTags() throws {
        let generator = ReleaseTimelineGenerator()
        let svg = try generator.generate(from: Self.sampleCard)

        #expect(svg.contains("<svg"))
        #expect(svg.contains("xmlns=\"http://www.w3.org/2000/svg\""))
        #expect(svg.contains("v1.0.0"))
        #expect(svg.contains("v2.0.0"))
        #expect(svg.contains("v2.1.5"))
    }

    @Test("ReleaseTimelineGenerator includes project name")
    func releaseTimelineProjectName() throws {
        let generator = ReleaseTimelineGenerator()
        let svg = try generator.generate(from: Self.sampleCard)

        #expect(svg.contains("BusinessMath"))
    }

    @Test("ReleaseTimelineGenerator handles empty release history gracefully")
    func releaseTimelineEmptyReleases() throws {
        let generator = ReleaseTimelineGenerator()
        let svg = try generator.generate(from: Self.minimalCard)

        // Should still produce valid SVG, even if minimal
        #expect(svg.contains("<svg"))
        #expect(svg.contains("xmlns=\"http://www.w3.org/2000/svg\""))
    }

    @Test("ReleaseTimelineGenerator produces SVG with valid dimensions")
    func releaseTimelineDimensions() throws {
        let generator = ReleaseTimelineGenerator()
        let svg = try generator.generate(from: Self.sampleCard)

        #expect(svg.contains("width="))
        #expect(svg.contains("height="))
    }
}
