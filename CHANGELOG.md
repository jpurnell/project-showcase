# Changelog

All notable changes to ProjectShowcase are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed
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
