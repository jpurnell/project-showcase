//
//  GitFacts.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Facts extracted from a project's git history.
public struct GitFacts: Codable, Sendable {
    public let commitCount: Int
    public let releaseHistory: [Release]
    public let branchCount: Int
    public let firstCommitDate: Date?
    public let latestCommitDate: Date?
    public let contributorCount: Int

    public init(
        commitCount: Int,
        releaseHistory: [Release],
        branchCount: Int,
        firstCommitDate: Date?,
        latestCommitDate: Date?,
        contributorCount: Int
    ) {
        self.commitCount = commitCount
        self.releaseHistory = releaseHistory
        self.branchCount = branchCount
        self.firstCommitDate = firstCommitDate
        self.latestCommitDate = latestCommitDate
        self.contributorCount = contributorCount
    }
}

/// A tagged release in the project's git history.
public struct Release: Codable, Sendable {
    public let tag: String
    public let date: Date?

    public init(tag: String, date: Date?) {
        self.tag = tag
        self.date = date
    }
}
