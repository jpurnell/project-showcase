//
//  ChartLayoutTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-11-10.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("The three charts share one layout")
struct ChartLayoutTests {

    static let generators: [any InfographicGenerator] = [
        StatsCardGenerator(), CommitTimelineGenerator(), ReleaseTimelineGenerator()
    ]

    /// A name's attribute, from the first element on a line that matches.
    private func attribute(_ name: String, in line: String) -> Double? {
        guard let range = line.range(of: " \(name)=\"") else { return nil }
        return Double(line[range.upperBound...].prefix { $0.isNumber || $0 == "." })
    }

    private func lines(_ svg: String) -> [String] {
        svg.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline).map(String.init)
    }

    @Test("Every chart is the same width, and the heavy rule sits under the title")
    func ruleUnderTitle() throws {
        for generator in Self.generators {
            let svg = try generator.generate(from: InfographicTests.sampleCard)
            let title = try #require(lines(svg).first { $0.contains("font-size=\"18\"") })
            let rule = try #require(lines(svg).first { $0.contains("class=\"ig-rule\"") })

            #expect(svg.contains("width=\"600\""), "\(type(of: generator)) is not 600 wide")
            let ruleY = try #require(attribute("y", in: rule))
            let titleY = try #require(attribute("y", in: title))
            #expect(ruleY > titleY, "\(type(of: generator)): the rule is not below the title")
            let ruleHeight = try #require(attribute("height", in: rule))
            #expect(abs(ruleHeight - 3) < 0.001)
        }
    }

    @Test("There is no border and no rule above the title")
    func noFrame() throws {
        for generator in Self.generators {
            let svg = try generator.generate(from: InfographicTests.sampleCard)
            #expect(!svg.contains("ig-frame"), "\(type(of: generator)) draws a border")
            #expect(lines(svg).filter { $0.contains("class=\"ig-rule\"") }.count == 1,
                    "\(type(of: generator)) draws more than one heavy rule")
        }
    }

    @Test("Titles share a size and a left edge")
    func consistentTitles() throws {
        var seen: Set<String> = []
        for generator in Self.generators {
            let svg = try generator.generate(from: InfographicTests.sampleCard)
            let title = try #require(lines(svg).first { $0.contains("font-size=\"18\"") })
            seen.insert("x=\(attribute("x", in: title) ?? -1) y=\(attribute("y", in: title) ?? -1) size=18")
        }
        #expect(seen.count == 1, "titles differ: \(seen)")
    }

    @Test("Release labels never overlap, even with many releases")
    func releaseLabelsDoNotCollide() throws {
        let releases = (0..<26).map { index in
            Release(tag: "v\(index / 10).\(index % 10).0",
                    date: Date(timeIntervalSince1970: 1_560_000_000 + Double(index) * 7_000_000))
        }
        let card = ProjectCard(
            projectName: "Many", projectPath: "/tmp/many", gatheredAt: Date(timeIntervalSince1970: 1_750_000_000),
            git: GitFacts(commitCount: 300, releaseHistory: releases, branchCount: 1,
                          firstCommitDate: releases.first?.date, latestCommitDate: releases.last?.date,
                          contributorCount: 1),
            packageManifest: nil, tests: nil, quality: nil, insights: nil, designArtifacts: nil)
        let svg = try ReleaseTimelineGenerator().generate(from: card)

        let labelled = lines(svg).filter { $0.contains("class=\"ig-label\"") && $0.contains("font-size=\"11\"") }
        let spans = labelled.compactMap { line -> (Double, Double)? in
            guard let x = attribute("x", in: line),
                  let open = line.range(of: ">"), let close = line.range(of: "</text>") else { return nil }
            let width = Double(line[open.upperBound..<close.lowerBound].count) * 6.5
            return (x - width / 2, x + width / 2)
        }.sorted { $0.0 < $1.0 }

        #expect(spans.count >= 2 && spans.count < 26)
        for (previous, next) in zip(spans, spans.dropFirst()) {
            #expect(previous.1 <= next.0, "two release labels overlap")
        }
        #expect(svg.contains(">26 releases"))
    }

    @Test("Releases and commits share one time axis, so they read together")
    func sharedAxis() throws {
        let card = CommitBarsTests.longCard
        let commits = try CommitTimelineGenerator().generate(from: card)
        let releases = try ReleaseTimelineGenerator().generate(from: ProjectCard(
            projectName: card.projectName, projectPath: card.projectPath, gatheredAt: card.gatheredAt,
            git: GitFacts(commitCount: card.git.commitCount,
                          releaseHistory: [Release(tag: "v1.0.0", date: InfographicTests.sampleCard.git.releaseHistory[0].date)],
                          branchCount: 1, firstCommitDate: card.git.firstCommitDate,
                          latestCommitDate: card.git.latestCommitDate, contributorCount: 1,
                          commitDates: card.git.commitDates),
            packageManifest: nil, tests: nil, quality: nil, insights: nil, designArtifacts: nil))

        func axis(_ svg: String) -> [String] {
            lines(svg).filter { $0.contains("class=\"ig-muted\"") && $0.contains("font-size=\"10\"") }
                .compactMap { line in
                    guard let x = attribute("x", in: line), let open = line.range(of: ">"),
                          let close = line.range(of: "</text>") else { return nil }
                    return "\(Int(x)):\(line[open.upperBound..<close.lowerBound])"
                }
        }
        #expect(!axis(commits).isEmpty)
        #expect(axis(commits) == axis(releases))
    }
}
