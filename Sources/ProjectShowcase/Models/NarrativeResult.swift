//
//  NarrativeResult.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// The output of narrative generation — a structured story about a project.
public struct NarrativeResult: Codable, Sendable {
    /// Name of the project this narrative describes.
    public let projectName: String
    /// Target audience the narrative is written for.
    public let audience: Audience
    /// Writing style used to generate the narrative.
    public let style: NarrativeStyle
    /// Title heading for the narrative.
    public let title: String
    /// One-sentence summary of the narrative.
    public let summary: String
    /// Full markdown body of the narrative.
    public let body: String
    /// Timestamp when the narrative was generated.
    public let generatedAt: Date
    /// SHA-256 hash of the source ProjectCard for cache invalidation.
    public let cardHash: String

    /// Creates a new NarrativeResult instance.
    public init(
        projectName: String,
        audience: Audience,
        style: NarrativeStyle,
        title: String,
        summary: String,
        body: String,
        generatedAt: Date,
        cardHash: String
    ) {
        self.projectName = projectName
        self.audience = audience
        self.style = style
        self.title = title
        self.summary = summary
        self.body = body
        self.generatedAt = generatedAt
        self.cardHash = cardHash
    }
}
