import ArgumentParser
import Foundation
import os
import ProjectShowcase

private let logger = Logger(subsystem: "com.showcase", category: "PortfolioCommand")

struct PortfolioCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "portfolio",
        abstract: "Generate a cross-project portfolio overview from multiple ProjectCard JSON files."
    )

    @Argument(help: "Paths to ProjectCard JSON files.")
    var cardPaths: [String]

    @Option(name: .long, help: "Anthropic API key. Falls back to ANTHROPIC_API_KEY env var.")
    var apiKey: String?

    @Option(name: .long, help: "Target audience: hiringManager, openSourceContributor, client, selfReflection.")
    var audience: String = "hiringManager"

    @Option(name: .long, help: "Output directory for the portfolio markdown. Defaults to current directory.")
    var output: String = "."

    func run() async throws {
        let key = try resolveAPIKey()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var cards: [ProjectCard] = []
        for path in cardPaths {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let card = try decoder.decode(ProjectCard.self, from: data)
            cards.append(card)
            logger.info("Loaded: \(card.projectName, privacy: .public) (\(card.git.commitCount, privacy: .public) commits)")
        }

        guard let audienceEnum = Audience(rawValue: audience) else {
            throw ShowcaseError.invalidConfiguration(
                message: "Unknown audience '\(audience)'. Use: hiringManager, openSourceContributor, client, selfReflection"
            )
        }

        logger.info("Generating portfolio overview for \(cards.count, privacy: .public) projects...")

        let generator = NarrativeGenerator(apiKey: key)
        let text = try await generator.generatePortfolio(cards: cards, audience: audienceEnum)

        let outputDir = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let now = Date()
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        dateTimeFormatter.timeZone = TimeZone(identifier: "UTC")
        let shortDateFormatter = DateFormatter()
        shortDateFormatter.dateFormat = "yyyy-MM-dd"
        shortDateFormatter.timeZone = TimeZone(identifier: "UTC")

        let projectList = cards.map(\.projectName).joined(separator: ", ")

        var markdown = "---\n"
        markdown += "title: Developer Portfolio Overview\n"
        markdown += "description: Cross-project portfolio covering \(cards.count) projects and \(cards.reduce(0) { $0 + $1.git.commitCount }) total commits.\n"
        markdown += "date: \(dateTimeFormatter.string(from: now))\n"
        markdown += "lastModified: \(shortDateFormatter.string(from: now))\n"
        markdown += "tags: showcase, portfolio, overview\n"
        markdown += "layout: ShowcaseLayout\n"
        markdown += "projects: \(projectList)\n"
        markdown += "published: true\n"
        markdown += "---\n\n"
        markdown += text
        markdown += "\n"

        let fileURL = outputDir.appendingPathComponent("portfolio-overview.md")
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        logger.info("Portfolio written to \(fileURL.path, privacy: .public)")
    }

    private func resolveAPIKey() throws -> String {
        if let key = apiKey, !key.isEmpty { return key }
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        throw ShowcaseError.invalidConfiguration(
            message: "No API key provided. Use --api-key or set ANTHROPIC_API_KEY environment variable."
        )
    }
}
