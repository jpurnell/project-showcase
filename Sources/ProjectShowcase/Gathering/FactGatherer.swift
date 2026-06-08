//
//  FactGatherer.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Orchestrates all extractors to produce a complete ProjectCard.
public struct FactGatherer: Sendable {

    private let packageExtractors: [any PackageExtractor]

    /// Creates a new FactGatherer with optional custom package extractors.
    public init(packageExtractors: [any PackageExtractor]? = nil) {
        self.packageExtractors = packageExtractors ?? [
            SwiftPackageExtractor(),
            NodePackageExtractor(),
            PythonPackageExtractor(),
            CargoExtractor(),
        ]
    }

    /// Gather all available facts from the project at the given path.
    ///
    /// - Parameters:
    ///   - projectPath: URL to the project root (must contain .git).
    ///   - insightsPath: Optional explicit path to Claude Code usage-data directory. If nil, auto-detects `~/.claude/usage-data/`.
    ///   - testOutput: Optional pre-captured output from running the project's test suite.
    /// - Returns: A fully populated ProjectCard.
    public func gather(from projectPath: URL, insightsPath: URL? = nil, testOutput: String? = nil) async throws -> ProjectCard {
        log("Starting git extraction...")
        let gitExtractor = GitExtractor()
        let gitFacts = try await gitExtractor.extract(from: projectPath)
        log("Git done. Extracting package manifest...")

        let packageFacts = await extractPackageManifest(from: projectPath)
        log("Package done. Extracting design docs...")

        let designDocExtractor = DesignDocExtractor()
        let designFacts = try? await designDocExtractor.extract(from: projectPath) // silent: best-effort gathering
        log("Design done. Extracting insights...")

        let insightsExtractor = InsightsExtractor()
        let usageDataPath = insightsPath ?? globalUsageDataPath()
        let insightsFacts: InsightsSummary?
        if let dataPath = usageDataPath {
            insightsFacts = try? await insightsExtractor.extractOptional( // silent: best-effort gathering
                from: dataPath,
                projectPath: projectPath.path
            )
        } else {
            insightsFacts = nil
        }
        log("Insights done.")

        let testFacts: TestFacts?
        if let output = testOutput {
            testFacts = TestOutputParser().parse(output: output)
        } else {
            testFacts = nil
        }

        let projectName = packageFacts?.targets.first
            ?? projectPath.lastPathComponent

        return ProjectCard(
            projectName: projectName,
            projectPath: projectPath.path,
            gatheredAt: Date(),
            git: gitFacts,
            packageManifest: packageFacts,
            tests: testFacts,
            quality: nil,
            insights: insightsFacts,
            designArtifacts: designFacts
        )
    }

    private func log(_ message: String) {
        FileHandle.standardError.write(Data("[gather] \(message)\n".utf8))
    }

    private func globalUsageDataPath() -> URL? {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("usage-data")
            .standardized
        // SAFETY: path is .standardized, bounded to homeDirectory/.claude/usage-data
        guard FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }
        return path
    }

    private func extractPackageManifest(from projectPath: URL) async -> PackageManifestFacts? {
        for extractor in packageExtractors {
            if extractor.canExtract(from: projectPath) {
                return try? await extractor.extract(from: projectPath) // silent: best-effort gathering
            }
        }
        return nil
    }
}
