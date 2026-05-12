//
//  QualityFacts.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Facts about a project's quality gate results.
public struct QualityFacts: Codable, Sendable {
    public let violationCount: Int
    public let checkerCategories: [String: Int]

    public init(violationCount: Int, checkerCategories: [String: Int]) {
        self.violationCount = violationCount
        self.checkerCategories = checkerCategories
    }
}
