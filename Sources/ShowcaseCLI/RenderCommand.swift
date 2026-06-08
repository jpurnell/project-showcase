import ArgumentParser
import Foundation
import os
import ProjectShowcase

private let logger = Logger(subsystem: "com.showcase", category: "RenderCommand")

struct RenderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "render",
        abstract: "Render a NarrativeResult JSON to markdown with YAML frontmatter."
    )

    @Argument(help: "Path to a NarrativeResult JSON file.")
    var narrativePath: String

    @Option(name: .long, help: "Output directory for the markdown file. Defaults to current directory.")
    var output: String = "."

    func run() async throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: narrativePath))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let narrative = try decoder.decode(NarrativeResult.self, from: data)

        let renderer = MarkdownRenderer()
        let outputDir = URL(fileURLWithPath: output)

        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let fileURL = try renderer.renderToFile(narrative: narrative, outputDirectory: outputDir)
        logger.info("Rendered to \(fileURL.path, privacy: .public)")
    }
}
