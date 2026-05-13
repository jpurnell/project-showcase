//
//  DesignArtifactFacts.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Facts about a project's design artifacts (proposals, architecture docs).
public struct DesignArtifactFacts: Codable, Sendable {
    public let designProposalCount: Int
    public let architectureNotes: [String]
    public let hasDesignFirstWorkflow: Bool
    public let hasClaudeMD: Bool
    public let projectDescription: String?

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
