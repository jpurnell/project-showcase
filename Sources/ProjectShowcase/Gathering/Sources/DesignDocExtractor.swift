//
//  DesignDocExtractor.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Extracts design artifact facts from CLAUDE.md, development-guidelines, and proposals.
public struct DesignDocExtractor: Sendable {

    /// Creates a new DesignDocExtractor instance.
    public init() {}

    /// Extract design artifact facts from the project at the given path.
    public func extract(from projectPath: URL) async throws -> DesignArtifactFacts {
        let fm = FileManager.default

        let claudeMDPath = projectPath.appendingPathComponent("CLAUDE.md").standardized
        let hasClaudeMD = fm.fileExists(atPath: claudeMDPath.path) // SAFETY: .standardized, bounded to projectPath

        let proposalDir = projectPath
            .appendingPathComponent("development-guidelines")
            .appendingPathComponent("02_IMPLEMENTATION_PLANS")
            .appendingPathComponent("PROPOSALS")
            .standardized

        var proposalCount = 0
        if fm.fileExists(atPath: proposalDir.path) { // SAFETY: .standardized, bounded to projectPath
            let files = try fm.contentsOfDirectory(at: proposalDir, includingPropertiesForKeys: nil)
            proposalCount = files.filter { $0.pathExtension == "md" }.count
        }

        let completedDir = projectPath
            .appendingPathComponent("development-guidelines")
            .appendingPathComponent("02_IMPLEMENTATION_PLANS")
            .appendingPathComponent("COMPLETED")
            .standardized
        if fm.fileExists(atPath: completedDir.path) { // SAFETY: .standardized, bounded to projectPath
            let files = try fm.contentsOfDirectory(at: completedDir, includingPropertiesForKeys: nil)
            proposalCount += files.filter { $0.pathExtension == "md" }.count
        }

        let upcomingDir = projectPath
            .appendingPathComponent("development-guidelines")
            .appendingPathComponent("02_IMPLEMENTATION_PLANS")
            .appendingPathComponent("UPCOMING")
            .standardized
        if fm.fileExists(atPath: upcomingDir.path) { // SAFETY: .standardized, bounded to projectPath
            let files = try fm.contentsOfDirectory(at: upcomingDir, includingPropertiesForKeys: nil)
            proposalCount += files.filter { $0.pathExtension == "md" }.count
        }

        let guidelinesDir = projectPath.appendingPathComponent("development-guidelines").standardized
        // SAFETY: all paths below are .standardized, bounded to projectPath/development-guidelines
        let hasDevGuidelines = fm.fileExists(atPath: guidelinesDir.path)

        // SAFETY: guidelinesDir is .standardized, subpath components are string literals
        let hasDesignFirst = hasDevGuidelines && fm.fileExists(
            atPath: guidelinesDir
                .appendingPathComponent("00_CORE_RULES")
                .appendingPathComponent("07_SESSION_WORKFLOW.md").standardized.path
        )

        var architectureNotes: [String] = []
        if hasClaudeMD {
            let content = try String(contentsOf: claudeMDPath, encoding: .utf8)
            architectureNotes = extractHeadings(from: content)
        }

        let projectDescription = extractProjectDescription(from: projectPath)

        return DesignArtifactFacts(
            designProposalCount: proposalCount,
            architectureNotes: architectureNotes,
            hasDesignFirstWorkflow: hasDesignFirst,
            hasClaudeMD: hasClaudeMD,
            projectDescription: projectDescription
        )
    }

    private func extractHeadings(from markdown: String) -> [String] {
        markdown
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("## ") else { return nil }
                return String(trimmed.dropFirst(3))
            }
    }

    private func extractProjectDescription(from projectPath: URL) -> String? {
        let masterPlanPath = projectPath
            .appendingPathComponent("development-guidelines")
            .appendingPathComponent("00_CORE_RULES")
            .appendingPathComponent("00_MASTER_PLAN.md")
            .standardized

        // SAFETY: masterPlanPath is .standardized, bounded to projectPath
        guard FileManager.default.fileExists(atPath: masterPlanPath.path),
              let content = try? String(contentsOf: masterPlanPath, encoding: .utf8) else { // silent: best-effort extraction
            return nil
        }

        if content.contains("[PROJECT_NAME]") || content.contains("[Describe the core mission") {
            return nil
        }

        var parts: [String] = []
        if let mission = extractSection(named: "Mission", from: content) {
            parts.append("Mission: \(mission)")
        }
        if let users = extractSection(named: "Target Users", from: content) {
            parts.append("Target Users: \(users)")
        }
        if let differentiators = extractSection(named: "Key Differentiators", from: content) {
            parts.append("Key Differentiators: \(differentiators)")
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "\n\n")
    }

    private func extractSection(named heading: String, from markdown: String) -> String? {
        let lines = markdown.lines
        var capturing = false
        var captured: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "### \(heading)" {
                capturing = true
                continue
            }
            if capturing {
                if trimmed.hasPrefix("### ") || trimmed.hasPrefix("## ") || trimmed.hasPrefix("# ") || trimmed == "---" {
                    break
                }
                captured.append(String(line))
            }
        }

        let result = captured.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}
