//
//  FactGathererTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

private func runShell(_ cmd: String, in directory: String) throws {
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
}

private func createFullFixture() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("showcase-full-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    try runShell("git init", in: dir.path)

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
    try packageSwift.write(
        to: dir.appendingPathComponent("Package.swift"),
        atomically: true, encoding: .utf8
    )

    try "# TestProject\n\nA test project.".write(
        to: dir.appendingPathComponent("CLAUDE.md"),
        atomically: true, encoding: .utf8
    )

    try runShell("git add . && git commit -m 'Initial commit'", in: dir.path)
    try runShell("git tag v1.0.0", in: dir.path)

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
        #expect(card.packageManifest != nil)
        #expect(card.packageManifest?.language == .swift)
        #expect(card.packageManifest?.toolsVersion == "5.9")
        #expect(card.designArtifacts?.hasClaudeMD == true)
    }

    @Test("Uses directory name as project name when no manifest")
    func usesDirectoryName() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-cool-project-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try runShell("git init", in: dir.path)
        try "hello".write(
            to: dir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )
        try runShell("git add . && git commit -m 'init'", in: dir.path)

        let gatherer = FactGatherer()
        let card = try await gatherer.gather(from: dir)

        #expect(card.projectName.hasPrefix("my-cool-project"))
        #expect(card.packageManifest == nil)
    }

    @Test("Throws for non-git directory")
    func throwsForNonGit() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-git-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

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
