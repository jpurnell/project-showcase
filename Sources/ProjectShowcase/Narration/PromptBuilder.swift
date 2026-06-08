//
//  PromptBuilder.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation
import CryptoKit

/// Builds prompts for the Claude API from ProjectCards and configuration.
public struct PromptBuilder: Sendable {

    /// Creates a new PromptBuilder instance.
    public init() {}

    /// Build the system prompt for narrative generation.
    public func buildSystemPrompt(audience: Audience, style: NarrativeStyle) throws -> String {
        let audienceDescription: String
        switch audience {
        case .hiringManager:
            audienceDescription = "a hiring manager evaluating this developer's technical capabilities, judgment, and craft"
        case .openSourceContributor:
            audienceDescription = "an open source contributor deciding whether to use or contribute to this project"
        case .client:
            audienceDescription = "a potential client evaluating whether to hire this developer for a project"
        case .selfReflection:
            audienceDescription = "the developer themselves, reviewing their own growth and trajectory"
        }

        let styleInstruction: String
        switch style {
        case .caseStudy:
            styleInstruction = """
            Write a case study narrative with this structure:
            1. A compelling title (as a markdown H1)
            2. A one-sentence summary (as a blockquote)
            3. Problem — what the project is, what problem it solves, and why it was built
            4. Approach — architectural decisions, methodology, tools
            5. Results — quantitative outcomes, what shipped
            6. Judgment Calls — the interesting decisions that show craft
            Each section should be a markdown H2.
            """
        case .projectCard:
            styleInstruction = """
            Write a concise project card (2-3 paragraphs) with:
            1. A clear title (markdown H1)
            2. A one-sentence summary (blockquote)
            3. What the project does, how it was built, and key outcomes
            Keep it tight — this appears alongside many other project cards.
            """
        case .deepDive:
            styleInstruction = """
            Write a technical deep-dive for practitioners with:
            1. A descriptive title (markdown H1)
            2. A one-sentence summary (blockquote)
            3. Overview — what the project does, why it exists, and who it's for
            4. Architecture — detailed technical design choices
            5. Implementation — interesting patterns, challenges, solutions
            6. Testing Strategy — how quality is ensured
            7. Lessons — what transferred to other projects
            Each section should be a markdown H2. Use code examples where relevant.
            """
        }

        return """
        You are writing a developer portfolio narrative for \(audienceDescription).

        \(styleInstruction)

        Guidelines:
        - Write in third person about the developer and their work
        - Ground claims in the specific data provided — commit counts, test numbers, release history
        - Highlight judgment and craft, not just output
        - If design proposals or a design-first workflow exist, emphasize this as evidence of architectural thinking
        - If Claude Code insights data exists, weave it naturally — mention session patterns that demonstrate working style
        - If a "Project Description" section is present, treat it as the authoritative source for what the project does, who it serves, and how it differentiates — the narrative must be consistent with this description
        - Never fabricate data not present in the input
        - Output pure markdown, no code fences around the entire response
        """
    }

    /// Build the user prompt containing project facts.
    public func buildUserPrompt(from card: ProjectCard) throws -> String {
        var sections: [String] = []

        sections.append("Project: \(card.projectName)")
        sections.append("Path: \(card.projectPath)")

        // Git
        var git = "## Git History\n"
        git += "- \(card.git.commitCount) commits\n"
        git += "- \(card.git.contributorCount) contributor(s)\n"
        git += "- \(card.git.branchCount) branches\n"
        if !card.git.releaseHistory.isEmpty {
            let tags = card.git.releaseHistory.map(\.tag).joined(separator: ", ")
            git += "- Releases: \(tags)\n"
        }
        if let first = card.git.firstCommitDate {
            git += "- First commit: \(ISO8601DateFormatter().string(from: first))\n"
        }
        if let latest = card.git.latestCommitDate {
            git += "- Latest commit: \(ISO8601DateFormatter().string(from: latest))\n"
        }
        sections.append(git)

        // Package manifest
        if let pkg = card.packageManifest {
            var pkgSection = "## Package\n"
            pkgSection += "- Language: \(pkg.language.rawValue)\n"
            if let version = pkg.toolsVersion {
                pkgSection += "- Tools version: \(version)\n"
            }
            if !pkg.dependencies.isEmpty {
                pkgSection += "- Dependencies: \(pkg.dependencies.joined(separator: ", "))\n"
            }
            if !pkg.targets.isEmpty {
                pkgSection += "- Targets: \(pkg.targets.joined(separator: ", "))\n"
            }
            if !pkg.platforms.isEmpty {
                pkgSection += "- Platforms: \(pkg.platforms.joined(separator: ", "))\n"
            }
            sections.append(pkgSection)
        }

        // Tests
        if let tests = card.tests {
            var testSection = "## Test Suite\n"
            testSection += "- \(tests.testCount) tests across \(tests.suiteCount) suites\n"
            if let rate = tests.passRate {
                let pct = (rate * 100).rounded()
                testSection += "- Pass rate: \(Int(pct))%\n"
            }
            sections.append(testSection)
        }

        // Quality
        if let quality = card.quality {
            var qualSection = "## Quality Gate\n"
            qualSection += "- \(quality.violationCount) violations\n"
            if !quality.checkerCategories.isEmpty {
                let cats = quality.checkerCategories
                    .map { "\($0.key): \($0.value)" }
                    .joined(separator: ", ")
                qualSection += "- Categories: \(cats)\n"
            }
            sections.append(qualSection)
        }

        // Project description (from MASTER_PLAN.md)
        if let description = card.designArtifacts?.projectDescription {
            var descSection = "## Project Description (from project's own MASTER_PLAN.md)\n"
            descSection += description + "\n"
            sections.append(descSection)
        }

        // Design artifacts
        if let design = card.designArtifacts {
            var designSection = "## Design Artifacts\n"
            designSection += "- \(design.designProposalCount) design proposals\n"
            designSection += "- CLAUDE.md present: \(design.hasClaudeMD)\n"
            designSection += "- Design-first workflow: \(design.hasDesignFirstWorkflow)\n"
            if !design.architectureNotes.isEmpty {
                designSection += "- Architecture sections: \(design.architectureNotes.joined(separator: ", "))\n"
            }
            sections.append(designSection)
        }

        // Insights
        if let insights = card.insights {
            var insightSection = "## Claude Code Usage\n"
            insightSection += "- \(insights.sessionCount) sessions\n"
            insightSection += "- \(insights.totalCommits) total commits across sessions\n"
            insightSection += "- \(insights.totalMessages) total messages\n"
            if !insights.frictionCategories.isEmpty {
                let friction = insights.frictionCategories
                    .sorted { $0.value > $1.value }
                    .map { "\($0.key): \($0.value)" }
                    .joined(separator: ", ")
                insightSection += "- Friction: \(friction)\n"
            }
            if !insights.outcomeDistribution.isEmpty {
                let outcomes = insights.outcomeDistribution
                    .sorted { $0.value > $1.value }
                    .map { "\($0.key): \($0.value)" }
                    .joined(separator: ", ")
                insightSection += "- Outcomes: \(outcomes)\n"
            }
            if !insights.sessionTypes.isEmpty {
                let types = insights.sessionTypes
                    .sorted { $0.value > $1.value }
                    .map { "\($0.key): \($0.value)" }
                    .joined(separator: ", ")
                insightSection += "- Session types: \(types)\n"
            }
            sections.append(insightSection)
        }

        return sections.joined(separator: "\n")
    }

    /// Compute a stable hash of the card for caching narratives.
    public func cardHash(for card: ProjectCard) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(card)
        let digest = SHA256.hash(data: data)
        return digest.prefix(16).map { byte in
            let hex = "0123456789abcdef"
            let hi = hex[hex.index(hex.startIndex, offsetBy: Int(byte >> 4))]
            let lo = hex[hex.index(hex.startIndex, offsetBy: Int(byte & 0x0F))]
            return "\(hi)\(lo)"
        }.joined()
    }
}
