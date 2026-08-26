# ProjectShowcase Master Plan

**Purpose:** Source of truth for project vision, architecture, and goals.

---

## Project Overview

### Mission
Extract structured facts from developer projects — git history, package manifests, test results, design artifacts, and Claude Code usage data — and generate narrative case-study portfolios with SVG infographics. The tool scans design documents (MASTER_PLAN.md, CLAUDE.md, design proposals) to capture the motivation and architectural reasoning behind each project, not just its metrics. This bridges the gap between "my projects exist on GitHub" and "here is a coherent developer portfolio that tells the story of each project," turning artifacts that already exist into prose a technical reader would care about.

### Target Users
- **Solo developers** maintaining multiple projects who want a portfolio site without manual writing
- **Job seekers** who need to present their work as narrative case studies for hiring managers
- **Open-source maintainers** who want richer project pages than a README alone provides

### Key Differentiators
- **Fact-grounded narratives**: Every claim in the generated prose is backed by extracted data (commit counts, test coverage, release history) — the model cannot fabricate capabilities
- **Three-stage pipeline with independent stages**: Gather is local-only (no API calls), Narrate is the only LLM-dependent step, Render is deterministic — users can inspect and edit at any stage
- **Language-agnostic extraction**: Built in Swift but analyzes any git repository; pluggable extractors for Swift, Node, Python, Rust, and Go projects
- **MASTER_PLAN.md grounding**: When a project carries its own mission statement (Mission, Target Users, Key Differentiators), the narrative uses it as authoritative context instead of inferring (and potentially hallucinating) the project's purpose
- **Design artifact scanning**: The `DesignDocExtractor` reads CLAUDE.md, development-guidelines, design proposals, and architecture notes to provide richer narrative context — capturing not just what a project does, but why it was built and what design decisions shaped it
- **Self-contained SVG infographics**: Stats cards, commit timelines, and release timelines generated as dependency-free SVGs ready for any web page

---

## Architecture

### Technology Stack
- **Language:** Swift 5.9+ (macOS 13+), strict concurrency enabled
- **Frameworks:** swift-argument-parser (CLI), Foundation (networking, file I/O, Process — spawns confined to `ProcessRunner`)
- **Build System:** Swift Package Manager
- **Testing:** Swift Testing framework (@Test, #expect)
- **API:** Anthropic Claude REST API via Foundation URLSession (no SDK dependency)

### Module Structure

```
ProjectShowcase/
├── Sources/
│   ├── ProjectShowcase/          # Library target
│   │   ├── Gathering/
│   │   │   ├── FactGatherer.swift
│   │   │   └── Sources/
│   │   │       ├── GitExtractor.swift
│   │   │       ├── DesignDocExtractor.swift
│   │   │       ├── InsightsExtractor.swift
│   │   │       ├── TestOutputParser.swift
│   │   │       └── PackageManifest/
│   │   │           ├── PackageExtractor.swift (protocol)
│   │   │           ├── SwiftPackageExtractor.swift
│   │   │           ├── NodePackageExtractor.swift
│   │   │           ├── PythonPackageExtractor.swift
│   │   │           └── CargoExtractor.swift
│   │   ├── Models/
│   │   │   ├── ProjectCard.swift
│   │   │   ├── GitFacts.swift
│   │   │   ├── PackageManifestFacts.swift
│   │   │   ├── TestFacts.swift
│   │   │   ├── InsightsSummary.swift
│   │   │   ├── DesignArtifactFacts.swift
│   │   │   ├── NarrativeResult.swift
│   │   │   ├── Enums.swift
│   │   │   └── ShowcaseError.swift
│   │   ├── Narration/
│   │   │   ├── PromptBuilder.swift
│   │   │   ├── PortfolioPromptBuilder.swift
│   │   │   ├── NarrativeGenerator.swift
│   │   │   └── NarrativeResponseParser.swift
│   │   ├── Rendering/
│   │   │   ├── MarkdownRenderer.swift
│   │   │   ├── InfographicGenerator.swift (protocol)
│   │   │   ├── StatsCardGenerator.swift
│   │   │   ├── CommitTimelineGenerator.swift
│   │   │   └── ReleaseTimelineGenerator.swift
│   │   ├── Support/
│   │   │   └── ProcessRunner.swift    # the package's only subprocess spawn site
│   │   └── ProjectShowcase.docc/      # DocC catalogue (excluded from the target's sources)
│   └── ShowcaseCLI/              # Executable target
│       ├── ShowcaseCLI.swift
│       ├── GatherCommand.swift
│       ├── NarrateCommand.swift
│       ├── RenderCommand.swift
│       ├── RefreshCommand.swift
│       ├── PortfolioCommand.swift
│       └── InfographicsCommand.swift
├── Tests/
│   └── ProjectShowcaseTests/     # 128 tests across 17 suites
└── Package.swift
```

### Key Types

| Type | Purpose |
|------|---------|
| `ProjectCard` | Central Codable struct aggregating all gathered facts about a project |
| `FactGatherer` | Orchestrates all extractors against a project directory |
| `GitFacts` | Commit count, branches, contributors, releases, date range |
| `PackageManifestFacts` | Language, dependencies, targets, platforms, tools version |
| `DesignArtifactFacts` | Design doc counts, CLAUDE.md presence, MASTER_PLAN.md description |
| `InsightsSummary` | Claude Code session patterns, friction categories, tool usage |
| `TestFacts` | Test count, suite count, pass rate from parsed test output |
| `NarrativeResult` | Generated narrative with title, summary, body, sections, metadata |
| `PromptBuilder` | Constructs audience- and style-targeted prompts from a ProjectCard |
| `PortfolioPromptBuilder` | Constructs cross-project portfolio prompts from multiple cards |
| `NarrativeGenerator` | Claude API client that sends prompts and parses responses |
| `MarkdownRenderer` | Converts NarrativeResult to YAML frontmatter + markdown body |
| `InfographicGenerator` | Protocol for SVG generators (stats card, commit timeline, release timeline) |
| `ShowcaseError` | Single error enum for all failure modes across the pipeline |
| `PackageExtractor` | Protocol for language-specific manifest parsers |
| `ProcessRunner` | The package's only subprocess spawn site: bounds each run with a watchdog and captures output through files |
| `ProcessResult` | A finished child's exit status and captured `stdout` / `stderr` |

---

## Current Status

### What's Working
- [x] Git extraction (commits, branches, contributors, releases, date range)
- [x] Swift Package.swift extraction
- [x] Node package.json extraction
- [x] Python pyproject.toml / setup.py extraction
- [x] Rust Cargo.toml extraction
- [x] Design doc extraction (CLAUDE.md, proposals, MASTER_PLAN.md)
- [x] Claude Code insights extraction (sessions, friction, tool usage)
- [x] Test output parsing (Swift Testing + XCTest)
- [x] Narrative generation via Claude API (4 audiences, 3 styles)
- [x] Cross-project portfolio generation
- [x] Markdown rendering with Ignite-compatible YAML frontmatter
- [x] SVG infographic generation (stats card, commit timeline, release timeline)
- [x] Default subcommand (`refresh`) for streamlined CLI usage
- [x] MASTER_PLAN.md grounding to prevent narrative hallucination
- [x] Bounded subprocess kernel (`ProcessRunner`) — every spawn in the package goes through it
- [ ] GenericExtractor (fallback file counting, language detection for non-manifest projects)
- [ ] MCP server wrapper
- [ ] Narrative caching (keyed by ProjectCard hash)
- [ ] HTML standalone output

### Known Issues
- Claude Code insights schema is undocumented and may change without notice — extraction is optional and degrades gracefully
- Narrative quality varies by project complexity; sparse projects (few commits, no tests) produce generic output
- `git shortlog` hangs when stdin is a TTY; `ProcessRunner` sets `FileHandle.nullDevice` for every child, so this is now handled in one place rather than per call site

### Current Priorities
1. Fill in MASTER_PLAN.md descriptions for remaining projects (19 of 30 still lack authoritative descriptions)
2. GenericExtractor for projects without package manifests
3. Narrative caching to avoid redundant API calls on re-runs

---

## Collaboration Principles

### AI as Sparring Partner, Not Oracle

AI proposes; the human interrogates. High AI confidence triggers harder questions, not faster acceptance.

- **Interrogate confident outputs.** When the AI states something with certainty, ask for the counterargument before accepting.
- **Demand counterarguments.** Before locking in an approach, require an explicit case for the strongest alternative.
- **Sit with discomfort.** Resist the pull to take the first plausible answer. Working through a hard call manually preserves the judgment that lets you catch the AI when it's wrong.

This principle is operationalized in the **Adversarial Review** step of `design_proposal.md` and is the canonical reference for any other doc that invokes it.

---

## Quality Standards

### Code Quality
- All code follows `coding_rules.md`
- 128 tests across 17 suites covering all extractors, models, narration, rendering, subprocess spawning, and integration
- Documentation for all public APIs
- No warnings in build output
- Strict concurrency enabled (StrictConcurrency upcoming feature flag)

### Documentation Quality
- README with pipeline diagram, command reference, and architecture tree
- Man page auto-generated via swift-argument-parser
- Tutorial and blog post for end-user onboarding

---

## Error Registry

> **Purpose:** Single source of truth for all error types in the project. Consult this
> registry during the Design Proposal Phase to ensure new error cases don't duplicate
> existing ones. Update it whenever new error types are introduced.

### Error Types

| Error Enum | Case | When Thrown | Module |
|------------|------|------------|--------|
| `ShowcaseError` | `.notAGitRepository(path:)` | Target directory has no `.git` folder | Gathering |
| `ShowcaseError` | `.extractionFailed(source:, message:)` | An extractor encounters an unrecoverable error | Gathering |
| `ShowcaseError` | `.narrativeGenerationFailed(message:)` | Claude API call fails or returns unparseable response | Narration |
| `ShowcaseError` | `.renderingFailed(message:)` | File write or template rendering fails | Rendering |
| `ShowcaseError` | `.invalidConfiguration(message:)` | Missing API key, invalid audience/style, bad file path, non-positive process timeout | CLI |
| `ShowcaseError` | `.processTimedOut(executable:, seconds:)` | A child process outlives the deadline `ProcessRunner` gave it | Support |

### Error Design Principles

- **One error enum per domain boundary** — `ShowcaseError` covers the entire library
- **Descriptive associated values** — include context (path, source name, API message)
- **No overlapping cases** — each case maps to a distinct failure mode in the pipeline
- **Consult this registry** before creating new error cases in a Design Proposal

---

## Roadmap

### Phase 1: CLI (COMPLETE)
- [x] Fact gathering pipeline with 8 extractors
- [x] Narrative generation with audience/style targeting
- [x] Markdown rendering with SSG-compatible frontmatter
- [x] SVG infographic generation (3 generators)
- [x] Cross-project portfolio overview
- [x] MASTER_PLAN.md grounding for narrative accuracy
- [x] 128 tests, CI-ready

### Phase 2: Hardening
- [ ] GenericExtractor for non-manifest projects (file counting, language detection)
- [ ] Narrative caching keyed by ProjectCard content hash
- [ ] Go module extraction (go.mod)
- [ ] Richer infographics (dependency graph, test coverage trend)

### Phase 3: MCP Server
- [ ] Wrap Gathering and Narration modules in MCP tool/resource handlers
- [ ] Expose `gather_facts`, `generate_narrative`, `refresh_portfolio` as MCP tools
- [ ] Enable Claude Code to generate portfolio pages conversationally

### Future Considerations
- Freemium monetization: gather/render free, narrate Stripe-gated
- HTML standalone output for non-SSG users
- GitHub Actions integration for automated portfolio updates on push
- Multi-language narrative generation

---

**Last Updated:** 2026-08-25 — reconciled test counts (119 → 128), recorded the `ProcessRunner`
subprocess kernel in Current Status and the Error Registry, and updated the `git shortlog` known
issue now that stdin handling lives in one place.
