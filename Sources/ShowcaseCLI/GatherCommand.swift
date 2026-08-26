import ArgumentParser
import Foundation
#if canImport(os)
import os
#endif
import ProjectShowcase

private let logger = Logger(subsystem: "com.showcase", category: "GatherCommand")

struct GatherCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gather",
        abstract: "Extract structured facts from a project directory."
    )

    @Argument(help: "Path to the project root directory.")
    var projectPath: String

    @Option(name: .long, help: "Explicit path to Claude Code usage data directory.")
    var insightsPath: String?

    @Flag(name: .long, help: "Run the project's test suite and include results in the card.")
    var runTests: Bool = false

    @Option(name: .long, help: "Output file for the ProjectCard JSON. Prints to stdout if omitted.")
    var output: String?

    func run() async throws {
        let url = URL(fileURLWithPath: projectPath)
        let insightsURL = insightsPath.map { URL(fileURLWithPath: $0) }

        var testOutput: String?
        if runTests {
            FileHandle.standardError.write(Data("Running tests...\n".utf8))
            testOutput = try await runTestSuite(at: url)
        }

        let gatherer = FactGatherer()
        let card = try await gatherer.gather(from: url, insightsPath: insightsURL, testOutput: testOutput)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(card)

        guard let json = String(data: data, encoding: .utf8) else {
            throw ShowcaseError.extractionFailed(source: "json", message: "Could not encode card")
        }

        if let outputPath = output {
            try json.write(toFile: outputPath, atomically: true, encoding: .utf8)
            logger.info("Card written to \(outputPath, privacy: .public)")
        } else {
            logger.info("\(json, privacy: .public)")
        }
    }

    /// How long a project's test suite may run before the spawn is torn down.
    private static let testSuiteTimeout: Duration = .seconds(900)

    private func runTestSuite(at projectPath: URL) async throws -> String {
        // The metacharacter screen that used to guard this call is gone with the shell it guarded:
        // ProcessRunner passes each argument as its own argv entry, which nothing parses.
        let result = try ProcessRunner.run(
            "/usr/bin/env",
            arguments: ["swift", "test"],
            workingDirectory: projectPath,
            timeout: Self.testSuiteTimeout
        )
        return result.standardOutput + result.standardError
    }
}
