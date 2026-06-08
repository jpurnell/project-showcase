# Changelog

All notable changes to ProjectShowcase are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Daily quality gate with corpus telemetry integration
- Default subcommand (`refresh`) for streamlined CLI usage
- MASTER_PLAN.md extraction for narrative grounding with project descriptions
- Ignite-compatible YAML frontmatter output

### Fixed
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
