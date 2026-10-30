import ArgumentParser
import Foundation
#if canImport(os)
import os
#endif
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

        let markdown = PortfolioRenderer.render(text: text, cards: cards, generatedAt: Date())

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
