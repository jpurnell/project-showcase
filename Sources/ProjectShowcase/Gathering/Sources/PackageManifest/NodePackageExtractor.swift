//
//  NodePackageExtractor.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Extracts package manifest facts from a Node.js package.json file.
public struct NodePackageExtractor: PackageExtractor, Sendable {

    public init() {}

    public func canExtract(from projectPath: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: projectPath.appendingPathComponent("package.json").path
        )
    }

    public func extract(from projectPath: URL) async throws -> PackageManifestFacts {
        let packageURL = projectPath.appendingPathComponent("package.json")
        guard FileManager.default.fileExists(atPath: packageURL.path) else {
            throw ShowcaseError.extractionFailed(
                source: "node-package",
                message: "No package.json at \(projectPath.path)"
            )
        }

        let data = try Data(contentsOf: packageURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ShowcaseError.extractionFailed(
                source: "node-package",
                message: "Failed to parse package.json as JSON object"
            )
        }

        let dependencies = extractDependencies(from: json)
        let targets = extractTargets(from: json)

        return PackageManifestFacts(
            language: .javascript,
            toolsVersion: nil,
            dependencies: dependencies,
            targets: targets,
            platforms: []
        )
    }

    private func extractDependencies(from json: [String: Any]) -> [String] {
        guard let deps = json["dependencies"] as? [String: Any] else { return [] }
        return Array(deps.keys).sorted()
    }

    private func extractTargets(from json: [String: Any]) -> [String] {
        guard let name = json["name"] as? String else { return [] }
        return [name]
    }
}
