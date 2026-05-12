//
//  CargoExtractorTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

private let fixtureCargoTOML = """
[package]
name = "cli-tool"
version = "0.5.0"
edition = "2021"

[dependencies]
serde = { version = "1.0", features = ["derive"] }
tokio = { version = "1", features = ["full"] }
clap = "4.0"
"""

private func createFixtureProject(cargoTOML: String) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("showcase-cargo-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try cargoTOML.write(
        to: dir.appendingPathComponent("Cargo.toml"),
        atomically: true, encoding: .utf8
    )
    return dir
}

@Suite("CargoExtractor Tests")
struct CargoExtractorTests {

    @Test("Detects Rust language from Cargo.toml")
    func detectsRust() async throws {
        let dir = try createFixtureProject(cargoTOML: fixtureCargoTOML)
        let extractor = CargoExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.language == .rust)
    }

    @Test("Extracts dependency names from [dependencies]")
    func extractsDependencies() async throws {
        let dir = try createFixtureProject(cargoTOML: fixtureCargoTOML)
        let extractor = CargoExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.dependencies.contains("serde"))
        #expect(facts.dependencies.contains("tokio"))
        #expect(facts.dependencies.contains("clap"))
        #expect(facts.dependencies.count == 3)
    }

    @Test("Extracts package name as target")
    func extractsPackageNameAsTarget() async throws {
        let dir = try createFixtureProject(cargoTOML: fixtureCargoTOML)
        let extractor = CargoExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.targets.contains("cli-tool"))
    }

    @Test("Extracts edition as toolsVersion")
    func extractsEdition() async throws {
        let dir = try createFixtureProject(cargoTOML: fixtureCargoTOML)
        let extractor = CargoExtractor()
        let facts = try await extractor.extract(from: dir)

        #expect(facts.toolsVersion == "2021")
    }

    @Test("canExtract returns true for directory with Cargo.toml")
    func canExtractTrue() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("showcase-cargo-can-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let cargoFile = dir.appendingPathComponent("Cargo.toml")
        try? "[package]\nname = \"test\"".write(to: cargoFile, atomically: true, encoding: .utf8)

        let extractor = CargoExtractor()
        #expect(extractor.canExtract(from: dir))
    }

    @Test("canExtract returns false for directory without Cargo.toml")
    func canExtractFalse() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("showcase-cargo-no-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let extractor = CargoExtractor()
        #expect(!extractor.canExtract(from: dir))
    }
}
