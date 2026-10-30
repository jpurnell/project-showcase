import ArgumentParser
import Foundation
#if canImport(os)
import os
#endif
import ProjectShowcase

private let logger = Logger(subsystem: "com.showcase", category: "SyncCommand")

struct SyncCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Regenerate every page whose source repository has moved since it was last generated."
    )

    @Option(name: .long, help: "Path to the sync manifest JSON.")
    var manifest: String

    @Option(name: .long, help: "Path to the state file. Defaults to .showcase-state.json beside the manifest.")
    var state: String?

    @Option(name: .long, help: "Anthropic API key. Falls back to ANTHROPIC_API_KEY env var.")
    var apiKey: String?

    @Option(name: .long, help: "Only consider this slug. Repeatable.")
    var only: [String] = []

    @Flag(name: .long, help: "Regenerate every selected page even if its source has not moved.")
    var force: Bool = false

    @Flag(name: .long, help: "Print the plan and exit without calling the API or writing anything.")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Only rewrite each page's infographics from its repository's current facts: no narrative, no API key, no markdown.")
    var infographicsOnly: Bool = false

    @Option(name: .long, help: "Write infographics here instead of the manifest's imagesDirectory.")
    var imagesDir: String?

    @Flag(name: .long, help: "Do not regenerate portfolio-overview.md after pages change.")
    var noPortfolio: Bool = false

    @Option(name: .long, help: "Audience for the portfolio overview.")
    var portfolioAudience: String = "selfReflection"

    func run() async throws {
        let manifestURL = URL(fileURLWithPath: manifest).standardizedFileURL
        let manifestDirectory = manifestURL.deletingLastPathComponent()
        let loaded = try SyncManifest.decode(from: Data(contentsOf: manifestURL))
        let stateURL = state.map { URL(fileURLWithPath: $0) }
            ?? manifestDirectory.appendingPathComponent(".showcase-state.json")
        var syncState = try SyncState.load(from: stateURL)
        let contentURL = loaded.contentURL(manifestDirectory: manifestDirectory)

        let selected = only.isEmpty ? loaded.entries : loaded.entries.filter { only.contains($0.slug) }
        if let unknown = only.first(where: { slug in !loaded.entries.contains { $0.slug == slug } }) {
            throw ShowcaseError.invalidConfiguration(message: "No manifest entry has slug '\(unknown)'.")
        }

        let imagesURL = imagesDir.map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL }
            ?? loaded.imagesURL(manifestDirectory: manifestDirectory)

        if infographicsOnly {
            try await writeInfographicsOnly(selected, loaded: loaded, manifestDirectory: manifestDirectory, imagesURL: imagesURL)
            return
        }

        var heads: [String: HeadLookup] = [:]
        for entry in selected {
            let source = loaded.sourceURL(for: entry, manifestDirectory: manifestDirectory)
            do {
                heads[entry.slug] = .success(try GitHead.resolve(at: source))
            } catch {
                logger.warning("Cannot read HEAD of \(source.path, privacy: .public): \(String(describing: error), privacy: .public)")
                heads[entry.slug] = .failure("\(source.path): \(error)")
            }
        }

        let plan = SyncPlanner.plan(entries: selected, heads: heads, state: syncState, force: force)
        for decision in plan { report(Self.describe(decision)) }

        let work = plan.filter { if case .regenerate = $0.action { return true } else { return false } }
        let unavailable = plan.filter { if case .skip(.sourceUnavailable) = $0.action { return true } else { return false } }
        report("\(work.count) to regenerate, \(plan.count - work.count - unavailable.count) current, \(unavailable.count) unreadable.")
        if dryRun || work.isEmpty { return }

        let key = try resolveAPIKey()
        let generator = NarrativeGenerator(apiKey: key)
        let gatherer = FactGatherer()
        let renderer = MarkdownRenderer()
        try FileManager.default.createDirectory(at: contentURL, withIntermediateDirectories: true)

        var failures: [String] = []
        var ungrounded: [String] = []
        for decision in work {
            let entry = decision.entry
            guard let head = decision.head else { continue }
            report("[\(entry.slug)] generating...")
            do {
                var card = try await gatherer.gather(from: loaded.sourceURL(for: entry, manifestDirectory: manifestDirectory), insightsPath: nil)
                if let name = entry.name { card = card.renamed(to: name) }
                guard SyncPlanner.isGrounded(card) else {
                    ungrounded.append(entry.slug)
                    report("[\(entry.slug)] SKIPPED, no master plan description to ground it; the published page is untouched")
                    continue
                }
                let narrative = try await generator.generate(card: card, audience: entry.audience, style: entry.style)
                let existing = Self.readText(at: contentURL.appendingPathComponent("\(entry.slug).md"))
                let written = try renderer.renderToFile(
                    narrative: narrative, outputDirectory: contentURL,
                    slug: entry.slug, projectLabel: entry.group, tags: entry.tags,
                    publishedDate: existing.flatMap { FrontmatterReader.value(for: "date", in: $0) },
                    published: Publication.isPublished(existingPage: existing))
                if let imagesURL { try InfographicWriter.write(card: card, slug: entry.slug, to: imagesURL) }
                syncState.records[entry.slug] = SyncRecord(head: head, generatedAt: Date())
                try syncState.save(to: stateURL)
                report("[\(entry.slug)] done: \(written.lastPathComponent)")
            } catch {
                logger.error("Page \(entry.slug, privacy: .public) failed: \(String(describing: error), privacy: .public)")
                failures.append(entry.slug)
                report("[\(entry.slug)] FAILED: \(error)")
            }
        }

        if !ungrounded.isEmpty {
            report("\(ungrounded.count) page(s) left as published for want of a master plan: \(ungrounded.joined(separator: ", "))")
        }

        if !noPortfolio, failures.count + ungrounded.count < work.count {
            try await writePortfolio(loaded: loaded, manifestDirectory: manifestDirectory, contentURL: contentURL, generator: generator, gatherer: gatherer)
        }

        if !failures.isEmpty {
            throw ShowcaseError.extractionFailed(source: "sync", message: "\(failures.count) page(s) failed: \(failures.joined(separator: ", "))")
        }
    }

    /// Rewrites every selected page's infographics without touching its narrative.
    private func writeInfographicsOnly(
        _ entries: [SyncEntry], loaded: SyncManifest, manifestDirectory: URL, imagesURL: URL?
    ) async throws {
        guard let imagesURL else {
            throw ShowcaseError.invalidConfiguration(message: "The manifest has no imagesDirectory; pass --images-dir.")
        }
        var failed: [String] = []
        for entry in entries {
            do {
                var card = try await FactGatherer().gather(
                    from: loaded.sourceURL(for: entry, manifestDirectory: manifestDirectory), insightsPath: nil)
                if let name = entry.name { card = card.renamed(to: name) }
                try InfographicWriter.write(card: card, slug: entry.slug, to: imagesURL)
                report("[\(entry.slug)] infographics written")
            } catch {
                logger.error("Infographics for \(entry.slug, privacy: .public) failed: \(String(describing: error), privacy: .public)")
                failed.append(entry.slug)
                report("[\(entry.slug)] FAILED: \(error)")
            }
        }
        if !failed.isEmpty {
            throw ShowcaseError.extractionFailed(source: "infographics", message: "\(failed.count) failed: \(failed.joined(separator: ", "))")
        }
    }

    private func writePortfolio(
        loaded: SyncManifest, manifestDirectory: URL, contentURL: URL,
        generator: NarrativeGenerator, gatherer: FactGatherer
    ) async throws {
        guard let audience = Audience(rawValue: portfolioAudience) else {
            throw ShowcaseError.invalidConfiguration(message: "Unknown audience '\(portfolioAudience)'.")
        }
        var cards: [ProjectCard] = []
        for entry in loaded.entries {
            var card: ProjectCard
            do {
                card = try await gatherer.gather(from: loaded.sourceURL(for: entry, manifestDirectory: manifestDirectory), insightsPath: nil)
            } catch {
                logger.warning("Leaving \(entry.slug, privacy: .public) out of the overview: \(String(describing: error), privacy: .public)")
                continue
            }
            if let name = entry.name { card = card.renamed(to: name) }
            guard SyncPlanner.isGrounded(card) else { continue }
            cards.append(card)
        }
        report("[portfolio-overview] generating from \(cards.count) projects...")
        let text = try await generator.generatePortfolio(cards: cards, audience: audience)
        let overviewURL = contentURL.appendingPathComponent("portfolio-overview.md")
        let previous = Self.readText(at: overviewURL)
        let markdown = PortfolioRenderer.render(
            text: text, cards: cards, generatedAt: Date(),
            publishedDate: previous.flatMap { FrontmatterReader.value(for: "date", in: $0) })
        try markdown.write(to: overviewURL, atomically: true, encoding: .utf8)
        report("[portfolio-overview] done.")
    }

    private static func describe(_ decision: SyncDecision) -> String {
        let slug = decision.entry.slug
        switch decision.action {
        case .regenerate(.neverGenerated): return "[\(slug)] regenerate: no record of a previous run"
        case .regenerate(.sourceMoved(let from, let to)): return "[\(slug)] regenerate: \(from.prefix(8)) -> \(to.prefix(8))"
        case .regenerate(.forced): return "[\(slug)] regenerate: forced"
        case .regenerate(let other), .skip(let other):
            if case .current = other { return "[\(slug)] current" }
            if case .sourceUnavailable(let why) = other { return "[\(slug)] SKIPPED, source unreadable: \(why)" }
            return "[\(slug)] \(other)"
        }
    }

    /// The text of a file, or `nil` when there is no such file or it is not UTF-8.
    private static func readText(at url: URL) -> String? {
        guard let data = FileManager.default.contents(atPath: url.path) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func report(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }

    private func resolveAPIKey() throws -> String {
        if let key = apiKey, !key.isEmpty { return key }
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty { return envKey }
        throw ShowcaseError.invalidConfiguration(
            message: "No API key provided. Use --api-key or set ANTHROPIC_API_KEY environment variable."
        )
    }
}
