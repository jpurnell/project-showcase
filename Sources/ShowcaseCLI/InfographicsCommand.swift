import ArgumentParser
import Foundation
#if canImport(os)
import os
#endif
import ProjectShowcase

private let logger = Logger(subsystem: "com.showcase", category: "InfographicsCommand")

struct InfographicsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "infographics",
        abstract: "Generate SVG infographic files from a ProjectCard JSON."
    )

    @Argument(help: "Path to a ProjectCard JSON file.")
    var cardPath: String

    @Option(name: .long, help: "Output directory for the SVG files. Defaults to current directory.")
    var output: String = "."

    func run() async throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: cardPath))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let card = try decoder.decode(ProjectCard.self, from: data)

        let outputDir = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let slug = card.projectName.lowercased().replacingOccurrences(of: " ", with: "-")

        let generators: [(any InfographicGenerator, String)] = [
            (StatsCardGenerator(), "\(slug)-stats.svg"),
            (CommitTimelineGenerator(), "\(slug)-commits.svg"),
            (ReleaseTimelineGenerator(), "\(slug)-releases.svg"),
        ]

        for (generator, filename) in generators {
            let svg = try generator.generate(from: card)
            let fileURL = outputDir.appendingPathComponent(filename)
            try svg.write(to: fileURL, atomically: true, encoding: .utf8)
            logger.info("Generated \(fileURL.path, privacy: .public)")
        }
    }
}
