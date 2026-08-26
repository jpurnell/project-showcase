# Changelog

All notable changes to ProjectShowcase are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
