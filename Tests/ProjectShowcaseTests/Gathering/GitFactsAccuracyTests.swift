//
//  GitFactsAccuracyTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-11-10.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("GitExtractor counts people and releases, not spellings and tags")
struct GitFactsAccuracyTests {

    private func repo(authors: [String], tags: [String]) throws -> URL {
        let directory = try makeFixtureDirectory(prefix: "showcase-accuracy")
        try runGit(["init"], in: directory)
        for (index, author) in authors.enumerated() {
            try writeFixtureFile("\(index)\n", named: "f.txt", in: directory)
            try runGit(["add", "."], in: directory)
            try runGit(["commit", "-m", "c\(index)", "--author=\(author)"], in: directory)
        }
        for tag in tags { try runGit(["tag", tag], in: directory) }
        return directory
    }

    @Test("One person under two names is one contributor")
    func sameEmailOnePerson() async throws {
        let dir = try repo(authors: [
            "Dustin <d@example.com>", "Dustin Bergman <d@example.com>", "Justin Purnell <j@example.com>"
        ], tags: [])
        let facts = try await GitExtractor().extract(from: dir)

        #expect(facts.contributorCount == 2)
    }

    @Test("An email's case does not make a second person")
    func emailCase() async throws {
        let dir = try repo(authors: ["D <dustin@GMAIL.com>", "D <dustin@gmail.COM>"], tags: [])
        let facts = try await GitExtractor().extract(from: dir)

        #expect(facts.contributorCount == 1)
    }

    @Test("The same name with different emails stays two people")
    func differentEmails() async throws {
        let dir = try repo(authors: ["Sam <a@example.com>", "Sam <b@example.com>"], tags: [])
        let facts = try await GitExtractor().extract(from: dir)

        #expect(facts.contributorCount == 2)
    }

    @Test("Only version tags are releases")
    func versionTagsOnly() async throws {
        let dir = try repo(authors: ["A <a@example.com>"], tags: [
            "v1.0.0", "2.0.0", "0.2", "3.1.4-beta.1", "archive/stash-2023-07-25", "backup", "wip"
        ])
        let facts = try await GitExtractor().extract(from: dir)
        let tags = Set(facts.releaseHistory.map(\.tag))

        #expect(tags == ["v1.0.0", "2.0.0", "0.2", "3.1.4-beta.1"])
    }
}
