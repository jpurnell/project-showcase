//
//  PythonPackageExtractorTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

private let fixturePyprojectTOML = """
[project]
name = "data-pipeline"
requires-python = ">=3.11"

[project.dependencies]
numpy = ">=1.24"
pandas = ">=2.0"

[tool.poetry.dependencies]
python = "^3.11"
"""

private func createFixtureProject(pyprojectTOML: String) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("showcase-python-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try pyprojectTOML.write(
        to: dir.appendingPathComponent("pyproject.toml"),
        atomically: true, encoding: .utf8
    )
    return dir
}

@Suite("PythonPackageExtractor Tests")
struct PythonPackageExtractorTests {

    @Test("Detects Python language from pyproject.toml")
    func detectsPython() async throws {
        let dir = try createFixtureProject(pyprojectTOML: fixturePyprojectTOML)
        let extractor = PythonPackageExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.language == .python)
    }

    @Test("Extracts dependency names from project.dependencies")
    func extractsDependencies() async throws {
        let dir = try createFixtureProject(pyprojectTOML: fixturePyprojectTOML)
        let extractor = PythonPackageExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.dependencies.contains("numpy"))
        #expect(facts.dependencies.contains("pandas"))
        #expect(facts.dependencies.count == 2)
    }

    @Test("Extracts project name as target")
    func extractsProjectNameAsTarget() async throws {
        let dir = try createFixtureProject(pyprojectTOML: fixturePyprojectTOML)
        let extractor = PythonPackageExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.targets.contains("data-pipeline"))
    }

    @Test("Extracts Python version as toolsVersion")
    func extractsPythonVersion() async throws {
        let dir = try createFixtureProject(pyprojectTOML: fixturePyprojectTOML)
        let extractor = PythonPackageExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.toolsVersion == ">=3.11")
    }

    @Test("canExtract returns true for directory with pyproject.toml")
    func canExtractTrue() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("showcase-python-can-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let pyprojectFile = dir.appendingPathComponent("pyproject.toml")
        try? "[project]\nname = \"test\"".write(to: pyprojectFile, atomically: true, encoding: .utf8)

        let extractor = PythonPackageExtractor()
        #expect(extractor.canExtract(from: dir))
    }

    @Test("canExtract returns false for directory without pyproject.toml")
    func canExtractFalse() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("showcase-python-no-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let extractor = PythonPackageExtractor()
        #expect(!extractor.canExtract(from: dir))
    }
}
