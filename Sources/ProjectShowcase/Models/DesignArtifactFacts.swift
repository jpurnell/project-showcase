//
//  DesignArtifactFacts.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Facts about a project's design artifacts (proposals, architecture docs).
public struct DesignArtifactFacts: Codable, Sendable {
    /// Number of design proposal documents found.
    public let designProposalCount: Int
    /// Section headings extracted from CLAUDE.md as architecture notes.
    public let architectureNotes: [String]
    /// Whether the project uses a design-first development workflow.
    public let hasDesignFirstWorkflow: Bool
    /// Whether a CLAUDE.md file exists in the project root.
    public let hasClaudeMD: Bool
    /// Project description extracted from MASTER_PLAN.md, if available.
    public let projectDescription: String?

    /// Creates a new DesignArtifactFacts instance.
    public init(
        designProposalCount: Int,
        architectureNotes: [String],
        hasDesignFirstWorkflow: Bool,
        hasClaudeMD: Bool,
        projectDescription: String? = nil
    ) {
        self.designProposalCount = designProposalCount
        self.architectureNotes = architectureNotes
        self.hasDesignFirstWorkflow = hasDesignFirstWorkflow
        self.hasClaudeMD = hasClaudeMD
        self.projectDescription = projectDescription
    }
}
