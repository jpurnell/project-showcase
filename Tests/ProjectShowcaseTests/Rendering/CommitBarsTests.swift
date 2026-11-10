//
//  CommitBarsTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-11-10.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("CommitTimelineGenerator bars show real activity")
struct CommitBarsTests {

    private static func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso) ?? .distantPast
    }

    /// January 1 commit, February none, March 3, April 6.
    static let card: ProjectCard = {
        let dates = ["2024-01-10T12:00:00Z"]
            + ["2024-03-02T12:00:00Z", "2024-03-09T12:00:00Z", "2024-03-16T12:00:00Z"]
            + (1...6).map { "2024-04-0\($0)T12:00:00Z" }
        return ProjectCard(
            projectName: "Bars",
            projectPath: "/tmp/bars",
            gatheredAt: date("2024-04-30T00:00:00Z"),
            git: GitFacts(
                commitCount: 10,
                releaseHistory: [],
                branchCount: 1,
                firstCommitDate: date("2024-01-10T12:00:00Z"),
                latestCommitDate: date("2024-04-06T12:00:00Z"),
                contributorCount: 1,
                commitDates: dates.map(date)
            ),
            packageManifest: nil, tests: nil, quality: nil, insights: nil, designArtifacts: nil
        )
    }()

    /// Heights of every `class="bar"` rect, in drawing order.
    private func barHeights(_ svg: String) -> [Int] {
        svg.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .filter { $0.contains("class=\"ig-bar\"") }
            .compactMap { line -> Int? in
                guard let range = line.range(of: "height=\"") else { return nil }
                return Int(line[range.upperBound...].prefix { $0.isNumber })
            }
    }

    @Test("Bar heights are proportional to each month's commits")
    func proportionalHeights() throws {
        let heights = barHeights(try CommitTimelineGenerator().generate(from: Self.card))

        // January 1, March 3, April 6; February has none and draws nothing.
        try #require(heights.count == 3)
        let tallest = try #require(heights.max())
        #expect(heights[2] == tallest)
        #expect(heights[0] < heights[1])
        #expect(heights[1] < heights[2])
        #expect(abs(Double(heights[1]) / Double(tallest) - 0.5) < 0.05)
        #expect(abs(Double(heights[0]) / Double(tallest) - 1.0 / 6.0) < 0.05)
    }

    @Test("A month with no commits draws no bar but keeps its place")
    func emptyMonthKeepsPlace() throws {
        let svg = try CommitTimelineGenerator().generate(from: Self.card)

        #expect(barHeights(svg).count == 3)
        #expect(svg.contains(">Feb</text>"))
    }

    @Test("A single commit still shows")
    func singleCommitVisible() throws {
        let heights = barHeights(try CommitTimelineGenerator().generate(from: Self.card))
        let first = try #require(heights.first)
        #expect(first >= 1)
    }

    @Test("The annotation states the true monthly average and the peak")
    func annotation() throws {
        let svg = try CommitTimelineGenerator().generate(from: Self.card)

        // 10 commits over four months, peak 6.
        #expect(svg.contains("~2/month"))
        #expect(svg.contains("peak 6"))
        #expect(svg.contains("(10 total)"))
    }

    @Test("Months are bucketed in the time zone the generator is given")
    func timeZoneBuckets() throws {
        // 02:00 UTC on 1 March is still 29 February in New York.
        let dates = ["2024-02-10T12:00:00Z", "2024-03-01T02:00:00Z", "2024-03-01T03:00:00Z"].map(Self.date)
        let card = ProjectCard(
            projectName: "Zone", projectPath: "/tmp/zone", gatheredAt: Self.date("2024-03-31T00:00:00Z"),
            git: GitFacts(commitCount: 3, releaseHistory: [], branchCount: 1,
                          firstCommitDate: dates[0], latestCommitDate: dates[2], contributorCount: 1,
                          commitDates: dates),
            packageManifest: nil, tests: nil, quality: nil, insights: nil, designArtifacts: nil
        )
        let newYork = try #require(TimeZone(identifier: "America/New_York"))

        let utc = barHeights(try CommitTimelineGenerator().generate(from: card))
        let local = barHeights(try CommitTimelineGenerator(timeZone: newYork).generate(from: card))

        // UTC: February 1, March 2, so two bars. New York: all three are in February, so one.
        try #require(utc.count == 2)
        #expect(utc[0] < utc[1])
        #expect(local.count == 1)
    }

    @Test("Without commit dates no bar claims an activity level")
    func noDatesNoBars() throws {
        let svg = try CommitTimelineGenerator().generate(from: InfographicTests.sampleCard)
        #expect(barHeights(svg).isEmpty)
        #expect(svg.contains("~"))
    }

    // MARK: - Labels on a long history

    /// A month number as two digits, for an ISO 8601 string.
    static func twoDigits(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }

    /// One commit a month from March 2021 to May 2024: 39 months, far more than a month-name axis can say.
    static let longCard: ProjectCard = {
        let dates = (0..<39).map { offset -> Date in
            let year = 2021 + (2 + offset) / 12
            let month = (2 + offset) % 12 + 1
            return date("\(year)-\(Self.twoDigits(month))-15T12:00:00Z")
        }
        return ProjectCard(
            projectName: "Long", projectPath: "/tmp/long", gatheredAt: date("2024-06-01T00:00:00Z"),
            git: GitFacts(commitCount: dates.count, releaseHistory: [], branchCount: 1,
                          firstCommitDate: dates.first, latestCommitDate: dates.last, contributorCount: 1,
                          commitDates: dates),
            packageManifest: nil, tests: nil, quality: nil, insights: nil, designArtifacts: nil
        )
    }()

    private func labels(_ svg: String) -> [String] {
        svg.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .filter { $0.contains("class=\"ig-muted\"") && $0.contains("y=\"") && $0.contains("font-size=\"10\"") }
            .compactMap { line -> String? in
                guard let open = line.range(of: ">"), let close = line.range(of: "</text>") else { return nil }
                return String(line[open.upperBound..<close.lowerBound])
            }
    }

    @Test("Over fourteen months the axis names years, not months")
    func longHistoryNamesYears() throws {
        let axis = labels(try CommitTimelineGenerator().generate(from: Self.longCard))

        #expect(axis == ["2022", "2023", "2024"])
    }

    @Test("Up to fourteen months the axis still names months")
    func shortHistoryNamesMonths() throws {
        let axis = labels(try CommitTimelineGenerator().generate(from: Self.card))

        #expect(axis.contains("Feb"))
        #expect(!axis.contains("2024"))
    }

    /// Eight years of months, one commit each: the case where fixed minimum bar widths ran off the chart.
    @Test("Bars never run past the chart's right edge, however long the history")
    func barsStayInside() throws {
        let dates = (0..<96).map { offset -> Date in
            let year = 2018 + offset / 12
            let month = offset % 12 + 1
            return Self.date("\(year)-\(Self.twoDigits(month))-10T12:00:00Z")
        }
        let card = ProjectCard(
            projectName: "Decade", projectPath: "/tmp/decade", gatheredAt: Self.date("2026-01-01T00:00:00Z"),
            git: GitFacts(commitCount: dates.count, releaseHistory: [], branchCount: 1,
                          firstCommitDate: dates.first, latestCommitDate: dates.last, contributorCount: 1,
                          commitDates: dates),
            packageManifest: nil, tests: nil, quality: nil, insights: nil, designArtifacts: nil
        )
        let svg = try CommitTimelineGenerator().generate(from: card)
        let rights = svg.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .filter { $0.contains("class=\"ig-bar\"") }
            .compactMap { line -> Int? in
                func value(_ key: String) -> Int? {
                    guard let r = line.range(of: " \(key)=\"") else { return nil }
                    return Int(line[r.upperBound...].prefix { $0.isNumber })
                }
                guard let x = value("x"), let w = value("width") else { return nil }
                return x + w
            }
        try #require(rights.count == 96)
        let widest = try #require(rights.max())
        #expect(widest <= 576)   // right edge = width 600 - margin 24
    }
}
