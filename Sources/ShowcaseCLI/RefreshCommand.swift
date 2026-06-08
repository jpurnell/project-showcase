import ArgumentParser
import Foundation
import os
import ProjectShowcase

private let logger = Logger(subsystem: "com.showcase", category: "RefreshCommand")

struct RefreshCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "refresh",
        abstract: "Gather facts, generate narrative, and render markdown in one step."
    )

    @Argument(help: "Path to the project root directory.")
    var projectPath: String

    @Option(name: .long, help: "Anthropic API key. Falls back to ANTHROPIC_API_KEY env var.")
    var apiKey: String?

    @Option(name: .long, help: "Explicit path to Claude Code usage data directory.")
    var insightsPath: String?

    @Option(name: .long, help: "Target audience: hiringManager, openSourceContributor, client, selfReflection.")
    var audience: String = "hiringManager"

    @Option(name: .long, help: "Narrative style: caseStudy, projectCard, deepDive.")
    var style: String = "caseStudy"

    @Option(name: .long, help: "Output directory for the markdown file.")
    var output: String = "."

    func run() async throws {
        let key = try resolveAPIKey()
        let projectURL = URL(fileURLWithPath: projectPath)
        let insightsURL = insightsPath.map { URL(fileURLWithPath: $0) }

        logger.info("Gathering facts from \(projectPath, privacy: .public)...")
        let gatherer = FactGatherer()
        let card = try await gatherer.gather(from: projectURL, insightsPath: insightsURL)

        logger.info("Generating narrative for \(card.projectName, privacy: .public)...")
        guard let audienceEnum = Audience(rawValue: audience) else {
            throw ShowcaseError.invalidConfiguration(
                message: "Unknown audience '\(audience)'. Use: hiringManager, openSourceContributor, client, selfReflection"
            )
        }
        guard let styleEnum = NarrativeStyle(rawValue: style) else {
            throw ShowcaseError.invalidConfiguration(
                message: "Unknown style '\(style)'. Use: caseStudy, projectCard, deepDive"
            )
        }

        let generator = NarrativeGenerator(apiKey: key)
        let narrative = try await generator.generate(
            card: card,
            audience: audienceEnum,
            style: styleEnum
        )

        logger.info("Rendering markdown...")
        let renderer = MarkdownRenderer()
        let outputDir = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let fileURL = try renderer.renderToFile(narrative: narrative, outputDirectory: outputDir)

        logger.info("Done! \(fileURL.path, privacy: .public)")
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
