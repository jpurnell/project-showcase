//
//  TestFacts.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Facts about a project's test suite.
public struct TestFacts: Codable, Sendable {
    /// Total number of tests discovered.
    public let testCount: Int
    /// Number of test suites.
    public let suiteCount: Int
    /// Fraction of tests passing (0.0 to 1.0), if determinable.
    public let passRate: Double?

    /// Creates a new TestFacts instance.
    public init(testCount: Int, suiteCount: Int, passRate: Double?) {
        self.testCount = testCount
        self.suiteCount = suiteCount
        self.passRate = passRate
    }
}
