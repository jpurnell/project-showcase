//
//  FactGathererTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

private func createFullFixture() throws -> URL {
    let dir = try makeFixtureDirectory(prefix: "showcase-full")
    try runGit(["init"], in: dir)

    let packageSwift = """
    // swift-tools-version: 5.9
    import PackageDescription
    let package = Package(
        name: "TestProject",
        platforms: [.macOS(.v13)],
        dependencies: [
            .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0"),
        ],
        targets: [.target(name: "TestProject")]
    )
    """
    try writeFixtureFile(packageSwift, named: "Package.swift", in: dir)
    try writeFixtureFile("# TestProject\n\nA test project.", named: "CLAUDE.md", in: dir)

    try runGit(["add", "."], in: dir)
    try runGit(["commit", "-m", "Initial commit"], in: dir)
    try runGit(["tag", "v1.0.0"], in: dir)

    return dir
}

@Suite("FactGatherer Tests")
struct FactGathererTests {

    @Test("Gathers all available facts into a ProjectCard")
    func gathersFullCard() async throws {
        let dir = try createFullFixture()
        let gatherer = FactGatherer()
        let card = try await gatherer.gather(from: dir)

        #expect(card.projectName == "TestProject")
        #expect(card.git.commitCount == 1)
        #expect(card.git.releaseHistory.count == 1)
        let manifest = try #require(card.packageManifest)
        #expect(manifest.language == .swift)
        #expect(manifest.toolsVersion == "5.9")
        #expect(card.designArtifacts?.hasClaudeMD == true)
    }

    @Test("Uses directory name as project name when no manifest")
    func usesDirectoryName() async throws {
        let dir = try makeFixtureDirectory(prefix: "my-cool-project")
        try runGit(["init"], in: dir)
        try writeFixtureFile("hello", named: "file.txt", in: dir)
        try runGit(["add", "."], in: dir)
        try runGit(["commit", "-m", "init"], in: dir)

        let gatherer = FactGatherer()
        let card = try await gatherer.gather(from: dir)

        #expect(card.projectName.hasPrefix("my-cool-project"))
        #expect(card.packageManifest == nil)
    }

    @Test("Throws for non-git directory")
    func throwsForNonGit() async throws {
        let dir = try makeFixtureDirectory(prefix: "no-git")

        let gatherer = FactGatherer()
        var didThrow = false
        do {
            _ = try await gatherer.gather(from: dir)
        } catch {
            didThrow = true
        }
        #expect(didThrow)
    }

    @Test("Card is Codable — full round trip")
    func cardCodableRoundTrip() async throws {
        let dir = try createFullFixture()
        let gatherer = FactGatherer()
        let card = try await gatherer.gather(from: dir)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(card)

        let decoded = try JSONDecoder.iso8601Configured().decode(ProjectCard.self, from: data)
        #expect(decoded.projectName == card.projectName)
        #expect(decoded.git.commitCount == card.git.commitCount)
    }
}
