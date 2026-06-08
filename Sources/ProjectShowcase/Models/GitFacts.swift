//
//  GitFacts.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Facts extracted from a project's git history.
public struct GitFacts: Codable, Sendable {
    /// Total number of commits in the repository.
    public let commitCount: Int
    /// Chronological list of tagged releases.
    public let releaseHistory: [Release]
    /// Number of local branches.
    public let branchCount: Int
    /// Date of the earliest commit, if available.
    public let firstCommitDate: Date?
    /// Date of the most recent commit, if available.
    public let latestCommitDate: Date?
    /// Number of unique contributors.
    public let contributorCount: Int

    /// Creates a new GitFacts instance.
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
    /// The version tag string (e.g. "v1.0.0").
    public let tag: String
    /// The date the tag was created, if available.
    public let date: Date?

    /// Creates a new Release instance.
    public init(tag: String, date: Date?) {
        self.tag = tag
        self.date = date
    }
}
