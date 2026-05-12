//
//  PythonPackageExtractor.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Extracts package manifest facts from a Python pyproject.toml file via regex parsing.
public struct PythonPackageExtractor: PackageExtractor, Sendable {

    public init() {}

    public func canExtract(from projectPath: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: projectPath.appendingPathComponent("pyproject.toml").path
        )
    }

    public func extract(from projectPath: URL) async throws -> PackageManifestFacts {
        let pyprojectURL = projectPath.appendingPathComponent("pyproject.toml")
        guard FileManager.default.fileExists(atPath: pyprojectURL.path) else {
            throw ShowcaseError.extractionFailed(
                source: "python-package",
                message: "No pyproject.toml at \(projectPath.path)"
            )
        }

        let content = try String(contentsOf: pyprojectURL, encoding: .utf8)

        let toolsVersion = extractRequiresPython(from: content)
        let dependencies = extractDependencies(from: content)
        let targets = extractProjectName(from: content)

        return PackageManifestFacts(
            language: .python,
            toolsVersion: toolsVersion,
            dependencies: dependencies,
            targets: targets,
            platforms: []
        )
    }

    private func extractProjectName(from content: String) -> [String] {
        // Look for name = "..." in [project] section
        let lines = content.components(separatedBy: .newlines)
        var inProjectSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("[") {
                inProjectSection = (trimmed == "[project]")
                continue
            }

            if inProjectSection {
                if let name = extractTOMLStringValue(key: "name", from: trimmed) {
                    return [name]
                }
            }
        }
        return []
    }

    private func extractRequiresPython(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        var inProjectSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("[") {
                inProjectSection = (trimmed == "[project]")
                continue
            }

            if inProjectSection {
                if let value = extractTOMLStringValue(key: "requires-python", from: trimmed) {
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
                inDepsSection = (trimmed == "[project.dependencies]")
                continue
            }

            if inDepsSection, !trimmed.isEmpty {
                // Format: package_name = "version_spec"
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
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsLine = line as NSString
        guard let match = regex.firstMatch(
            in: line,
            range: NSRange(location: 0, length: nsLine.length)
        ) else { return nil }
        guard match.numberOfRanges >= 2 else { return nil }
        return nsLine.substring(with: match.range(at: 1))
    }
}
