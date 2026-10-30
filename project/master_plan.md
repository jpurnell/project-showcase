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
│   └── ProjectShowcaseTests/     # 213 tests across 42 suites
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
- [x] `showcase sync`: manifest-driven regeneration of only the pages whose source repo moved (2026-10-30). Shipped ahead of the Roadmap's "GitHub Actions integration" idea, as a local launchd job instead, because the source repos are private and hosted macOS is billed 10x
- [x] `showcase discover`: proposes new pages from public, owned, active, plan-bearing repos, five per run (2026-10-30). The manifest was previously only the 28 pages the May batch happened to produce
- [x] Approve step: new pages from `discover` wait for a person (dialog, local preview, approve / decline); declined slugs are remembered
- [x] Infographics: `sync` writes each regenerated page's three SVGs, named by slug; `sync --infographics-only` refreshes all of them without an API key
- [x] Editorial fields survive regeneration: `date:`, tags, `project:` group and `published:` (an explicit `false` stays false)
- [x] Master plans written for the five repos that had none; the pages regenerated from them (website PR #2, awaiting review)
- [x] Grounding guard: `sync` will not replace a published page with a narrative the card cannot ground
- [ ] GenericExtractor (fallback file counting, language detection for non-manifest projects)
- [ ] MCP server wrapper
- [ ] Narrative caching (keyed by ProjectCard hash)
- [ ] HTML standalone output

### Known Issues
- **Most existing showcase pages describe private repositories** (decided 2026-10-30: keep them). Of the 33 manifest entries, 12 are public on GitHub and 21 are not (checked against `gh repo list jpurnell --visibility public`, which returns exactly the 100 public repos the API reports); the May batch published 19 of the private ones. The owner chose to leave them live. `discover` still proposes only public repos, and `sync` keeps refreshing all 33, so those pages stay current. Reversible: unpublish by setting `published: false`, which regeneration now preserves
- ~~MASTER_PLAN.md grounding~~ read only the pre-v2 path (`development-guidelines/00_CORE_RULES/00_MASTER_PLAN.md`), so it silently stopped working for every project migrated in August 2026; fixed 2026-10-30. The checklist item above claimed it worked and the tests passed, because the fixtures used the old layout. It was found only because a regenerated page described a game engine as an icon library
- ~~Five source repos have no usable master plan~~ (`org-judgement-corpus`, `quality-gate-swift`, `quality-gate-types`, `swift-security-rules`, `geo-audit`; `sync` left their pages as published). Resolved 2026-10-30: each now has a plan, written by agents from the repos' own files and spot-checked, committed locally and unpushed. `quality-gate-swift` gitignores `/project/` on purpose, so its plan is an untracked file (it works while the repo stays on this Mac; a fresh clone would lose it). The plans are drafts that now define what the site says about those projects, so they want an owner read-through
- Claude Code insights schema is undocumented and may change without notice — extraction is optional and degrades gracefully
- Narrative quality varies by project complexity; sparse projects (few commits, no tests) produce generic output
- `git shortlog` hangs when stdin is a TTY; `ProcessRunner` sets `FileHandle.nullDevice` for every child, so this is now handled in one place rather than per call site

### Current Priorities
1. ~~Write master plans for the five repos `sync` skips, then regenerate them~~ done 2026-10-30 (website PR #2); the owner still needs to read the five plans and merge the PR
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
- 213 tests across 42 suites covering all extractors, models, narration, rendering, subprocess spawning, and integration
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
- ~~GitHub Actions integration for automated portfolio updates on push~~ shipped as a weekly local launchd job (`scripts/sync-site.sh`) instead, because the source repos are private and hosted macOS is billed 10x on private repos
- Multi-language narrative generation

---

**Last Updated:** 2026-10-30 — session reconciliation. Test counts 128 → 213 (42 suites). Added to Current Status:
`sync`, `discover`, the approve step, infographics in `sync`, preservation of editorial fields, and master plans for the
five repos that had none. Resolved (struck through, reasoning kept): the "five repos have no master plan" known issue,
priority 1, and the "GitHub Actions integration" idea, which shipped as a local launchd job rather than CI. Recorded the
`MASTER_PLAN.md` path bug (grounding silently stopped working after the v2 migration) and the open question about
private-repo pages (decided: keep them live). The August 25 reconciliation (119 → 128, `ProcessRunner`) stands.
