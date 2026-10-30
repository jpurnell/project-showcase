//
//  GitHead.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-10-29.
//

import Foundation

/// Reads a repository's current commit.
public enum GitHead {

    /// Resolves `HEAD` to its full commit id.
    ///
    /// - Throws: ``ShowcaseError/notAGitRepository(path:)`` when `directory` has no commit to
    ///   report, whether because it is not a repository or because it has no commits yet.
    public static func resolve(at directory: URL) throws -> String {
        let result = try ProcessRunner.run(
            "/usr/bin/git",
            arguments: ["rev-parse", "--verify", "HEAD"],
            workingDirectory: directory
        )
        let head = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.didSucceed, !head.isEmpty else {
            throw ShowcaseError.notAGitRepository(path: directory.path)
        }
        return head
    }
}
