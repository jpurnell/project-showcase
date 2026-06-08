//
//  InsightsExtractor.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Extracts and aggregates Claude Code usage data from facets and session-meta directories.
public struct InsightsExtractor: Sendable {

    /// Creates a new InsightsExtractor instance.
    public init() {}

    /// Extract insights from the given usage-data directory.
    ///
    /// - Parameters:
    ///   - usageDataPath: URL to the directory containing `facets/` and `session-meta/`.
    ///   - projectPath: Optional project path to filter sessions. If nil, aggregates all sessions.
    /// - Throws: `ShowcaseError.extractionFailed` if data cannot be parsed.
    /// - Returns: Aggregated insights summary.
    public func extract(from usageDataPath: URL, projectPath: String? = nil) async throws -> InsightsSummary {
        let facetsDir = usageDataPath.appendingPathComponent("facets").standardized
        let sessionDir = usageDataPath.appendingPathComponent("session-meta").standardized
        let fm = FileManager.default

        // SAFETY: facetsDir and sessionDir are .standardized, bounded to usageDataPath subdirectories
        guard fm.fileExists(atPath: facetsDir.path) else {
            throw ShowcaseError.extractionFailed(
                source: "insights",
                message: "No facets directory at \(facetsDir.path)"
            )
        }

        let metaFiles: [URL]
        if fm.fileExists(atPath: sessionDir.path) { // SAFETY: sessionDir is .standardized
            metaFiles = try fm.contentsOfDirectory(at: sessionDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
        } else {
            metaFiles = []
        }

        let decoder = JSONDecoder()

        let matchingSessionIDs: Set<String>?
        if let projectPath {
            var ids = Set<String>()
            for file in metaFiles {
                let data = try Data(contentsOf: file)
                guard let meta = try? decoder.decode(SessionMetaRecord.self, from: data) else { // silent: best-effort extraction
                    continue
                }
                if let metaPath = meta.projectPath, metaPath == projectPath {
                    ids.insert(file.deletingPathExtension().lastPathComponent)
                }
            }
            matchingSessionIDs = ids
        } else {
            matchingSessionIDs = nil
        }

        let facetFiles = try fm.contentsOfDirectory(at: facetsDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .filter { url in
                guard let ids = matchingSessionIDs else { return true }
                return ids.contains(url.deletingPathExtension().lastPathComponent)
            }

        var totalCommits = 0
        var totalMessages = 0
        var frictionCategories: [String: Int] = [:]
        var outcomeDistribution: [String: Int] = [:]
        var toolUsageProfile: [String: Int] = [:]
        var sessionTypes: [String: Int] = [:]

        for file in facetFiles {
            let data = try Data(contentsOf: file)
            guard let facet = try? decoder.decode(FacetRecord.self, from: data) else { // silent: best-effort extraction
                continue
            }

            if let outcome = facet.outcome {
                outcomeDistribution[outcome, default: 0] += 1
            }

            if let friction = facet.frictionCounts {
                for (key, value) in friction {
                    frictionCategories[key, default: 0] += value
                }
            }

            if let sessionType = facet.sessionType {
                sessionTypes[sessionType, default: 0] += 1
            }
        }

        let relevantMetaFiles: [URL]
        if let ids = matchingSessionIDs {
            relevantMetaFiles = metaFiles.filter { ids.contains($0.deletingPathExtension().lastPathComponent) }
        } else {
            relevantMetaFiles = metaFiles
        }

        for file in relevantMetaFiles {
            let data = try Data(contentsOf: file)
            guard let meta = try? decoder.decode(SessionMetaRecord.self, from: data) else { // silent: best-effort extraction
                continue
            }

            totalCommits += meta.gitCommits ?? 0
            totalMessages += meta.userMessageCount ?? 0

            if let tools = meta.toolCounts {
                for (key, value) in tools {
                    toolUsageProfile[key, default: 0] += value
                }
            }
        }

        return InsightsSummary(
            sessionCount: facetFiles.count,
            totalCommits: totalCommits,
            totalMessages: totalMessages,
            frictionCategories: frictionCategories,
            outcomeDistribution: outcomeDistribution,
            toolUsageProfile: toolUsageProfile,
            sessionTypes: sessionTypes
        )
    }

    /// Extract insights if the directory contains valid data, otherwise return nil.
    public func extractOptional(from usageDataPath: URL, projectPath: String? = nil) async throws -> InsightsSummary? {
        let facetsDir = usageDataPath.appendingPathComponent("facets").standardized
        // SAFETY: facetsDir is .standardized, bounded to usageDataPath
        guard FileManager.default.fileExists(atPath: facetsDir.path) else {
            return nil
        }
        return try await extract(from: usageDataPath, projectPath: projectPath)
    }
}

// Internal Codable records matching the Claude Code JSON format
struct FacetRecord: Codable {
    let outcome: String?
    let frictionCounts: [String: Int]?
    let sessionType: String?

    enum CodingKeys: String, CodingKey {
        case outcome
        case frictionCounts = "friction_counts"
        case sessionType = "session_type"
    }
}

struct SessionMetaRecord: Codable {
    let projectPath: String?
    let gitCommits: Int?
    let userMessageCount: Int?
    let toolCounts: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case projectPath = "project_path"
        case gitCommits = "git_commits"
        case userMessageCount = "user_message_count"
        case toolCounts = "tool_counts"
    }
}
