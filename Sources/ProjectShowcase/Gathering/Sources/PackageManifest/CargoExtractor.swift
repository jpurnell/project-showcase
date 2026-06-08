//
//  CargoExtractor.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Extracts package manifest facts from a Rust Cargo.toml file via regex parsing.
public struct CargoExtractor: PackageExtractor, Sendable {

    /// Creates a new CargoExtractor instance.
    public init() {}

    /// Checks whether a Cargo.toml file exists at the given project path.
    public func canExtract(from projectPath: URL) -> Bool {
        // SAFETY: path is .standardized, bounded to projectPath
        FileManager.default.fileExists(
            atPath: projectPath.appendingPathComponent("Cargo.toml").standardized.path
        )
    }

    /// Extracts package manifest facts from the Cargo.toml at the given path.
    public func extract(from projectPath: URL) async throws -> PackageManifestFacts {
        let cargoURL = projectPath.appendingPathComponent("Cargo.toml").standardized
        // SAFETY: cargoURL is .standardized, bounded to projectPath
        guard FileManager.default.fileExists(atPath: cargoURL.path) else {
            throw ShowcaseError.extractionFailed(
                source: "cargo",
                message: "No Cargo.toml at \(projectPath.path)"
            )
        }

        let content = try String(contentsOf: cargoURL, encoding: .utf8)

        let toolsVersion = extractEdition(from: content)
        let dependencies = extractDependencies(from: content)
        let targets = extractPackageName(from: content)

        return PackageManifestFacts(
            language: .rust,
            toolsVersion: toolsVersion,
            dependencies: dependencies,
            targets: targets,
            platforms: []
        )
    }

    private func extractPackageName(from content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var inPackageSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("[") {
                inPackageSection = (trimmed == "[package]")
                continue
            }

            if inPackageSection {
                if let name = extractTOMLStringValue(key: "name", from: trimmed) {
                    return [name]
                }
            }
        }
        return []
    }

    private func extractEdition(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        var inPackageSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("[") {
                inPackageSection = (trimmed == "[package]")
                continue
            }

            if inPackageSection {
                if let value = extractTOMLStringValue(key: "edition", from: trimmed) {
                    return value
                }
            }
        }
        return nil
    }

    private func extractDependencies(from content: String) -> [String] {
        var deps: [String] = []
        let lines = content.components(separatedBy: .newlines)
        var inDepsSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("[") {
                inDepsSection = (trimmed == "[dependencies]")
                continue
            }

            if inDepsSection, !trimmed.isEmpty {
                // Handles both simple ("clap = "4.0"") and table ("serde = { ... }") formats
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                if parts.count >= 1 {
                    let depName = parts[0].trimmingCharacters(in: .whitespaces)
                    if !depName.isEmpty {
                        deps.append(depName)
                    }
                }
            }
        }
        return deps
    }

    private func extractTOMLStringValue(key: String, from line: String) -> String? {
        let pattern = #"^\#(key)\s*=\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil } // silent: best-effort TOML parsing
        let nsLine = line as NSString
        guard let match = regex.firstMatch(
            in: line,
            range: NSRange(location: 0, length: nsLine.length)
        ) else { return nil }
        guard match.numberOfRanges >= 2 else { return nil }
        return nsLine.substring(with: match.range(at: 1))
    }
}
