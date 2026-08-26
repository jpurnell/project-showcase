//
//  GitFixture.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-08-25.
//

import Foundation
@testable import ProjectShowcase

/// Creates an empty fixture directory under the system temporary directory.
///
/// The URL is standardized so the path handed to `FileManager` contains no traversal
/// components, and every fixture lands in its own UUID-suffixed directory.
func makeFixtureDirectory(prefix: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        .standardizedFileURL
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

/// Writes `contents` to `name` inside `directory`, replacing anything already there.
func writeFixtureFile(_ contents: String, named name: String, in directory: URL) throws {
    try contents.write(
        to: directory.appendingPathComponent(name),
        atomically: true,
        encoding: .utf8
    )
}

/// Runs `git` in `directory` with each argument as its own `argv` entry.
///
/// No shell is involved, so nothing in a fixture path or a commit message is parsed as a
/// command. Author and committer identity come from the environment rather than a config
/// file, keeping the fixture independent of the machine's git setup.
func runGit(_ arguments: [String], in directory: URL) throws {
    let result = try ProcessRunner.run(
        "/usr/bin/git",
        arguments: arguments,
        workingDirectory: directory,
        environment: [
            "PATH": "/usr/bin:/bin:/usr/local/bin",
            "HOME": NSHomeDirectory(),
            "GIT_AUTHOR_NAME": "Test",
            "GIT_AUTHOR_EMAIL": "test@test.com",
            "GIT_COMMITTER_NAME": "Test",
            "GIT_COMMITTER_EMAIL": "test@test.com"
        ]
    )

    guard result.didSucceed else {
        throw ShowcaseError.extractionFailed(
            source: "git",
            message: "git \(arguments.joined(separator: " ")) exited with \(result.exitStatus): \(result.standardError)"
        )
    }
}
