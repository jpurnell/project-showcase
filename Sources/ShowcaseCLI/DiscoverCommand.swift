import ArgumentParser
import Foundation
#if canImport(os)
import os
#endif
import ProjectShowcase

private let logger = Logger(subsystem: "com.showcase", category: "DiscoverCommand")

struct DiscoverCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "discover",
        abstract: "Find public repositories that deserve a showcase page and propose manifest entries."
    )

    @Option(name: .long, help: "Path to the sync manifest JSON.")
    var manifest: String

    @Option(name: .long, help: "Directory whose immediate children are scanned. Repeatable. Defaults to the manifest's sourceRoot and its Tools folder.")
    var root: [String] = []

    @Option(name: .long, help: "GitHub owner whose public repositories may be proposed.")
    var owner: String = "jpurnell"

    @Option(name: .long, help: "Fewest commits a repository may have.")
    var minCommits: Int = 30

    @Option(name: .long, help: "Oldest its newest commit may be, in days.")
    var maxAgeDays: Int = 365

    @Option(name: .long, help: "Most repositories to propose in one run.")
    var maxNew: Int = 5

    @Flag(name: .long, help: "Write the proposals into the manifest. Without it, they are only printed.")
    var add: Bool = false

    func run() async throws {
        guard minCommits > 0, maxAgeDays > 0, maxNew > 0 else {
            throw ShowcaseError.invalidConfiguration(message: "--min-commits, --max-age-days and --max-new must be positive.")
        }
        let manifestURL = URL(fileURLWithPath: manifest).standardizedFileURL
        let manifestDirectory = manifestURL.deletingLastPathComponent()
        let loaded = try SyncManifest.decode(from: Data(contentsOf: manifestURL))
        let sourceRoot = URL(fileURLWithPath: loaded.sourceRoot, isDirectory: true, relativeTo: manifestDirectory).standardizedFileURL

        let roots = root.isEmpty
            ? [sourceRoot, sourceRoot.appendingPathComponent("Tools", isDirectory: true)]
            : root.map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL }
        let existingRoots = roots.filter { FileManager.default.fileExists(atPath: $0.path) }

        report("scanning \(existingRoots.map(\.path).joined(separator: ", "))")
        let repos = try await RepoScanner.scan(roots: existingRoots)
        let publicRepos = try GitHubRepoList.publicRepos(owner: owner)
        report("\(repos.count) checkouts, \(publicRepos.count) public repositories under \(owner)")

        var covered = Set<String>()
        for entry in loaded.entries {
            let source = loaded.sourceURL(for: entry, manifestDirectory: manifestDirectory)
            do {
                if let slug = try RepoScanner.remoteSlug(of: source) { covered.insert(slug) }
            } catch {
                logger.warning("Cannot read remote of \(source.path, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }

        let proposals = Discovery.propose(
            repos: repos, publicRepos: publicRepos, owner: owner,
            policy: DiscoveryPolicy(minCommits: minCommits, maxAgeDays: maxAgeDays, maxNew: maxNew),
            coveredRemotes: covered, existingSlugs: Set(loaded.entries.map(\.slug)).union(loaded.declined), now: Date())

        let entries = proposals.compactMap { repo in
            Discovery.entry(for: repo, relativePath: Discovery.relativePath(of: repo.path, from: sourceRoot))
        }
        for (repo, entry) in zip(proposals, entries) {
            report("[\(entry.slug)] propose: \(repo.commitCount) commits, \(repo.remoteSlug ?? "?") -> \(entry.path)")
        }
        report("\(entries.count) proposed, \(covered.count) remotes already covered.")

        guard add, !entries.isEmpty else { return }
        try loaded.appending(entries).encoded().write(to: manifestURL, options: .atomic)
        report("manifest updated: \(manifestURL.path)")
        // The only thing on stdout: one added slug per line, for the weekly script to read.
        for entry in entries { FileHandle.standardOutput.write(Data((entry.slug + "\n").utf8)) }
    }

    private func report(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }
}
