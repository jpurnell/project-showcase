import ArgumentParser
import Foundation
import ProjectShowcase

struct DeclineCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "decline",
        abstract: "Remove pages from the manifest and remember them, so discovery does not propose them again."
    )

    @Option(name: .long, help: "Path to the sync manifest JSON.")
    var manifest: String

    @Option(name: .long, help: "Path to the state file. Defaults to .showcase-state.json beside the manifest.")
    var state: String?

    @Argument(help: "Slugs to decline.")
    var slugs: [String]

    func run() async throws {
        guard !slugs.isEmpty else {
            throw ShowcaseError.invalidConfiguration(message: "Name at least one slug to decline.")
        }
        let manifestURL = URL(fileURLWithPath: manifest).standardizedFileURL
        let manifestDirectory = manifestURL.deletingLastPathComponent()
        let loaded = try SyncManifest.decode(from: Data(contentsOf: manifestURL))
        let stateURL = state.map { URL(fileURLWithPath: $0) }
            ?? manifestDirectory.appendingPathComponent(".showcase-state.json")

        try loaded.declining(slugs).encoded().write(to: manifestURL, options: .atomic)
        try SyncState.load(from: stateURL).removing(slugs).save(to: stateURL)

        // Slugs were validated as plain file stems when the manifest was decoded; an unknown one
        // is checked here so it cannot name a path outside the content directory.
        let content = loaded.contentURL(manifestDirectory: manifestDirectory)
        for slug in slugs where SyncManifest.isSafeSlug(slug) {
            let page = content.appendingPathComponent("\(slug).md")
            if FileManager.default.fileExists(atPath: page.path) { try FileManager.default.removeItem(at: page) }
        }
        if let images = loaded.imagesURL(manifestDirectory: manifestDirectory) {
            for slug in slugs { try InfographicWriter.remove(slug: slug, from: images) }
        }
        FileHandle.standardError.write(Data("declined: \(slugs.joined(separator: ", "))\n".utf8))
    }
}
