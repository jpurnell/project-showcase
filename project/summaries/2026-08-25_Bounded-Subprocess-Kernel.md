# Session Summary — Bounded Subprocess Kernel and Safety Gate Fixes

**Date:** 2026-08-25
**Branch:** main
**Outcome:** Quality gate 0 errors / 0 warnings across 40 checkers; 128 tests passing

## What prompted this

The updated quality gate reported 5 errors and 2 warnings from the `safety` checker, all in the
test target. Fixing them exposed a second, pre-existing failure — `bounded-io` — which the
original single-checker run had never reached.

## Safety findings, and what each actually was

| Finding | Fix |
|---|---|
| `components(separatedBy: "\n")` ×3 in `MarkdownRendererTests` | `split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)` — the old form finds the `\n` inside a `\r\n` and leaves the `\r` on every line |
| `/bin/zsh -c` with an assembled command string ×2 (`GitExtractorTests`, `FactGathererTests`) | Fixtures now spawn `git` with each argument as its own `argv` entry; shell-only constructs (`echo >`, `&&`) became Swift file writes and separate invocations |
| `FileManager` with a dynamic path ×2 | URL-based `createDirectory(at:)` on standardized URLs; the renderer test asserts containment in its output directory plus `checkResourceIsReachable()` |

No suppression comments were used for any of them.

## The bounded-io kernel

`bounded-io` flags `Process()`, `waitUntilExit()`, `readDataToEndOfFile()` and `availableData`
anywhere outside a single declared kernel file. The project declared none, so all 7 spawn sites
in the tree were outside it by construction.

Added `Sources/ProjectShowcase/Support/ProcessRunner.swift` and declared it in
`.quality-gate.yml` under `boundedIO.kernelPath`. It bounds the two ways a spawn hangs:

- **The wait** — a watchdog signals the child's pid at the deadline (`SIGTERM`, then `SIGKILL`
  after a 2s grace period). Signals go to the pid rather than the `Process`, because `Process` is
  not `Sendable` and the deadline fires on another queue.
- **The read** — the child's streams are redirected to files, not pipes. A pipe holds ~64KB; a
  child that writes more blocks until drained, and a parent that waits for exit before draining
  deadlocks against it.

Three call sites now route through it: `GitExtractor.runShell`, `GatherCommand.runTestSuite`
(which lost a shell-metacharacter screen that guarded a shell it no longer uses), and the test
fixture helper. `bounded-io` reports 2 remaining subprocess sites, both inside the kernel.

## `.quality-gate.yml` is now tracked

Declaring the kernel exposed a second problem: the config file was gitignored, so a repo-level
fact — *which file is the kernel* — would never have reached CI, and the reusable workflow only
passes `--config` when the file exists. The file was being treated as machine-local because of
one line in it: an absolute `corpusPath` under `/Users/jpurnell`.

Split by kind rather than by file: the corpus path is now relative to the project root
(`../org-judgement-corpus`, the form the gate's own configuration docs use), CI keeps overriding
it with `--telemetry-corpus-path`, and the file is out of `.gitignore` and committed. Verified
locally: consistency still reads the corpus and scores 1.00 rather than skipping.

## Other gate work

- **doc-lint** was failing on clean `HEAD` — the package had no DocC catalogue, so the checker
  examined nothing. Added `Sources/ProjectShowcase/ProjectShowcase.docc/ProjectShowcase.md` and
  excluded it from the target's sources, matching the convention in quality-gate-swift.
- **test-quality** flagged the first draft of the ProcessRunner tests: three `!= 0` / `!= nil`
  assertions and one wall-clock threshold. The assertions now destructure the specific
  `ShowcaseError` case, and the timeout test relies on `.processTimedOut` being thrown rather
  than on measured elapsed time — an unbounded runner still fails it, just slowly.

## Files

- Added: `Sources/ProjectShowcase/Support/ProcessRunner.swift`,
  `Sources/ProjectShowcase/ProjectShowcase.docc/ProjectShowcase.md`,
  `Tests/ProjectShowcaseTests/Support/{GitFixture,ProcessRunnerTests}.swift`
- Changed: `GitExtractor.swift`, `GatherCommand.swift`, `ShowcaseError.swift`, `Package.swift`,
  `.quality-gate.yml`, the three flagged test files, `CHANGELOG.md`, `README.md`,
  `project/master_plan.md`

## Next

- `GenericExtractor` for projects without package manifests (unchanged priority)
- Narrative caching keyed by ProjectCard hash
