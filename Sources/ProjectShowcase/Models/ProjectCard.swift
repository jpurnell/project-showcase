//
//  ProjectCard.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// All gathered facts about a single project, assembled from multiple extractors.
public struct ProjectCard: Codable, Sendable {
    public let projectName: String
    public let projectPath: String
    public let gatheredAt: Date
    public let git: GitFacts
    public let packageManifest: PackageManifestFacts?
    public let tests: TestFacts?
    public let quality: QualityFacts?
    public let insights: InsightsSummary?
    public let designArtifacts: DesignArtifactFacts?

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
