# ProjectShowcase

A Swift CLI tool that extracts structured facts from developer projects and generates AI-powered narrative case-study portfolios with SVG infographics. It reads git history, package manifests, design artifacts, Claude Code usage data, and test results, then sends that structured data to the Claude API to produce polished portfolio content ready for static site generators like [Ignite](https://github.com/twostraws/Ignite).

## How It Works

ProjectShowcase operates as a three-stage pipeline:

```
Project Directory ──> [Gather] ──> ProjectCard JSON ──> [Narrate] ──> NarrativeResult JSON ──> [Render] ──> Markdown + SVGs
```

1. **Gathering** extracts raw facts from a project directory into a `ProjectCard` JSON file.
2. **Narration** sends the card to the Claude API, which generates a structured narrative tailored to a specific audience and style.
3. **Rendering** converts the narrative into markdown with YAML frontmatter (for SSGs) and produces SVG infographics.

Each stage is independent. You can gather once and narrate multiple times for different audiences, or skip narration entirely and just generate infographics from a card.

## Requirements

- Swift 5.9+ (macOS 13+)
- Git (the `gather` command shells out to `git` for history extraction)
- `ANTHROPIC_API_KEY` environment variable (required for `narrate`, `refresh`, and `portfolio` commands)

## Installation

```bash
git clone <repo-url>
cd project-showcase
swift build -c release
# The binary is at .build/release/showcase
```

To install it to your path:

```bash
cp .build/release/showcase /usr/local/bin/
```

## Quick Start

**Single project, step by step:**

```bash
# 1. Extract facts from a project
showcase gather ~/Code/MyProject --output card.json

# 2. Generate a narrative (requires ANTHROPIC_API_KEY)
showcase narrate card.json --audience selfReflection --output narrative.json

# 3. Render to markdown with YAML frontmatter
showcase render narrative.json --output ./content/

# 4. Generate SVG infographics
showcase infographics card.json --output ./assets/images/
```

**Single project, all-in-one** (`refresh` is the default command):

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
showcase ~/Code/MyProject --audience hiringManager --style caseStudy --output ./content/
```

**Batch processing multiple projects:**

```bash
# Gather cards for all projects
for dir in ~/Code/ProjectA ~/Code/ProjectB ~/Code/ProjectC; do
    name=$(basename "$dir")
    showcase gather "$dir" --output "cards/${name}.json"
done

# Generate individual narratives
for card in cards/*.json; do
    showcase narrate "$card" --audience hiringManager --output narratives/
done

# Generate a cross-project portfolio overview
showcase portfolio cards/*.json --audience hiringManager --output ./content/

# Generate infographics for each project
for card in cards/*.json; do
    showcase infographics "$card" --output ./assets/images/
done
```

## Command Reference

| Command | Description | Requires API Key |
|---|---|---|
| `gather` | Extract facts from a project into a ProjectCard JSON | No |
| `narrate` | Generate a narrative from a ProjectCard JSON | Yes |
| `render` | Convert a NarrativeResult JSON to markdown | No |
| `refresh` | All-in-one: gather + narrate + render | Yes |
| `portfolio` | Cross-project overview from multiple cards | Yes |
| `infographics` | Generate SVG files from a ProjectCard JSON | No |

### `showcase gather <project-path>`

Walks a project directory and extracts structured facts from every available source.

```
Arguments:
  <project-path>          Path to the project root directory

Options:
  --insights-path <path>  Explicit path to Claude Code usage-data directory
                          (defaults to ~/.claude/usage-data/)
  --run-tests             Run the project's test suite and include results
  --output <path>         Output file path (prints to stdout if omitted)
```

The gatherer runs 8 extractors:

| Extractor | What it reads |
|---|---|
| GitExtractor | Commit count, tags/releases, branches, contributors, date range |
| SwiftPackageExtractor | `Package.swift` — tools version, dependencies, targets, platforms |
| NodePackageExtractor | `package.json` — name, version, dependencies |
| PythonPackageExtractor | `pyproject.toml` / `setup.py` — name, dependencies |
| CargoExtractor | `Cargo.toml` — name, version, dependencies |
| DesignDocExtractor | `CLAUDE.md`, `MASTER_PLAN.md`, design proposals |
| InsightsExtractor | Claude Code usage-data (sessions, friction, tool usage) |
| TestOutputParser | Swift Testing and XCTest console output |

When a `MASTER_PLAN.md` is found, its project description is treated as the authoritative source for what the project does. This grounds the Claude-generated narrative in the developer's own words instead of letting the model infer (and potentially hallucinate) the project's purpose.

### `showcase narrate <card-path>`

Sends a ProjectCard to the Claude API and returns a structured narrative.

```
Arguments:
  <card-path>             Path to a ProjectCard JSON file

Options:
  --api-key <key>         Anthropic API key (falls back to ANTHROPIC_API_KEY env var)
  --audience <audience>   Target audience (default: hiringManager)
  --style <style>         Narrative style (default: caseStudy)
  --output <path>         Output file path (prints to stdout if omitted)
```

**Audiences:**

| Value | Framing |
|---|---|
| `hiringManager` | Technical capabilities, judgment, and craft |
| `openSourceContributor` | Whether to use or contribute to the project |
| `client` | Whether to hire this developer |
| `selfReflection` | The developer reviewing their own growth |

**Styles:**

| Value | Structure |
|---|---|
| `caseStudy` | Problem, Approach, Results, Judgment Calls |
| `projectCard` | Concise 2-3 paragraph overview |
| `deepDive` | Architecture, Implementation, Testing Strategy, Lessons |

### `showcase render <narrative-path>`

Converts a NarrativeResult JSON into a markdown file with YAML frontmatter compatible with static site generators.

```
Arguments:
  <narrative-path>        Path to a NarrativeResult JSON file

Options:
  --output <dir>          Output directory (default: current directory)
```

The generated frontmatter includes `title`, `description`, `date`, `lastModified`, `tags`, `layout`, `style`, `project`, and `published` fields.

### `showcase refresh <project-path>`

Runs the full pipeline (gather, narrate, render) in a single command.

```
Arguments:
  <project-path>          Path to the project root directory

Options:
  --api-key <key>         Anthropic API key (falls back to ANTHROPIC_API_KEY env var)
  --insights-path <path>  Explicit path to Claude Code usage-data directory
  --audience <audience>   Target audience (default: hiringManager)
  --style <style>         Narrative style (default: caseStudy)
  --output <dir>          Output directory for the markdown file (default: current directory)
```

### `showcase portfolio <card-paths...>`

Generates a cross-project portfolio overview from multiple ProjectCard JSON files. Produces a single `portfolio-overview.md` with YAML frontmatter.

```
Arguments:
  <card-paths>            One or more paths to ProjectCard JSON files

Options:
  --api-key <key>         Anthropic API key (falls back to ANTHROPIC_API_KEY env var)
  --audience <audience>   Target audience (default: hiringManager)
  --output <dir>          Output directory (default: current directory)
```

### `showcase infographics <card-path>`

Generates three SVG infographic files from a ProjectCard:

- `<project>-stats.svg` — Key metrics card (commits, tests, contributors, etc.)
- `<project>-commits.svg` — Commit activity timeline
- `<project>-releases.svg` — Release history timeline

```
Arguments:
  <card-path>             Path to a ProjectCard JSON file

Options:
  --output <dir>          Output directory (default: current directory)
```

The SVGs are self-contained with no external dependencies -- they can be embedded directly in HTML or markdown.

## Architecture

```
Sources/
  ProjectShowcase/          # Library target
    Gathering/
      FactGatherer.swift              # Orchestrates all extractors
      Sources/
        GitExtractor.swift            # Shell → git log/tag/branch
        DesignDocExtractor.swift      # CLAUDE.md, MASTER_PLAN.md, proposals
        InsightsExtractor.swift       # Claude Code usage-data JSONs
        TestOutputParser.swift        # Swift Testing / XCTest output
        PackageManifest/
          SwiftPackageExtractor.swift  # Package.swift
          NodePackageExtractor.swift   # package.json
          PythonPackageExtractor.swift # pyproject.toml / setup.py
          CargoExtractor.swift         # Cargo.toml
    Models/
      ProjectCard.swift               # Central data structure
      GitFacts.swift                  # Commits, releases, branches
      PackageManifestFacts.swift      # Language, deps, targets
      TestFacts.swift                 # Test count, pass rate
      InsightsSummary.swift           # Session patterns, friction
      DesignArtifactFacts.swift       # Design docs, architecture
      NarrativeResult.swift           # Generated narrative output
      Enums.swift                     # Audience, NarrativeStyle, ProjectLanguage
    Narration/
      PromptBuilder.swift             # Card → Claude prompt
      PortfolioPromptBuilder.swift    # Multi-card → portfolio prompt
      NarrativeGenerator.swift        # Claude API client
      NarrativeResponseParser.swift   # API response → NarrativeResult
    Rendering/
      MarkdownRenderer.swift          # NarrativeResult → YAML frontmatter + markdown
      InfographicGenerator.swift      # Protocol for SVG generators
      StatsCardGenerator.swift        # Key metrics SVG
      CommitTimelineGenerator.swift   # Commit activity SVG
      ReleaseTimelineGenerator.swift  # Release history SVG

  ShowcaseCLI/                # Executable target (swift-argument-parser)
    ShowcaseCLI.swift                 # Entry point, subcommand registration
    GatherCommand.swift
    NarrateCommand.swift
    RenderCommand.swift
    RefreshCommand.swift
    PortfolioCommand.swift
    InfographicsCommand.swift

Tests/
  ProjectShowcaseTests/       # 119 tests across 16 suites
    Gathering/                # Extractor unit tests
    Models/                   # Serialization round-trip tests
    Narration/                # Prompt construction, response parsing
    Rendering/                # Markdown output, SVG generation
    Integration/              # End-to-end smoke tests
```

## Data Flow

```
ProjectCard (JSON)
├── projectName: String
├── projectPath: String
├── gatheredAt: Date
├── git: GitFacts
│   ├── commitCount, branchCount, contributorCount
│   ├── firstCommitDate, latestCommitDate
│   └── releaseHistory: [Release]
├── packageManifest: PackageManifestFacts?
│   ├── language (swift | typescript | python | rust | ...)
│   ├── toolsVersion, dependencies, targets, platforms
├── tests: TestFacts?
│   ├── testCount, suiteCount, passRate
├── insights: InsightsSummary?
│   ├── sessionCount, totalCommits, totalMessages
│   ├── frictionCategories, outcomeDistribution
│   └── toolUsageProfile, sessionTypes
└── designArtifacts: DesignArtifactFacts?
    ├── designProposalCount, hasClaudeMD, hasDesignFirstWorkflow
    ├── projectDescription (from MASTER_PLAN.md)
    └── architectureNotes
```

## Testing

```bash
swift test
```

The test suite covers all extractors with fixture data, model serialization round-trips, prompt construction, markdown rendering, and SVG generation. No API key is needed to run tests -- the narration tests use mocked responses.

## License

See LICENSE file for details.
