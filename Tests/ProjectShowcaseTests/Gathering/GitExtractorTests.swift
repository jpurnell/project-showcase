//
//  GitExtractorTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

private func createFixtureRepo() throws -> URL {
    let directory = try makeFixtureDirectory(prefix: "showcase-test")
    try runGit(["init"], in: directory)

    try writeFixtureFile("hello\n", named: "file.txt", in: directory)
    try runGit(["add", "."], in: directory)
    try runGit(["commit", "-m", "Initial commit"], in: directory)

    try writeFixtureFile("hello\nworld\n", named: "file.txt", in: directory)
    try runGit(["add", "."], in: directory)
    try runGit(["commit", "-m", "Second commit"], in: directory)
    try runGit(["tag", "v1.0.0"], in: directory)

    try writeFixtureFile("hello\nworld\nthird\n", named: "file.txt", in: directory)
    try runGit(["add", "."], in: directory)
    try runGit(["commit", "-m", "Third commit"], in: directory)
    try runGit(["tag", "v1.1.0"], in: directory)

    return directory
}

@Suite("GitExtractor Tests")
struct GitExtractorTests {

    let fixtureRepo: URL

    init() throws {
        self.fixtureRepo = try createFixtureRepo()
    }

    @Test("Extracts correct commit count from fixture repo")
    func commitCount() async throws {
        let extractor = GitExtractor()
        let facts = try await extractor.extract(from: fixtureRepo)

        #expect(facts.commitCount == 3)
    }

    @Test("Extracts release tags as Release objects")
    func releaseTags() async throws {
        let extractor = GitExtractor()
        let facts = try await extractor.extract(from: fixtureRepo)

        #expect(facts.releaseHistory.count == 2)
        let tags = facts.releaseHistory.map(\.tag)
        #expect(tags.contains("v1.0.0"))
        #expect(tags.contains("v1.1.0"))
    }

    @Test("Extracts contributor count")
    func contributorCount() async throws {
        let extractor = GitExtractor()
        let facts = try await extractor.extract(from: fixtureRepo)

        #expect(facts.contributorCount == 1)
    }

    @Test("Extracts branch count")
    func branchCount() async throws {
        let extractor = GitExtractor()
        let facts = try await extractor.extract(from: fixtureRepo)

        #expect(facts.branchCount >= 1)
    }

    @Test("Extracts first and latest commit dates")
    func commitDates() async throws {
        let extractor = GitExtractor()
        let facts = try await extractor.extract(from: fixtureRepo)

        let first = try #require(facts.firstCommitDate)
        let latest = try #require(facts.latestCommitDate)
        #expect(first <= latest)
    }

    @Test("Throws for non-git directory")
    func nonGitDirectory() async throws {
        let extractor = GitExtractor()
        let nonGitPath = try makeFixtureDirectory(prefix: "not-a-repo")

        var didThrow = false
        do {
            _ = try await extractor.extract(from: nonGitPath)
        } catch is ShowcaseError {
            didThrow = true
        }
        #expect(didThrow, "Expected ShowcaseError for non-git directory")
    }
}
