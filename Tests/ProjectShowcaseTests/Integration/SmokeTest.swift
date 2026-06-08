//
//  SmokeTest.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("Integration Smoke Tests")
struct SmokeTest {

    @Test("Gather facts from project-showcase itself")
    func gatherSelf() async throws {
        let projectPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Integration/
            .deletingLastPathComponent()  // ProjectShowcaseTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // project-showcase/

        let gatherer = FactGatherer()
        let card = try await gatherer.gather(from: projectPath)

        #expect(card.git.commitCount > 0)
        let manifest = try #require(card.packageManifest)
        #expect(manifest.language == .swift)
        #expect(manifest.toolsVersion == "6.2")
        #expect(manifest.dependencies.contains("swift-argument-parser") == true)
        #expect(card.designArtifacts?.hasClaudeMD == true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let json = try encoder.encode(card)
        let jsonString = String(data: json, encoding: .utf8) ?? ""

        #expect(jsonString.contains("ProjectShowcase") || jsonString.contains("ShowcaseCLI"))
    }
}
