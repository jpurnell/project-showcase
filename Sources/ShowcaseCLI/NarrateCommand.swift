import ArgumentParser
import Foundation
import ProjectShowcase

struct NarrateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "narrate",
        abstract: "Generate a narrative from a ProjectCard JSON file."
    )

    @Argument(help: "Path to a ProjectCard JSON file.")
    var cardPath: String

    @Option(name: .long, help: "Anthropic API key. Falls back to ANTHROPIC_API_KEY env var.")
    var apiKey: String?

    @Option(name: .long, help: "Target audience: hiringManager, openSourceContributor, client, selfReflection.")
    var audience: String = "hiringManager"

    @Option(name: .long, help: "Narrative style: caseStudy, projectCard, deepDive.")
    var style: String = "caseStudy"

    @Option(name: .long, help: "Output file for the NarrativeResult JSON. Prints to stdout if omitted.")
    var output: String?

    func run() async throws {
        let key = resolveAPIKey()

        let cardData = try Data(contentsOf: URL(fileURLWithPath: cardPath))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let card = try decoder.decode(ProjectCard.self, from: cardData)

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
        let result = try await generator.generate(
            card: card,
            audience: audienceEnum,
            style: styleEnum
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(result)

        guard let json = String(data: data, encoding: .utf8) else {
            throw ShowcaseError.narrativeGenerationFailed(message: "Could not encode result")
        }

        if let outputPath = output {
            try json.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("Narrative written to \(outputPath)")
        } else {
            print(json)
        }
    }

    private func resolveAPIKey() -> String {
        if let key = apiKey, !key.isEmpty { return key }
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        fatalError("No API key provided. Use --api-key or set ANTHROPIC_API_KEY environment variable.")
    }
}
