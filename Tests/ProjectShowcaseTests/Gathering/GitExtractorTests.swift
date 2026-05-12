//
//  GitExtractorTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

private func runGit(_ cmd: String, in directory: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", cmd]
    process.currentDirectoryURL = URL(fileURLWithPath: directory)
    process.environment = [
        "PATH": "/usr/bin:/bin:/usr/local/bin",
        "HOME": NSHomeDirectory(),
        "GIT_AUTHOR_NAME": "Test",
        "GIT_AUTHOR_EMAIL": "test@test.com",
        "GIT_COMMITTER_NAME": "Test",
        "GIT_COMMITTER_EMAIL": "test@test.com"
    ]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw ShowcaseError.extractionFailed(source: "git", message: "Command failed: \(cmd)")
    }
}

private func createFixtureRepo() throws -> String {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("showcase-test-\(UUID().uuidString)").path
    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    try runGit("git init", in: path)
    try runGit("echo 'hello' > file.txt && git add . && git commit -m 'Initial commit'", in: path)
    try runGit("echo 'world' >> file.txt && git add . && git commit -m 'Second commit'", in: path)
    try runGit("git tag v1.0.0", in: path)
    try runGit("echo 'third' >> file.txt && git add . && git commit -m 'Third commit'", in: path)
    try runGit("git tag v1.1.0", in: path)
    return path
}

@Suite("GitExtractor Tests")
struct GitExtractorTests {

    let fixtureRepoPath: String

    init() throws {
        self.fixtureRepoPath = try createFixtureRepo()
    }

    @Test("Extracts correct commit count from fixture repo")
    func commitCount() async throws {
        let extractor = GitExtractor()
        let facts = try await extractor.extract(from: URL(fileURLWithPath: fixtureRepoPath))

        #expect(facts.commitCount == 3)
    }

    @Test("Extracts release tags as Release objects")
    func releaseTags() async throws {
        let extractor = GitExtractor()
        let facts = try await extractor.extract(from: URL(fileURLWithPath: fixtureRepoPath))

        #expect(facts.releaseHistory.count == 2)
        let tags = facts.releaseHistory.map(\.tag)
        #expect(tags.contains("v1.0.0"))
        #expect(tags.contains("v1.1.0"))
    }

    @Test("Extracts contributor count")
    func contributorCount() async throws {
        let extractor = GitExtractor()
        let facts = try await extractor.extract(from: URL(fileURLWithPath: fixtureRepoPath))

        #expect(facts.contributorCount == 1)
    }

    @Test("Extracts branch count")
    func branchCount() async throws {
        let extractor = GitExtractor()
        let facts = try await extractor.extract(from: URL(fileURLWithPath: fixtureRepoPath))

        #expect(facts.branchCount >= 1)
    }

    @Test("Extracts first and latest commit dates")
    func commitDates() async throws {
        let extractor = GitExtractor()
        let facts = try await extractor.extract(from: URL(fileURLWithPath: fixtureRepoPath))

        #expect(facts.firstCommitDate != nil)
        #expect(facts.latestCommitDate != nil)
        if let first = facts.firstCommitDate, let latest = facts.latestCommitDate {
            #expect(first <= latest)
        }
    }

    @Test("Throws for non-git directory")
    func nonGitDirectory() async throws {
        let extractor = GitExtractor()
        let nonGitPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-a-repo-\(UUID().uuidString)")

        try FileManager.default.createDirectory(
            at: nonGitPath, withIntermediateDirectories: true
        )

        var didThrow = false
        do {
            _ = try await extractor.extract(from: nonGitPath)
        } catch is ShowcaseError {
            didThrow = true
        }
        #expect(didThrow, "Expected ShowcaseError for non-git directory")
    }
}
