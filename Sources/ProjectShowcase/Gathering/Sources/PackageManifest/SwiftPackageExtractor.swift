//
//  SwiftPackageExtractor.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Extracts package manifest facts from a Swift Package.swift file via regex parsing.
public struct SwiftPackageExtractor: PackageExtractor, Sendable {

    /// Creates a new SwiftPackageExtractor instance.
    public init() {}

    /// Checks whether a Package.swift file exists at the given project path.
    public func canExtract(from projectPath: URL) -> Bool {
        // SAFETY: path is .standardized, bounded to projectPath
        FileManager.default.fileExists(
            atPath: projectPath.appendingPathComponent("Package.swift").standardized.path
        )
    }

    /// Extracts package manifest facts from the Package.swift at the given path.
    public func extract(from projectPath: URL) async throws -> PackageManifestFacts {
        let packageURL = projectPath.appendingPathComponent("Package.swift").standardized
        // SAFETY: packageURL is .standardized, bounded to projectPath
        guard FileManager.default.fileExists(atPath: packageURL.path) else {
            throw ShowcaseError.extractionFailed(
                source: "swift-package",
                message: "No Package.swift at \(projectPath.path)"
            )
        }

        let content = try String(contentsOf: packageURL, encoding: .utf8)

        let toolsVersion = extractToolsVersion(from: content)
        let dependencies = extractDependencies(from: content)
        let targets = extractTargets(from: content)
        let platforms = extractPlatforms(from: content)

        return PackageManifestFacts(
            language: .swift,
            toolsVersion: toolsVersion,
            dependencies: dependencies,
            targets: targets,
            platforms: platforms
        )
    }

    private func extractToolsVersion(from content: String) -> String? {
        guard let range = content.range(
            of: #"swift-tools-version:\s*(\S+)"#,
            options: .regularExpression
        ) else { return nil }

        let match = content[range]
        let parts = match.split(separator: ":")
        guard parts.count >= 2 else { return nil }
        return parts[1].trimmingCharacters(in: .whitespaces)
    }

    private func extractDependencies(from content: String) -> [String] {
        var deps: [String] = []
        let pattern = #"\.package\(\s*url:\s*"[^"]*?/([^/"]+)(?:\.git)?""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return deps } // silent: best-effort parsing

        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
        for match in matches {
            if match.numberOfRanges >= 2 {
                let nameRange = match.range(at: 1)
                var name = nsContent.substring(with: nameRange)
                if name.hasSuffix(".git") {
                    name = String(name.dropLast(4))
                }
                deps.append(name)
            }
        }
        return deps
    }

    private func extractTargets(from content: String) -> [String] {
        var targets: [String] = []
        let pattern = #"\.\w*[Tt]arget\(\s*name:\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return targets } // silent: best-effort parsing

        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
        for match in matches {
            if match.numberOfRanges >= 2 {
                targets.append(nsContent.substring(with: match.range(at: 1)))
            }
        }
        return targets
    }

    private func extractPlatforms(from content: String) -> [String] {
        var platforms: [String] = []
        let knownPlatforms = ["macOS", "iOS", "tvOS", "watchOS", "visionOS"]
        for platform in knownPlatforms {
            if content.contains(".\(platform)(") {
                platforms.append(platform)
            }
        }
        return platforms
    }
}
