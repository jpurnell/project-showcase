//
//  InsightsSummary.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Aggregated facts from Claude Code usage data (facets + session-meta).
public struct InsightsSummary: Codable, Sendable {
    public let sessionCount: Int
    public let totalCommits: Int
    public let totalMessages: Int
    public let frictionCategories: [String: Int]
    public let outcomeDistribution: [String: Int]
    public let toolUsageProfile: [String: Int]
    public let sessionTypes: [String: Int]

    public init(
        sessionCount: Int,
        totalCommits: Int,
        totalMessages: Int,
        frictionCategories: [String: Int],
        outcomeDistribution: [String: Int],
        toolUsageProfile: [String: Int],
        sessionTypes: [String: Int]
    ) {
        self.sessionCount = sessionCount
        self.totalCommits = totalCommits
        self.totalMessages = totalMessages
        self.frictionCategories = frictionCategories
        self.outcomeDistribution = outcomeDistribution
        self.toolUsageProfile = toolUsageProfile
        self.sessionTypes = sessionTypes
    }
}
