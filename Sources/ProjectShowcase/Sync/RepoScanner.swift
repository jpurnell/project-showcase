//
//  RepoScanner.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-10-30.
//

import Foundation

/// Finds git checkouts directly under a set of directories and reads what discovery needs.
public enum RepoScanner {

    /// Scans the immediate children of each root.
    ///
    /// A child that is not a git repository, has no commits, or cannot be read is left out
    /// rather than reported with guessed values.
    public static func scan(roots: [URL]) async throws -> [RepoFacts] {
        var found: [RepoFacts] = []
        for root in roots {
            let children = try FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard FileManager.default.fileExists(atPath: child.appendingPathComponent(".git").path) else { continue }
                if let facts = try await facts(for: child) { found.append(facts) }
            }
        }
        return found
    }

    /// The `owner/repo` of a checkout's `origin`, or `nil` if it has none or it is not on GitHub.
    public static func remoteSlug(of directory: URL) throws -> String? {
        try git(["remote", "get-url", "origin"], in: directory).flatMap(RemoteSlug.parse)
    }

    private static func facts(for directory: URL) async throws -> RepoFacts? {
        guard let count = Int(try git(["rev-list", "--count", "HEAD"], in: directory) ?? ""), count > 0,
              let stamp = TimeInterval(try git(["log", "-1", "--format=%ct"], in: directory) ?? "")
        else { return nil }
        let remote = try remoteSlug(of: directory)
        let description = try await DesignDocExtractor().extract(from: directory).projectDescription
        let hasPlan = description.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
        return RepoFacts(
            path: directory.standardizedFileURL.path, name: directory.lastPathComponent,
            commitCount: count, lastCommit: Date(timeIntervalSince1970: stamp),
            remoteSlug: remote, hasMasterPlan: hasPlan)
    }

    /// Trimmed stdout of a git command, or `nil` when it exits non-zero.
    private static func git(_ arguments: [String], in directory: URL) throws -> String? {
        let result = try ProcessRunner.run("/usr/bin/git", arguments: arguments, workingDirectory: directory)
        guard result.didSucceed else { return nil }
        return result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
