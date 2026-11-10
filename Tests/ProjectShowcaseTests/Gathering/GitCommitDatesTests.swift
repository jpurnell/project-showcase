//
//  GitCommitDatesTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-11-10.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("GitExtractor commit dates")
struct GitCommitDatesTests {

    /// Commits authored on fixed dates: two in January 2024, none in February, three in March.
    private func datedRepo() throws -> URL {
        let directory = try makeFixtureDirectory(prefix: "showcase-dates")
        try runGit(["init"], in: directory)
        let dates = [
            "2024-01-05T12:00:00Z", "2024-01-20T12:00:00Z",
            "2024-03-02T12:00:00Z", "2024-03-03T12:00:00Z", "2024-03-30T12:00:00Z"
        ]
        for (index, date) in dates.enumerated() {
            try writeFixtureFile("line \(index)\n", named: "file.txt", in: directory)
            try runGit(["add", "."], in: directory)
            try runGit(["commit", "-m", "Commit \(index)", "--date=\(date)"], in: directory)
        }
        return directory
    }

    @Test("Records one author date per commit")
    func oneDatePerCommit() async throws {
        let facts = try await GitExtractor().extract(from: datedRepo())
        let dates = try #require(facts.commitDates)

        #expect(dates.count == facts.commitCount)
        #expect(dates.count == 5)
    }

    @Test("Dates are the author dates, oldest first")
    func authorDatesOldestFirst() async throws {
        let facts = try await GitExtractor().extract(from: datedRepo())
        let dates = try #require(facts.commitDates)
        let formatter = ISO8601DateFormatter()

        #expect(dates.first == formatter.date(from: "2024-01-05T12:00:00Z"))
        #expect(dates.last == formatter.date(from: "2024-03-30T12:00:00Z"))
        #expect(dates == dates.sorted())
    }

    @Test("A card saved before commit dates existed still decodes")
    func oldCardDecodes() throws {
        let json = """
        {"commitCount":3,"releaseHistory":[],"branchCount":1,"contributorCount":1}
        """
        let facts = try JSONDecoder().decode(GitFacts.self, from: Data(json.utf8))

        #expect(facts.commitDates == nil)
        #expect(facts.commitCount == 3)
    }
}
