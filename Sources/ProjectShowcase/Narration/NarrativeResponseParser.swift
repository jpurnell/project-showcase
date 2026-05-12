//
//  NarrativeResponseParser.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Parses Claude API responses into structured NarrativeResult.
public struct NarrativeResponseParser: Sendable {

    public init() {}

    /// Parse a raw text response into a NarrativeResult.
    public func parse(
        response: String,
        projectName: String,
        audience: Audience,
        style: NarrativeStyle,
        cardHash: String
    ) throws -> NarrativeResult {
        let lines = response.split(separator: "\n", omittingEmptySubsequences: false)

        var title = "\(projectName) — Portfolio"
        var summary = ""
        var bodyStartIndex = 0

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
                title = String(trimmed.dropFirst(2))
                bodyStartIndex = max(bodyStartIndex, index + 1)
                continue
            }

            if trimmed.hasPrefix("> ") && summary.isEmpty {
                summary = String(trimmed.dropFirst(2))
                bodyStartIndex = max(bodyStartIndex, index + 1)
                continue
            }

            if !trimmed.isEmpty && bodyStartIndex <= index {
                bodyStartIndex = index
                break
            }
        }

        if summary.isEmpty {
            summary = title
        }

        let bodyLines = lines.dropFirst(bodyStartIndex)
        let body = bodyLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return NarrativeResult(
            projectName: projectName,
            audience: audience,
            style: style,
            title: title,
            summary: summary,
            body: body,
            generatedAt: Date(),
            cardHash: cardHash
        )
    }
}
