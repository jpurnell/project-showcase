//
//  DiscoveryTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-10-30.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("Remote Slug Tests")
struct RemoteSlugTests {

    @Test("Parses the forms git remotes take on GitHub")
    func parses() {
        #expect(RemoteSlug.parse("git@github.com:jpurnell/x.git") == "jpurnell/x")
        #expect(RemoteSlug.parse("https://github.com/jpurnell/x.git") == "jpurnell/x")
        #expect(RemoteSlug.parse("https://github.com/jpurnell/x") == "jpurnell/x")
        #expect(RemoteSlug.parse("https://github.com/jpurnell/x/\n") == "jpurnell/x")
    }

    @Test("Anything that is not a GitHub repository reads as nil")
    func rejects() {
        #expect(RemoteSlug.parse("https://gitlab.com/a/b.git") == nil)
        #expect(RemoteSlug.parse("") == nil)
        #expect(RemoteSlug.parse("/local/path/repo") == nil)
        #expect(RemoteSlug.parse("https://github.com/onlyowner") == nil)
    }
}

@Suite("GitHub Repo List Tests")
struct GitHubRepoListTests {

    @Test("Parses gh's JSON into facts keyed by lowercased slug")
    func parses() throws {
        let json = """
        [{"nameWithOwner":"jpurnell/Alpha","isFork":false,"isArchived":false},
         {"nameWithOwner":"jpurnell/Beta","isFork":true,"isArchived":false},
         {"nameWithOwner":"jpurnell/Gamma","isFork":false,"isArchived":true}]
        """
        let list = try GitHubRepoList.parse(Data(json.utf8))
        #expect(list["jpurnell/alpha"] == RemoteRepo(isFork: false, isArchived: false))
        #expect(list["jpurnell/beta"]?.isFork == true)
        #expect(list["jpurnell/gamma"]?.isArchived == true)
        #expect(list.count == 3)
    }

    @Test("Malformed output throws instead of reading as an empty list")
    func malformed() {
        #expect(throws: (any Error).self) { try GitHubRepoList.parse(Data("not json".utf8)) }
    }
}

@Suite("Discovery Policy Tests")
struct DiscoveryPolicyTests {

    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let recent = now.addingTimeInterval(-30 * 86_400)

    static func repo(
        _ name: String, commits: Int = 100, last: Date = recent, plan: Bool = true,
        remote: String? = nil, path: String? = nil
    ) -> RepoFacts {
        RepoFacts(
            path: path ?? "/src/\(name)", name: name, commitCount: commits, lastCommit: last,
            remoteSlug: remote ?? "jpurnell/\(name.lowercased())", hasMasterPlan: plan)
    }

    static let publicRepos: [String: RemoteRepo] = [
        "jpurnell/good": RemoteRepo(isFork: false, isArchived: false),
        "jpurnell/forked": RemoteRepo(isFork: true, isArchived: false),
        "jpurnell/old": RemoteRepo(isFork: false, isArchived: false),
        "jpurnell/tiny": RemoteRepo(isFork: false, isArchived: false),
        "jpurnell/noplan": RemoteRepo(isFork: false, isArchived: false),
        "jpurnell/archived": RemoteRepo(isFork: false, isArchived: true),
        "jpurnell/a": RemoteRepo(isFork: false, isArchived: false),
        "jpurnell/b": RemoteRepo(isFork: false, isArchived: false),
        "jpurnell/c": RemoteRepo(isFork: false, isArchived: false),
        "jpurnell/shared": RemoteRepo(isFork: false, isArchived: false)
    ]

    func propose(
        _ repos: [RepoFacts], covered: Set<String> = [], slugs: Set<String> = [], maxNew: Int = 5
    ) -> [RepoFacts] {
        Discovery.propose(
            repos: repos, publicRepos: Self.publicRepos, owner: "jpurnell",
            policy: DiscoveryPolicy(minCommits: 30, maxAgeDays: 365, maxNew: maxNew),
            coveredRemotes: covered, existingSlugs: slugs, now: Self.now)
    }

    @Test("A public, owned, active repo with a plan is proposed")
    func accepts() {
        #expect(propose([Self.repo("Good")]).map(\.name) == ["Good"])
    }

    @Test("A private repo, absent from GitHub's public list, is never proposed")
    func privateRejected() {
        #expect(propose([Self.repo("Secret")]).isEmpty)
    }

    @Test("Each rule rejects on its own")
    func rules() {
        #expect(propose([Self.repo("Forked")]).isEmpty)
        #expect(propose([Self.repo("Archived")]).isEmpty)
        #expect(propose([Self.repo("Old", last: Self.now.addingTimeInterval(-400 * 86_400))]).isEmpty)
        #expect(propose([Self.repo("Tiny", commits: 29)]).isEmpty)
        #expect(propose([Self.repo("NoPlan", plan: false)]).isEmpty)
    }

    @Test("A repo owned by someone else is rejected even if public")
    func foreignOwner() {
        let foreign = Self.repo("Good", remote: "someone/good")
        #expect(propose([foreign]).isEmpty)
    }

    @Test("A repo with no remote is rejected, since its visibility is unknown")
    func noRemote() {
        let local = RepoFacts(path: "/src/x", name: "X", commitCount: 100, lastCommit: Self.recent, remoteSlug: nil, hasMasterPlan: true)
        #expect(propose([local]).isEmpty)
    }

    @Test("Two checkouts of one remote yield one proposal, the one with more history")
    func dedupesByRemote() {
        let a = Self.repo("Shared", commits: 50, remote: "jpurnell/shared", path: "/src/a")
        let b = Self.repo("Shared2", commits: 90, remote: "jpurnell/shared", path: "/src/b")
        #expect(propose([a, b]).map(\.path) == ["/src/b"])
    }

    @Test("A remote an existing page already covers is not proposed again")
    func skipsCovered() {
        #expect(propose([Self.repo("Good")], covered: ["jpurnell/good"]).isEmpty)
    }

    @Test("A slug already in the manifest is not reused")
    func skipsExistingSlug() {
        #expect(propose([Self.repo("Good")], slugs: ["good"]).isEmpty)
    }

    @Test("The cap keeps the repos with the most history first")
    func caps() {
        let repos = [Self.repo("A", commits: 40), Self.repo("B", commits: 300), Self.repo("C", commits: 120)]
        #expect(propose(repos, maxNew: 2).map(\.name) == ["B", "C"])
    }

    @Test("Slugs are lowercase file stems")
    func slugs() {
        #expect(Discovery.slug(for: "My Cool_Repo.v2") == "my-cool-repo-v2")
        #expect(Discovery.slug(for: "swift-oauth") == "swift-oauth")
        #expect(Discovery.slug(for: "..") == nil)
    }
}

@Suite("Discovery Manifest Entry Tests")
struct DiscoveryEntryTests {

    @Test("A proposal becomes a manifest entry with the standard defaults")
    func entry() throws {
        let repo = RepoFacts(path: "/src/Swift-OAuth", name: "swift-oauth", commitCount: 143,
                             lastCommit: Date(timeIntervalSince1970: 0), remoteSlug: "jpurnell/swift-oauth", hasMasterPlan: true)
        let entry = try #require(Discovery.entry(for: repo, relativePath: "Tools/swift-oauth"))
        #expect(entry.slug == "swift-oauth")
        #expect(entry.path == "Tools/swift-oauth")
        #expect(entry.audience == .selfReflection)
        #expect(entry.style == .caseStudy)
        #expect(entry.tags == ["showcase", "swift-oauth", "selfReflection"])
    }
}

@Suite("Repo Scanner Tests")
struct RepoScannerTests {

    @Test("Reads commit count, last commit, remote and master plan from a checkout")
    func scans() async throws {
        let root = try makeFixtureDirectory(prefix: "showcase-scan")
        let repo = root.appendingPathComponent("alpha")
        try FileManager.default.createDirectory(at: repo.appendingPathComponent("project"), withIntermediateDirectories: true)
        try runGit(["init", "-q"], in: repo)
        try runGit(["remote", "add", "origin", "git@github.com:jpurnell/alpha.git"], in: repo)
        try writeFixtureFile("## Project Overview\n\n### Mission\nDoes a thing.\n", named: "project/master_plan.md", in: repo)
        try runGit(["add", "."], in: repo)
        try runGit(["commit", "-q", "-m", "one"], in: repo)
        try writeFixtureFile("x", named: "f.txt", in: repo)
        try runGit(["add", "."], in: repo)
        try runGit(["commit", "-q", "-m", "two"], in: repo)

        // A directory that is not a repository must be ignored, not reported.
        try FileManager.default.createDirectory(at: root.appendingPathComponent("not-a-repo"), withIntermediateDirectories: true)

        let found = try await RepoScanner.scan(roots: [root])
        #expect(found.count == 1)
        let facts = try #require(found.first)
        #expect(facts.name == "alpha")
        #expect(facts.commitCount == 2)
        #expect(facts.remoteSlug == "jpurnell/alpha")
        #expect(facts.hasMasterPlan)
    }

    @Test("A repo with no remote and no plan reports both as absent")
    func bare() async throws {
        let root = try makeFixtureDirectory(prefix: "showcase-scan")
        let repo = root.appendingPathComponent("bare")
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        try runGit(["init", "-q"], in: repo)
        try writeFixtureFile("x", named: "f.txt", in: repo)
        try runGit(["add", "."], in: repo)
        try runGit(["commit", "-q", "-m", "one"], in: repo)
        let facts = try #require(try await RepoScanner.scan(roots: [root]).first)
        #expect(facts.remoteSlug == nil)
        #expect(!facts.hasMasterPlan)
    }
}

@Suite("Manifest Append Tests")
struct ManifestAppendTests {

    static let base = SyncManifest(sourceRoot: "..", contentDirectory: "Content/showcase", entries: [
        SyncEntry(slug: "a", path: "A", name: nil, group: "G", tags: ["t"], audience: .client, style: .deepDive)
    ])

    @Test("Appending keeps existing entries untouched and in order")
    func appends() throws {
        let added = SyncEntry(slug: "b", path: "B", name: nil, group: nil, tags: nil, audience: .selfReflection, style: .caseStudy)
        let merged = Self.base.appending([added])
        #expect(merged.entries.map(\.slug) == ["a", "b"])
        #expect(merged.entries[0] == Self.base.entries[0])
        #expect(merged.sourceRoot == ".." && merged.contentDirectory == "Content/showcase")
    }

    @Test("An encoded manifest decodes, validates and round-trips")
    func roundTrip() throws {
        let added = SyncEntry(slug: "b", path: "B", name: "Bee", group: nil, tags: nil, audience: .selfReflection, style: .caseStudy)
        let merged = Self.base.appending([added])
        let decoded = try SyncManifest.decode(from: try merged.encoded())
        #expect(decoded == merged)
    }
}

@Suite("Decline Tests")
struct DeclineTests {

    static func entry(_ slug: String) -> SyncEntry {
        SyncEntry(slug: slug, path: slug, name: nil, group: nil, tags: nil, audience: .selfReflection, style: .caseStudy)
    }

    static let manifest = SyncManifest(sourceRoot: "..", contentDirectory: "c", entries: [entry("a"), entry("b"), entry("c")])

    @Test("A manifest written before `declined` existed still decodes, with none declined")
    func oldManifestDecodes() throws {
        let json = #"{"sourceRoot":"..","contentDirectory":"c","entries":[]}"#
        #expect(try SyncManifest.decode(from: Data(json.utf8)).declined.isEmpty)
    }

    @Test("Declining removes the entry and remembers the slug")
    func declines() {
        let result = Self.manifest.declining(["b"])
        #expect(result.entries.map(\.slug) == ["a", "c"])
        #expect(result.declined == ["b"])
    }

    @Test("Declining twice, or declining a slug that is not there, adds it once and changes nothing else")
    func idempotent() {
        let once = Self.manifest.declining(["b"])
        let twice = once.declining(["b", "ghost"])
        #expect(twice.entries.map(\.slug) == ["a", "c"])
        #expect(twice.declined == ["b", "ghost"])
    }

    @Test("A declined list survives encode and decode")
    func roundTrip() throws {
        let declined = Self.manifest.declining(["b"])
        #expect(try SyncManifest.decode(from: try declined.encoded()) == declined)
    }

    @Test("An unchanged manifest encodes without a declined key")
    func noEmptyKey() throws {
        let text = String(decoding: try Self.manifest.encoded(), as: UTF8.self)
        #expect(!text.contains("declined"))
    }

    @Test("A declined slug is never proposed again")
    func notReproposed() {
        let publicRepos = ["jpurnell/good": RemoteRepo(isFork: false, isArchived: false)]
        let repo = RepoFacts(path: "/s/Good", name: "Good", commitCount: 100,
                             lastCommit: DiscoveryPolicyTests.recent, remoteSlug: "jpurnell/good", hasMasterPlan: true)
        let policy = DiscoveryPolicy(minCommits: 30, maxAgeDays: 365, maxNew: 5)
        func propose(declined: Set<String>) -> [RepoFacts] {
            Discovery.propose(repos: [repo], publicRepos: publicRepos, owner: "jpurnell", policy: policy,
                              coveredRemotes: [], existingSlugs: declined, now: DiscoveryPolicyTests.now)
        }
        #expect(propose(declined: []).count == 1)
        #expect(propose(declined: ["good"]).isEmpty)
    }

    @Test("Declining drops the page's sync record so a later re-add starts fresh")
    func dropsState() {
        var state = SyncState()
        state.records["b"] = SyncRecord(head: "1", generatedAt: Date(timeIntervalSince1970: 0))
        state.records["a"] = SyncRecord(head: "2", generatedAt: Date(timeIntervalSince1970: 0))
        let trimmed = state.removing(["b"])
        #expect(trimmed.records.keys.sorted() == ["a"])
    }
}

@Suite("Discovery Relative Path Tests")
struct DiscoveryRelativePathTests {

    @Test("A path under the root becomes relative to it")
    func relative() {
        let base = URL(fileURLWithPath: "/Users/me/Dev/Swift", isDirectory: true)
        #expect(Discovery.relativePath(of: "/Users/me/Dev/Swift/Tools/oauth", from: base) == "Tools/oauth")
    }

    @Test("A different spelling of the same folder's case still matches, as on a case-insensitive volume")
    func caseDifference() {
        let base = URL(fileURLWithPath: "/Users/me/dropbox/dev/swift", isDirectory: true)
        #expect(Discovery.relativePath(of: "/Users/me/Dropbox/Dev/Swift/Tools/oauth", from: base) == "Tools/oauth")
    }

    @Test("A path outside the root, or the root itself, stays absolute")
    func outside() {
        let base = URL(fileURLWithPath: "/Users/me/Dev/Swift", isDirectory: true)
        #expect(Discovery.relativePath(of: "/Users/me/Other/x", from: base) == "/Users/me/Other/x")
        #expect(Discovery.relativePath(of: "/Users/me/Dev/Swift", from: base) == "/Users/me/Dev/Swift")
        #expect(Discovery.relativePath(of: "/Users/me/Dev/SwiftExtra/x", from: base) == "/Users/me/Dev/SwiftExtra/x")
    }
}

@Suite("Infographic Writer Tests")
struct InfographicWriterTests {

    static func card(name: String) -> ProjectCard {
        ProjectCard(
            projectName: name, projectPath: "/p", gatheredAt: Date(timeIntervalSince1970: 1_700_000_000),
            git: GitFacts(commitCount: 12, releaseHistory: [], branchCount: 1,
                          firstCommitDate: Date(timeIntervalSince1970: 1_690_000_000),
                          latestCommitDate: Date(timeIntervalSince1970: 1_699_000_000), contributorCount: 1),
            packageManifest: nil, tests: nil, quality: nil, insights: nil, designArtifacts: nil)
    }

    @Test("Writes the three files the site layout requests, named by slug rather than project name")
    func writesByThreeNames() throws {
        let dir = try makeFixtureDirectory(prefix: "showcase-svg")
        let written = try InfographicWriter.write(card: Self.card(name: "SwiftOAuthCore"), slug: "swift-oauth", to: dir)
        #expect(written.map(\.lastPathComponent).sorted() ==
                ["swift-oauth-commits.svg", "swift-oauth-releases.svg", "swift-oauth-stats.svg"])
        for url in written {
            #expect(try String(contentsOf: url, encoding: .utf8).hasPrefix("<svg"))
        }
    }

    @Test("Creates the directory if it does not exist")
    func createsDirectory() throws {
        let dir = try makeFixtureDirectory(prefix: "showcase-svg").appendingPathComponent("nested/images")
        _ = try InfographicWriter.write(card: Self.card(name: "X"), slug: "x", to: dir)
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("x-stats.svg").path))
    }

    @Test("A slug that could leave the directory is refused and nothing is written")
    func refusesHostileSlug() throws {
        let dir = try makeFixtureDirectory(prefix: "showcase-svg")
        #expect(throws: ShowcaseError.self) {
            try InfographicWriter.write(card: Self.card(name: "X"), slug: "../escape", to: dir)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }

    @Test("Removing a page's infographics deletes those three files and leaves others alone")
    func removes() throws {
        let dir = try makeFixtureDirectory(prefix: "showcase-svg")
        _ = try InfographicWriter.write(card: Self.card(name: "A"), slug: "a", to: dir)
        _ = try InfographicWriter.write(card: Self.card(name: "B"), slug: "b", to: dir)
        try InfographicWriter.remove(slug: "a", from: dir)
        let left = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
        #expect(left == ["b-commits.svg", "b-releases.svg", "b-stats.svg"])
    }

    @Test("Removing a page that has no infographics is not an error")
    func removeMissing() throws {
        let dir = try makeFixtureDirectory(prefix: "showcase-svg")
        try InfographicWriter.remove(slug: "ghost", from: dir)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }
}

@Suite("Manifest Images Directory Tests")
struct ManifestImagesTests {

    @Test("imagesDirectory is optional, survives a round trip, and survives append and decline")
    func roundTrip() throws {
        let json = #"{"sourceRoot":"..","contentDirectory":"c","imagesDirectory":"Assets/images/showcase","entries":[]}"#
        let manifest = try SyncManifest.decode(from: Data(json.utf8))
        #expect(manifest.imagesDirectory == "Assets/images/showcase")
        #expect(manifest.appending([]).imagesDirectory == "Assets/images/showcase")
        #expect(manifest.declining(["x"]).imagesDirectory == "Assets/images/showcase")
        #expect(try SyncManifest.decode(from: try manifest.encoded()) == manifest)
    }

    @Test("A manifest without it has none, and encodes without the key")
    func absent() throws {
        let manifest = try SyncManifest.decode(from: Data(#"{"sourceRoot":"..","contentDirectory":"c","entries":[]}"#.utf8))
        #expect(manifest.imagesDirectory == nil)
        #expect(!String(decoding: try manifest.encoded(), as: UTF8.self).contains("imagesDirectory"))
    }
}
