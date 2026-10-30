//
//  SyncTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-10-29.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("Sync Manifest Tests")
struct SyncManifestTests {

    static let json = """
    {
      "sourceRoot": "..",
      "contentDirectory": "Content/showcase",
      "entries": [
        { "slug": "iconquercore", "path": "IconquerCore", "group": "iConquer",
          "tags": ["showcase", "iConquer"], "audience": "selfReflection", "style": "caseStudy" },
        { "slug": "tool", "path": "/abs/Tool", "audience": "hiringManager", "style": "deepDive" }
      ]
    }
    """

    @Test("Decodes entries with optional group, tags and name")
    func decodes() throws {
        let manifest = try SyncManifest.decode(from: Data(Self.json.utf8))
        #expect(manifest.entries.count == 2)
        #expect(manifest.entries[0].group == "iConquer")
        #expect(manifest.entries[0].tags == ["showcase", "iConquer"])
        #expect(manifest.entries[1].group == nil)
        #expect(manifest.entries[1].style == .deepDive)
    }

    @Test("Relative source paths resolve against sourceRoot, which resolves against the manifest")
    func resolvesRelative() throws {
        let manifest = try SyncManifest.decode(from: Data(Self.json.utf8))
        let manifestDir = URL(fileURLWithPath: "/work/site", isDirectory: true)
        #expect(manifest.sourceURL(for: manifest.entries[0], manifestDirectory: manifestDir).path == "/work/IconquerCore")
        #expect(manifest.sourceURL(for: manifest.entries[1], manifestDirectory: manifestDir).path == "/abs/Tool")
    }

    @Test("Duplicate slugs are rejected")
    func rejectsDuplicateSlugs() {
        let dup = """
        { "sourceRoot": ".", "contentDirectory": "c", "entries": [
          { "slug": "a", "path": "A", "audience": "client", "style": "caseStudy" },
          { "slug": "a", "path": "B", "audience": "client", "style": "caseStudy" } ] }
        """
        #expect(throws: ShowcaseError.self) { try SyncManifest.decode(from: Data(dup.utf8)) }
    }

    @Test("A slug that could escape the content directory is rejected")
    func rejectsTraversalSlug() {
        for bad in ["../x", "a/b", "", ".hidden"] {
            let doc = """
            { "sourceRoot": ".", "contentDirectory": "c", "entries": [
              { "slug": "\(bad)", "path": "A", "audience": "client", "style": "caseStudy" } ] }
            """
            #expect(throws: ShowcaseError.self, "slug '\(bad)'") { try SyncManifest.decode(from: Data(doc.utf8)) }
        }
    }

    @Test("An unknown audience fails the decode rather than defaulting")
    func rejectsUnknownAudience() {
        let doc = """
        { "sourceRoot": ".", "contentDirectory": "c", "entries": [
          { "slug": "a", "path": "A", "audience": "everyone", "style": "caseStudy" } ] }
        """
        #expect(throws: (any Error).self) { try SyncManifest.decode(from: Data(doc.utf8)) }
    }
}

@Suite("Sync Planner Tests")
struct SyncPlannerTests {

    static func entry(_ slug: String) -> SyncEntry {
        SyncEntry(slug: slug, path: slug, name: nil, group: nil, tags: nil, audience: .selfReflection, style: .caseStudy)
    }

    static let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("An entry with no record is stale as never generated")
    func neverGenerated() {
        let plan = SyncPlanner.plan(entries: [Self.entry("a")], heads: ["a": .success("111")], state: SyncState(), force: false)
        #expect(plan.first?.action == .regenerate(reason: .neverGenerated))
    }

    @Test("An unchanged head is current")
    func current() {
        var state = SyncState()
        state.records["a"] = SyncRecord(head: "111", generatedAt: Self.t0)
        let plan = SyncPlanner.plan(entries: [Self.entry("a")], heads: ["a": .success("111")], state: state, force: false)
        #expect(plan.first?.action == .skip(reason: .current))
    }

    @Test("A moved head regenerates and names both commits")
    func moved() {
        var state = SyncState()
        state.records["a"] = SyncRecord(head: "111", generatedAt: Self.t0)
        let plan = SyncPlanner.plan(entries: [Self.entry("a")], heads: ["a": .success("222")], state: state, force: false)
        #expect(plan.first?.action == .regenerate(reason: .sourceMoved(from: "111", to: "222")))
    }

    @Test("force regenerates a current entry")
    func forced() {
        var state = SyncState()
        state.records["a"] = SyncRecord(head: "111", generatedAt: Self.t0)
        let plan = SyncPlanner.plan(entries: [Self.entry("a")], heads: ["a": .success("111")], state: state, force: true)
        #expect(plan.first?.action == .regenerate(reason: .forced))
    }

    @Test("An unreadable source is reported, never regenerated from nothing")
    func unavailable() {
        let plan = SyncPlanner.plan(entries: [Self.entry("a")], heads: ["a": .failure("not a git repository")], state: SyncState(), force: true)
        #expect(plan.first?.action == .skip(reason: .sourceUnavailable("not a git repository")))
    }

    @Test("A missing head lookup is treated as unavailable")
    func missingHead() {
        let plan = SyncPlanner.plan(entries: [Self.entry("a")], heads: [:], state: SyncState(), force: false)
        #expect(plan.first?.action == .skip(reason: .sourceUnavailable("no head resolved")))
    }

    @Test("Plan preserves manifest order")
    func order() {
        let heads: [String: HeadLookup] = ["b": .success("1"), "a": .success("1")]
        let plan = SyncPlanner.plan(entries: [Self.entry("b"), Self.entry("a")], heads: heads, state: SyncState(), force: false)
        #expect(plan.map(\.entry.slug) == ["b", "a"])
    }
}

@Suite("Sync State Tests")
struct SyncStateTests {

    @Test("A missing state file is an empty state")
    func missingFile() throws {
        let dir = try makeFixtureDirectory(prefix: "showcase-state")
        let state = try SyncState.load(from: dir.appendingPathComponent("absent.json"))
        #expect(state.records.isEmpty)
    }

    @Test("State round-trips through disk")
    func roundTrip() throws {
        let dir = try makeFixtureDirectory(prefix: "showcase-state")
        let file = dir.appendingPathComponent("state.json")
        var state = SyncState()
        state.records["a"] = SyncRecord(head: "abc", generatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        try state.save(to: file)
        let loaded = try SyncState.load(from: file)
        #expect(loaded.records["a"]?.head == "abc")
    }

    @Test("A corrupt state file throws instead of silently resetting")
    func corrupt() throws {
        let dir = try makeFixtureDirectory(prefix: "showcase-state")
        let file = dir.appendingPathComponent("state.json")
        try writeFixtureFile("{ not json", named: "state.json", in: dir)
        #expect(throws: (any Error).self) { try SyncState.load(from: file) }
    }
}

@Suite("Git Head Tests")
struct GitHeadTests {

    @Test("Resolves the full commit id of a repository")
    func resolves() throws {
        let dir = try makeFixtureDirectory(prefix: "showcase-head")
        try runGit(["init", "-q"], in: dir)
        try writeFixtureFile("x", named: "f.txt", in: dir)
        try runGit(["add", "."], in: dir)
        try runGit(["commit", "-q", "-m", "one"], in: dir)
        let head = try GitHead.resolve(at: dir)
        #expect(head.count == 40)
    }

    @Test("A directory that is not a repository throws")
    func notARepo() throws {
        let dir = try makeFixtureDirectory(prefix: "showcase-head")
        #expect(throws: ShowcaseError.self) { try GitHead.resolve(at: dir) }
    }
}

@Suite("MarkdownRenderer Sync Overrides")
struct MarkdownRendererOverrideTests {

    @Test("A group label and tag list override the derived values")
    func overrides() throws {
        let output = try MarkdownRenderer().render(
            narrative: MarkdownRendererTests.sampleNarrative,
            projectLabel: "iConquer",
            tags: ["showcase", "iConquer", "selfReflection"]
        )
        #expect(output.contains("project: iConquer\n"))
        #expect(output.contains("tags: showcase, iConquer, selfReflection\n"))
        #expect(!output.contains("project: BusinessMath"))
    }

    @Test("A slug override names the file, and a hostile slug cannot leave the directory")
    func slugOverride() throws {
        let dir = try makeFixtureDirectory(prefix: "showcase-slug")
        let url = try MarkdownRenderer().renderToFile(
            narrative: MarkdownRendererTests.sampleNarrative, outputDirectory: dir, slug: "iconquercore")
        #expect(url.lastPathComponent == "iconquercore.md")
        #expect(throws: ShowcaseError.self) {
            try MarkdownRenderer().renderToFile(
                narrative: MarkdownRendererTests.sampleNarrative, outputDirectory: dir, slug: "../escape")
        }
    }

    @Test("Defaults are unchanged when no override is given")
    func defaultsUnchanged() throws {
        let output = try MarkdownRenderer().render(narrative: MarkdownRendererTests.sampleNarrative)
        #expect(output.contains("project: BusinessMath\n"))
        #expect(output.contains("tags: showcase, project, businessmath, hiringManager\n"))
    }
}

@Suite("ProjectCard Rename Tests")
struct ProjectCardRenameTests {
    @Test("renamed(to:) changes only the name")
    func renames() {
        let card = ProjectCard(
            projectName: "IconquerCore", projectPath: "/p", gatheredAt: Date(timeIntervalSince1970: 0),
            git: GitFacts(commitCount: 3, releaseHistory: [], branchCount: 1, firstCommitDate: nil, latestCommitDate: nil, contributorCount: 1),
            packageManifest: nil, tests: nil, quality: nil, insights: nil, designArtifacts: nil)
        let renamed = card.renamed(to: "iConquer Core")
        #expect(renamed.projectName == "iConquer Core")
        #expect(renamed.projectPath == "/p")
        #expect(renamed.git.commitCount == 3)
    }
}

@Suite("Sync Grounding Guard Tests")
struct SyncGroundingTests {

    static func card(description: String?) -> ProjectCard {
        ProjectCard(
            projectName: "X", projectPath: "/p", gatheredAt: Date(timeIntervalSince1970: 0),
            git: GitFacts(commitCount: 1, releaseHistory: [], branchCount: 1, firstCommitDate: nil, latestCommitDate: nil, contributorCount: 1),
            packageManifest: nil, tests: nil, quality: nil, insights: nil,
            designArtifacts: DesignArtifactFacts(
                designProposalCount: 0, architectureNotes: [],
                hasDesignFirstWorkflow: false, hasClaudeMD: true, projectDescription: description))
    }

    @Test("A card with a project description is grounded")
    func grounded() {
        #expect(SyncPlanner.isGrounded(Self.card(description: "Mission: a thing")))
    }

    @Test("A card without one is not, so a published page is not replaced by a guess")
    func ungrounded() {
        #expect(!SyncPlanner.isGrounded(Self.card(description: nil)))
        #expect(!SyncPlanner.isGrounded(Self.card(description: "  \n")))
    }

    @Test("A card with no design artifacts at all is not grounded")
    func noArtifacts() {
        let bare = ProjectCard(
            projectName: "X", projectPath: "/p", gatheredAt: Date(timeIntervalSince1970: 0),
            git: GitFacts(commitCount: 1, releaseHistory: [], branchCount: 1, firstCommitDate: nil, latestCommitDate: nil, contributorCount: 1),
            packageManifest: nil, tests: nil, quality: nil, insights: nil, designArtifacts: nil)
        #expect(!SyncPlanner.isGrounded(bare))
    }
}

@Suite("Sync Date Preservation Tests")
struct SyncDatePreservationTests {

    @Test("The original publication date survives a regeneration, lastModified does not")
    func preservesDate() throws {
        let output = try MarkdownRenderer().render(
            narrative: MarkdownRendererTests.sampleNarrative,
            publishedDate: "2026-05-13 15:57")
        #expect(output.contains("date: 2026-05-13 15:57\n"))
        #expect(output.contains("lastModified: 2023-11-14\n"))
        #expect(!output.contains("date: 2023-11-14"))
    }

    @Test("Reads the date line from existing frontmatter")
    func readsDate() {
        let page = "---\ntitle: X\ndate: 2026-05-13 15:57\nlastModified: 2026-05-13\n---\n\nbody\ndate: not this\n"
        #expect(FrontmatterReader.value(for: "date", in: page) == "2026-05-13 15:57")
    }

    @Test("A key that is only in the body, or absent, reads as nil")
    func ignoresBody() {
        let page = "---\ntitle: X\n---\n\ndate: 2020-01-01\n"
        #expect(FrontmatterReader.value(for: "date", in: page) == nil)
        #expect(FrontmatterReader.value(for: "date", in: "no frontmatter") == nil)
    }
}
