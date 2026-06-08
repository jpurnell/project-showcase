//
//  QualityFacts.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Facts about a project's quality gate results.
public struct QualityFacts: Codable, Sendable {
    /// Total number of quality-gate violations.
    public let violationCount: Int
    /// Violation counts grouped by checker category.
    public let checkerCategories: [String: Int]

    /// Creates a new QualityFacts instance.
    public init(violationCount: Int, checkerCategories: [String: Int]) {
        self.violationCount = violationCount
        self.checkerCategories = checkerCategories
    }
}
