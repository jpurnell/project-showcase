//
//  GitExtractor.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Extracts facts from a project's git repository.
public struct GitExtractor: Sendable {

    /// Creates a new GitExtractor instance.
    public init() {}

    /// Extract git facts from the repository at the given path.
    public func extract(from projectPath: URL) async throws -> GitFacts {
        let gitDir = projectPath.appendingPathComponent(".git").standardized
        // SAFETY: gitDir is .standardized, bounded to projectPath
        guard FileManager.default.fileExists(atPath: gitDir.path) else {
            throw ShowcaseError.notAGitRepository(path: projectPath.path)
        }

        let script = """
        echo "===COMMITS==="
        git rev-list --count HEAD 2>/dev/null || echo "0"
        echo "===TAGS==="
        git tag --sort=-version:refname 2>/dev/null
        echo "===TAG_DATES==="
        git tag --sort=-version:refname --format='%(refname:short) %(creatordate:iso-strict)' 2>/dev/null
        echo "===BRANCHES==="
        git branch --list 2>/dev/null
        echo "===CONTRIBUTORS==="
        git shortlog -sn --all 2>/dev/null
        echo "===FIRST_DATE==="
        git log --reverse --format=%aI 2>/dev/null | head -1
        echo "===LATEST_DATE==="
        git log -1 --format=%aI 2>/dev/null
        echo "===END==="
        """

        let output = try await runShell(script, in: projectPath.path)
        return parseGitOutput(output)
    }

    private func parseGitOutput(_ output: String) -> GitFacts {
        let sections = parseSections(output)
        let formatter = ISO8601DateFormatter()

        let commits = Int(sections["COMMITS"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0") ?? 0

        let tags = (sections["TAGS"] ?? "")
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }

        var tagDates: [String: Date] = [:]
        for line in (sections["TAG_DATES"] ?? "").split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: " ", maxSplits: 1)
            if parts.count == 2, let date = formatter.date(from: String(parts[1])) {
                tagDates[String(parts[0])] = date
            }
        }

        let releases = tags.map { tag in
            Release(tag: tag, date: tagDates[tag])
        }

        let branches = (sections["BRANCHES"] ?? "")
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .count

        let contributors = (sections["CONTRIBUTORS"] ?? "")
            .split(whereSeparator: \.isNewline)
            .filter { !$0.isEmpty }
            .count

        let firstDateStr = (sections["FIRST_DATE"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let firstDate = formatter.date(from: firstDateStr)

        let latestDateStr = (sections["LATEST_DATE"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let latestDate = formatter.date(from: latestDateStr)

        return GitFacts(
            commitCount: commits,
            releaseHistory: releases,
            branchCount: branches,
            firstCommitDate: firstDate,
            latestCommitDate: latestDate,
            contributorCount: contributors
        )
    }

    private func parseSections(_ output: String) -> [String: String] {
        var sections: [String: String] = [:]
        var currentKey: String?
        var currentLines: [String] = []

        for line in output.lines {
            if line.hasPrefix("===") && line.hasSuffix("===") {
                if let key = currentKey {
                    sections[key] = currentLines.joined(separator: "\n")
                }
                let key = line.replacingOccurrences(of: "===", with: "")
                if key == "END" {
                    break
                }
                currentKey = key
                currentLines = []
            } else {
                currentLines.append(line)
            }
        }

        if let key = currentKey {
            sections[key] = currentLines.joined(separator: "\n")
        }

        return sections
    }

    private func runShell(_ script: String, in directory: String) async throws -> String {
        let outputFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("showcase-git-\(UUID().uuidString).txt")
        let fullScript = "(\(script)) > '\(outputFile.path)' 2>/dev/null"

        // SAFETY: Executable hardcoded to /bin/zsh, script is internal string literal not user input
        let process = Process()
        let shellPath = "/bin/zsh"
        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = ["-c", fullScript]
        process.currentDirectoryURL = URL(fileURLWithPath: directory).standardized
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        defer { try? FileManager.default.removeItem(at: outputFile) } // silent: git data extraction

        // SAFETY: outputFile is from FileManager.temporaryDirectory, no user-controlled path components
        guard FileManager.default.fileExists(atPath: outputFile.path) else {
            return ""
        }
        return try String(contentsOf: outputFile, encoding: .utf8)
    }
}
