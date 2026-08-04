# Implementation Checklist for ProjectShowcase

**Last Updated:** 2026-05-11
**Design Proposal:** [UPCOMING/ProjectShowcase.md](../project/plans/upcoming/ProjectShowcase.md)

---

## Current Phase: Phase 1 — Core Models + Git Extractor

### In Progress
- [ ] Core models (ProjectCard, InsightsSummary, enums)
- [ ] GitExtractor — commit history, releases, branches, contributors
- [ ] InsightsExtractor — Claude Code facets + session-meta parsing

### Up Next
- [ ] PackageExtractor protocol + SwiftPackageExtractor
- [ ] GenericExtractor (file counting, language detection)
- [ ] DesignDocExtractor (CLAUDE.md, proposals)
- [ ] TestOutputParser
- [ ] FactGatherer orchestrator
- [ ] NarrativeGenerator (Claude API integration)
- [ ] MarkdownRenderer + SVG infographics
- [ ] PortfolioGenerator (cross-project synthesis)
- [ ] CLI commands (ArgumentParser)
- [ ] Node/Python/Cargo package extractors

### Completed
- [x] Design proposal approved
- [x] Package.swift created
- [x] Project scaffolding

---

## Module Status

| Module | Status | Tests | Docs | Warnings |
|--------|--------|-------|------|----------|
| Models | In Progress | No | No | — |
| Gathering/Git | Planned | No | No | — |
| Gathering/Insights | Planned | No | No | — |
| Gathering/Package | Planned | No | No | — |
| Gathering/DesignDoc | Planned | No | No | — |
| Narration | Planned | No | No | — |
| Rendering | Planned | No | No | — |
| CLI | Planned | No | No | — |

---

## Notes

- Phase 1 focuses on the data pipeline: gather facts → structured ProjectCard
- Phase 2 adds narrative generation (Claude API dependency)
- Phase 3 adds rendering and CLI polish
- MCP server is Phase 4 (reuses all core modules)
