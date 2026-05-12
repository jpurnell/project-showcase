import ArgumentParser
import Foundation
import ProjectShowcase

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
        let key = resolveAPIKey()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var cards: [ProjectCard] = []
        for path in cardPaths {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let card = try decoder.decode(ProjectCard.self, from: data)
            cards.append(card)
            print("Loaded: \(card.projectName) (\(card.git.commitCount) commits)")
        }

        guard let audienceEnum = Audience(rawValue: audience) else {
            throw ShowcaseError.invalidConfiguration(
                message: "Unknown audience '\(audience)'. Use: hiringManager, openSourceContributor, client, selfReflection"
            )
        }

        print("Generating portfolio overview for \(cards.count) projects...")

        let generator = NarrativeGenerator(apiKey: key)
        let text = try await generator.generatePortfolio(cards: cards, audience: audienceEnum)

        let outputDir = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let dateString = ISO8601DateFormatter().string(from: Date())
        var markdown = "---\n"
        markdown += "title: \"Developer Portfolio Overview\"\n"
        markdown += "date: \(dateString)\n"
        markdown += "tags: [\"portfolio\", \"overview\"]\n"
        markdown += "projects: [\(cards.map { "\"\($0.projectName)\"" }.joined(separator: ", "))]\n"
        markdown += "---\n\n"
        markdown += text
        markdown += "\n"

        let fileURL = outputDir.appendingPathComponent("portfolio-overview.md")
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        print("Portfolio written to \(fileURL.path)")
    }

    private func resolveAPIKey() -> String {
        if let key = apiKey, !key.isEmpty { return key }
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        fatalError("No API key provided. Use --api-key or set ANTHROPIC_API_KEY environment variable.")
    }
}
