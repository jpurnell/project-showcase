//
//  TestFacts.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Facts about a project's test suite.
public struct TestFacts: Codable, Sendable {
    public let testCount: Int
    public let suiteCount: Int
    public let passRate: Double?

    public init(testCount: Int, suiteCount: Int, passRate: Double?) {
        self.testCount = testCount
        self.suiteCount = suiteCount
        self.passRate = passRate
    }
}
