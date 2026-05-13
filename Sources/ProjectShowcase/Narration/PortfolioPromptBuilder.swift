import Foundation

/// Builds prompts for cross-project portfolio overview narratives.
public struct PortfolioPromptBuilder: Sendable {

    public init() {}

    /// Build the system prompt for portfolio overview generation.
    public func buildSystemPrompt(audience: Audience) throws -> String {
        let audienceDescription: String
        switch audience {
        case .hiringManager:
            audienceDescription = "a hiring manager evaluating this developer's breadth, depth, and trajectory"
        case .openSourceContributor:
            audienceDescription = "an open source community member assessing this developer's body of work"
        case .client:
            audienceDescription = "a potential client evaluating this developer's range and reliability"
        case .selfReflection:
            audienceDescription = "the developer themselves, reviewing their growth across projects"
        }

        return """
        You are writing a developer portfolio overview for \(audienceDescription).

        This is a cross-project summary covering multiple repositories. Write a cohesive narrative with:
        1. A compelling title (markdown H1)
        2. A one-sentence portfolio summary (blockquote)
        3. Overview — the developer's scope, themes, and trajectory
        4. Technical Breadth — languages, platforms, and domains covered
        5. Craft Signals — patterns that appear across projects (testing discipline, design-first workflow, release rigor)
        6. Key Projects — brief highlights of the most notable work
        Each section should be a markdown H2.

        Guidelines:
        - Write in third person about the developer
        - Look for patterns ACROSS projects, not just within each one
        - Ground claims in aggregate data — total commits, total tests, shared dependencies
        - Highlight trajectory and growth over time using first/latest commit dates
        - If design proposals or design-first workflows appear across multiple projects, emphasize this as a core practice
        - If individual projects include a "Project Description" from their MASTER_PLAN.md, use it as the authoritative description of what each project does — do not contradict or embellish beyond what the project states about itself
        - Never fabricate data not present in the input
        - Output pure markdown, no code fences around the entire response
        """
    }

    /// Build the user prompt containing aggregated project facts.
    public func buildUserPrompt(from cards: [ProjectCard]) throws -> String {
        var sections: [String] = []

        let projectCount = cards.count
        let totalCommits = cards.reduce(0) { $0 + $1.git.commitCount }
        let totalReleases = cards.reduce(0) { $0 + $1.git.releaseHistory.count }
        let totalTests = cards.compactMap(\.tests?.testCount).reduce(0, +)
        let totalDesignProposals = cards.compactMap(\.designArtifacts?.designProposalCount).reduce(0, +)
        let designFirstCount = cards.filter { $0.designArtifacts?.hasDesignFirstWorkflow == true }.count
        let claudeMDCount = cards.filter { $0.designArtifacts?.hasClaudeMD == true }.count

        sections.append("# Portfolio Overview: \(projectCount) project\(projectCount == 1 ? "" : "s")")

        var aggregate = "## Aggregate Statistics\n"
        aggregate += "- \(projectCount) project\(projectCount == 1 ? "" : "s")\n"
        aggregate += "- \(totalCommits) total commits\n"
        aggregate += "- \(totalReleases) total releases\n"
        if totalTests > 0 {
            aggregate += "- \(totalTests) total tests\n"
        }
        if totalDesignProposals > 0 {
            aggregate += "- \(totalDesignProposals) design proposals across projects\n"
        }
        if designFirstCount > 0 {
            aggregate += "- \(designFirstCount) project\(designFirstCount == 1 ? "" : "s") with design-first workflow\n"
        }
        if claudeMDCount > 0 {
            aggregate += "- \(claudeMDCount) project\(claudeMDCount == 1 ? "" : "s") with CLAUDE.md\n"
        }

        let languages = Set(cards.compactMap(\.packageManifest?.language))
        if !languages.isEmpty {
            aggregate += "- Languages: \(languages.map(\.rawValue).sorted().joined(separator: ", "))\n"
        }

        let allPlatforms = Set(cards.flatMap { $0.packageManifest?.platforms ?? [] })
        if !allPlatforms.isEmpty {
            aggregate += "- Platforms: \(allPlatforms.sorted().joined(separator: ", "))\n"
        }

        let allDeps = Set(cards.flatMap { $0.packageManifest?.dependencies ?? [] })
        if !allDeps.isEmpty {
            aggregate += "- Shared ecosystem dependencies: \(allDeps.sorted().joined(separator: ", "))\n"
        }

        let dates = cards.compactMap(\.git.firstCommitDate).sorted()
        if let earliest = dates.first {
            aggregate += "- Earliest commit: \(ISO8601DateFormatter().string(from: earliest))\n"
        }
        let latestDates = cards.compactMap(\.git.latestCommitDate).sorted()
        if let latest = latestDates.last {
            aggregate += "- Most recent commit: \(ISO8601DateFormatter().string(from: latest))\n"
        }

        let totalSessions = cards.compactMap(\.insights?.sessionCount).reduce(0, +)
        let totalInsightCommits = cards.compactMap(\.insights?.totalCommits).reduce(0, +)
        if totalSessions > 0 {
            aggregate += "- \(totalSessions) Claude Code sessions, \(totalInsightCommits) AI-assisted commits\n"
        }

        sections.append(aggregate)

        for card in cards {
            var projectSection = "## Project: \(card.projectName)\n"
            projectSection += "- \(card.git.commitCount) commits"
            if !card.git.releaseHistory.isEmpty {
                projectSection += ", \(card.git.releaseHistory.count) releases"
            }
            projectSection += "\n"

            if let pkg = card.packageManifest {
                projectSection += "- \(pkg.language.rawValue)"
                if !pkg.platforms.isEmpty {
                    projectSection += " targeting \(pkg.platforms.joined(separator: ", "))"
                }
                projectSection += "\n"
            }

            if let tests = card.tests {
                projectSection += "- \(tests.testCount) tests across \(tests.suiteCount) suites\n"
            }

            if let design = card.designArtifacts {
                if design.designProposalCount > 0 {
                    projectSection += "- \(design.designProposalCount) design proposals\n"
                }
                if design.hasDesignFirstWorkflow {
                    projectSection += "- Uses design-first workflow\n"
                }
            }

            if let insights = card.insights {
                projectSection += "- \(insights.sessionCount) Claude Code sessions, \(insights.totalCommits) commits\n"
            }

            if let description = card.designArtifacts?.projectDescription {
                projectSection += "- Description: \(description)\n"
            }

            sections.append(projectSection)
        }

        return sections.joined(separator: "\n")
    }
}
