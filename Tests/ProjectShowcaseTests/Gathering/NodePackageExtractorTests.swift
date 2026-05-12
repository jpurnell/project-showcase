//
//  NodePackageExtractorTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

private let fixturePackageJSON = """
{
  "name": "my-web-app",
  "version": "1.2.0",
  "dependencies": {
    "express": "^4.18.0",
    "lodash": "^4.17.21"
  },
  "devDependencies": {
    "jest": "^29.0.0"
  },
  "scripts": {
    "test": "jest"
  }
}
"""

private func createFixtureProject(packageJSON: String) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("showcase-node-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try packageJSON.write(
        to: dir.appendingPathComponent("package.json"),
        atomically: true, encoding: .utf8
    )
    return dir
}

@Suite("NodePackageExtractor Tests")
struct NodePackageExtractorTests {

    @Test("Detects JavaScript language from package.json")
    func detectsJavaScript() async throws {
        let dir = try createFixtureProject(packageJSON: fixturePackageJSON)
        let extractor = NodePackageExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.language == .javascript)
    }

    @Test("Extracts dependency names from dependencies only, not devDependencies")
    func extractsDependencies() async throws {
        let dir = try createFixtureProject(packageJSON: fixturePackageJSON)
        let extractor = NodePackageExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.dependencies.contains("express"))
        #expect(facts.dependencies.contains("lodash"))
        #expect(!facts.dependencies.contains("jest"))
        #expect(facts.dependencies.count == 2)
    }

    @Test("Extracts package name as target")
    func extractsPackageNameAsTarget() async throws {
        let dir = try createFixtureProject(packageJSON: fixturePackageJSON)
        let extractor = NodePackageExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.targets.contains("my-web-app"))
    }

    @Test("canExtract returns true for directory with package.json")
    func canExtractTrue() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("showcase-node-can-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let packageFile = dir.appendingPathComponent("package.json")
        try? "{}".write(to: packageFile, atomically: true, encoding: .utf8)

        let extractor = NodePackageExtractor()
        #expect(extractor.canExtract(from: dir))
    }

    @Test("canExtract returns false for directory without package.json")
    func canExtractFalse() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("showcase-node-no-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let extractor = NodePackageExtractor()
        #expect(!extractor.canExtract(from: dir))
    }
}
