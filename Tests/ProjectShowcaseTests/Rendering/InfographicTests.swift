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

    /// Conformance is the compiler's to check, and it has by the time this runs: the three
    /// bindings below would not build otherwise. What a test can add is that each generator,
    /// reached only through the protocol, draws its own chart for the card it was given.
    @Test("Each generator, called through the protocol, draws its own chart")
    func protocolConformance() throws {
        let stats: any InfographicGenerator = StatsCardGenerator()
        let timeline: any InfographicGenerator = CommitTimelineGenerator()
        let releases: any InfographicGenerator = ReleaseTimelineGenerator()

        let statsSVG = try stats.generate(from: Self.sampleCard)
        let timelineSVG = try timeline.generate(from: Self.sampleCard)
        let releasesSVG = try releases.generate(from: Self.sampleCard)

        let svgOpening = "<svg xmlns=\"http://www.w3.org/2000/svg\""
        #expect(statsSVG.hasPrefix(svgOpening))
        #expect(timelineSVG.hasPrefix(svgOpening))
        #expect(releasesSVG.hasPrefix(svgOpening))

        #expect(statsSVG.contains(">BusinessMath</text>"))
        #expect(timelineSVG.contains(">BusinessMath — Commit Activity</text>"))
        #expect(releasesSVG.contains(">BusinessMath — Releases</text>"))
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

    // MARK: - CommitTimelineGenerator: where it runs must not change what it draws

    /// One commit at 02:00 UTC on 1 November 2023, the last on 20 November. In UTC that is one
    /// month. In New York the first commit is still 31 October, so it is two.
    static let monthBoundaryCard = ProjectCard(
        projectName: "Boundary",
        projectPath: "/tmp/boundary",
        gatheredAt: Date(timeIntervalSince1970: 1_700_438_400),
        git: GitFacts(
            commitCount: 8,
            releaseHistory: [],
            branchCount: 1,
            firstCommitDate: Date(timeIntervalSince1970: 1_698_804_000),
            latestCommitDate: Date(timeIntervalSince1970: 1_700_438_400),
            contributorCount: 1
        ),
        packageManifest: nil,
        tests: nil,
        quality: nil,
        insights: nil,
        designArtifacts: nil
    )

    @Test("CommitTimelineGenerator counts months in UTC unless told otherwise")
    func commitTimelineDefaultsToUTC() throws {
        let svg = try CommitTimelineGenerator().generate(from: Self.monthBoundaryCard)

        #expect(svg.contains(">Nov</text>"))
        #expect(!svg.contains(">Oct</text>"))
        #expect(svg.contains("~8/month (8 total)"))
    }

    @Test("CommitTimelineGenerator counts months in the time zone it is given")
    func commitTimelineUsesInjectedTimeZone() throws {
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        let svg = try CommitTimelineGenerator(timeZone: newYork).generate(from: Self.monthBoundaryCard)

        #expect(svg.contains(">Oct</text>"))
        #expect(svg.contains(">Nov</text>"))
        #expect(svg.contains("~4/month (8 total)"))
    }

    @Test("CommitTimelineGenerator labels months in the locale it is given")
    func commitTimelineUsesInjectedLocale() throws {
        let generator = CommitTimelineGenerator(locale: Locale(identifier: "fr_FR"))
        let svg = try generator.generate(from: Self.monthBoundaryCard)

        #expect(svg.contains(">nov.</text>"))
        #expect(!svg.contains(">Nov</text>"))
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
