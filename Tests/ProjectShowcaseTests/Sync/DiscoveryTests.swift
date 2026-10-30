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
