# ``ProjectShowcase``

Extract structured facts from a developer project and turn them into a narrative case study.

## Overview

ProjectShowcase reads a project directory and produces a ``ProjectCard`` — commit history,
release tags, package manifest, design artifacts and test results, gathered into one value.
That card feeds narrative generation and rendering: Markdown with Ignite-compatible
frontmatter, and SVG infographics drawn from the same facts.

Every subprocess the package runs goes through ``ProcessRunner``, the single spawn site that
bounds the run and captures its output.

## Topics

### Gathering facts

- ``FactGatherer``
- ``GitExtractor``
- ``ProjectCard``
- ``GitFacts``

### Narrating

- ``NarrativeGenerator``
- ``NarrativeResult``

### Rendering

- ``MarkdownRenderer``
- ``InfographicGenerator``

### Running subprocesses

- ``ProcessRunner``
- ``ProcessResult``

### Errors

- ``ShowcaseError``
