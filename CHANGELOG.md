# Changelog

All notable changes to ProjectShowcase are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed
- **`sync` never wrote a page's infographics.** The site's layout requests
  `/images/showcase/<slug>-{stats,commits,releases}.svg`, so every page `sync` created showed three
  broken images, and the pages it refreshed kept the commit counts of the original May run. Pages
  `sync` regenerates now get their SVGs, named by slug, in the manifest's `imagesDirectory`;
  `--infographics-only` refreshes all of them without an API key; and `decline` deletes them.
- `discover` wrote an absolute path into the manifest whenever the folder was reached under a
  different spelling of its case; the relative-path check is now case-insensitive and tested.
- **`ProcessRunner`'s documentation promised that `environment: nil` inherits the parent's
  environment; it gives the child an empty one.** Assigning `nil` to `Process.environment` does
  not inherit. `gh` therefore reported "not logged in" (it found neither `HOME` nor the keychain
  session). The default is kept, since it also keeps `ANTHROPIC_API_KEY` out of children that do
  not need it; the documentation now says so, a test pins it, and the `gh` call passes its
  environment explicitly.
- **Master-plan grounding had stopped working for every migrated project.** `DesignDocExtractor`
  read only `development-guidelines/00_CORE_RULES/00_MASTER_PLAN.md`. The v2 migration moved the
  plan to `project/master_plan.md`, so cards gathered since August carried no description of
  the project and the narrative guessed from names — it described IconquerCore, a headless rules
  engine for a Risk-style game, as an icon library. The extractor now checks
  `project/master_plan.md`, `project/MASTER_PLAN.md`, `MASTER_PLAN.md` and the legacy path in
  that order, and accepts `Target Consumers` as well as `Target Users`.
- **A narrative request could not outlast URLSession's 60 second default.** A deep-dive prompt
  over a large repository timed out. `NarrativeGenerator.makeRequest(body:)` now builds the
  request with a 300 second timeout and is where the host allowlist is applied.
- **The API key could be sent to a lookalike host.** The endpoint check was
  `host.hasSuffix("anthropic.com")`, which admits `evilanthropic.com`, and the request that
  follows carries the key in `x-api-key`. `NarrativeGenerator.isAllowedEndpoint(_:)` accepts
  `anthropic.com` or a subdomain matched with its dot, over HTTPS, or `localhost`; tested for a
  lookalike, a suffix-extended host, plain HTTP and an unrelated host.
- **The commit timeline depended on where it was generated.** `CommitTimelineGenerator` counted
  months in a Gregorian calendar that inherited the machine's time zone and labelled them in the
  machine's locale, so a first commit at 02:00 UTC on 1 November added an October bar anywhere
  west of Greenwich. It now takes `timeZone` and `locale` — `CommitTimelineGenerator(timeZone:locale:)`,
  defaulting to UTC and `en_US_POSIX` — and `CommitTimelineGenerator()` still compiles. Output
  changes only for a history that crosses a month boundary between UTC and the local zone, or
  on a machine whose locale abbreviates months differently.
- The DocC catalogue was excluded from the `ProjectShowcase` target, so DocC received no
  articles and `doc-lint` passed without reading it. It is declared as a resource instead.
- The infographic protocol test asserted `generator is any InfographicGenerator`, which the
  compiler had already decided. It now checks what each generator draws through the protocol.

### Added
- **An approve step for new pages.** When a run adds pages, the weekly job leaves its PR open and
  shows a dialog with a button that runs `scripts/review-site.sh`: it serves the PR's built site
  locally, opens each new page, and asks approve / decline / skip. `showcase decline` removes a
  declined page and records it in the manifest's `declined` list, which `discover` honours. A run
  that only refreshes existing pages still merges itself.
- **`showcase discover`** proposes new pages without anyone choosing them. A repository
  qualifies if GitHub lists it as public under the owner (not a fork, not archived), it has a
  master plan, 30+ commits, and a commit in the last year; remotes an existing page covers are
  skipped, and at most five are added per run. `--add` appends them to the manifest. The weekly
  job runs it before `sync`.
- **`showcase sync`** keeps a site's pages current. It reads a manifest (slug → source repo,
  audience, style, `project:` group, curated tags), compares each repo's `HEAD` with the commit
  the page was last generated from, and regenerates only the pages whose source moved. It
  records progress after every page, so a failed run resumes where it stopped; `--dry-run`,
  `--force` and `--only <slug>` select what runs. It declines to replace a published page with a
  narrative the card cannot ground (no master-plan description), and skips an unreadable repo
  even under `--force`.
- `SyncManifest`, `SyncState`, `SyncPlanner`, `GitHead` and `PortfolioRenderer` in the library;
  `MarkdownRenderer` accepts a slug, `project:` label and tag list, and `ProjectCard.renamed(to:)`
  covers pages that describe one module of a larger repository.
- `scripts/sync-site.sh` and `deploy/com.jpurnell.showcase-sync.plist`: a weekly launchd job that
  runs the sync, rebuilds the site and opens a pull request on a dated branch, merging it when
  the sync finished clean and leaving it open for review after any page failure.
- `ProcessRunner`: the single subprocess spawn site for the package, bounding every run with a
  watchdog and capturing output through files rather than pipes
- `ShowcaseError.processTimedOut(executable:seconds:)` for a child that outlives its deadline
- DocC catalogue for the `ProjectShowcase` library target
- Daily quality gate with corpus telemetry integration
- Default subcommand (`refresh`) for streamlined CLI usage
- MASTER_PLAN.md extraction for narrative grounding with project descriptions
- Ignite-compatible YAML frontmatter output

### Changed
- Git extraction, `--run-tests`, and the test fixtures all spawn through `ProcessRunner`; the
  fixtures no longer build shell command strings, passing each argument as its own `argv` entry
- Test fixture helpers consolidated in `Tests/ProjectShowcaseTests/Support/GitFixture.swift`
- `.quality-gate.yml` is tracked rather than gitignored, so the bounded-io kernel declaration
  reaches CI; its corpus path is now relative to the project root
- Removed three `// SECURITY:` acknowledgements that no longer answer a finding now that
  `security.ssrf` reports requests rather than parses; one remains, on the plain-HTTP fixture

### Fixed
- Line splitting in renderer tests now survives CRLF (`split(whereSeparator: \.isNewline)`
  instead of `components(separatedBy: "\n")`, which leaves the `\r` behind)
- Frontmatter output compatibility with Ignite's YAML parser

## [0.1.0] - 2026-05-12

### Added
- Initial three-stage pipeline: gather, narrate, render
- Git history extraction (commits, branches, contributors, releases)
- Package manifest extraction for Swift, Node, Python, and Rust projects
- Design document extraction (CLAUDE.md, MASTER_PLAN.md, design proposals)
- Claude Code insights extraction (session patterns, tool usage)
- Test output parsing with pass/fail/skip counts
- LLM-powered narrative generation via Anthropic Claude API
- Portfolio mode for multi-project narrative generation
- Markdown rendering with YAML frontmatter
- SVG infographic generation (stats cards, commit timelines, release timelines)
- CLI commands: gather, narrate, render, refresh, portfolio, infographics
