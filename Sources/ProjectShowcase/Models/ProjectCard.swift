//
//  ProjectCard.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// All gathered facts about a single project, assembled from multiple extractors.
public struct ProjectCard: Codable, Sendable {
    /// Display name of the project.
    public let projectName: String
    /// Absolute filesystem path to the project root.
    public let projectPath: String
    /// Timestamp when these facts were gathered.
    public let gatheredAt: Date
    /// Facts extracted from the git repository.
    public let git: GitFacts
    /// Facts from the package manifest, if one was found.
    public let packageManifest: PackageManifestFacts?
    /// Test suite facts, if test output was provided.
    public let tests: TestFacts?
    /// Quality-gate results, if available.
    public let quality: QualityFacts?
    /// Claude Code usage insights, if available.
    public let insights: InsightsSummary?
    /// Design artifact facts, if available.
    public let designArtifacts: DesignArtifactFacts?

    /// Creates a new ProjectCard instance.
    public init(
        projectName: String,
        projectPath: String,
        gatheredAt: Date,
        git: GitFacts,
        packageManifest: PackageManifestFacts?,
        tests: TestFacts?,
        quality: QualityFacts?,
        insights: InsightsSummary?,
        designArtifacts: DesignArtifactFacts?
    ) {
        self.projectName = projectName
        self.projectPath = projectPath
        self.gatheredAt = gatheredAt
        self.git = git
        self.packageManifest = packageManifest
        self.tests = tests
        self.quality = quality
        self.insights = insights
        self.designArtifacts = designArtifacts
    }
}
