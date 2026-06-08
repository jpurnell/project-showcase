//
//  InsightsSummary.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Aggregated facts from Claude Code usage data (facets + session-meta).
public struct InsightsSummary: Codable, Sendable {
    /// Number of Claude Code sessions analyzed.
    public let sessionCount: Int
    /// Total git commits across all sessions.
    public let totalCommits: Int
    /// Total user messages across all sessions.
    public let totalMessages: Int
    /// Friction event categories and their counts.
    public let frictionCategories: [String: Int]
    /// Distribution of session outcomes (e.g. success, failure).
    public let outcomeDistribution: [String: Int]
    /// Tool usage counts aggregated across sessions.
    public let toolUsageProfile: [String: Int]
    /// Distribution of session types (e.g. coding, debugging).
    public let sessionTypes: [String: Int]

    /// Creates a new InsightsSummary instance.
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
