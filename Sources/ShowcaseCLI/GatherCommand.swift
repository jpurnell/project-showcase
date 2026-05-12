import ArgumentParser
import Foundation
import ProjectShowcase

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
            print("Card written to \(outputPath)")
        } else {
            print(json)
        }
    }

    private func runTestSuite(at projectPath: URL) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["test"]
        process.currentDirectoryURL = projectPath
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
