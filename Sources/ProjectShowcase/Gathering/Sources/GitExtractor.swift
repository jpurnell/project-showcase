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
        git log --all --format=%aE 2>/dev/null | tr '[:upper:]' '[:lower:]' | sort -u
        echo "===FIRST_DATE==="
        git log --reverse --format=%aI 2>/dev/null | head -1
        echo "===LATEST_DATE==="
        git log -1 --format=%aI 2>/dev/null
        echo "===COMMIT_DATES==="
        git log --reverse --format=%aI 2>/dev/null
        echo "===END==="
        """

        let output = try runShell(script, in: projectPath.path)
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

        // A tag that is not a version (a safety tag, a backup, a work-in-progress marker) is not a release.
        let releases = tags.filter(Self.isVersionTag).map { tag in
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

        let commitDates = (sections["COMMIT_DATES"] ?? "")
            .split(whereSeparator: \.isNewline)
            .compactMap { formatter.date(from: $0.trimmingCharacters(in: .whitespaces)) }

        return GitFacts(
            commitCount: commits,
            releaseHistory: releases,
            branchCount: branches,
            firstCommitDate: firstDate,
            latestCommitDate: latestDate,
            contributorCount: contributors,
            commitDates: commitDates
        )
    }

    /// Whether a tag names a version: an optional `v`, then dot-separated numbers, then an optional
    /// pre-release suffix, such as `v1.0.0`, `0.2` or `3.1.4-beta.1`.
    static func isVersionTag(_ tag: String) -> Bool {
        tag.range(of: #"^v?[0-9]+(\.[0-9]+)*([-+][0-9A-Za-z.\-]+)?$"#, options: .regularExpression) != nil
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

    /// Runs a read-only git script and returns its standard output.
    ///
    /// The script is a literal assembled at compile time — no caller value reaches it — and the
    /// spawn is bounded by ``ProcessRunner``, which also captures the output the script used to
    /// redirect to a scratch file itself.
    private func runShell(_ script: String, in directory: String) throws -> String {
        // SAFETY: /bin/zsh with a compile-time literal script; no interpolation reaches the shell.
        let result = try ProcessRunner.run(
            "/bin/zsh",
            arguments: ["-c", script],
            workingDirectory: URL(fileURLWithPath: directory)
        )
        return result.standardOutput
    }
}
