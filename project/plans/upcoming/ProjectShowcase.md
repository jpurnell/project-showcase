# Design Proposal: ProjectShowcase

## 1. Objective

**Objective:** Build a **language-agnostic** CLI tool (evolving to MCP server) that extracts structured facts from developer projects and Claude Code usage data, then generates narrative case-study portfolios as generic markdown + graphic artifacts suitable for any static site generator.

The tool solves a gap in the developer productivity landscape: existing metrics (commits, tokens, lines) measure throughput, while existing portfolios (GitHub profiles, resumes) list claims. Nothing currently captures **craft trajectory** — the ability to take an ambiguous problem, design an architecture, ship a tested product, and iterate. ProjectShowcase bridges structured data with narrative storytelling, backed by verifiable artifacts.

**Language scope:** The tool is built in Swift but operates on any project with a git repository. Language-specific extractors (Swift Package.swift, Node package.json, Python pyproject.toml, Cargo.toml, etc.) are pluggable — git and Claude Code insights extraction work universally.

**Business Model:** Freemium. Gathering and rendering are free (local-only, no API calls). Narrative generation is the paid tier (Stripe-gated API key), since it consumes Claude API tokens. This maps costs directly to value: the LLM narrative is the differentiating product.

## 2. Proposed Architecture

### Phase 1: CLI (`project-showcase`)

```
Sources/ProjectShowcase/
├── CLI/
│   ├── main.swift                    — CLI entry point (ArgumentParser)
│   └── Commands/
│       ├── GatherCommand.swift       — `showcase gather <path>`
│       ├── NarrateCommand.swift      — `showcase narrate <card>`
│       ├── RenderCommand.swift       — `showcase render <narrative>`
│       ├── RefreshCommand.swift      — `showcase refresh <path>`
│       └── PortfolioCommand.swift    — `showcase portfolio <paths...>`
├── Gathering/
│   ├── FactGatherer.swift            — Orchestrates all source extractors
│   ├── Sources/
│   │   ├── GitExtractor.swift        — Commit history, releases, branches (universal)
│   │   ├── InsightsExtractor.swift   — Claude Code facets + session-meta (universal)
│   │   ├── DesignDocExtractor.swift  — CLAUDE.md, proposals, architecture docs (universal)
│   │   ├── TestOutputParser.swift    — Parse test results from stdout (universal)
│   │   └── PackageManifest/
│   │       ├── PackageExtractor.swift      — Protocol for language-specific manifests
│   │       ├── SwiftPackageExtractor.swift  — Package.swift
│   │       ├── NodePackageExtractor.swift   — package.json
│   │       ├── PythonPackageExtractor.swift — pyproject.toml / setup.py
│   │       ├── CargoExtractor.swift         — Cargo.toml
│   │       └── GenericExtractor.swift       — Fallback: file counting, language detection
│   └── ProjectCard.swift             — Codable model for all gathered facts
├── Narration/
│   ├── NarrativeGenerator.swift      — Claude API integration for story gen
│   ├── PromptTemplates/
│   │   ├── CaseStudyTemplate.swift   — Full case study narrative
│   │   ├── ProjectCardTemplate.swift — Short-form project card
│   │   └── PortfolioTemplate.swift   — Multi-project overview
│   └── NarrativeResult.swift         — Codable model for generated narrative
├── Rendering/
│   ├── MarkdownRenderer.swift        — Generic .md with YAML frontmatter (works with any SSG)
│   ├── HTMLRenderer.swift            — Standalone HTML output
│   ├── InfographicGenerator.swift    — SVG chart artifacts (commit timeline, test growth, etc.)
│   └── PortfolioRenderer.swift       — Cross-project portfolio overview page
└── Models/
    ├── ProjectCard.swift             — All gathered facts (Codable, Sendable)
    ├── NarrativeResult.swift         — Generated narrative + metadata
    └── ShowcaseConfig.swift          — User preferences, API keys, output format
```

### Phase 2: MCP Server (future)

Wraps the same core logic in MCP tool/resource handlers. The `Gathering/` and `Narration/` modules remain unchanged — only the interface layer changes from CLI to MCP.

**Modified Files:** None (new project)

**Module Placement:** `Sources/ProjectShowcase/` (single target initially)

## 3. API Surface

### CLI Interface

```bash
# Gather facts from a project directory → JSON project card
showcase gather ~/Projects/BusinessMath --output card.json

# Generate narrative from project card → narrative JSON
showcase narrate card.json --audience hiring-manager --style case-study

# Render narrative to output format (.md + SVG infographics)
showcase render narrative.json --format markdown --output ~/site/Content/

# All-in-one: gather + narrate + render
showcase refresh ~/Projects/BusinessMath --format markdown --output ~/site/Content/

# Generate cross-project portfolio overview from multiple cards
showcase portfolio ~/Projects/BusinessMath ~/Projects/quality-gate-swift ~/Projects/SwiftMCPServer --output ~/site/Content/portfolio/
```

### Programmatic API

```swift
public struct FactGatherer: Sendable {
    public init()
    public func gather(from projectPath: URL) async throws -> ProjectCard
}

public struct NarrativeGenerator: Sendable {
    public init(apiKey: String, model: String = "claude-sonnet-4-6")
    public func generate(
        card: ProjectCard,
        audience: Audience,
        style: NarrativeStyle,
        priorNarrative: NarrativeResult? = nil
    ) async throws -> NarrativeResult
}

public struct ShowcaseRenderer: Sendable {
    public init()
    public func render(
        narrative: NarrativeResult,
        format: OutputFormat,
        outputDirectory: URL
    ) throws
}

public struct PortfolioGenerator: Sendable {
    public init(apiKey: String, model: String = "claude-sonnet-4-6")
    /// Synthesizes cross-project traits and themes from multiple cards.
    /// Produces a portfolio overview that highlights cross-project patterns
    /// (design discipline, test rigor, domain breadth) and links to
    /// individual project case study pages for detail.
    public func generate(
        cards: [ProjectCard],
        audience: Audience
    ) async throws -> NarrativeResult
}
```

### Key Types

```swift
public struct ProjectCard: Codable, Sendable {
    public let projectName: String
    public let projectPath: String
    public let gatheredAt: Date

    // Git
    public let commitCount: Int
    public let releaseHistory: [Release]
    public let branchCount: Int
    public let firstCommitDate: Date?
    public let latestCommitDate: Date?
    public let contributorCount: Int

    // Package
    public let swiftToolsVersion: String?
    public let dependencies: [Dependency]
    public let targets: [Target]
    public let platforms: [String]

    // Tests
    public let testCount: Int
    public let suiteCount: Int
    public let passRate: Double?

    // Quality
    public let qualityGateViolations: Int?
    public let checkerCategories: [String: Int]?

    // Claude Code Insights (optional — only if insights data exists)
    public let insights: InsightsSummary?

    // Design Artifacts
    public let designProposalCount: Int
    public let architectureNotes: [String]
    public let hasDesignFirstWorkflow: Bool
}

public struct InsightsSummary: Codable, Sendable {
    public let sessionCount: Int
    public let totalCommits: Int
    public let totalMessages: Int
    public let frictionCategories: [String: Int]
    public let outcomeDistribution: [String: Int]
    public let toolUsageProfile: [String: Int]
    public let sessionTypes: [String: Int]
}

public enum Audience: String, Codable, Sendable {
    case hiringManager
    case openSourceContributor
    case client
    case selfReflection
}

public enum NarrativeStyle: String, Codable, Sendable {
    case caseStudy       // Full arc: problem → design → ship → results
    case projectCard     // Short-form: 1-2 paragraphs + key stats
    case deepDive        // Technical deep-dive for practitioners
}

public enum OutputFormat: String, Codable, Sendable {
    case markdown        // Generic .md with YAML frontmatter (any SSG)
    case html            // Standalone HTML
    case json            // Raw structured data
}
// Note: Markdown output uses standard YAML frontmatter compatible with
// Jekyll, Hugo, Astro, Eleventy, Ignite, Publish, and most other SSGs.
```

## 4. MCP Schema

**Tool Description:** Gather structured facts from a software project and generate a narrative portfolio entry.

**REQUIRED STRUCTURE (JSON):**

```json
{
  "tool": "gather_facts",
  "input": {
    "project_path": "/Users/jpurnell/Projects/BusinessMath"
  }
}
```

```json
{
  "tool": "generate_narrative",
  "input": {
    "project_name": "BusinessMath",
    "audience": "hiring_manager",
    "style": "case_study",
    "format": "ignite"
  }
}
```

```json
{
  "tool": "refresh_portfolio",
  "input": {
    "projects": [
      "/Users/jpurnell/Projects/BusinessMath",
      "/Users/jpurnell/Projects/quality-gate-swift"
    ],
    "format": "ignite",
    "output_directory": "~/site/Content/portfolio/"
  }
}
```

**Parameter Types:**
- project_path (string): Absolute path to project directory. Must contain a `.git` directory.
- audience (string): One of `"hiring_manager"`, `"open_source_contributor"`, `"client"`, `"self_reflection"`.
- style (string): One of `"case_study"`, `"project_card"`, `"deep_dive"`.
- format (string): One of `"markdown"`, `"html"`, `"json"`.
- output_directory (string): Where to write rendered files.

## 5. Constraints & Compliance

**Concurrency:** All core types (ProjectCard, NarrativeResult, InsightsSummary) are Sendable value types. File I/O and API calls use async/await.

**Safety:** No force unwraps. All file reads guarded with existence checks. API failures throw descriptive errors.

**Generics:** Not applicable — this is a tooling project, not a numerics library. Types are concrete.

**Privacy:** The `gather_facts` step never transmits data externally. Only `generate_narrative` calls the Claude API, and only with the structured ProjectCard (no raw source code sent). Users control what gets included via config.

**API Key Management:** Claude API key read from environment variable `ANTHROPIC_API_KEY` or config file. Never hardcoded, never logged.

## 6. Backend Abstraction (If Compute-Intensive)

Not applicable. This is an I/O-bound tool (file reads + API calls), not compute-intensive.

## 7. Dependencies

**Internal Dependencies:** None (new project)

**External Dependencies:**
- `swift-argument-parser` — CLI framework
- `@anthropic-ai/sdk` equivalent for Swift (or raw HTTP via Foundation) — Claude API calls
- `swift-markdown` (Apple) — Markdown generation/parsing (optional, for Ignite output)

**No dependency on BusinessMath or quality-gate-swift.** This tool reads their artifacts but does not import them.

## 8. Test Strategy

**Test Categories:**

- **Extractors (unit):** Feed known git repos / Package.swift / test output → verify ProjectCard fields
  - Golden path: Real project with all data sources present
  - Edge cases: Empty repo, no tests, no Package.swift, no insights data
  - Missing data: Graceful degradation when optional sources are absent

- **Narrative generation (integration):** Verify prompt construction and response parsing
  - Golden path: Full ProjectCard → well-formed narrative
  - Edge cases: Minimal card (just git data) → still produces coherent output
  - Determinism: Same card + same seed → same narrative structure

- **Rendering (unit):** Verify output format correctness
  - Markdown: Valid YAML frontmatter, correct date format, proper markdown body
  - SVG infographics: Valid SVG, correct data points, renders without errors
  - HTML: Valid HTML5, includes structured data (JSON-LD/OpenGraph)
  - JSON: Valid, matches schema
  - Portfolio: Cross-project themes extracted, no repetitive per-project summaries

- **End-to-end:** Run `refresh` on a known test fixture repo → verify rendered output

**Reference Truth:**
- Git extraction: Verified against `git log --format` output for a known test repo
- Package extraction: Verified against manual Package.swift inspection
- Insights extraction: Verified against known facet/session-meta JSON files
- Rendering: Ignite frontmatter validated against Ignite's actual parser

**Validation Trace (REQUIRED):**
- "Given a repo with 150 commits, 3 releases, 500 tests → ProjectCard.commitCount == 150, releaseHistory.count == 3, testCount == 500"
- "Given a ProjectCard with all fields populated → output .md contains `---` YAML frontmatter block with `title`, `date`, `tags` keys"

## 9. Architecture Decision Review

**ADR Check:**
- [x] Reviewed — no existing ADRs (new project)
- [ ] Does this supersede an existing ADR? No
- [ ] Does this amend an existing ADR? No
- [x] New ADR required? Yes → draft below

**New ADR Draft:**
- **Title:** CLI-First, MCP-Second Architecture
- **Category:** architecture
- **Key decision:** Build as a Swift CLI with clean module boundaries so the same `Gathering/` and `Narration/` code can be wrapped in an MCP server without refactoring. The CLI is the MVP; the MCP server is the monetization path.

**New ADR Draft:**
- **Title:** Structured Facts Separated from Narrative Generation
- **Category:** architecture
- **Key decision:** The `gather` step is deterministic and local (no API calls). The `narrate` step is the only LLM-dependent operation. This separation means users can inspect/edit the ProjectCard before narrative generation, and the gather step works offline.

## 10. Adversarial Review

**Strongest case for a different approach:**
- A reviewer might argue this should be a **TypeScript/Node.js project** since (a) the MCP ecosystem is predominantly JS, (b) the Anthropic SDK has first-class TypeScript support, and (c) the target audience is language-agnostic developers, not just Swift practitioners. Counter: we already have SwiftMCPServer infrastructure, the CLI is language-agnostic in what it analyzes (git, file counting, Claude Code insights all work on any repo), and building in Swift dogfoods our own toolchain. The MCP phase can reuse our existing server framework.

**Where this design is most likely wrong:**
- The assumption that **Claude Code insights data has a stable schema**. The facets and session-meta JSON formats are undocumented internal formats. If Anthropic changes them, the InsightsExtractor breaks silently. The mitigation is to make insights extraction optional and version-aware.
- The assumption that **narrative quality is good enough to publish without editing**. Early versions will likely produce generic text that needs human refinement. The design should treat generated narratives as drafts, not final copy.

**What an experienced critic would say:**
"You're building a tool that depends on an undocumented, local-only data format (Claude Code insights) for its most differentiating feature — that's fragile." We're proceeding because (a) insights are optional enrichment, not required, (b) the core value (git + tests + design docs → narrative) works without insights, and (c) if Anthropic stabilizes the format or adds an API, we're positioned to adopt it.

## 11. Open Questions

### Resolved

2. ~~**SSG integration:**~~ **RESOLVED → Generic markdown.** Output standard .md with YAML frontmatter + SVG infographic artifacts. Works with any SSG (Ignite, Hugo, Jekyll, Astro, Eleventy, Publish). No SSG-specific code generation.
3. ~~**Monetization model:**~~ **RESOLVED → Freemium with Stripe.** Gather and render are free. Narrate requires a Stripe-gated API key. Stripe is more robust long-term than crypto-based alternatives.
4. ~~**Narrative caching:**~~ **RESOLVED → Yes.** Cache narratives keyed by ProjectCard hash. Only regenerate when facts change.
5. ~~**Multi-project portfolio:**~~ **RESOLVED → Both.** Individual project case study pages for each project (the detailed "what and why" of a specific effort), plus a portfolio overview page that synthesizes cross-project themes and traits (design discipline, test coverage patterns, breadth vs depth, shipping cadence). The portfolio page speaks to the developer; the project pages speak to the work.

### Open

1. **Claude API in Swift:** Should we use raw Foundation URLSession against the Anthropic REST API, or is there a maintained Swift SDK? We already have SwiftMCPServer (`/Users/jpurnell/Dropbox/Computer/Development/Swift/Tools/SwiftMCPServer`) — check if it includes API client code we can reuse.
6. **Language detection heuristic:** For non-manifest projects (no Package.swift, package.json, etc.), how do we detect the primary language? Options: GitHub Linguist-style file extension counting, or rely on git attributes.
7. **Infographic format:** SVG (universal, scalable, git-friendly) vs PNG (simpler rendering, wider compatibility in older SSGs). Leaning SVG.
8. **Portfolio trait extraction:** When synthesizing 18+ projects into a portfolio page, what traits to extract? Candidates: design-first workflow adoption, test discipline, language breadth, shipping cadence, domain diversity. Need to validate these don't become vanity metrics.

## 12. Documentation Strategy

**Documentation Type:** Narrative Article Required

**Complexity Threshold Check:**
- Does it combine 3+ APIs? Yes (gather, narrate, render)
- Does explanation require 50+ lines? Yes
- Does it need theory/background context? Yes (why narratives > metrics)

**Article Name:** GettingStartedGuide.md
