//
//  NarrativeResult.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// The output of narrative generation — a structured story about a project.
public struct NarrativeResult: Codable, Sendable {
    public let projectName: String
    public let audience: Audience
    public let style: NarrativeStyle
    public let title: String
    public let summary: String
    public let body: String
    public let generatedAt: Date
    public let cardHash: String

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
