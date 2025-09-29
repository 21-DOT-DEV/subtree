<!--
Sync Impact Report
- Version change: N/A → 1.0.0
- Modified principles:
  - New: CLI I/O Contract
  - New: Test-First & CI
  - New: Versioning & Releases
  - New: Cross-Platform Builds
  - New: Exit Codes & Error Handling
- Added sections:
  - Additional Constraints
  - Development Workflow & Quality Gates
- Removed sections: None
- Templates requiring updates:
  - .specify/templates/plan-template.md — ✅ aligned (Constitution Check section remains valid; version reference is a template comment)
  - .specify/templates/spec-template.md — ✅ aligned
  - .specify/templates/tasks-template.md — ✅ aligned
  - .specify/templates/commands/* — N/A (directory not present)
- Follow-up TODOs:
  - Consider updating the footer note in plan-template.md to reference the current constitution version dynamically.
-->

# Subtree Constitution

## Core Principles

### I. CLI I/O Contract
Subtree is a non-interactive, pipeline-friendly CLI by default.
- Input: command-line args and STDIN; Output: STDOUT; Errors/warnings: STDERR.
- Default output is human-readable. When `--json` is provided, output MUST be valid JSON and stable across patch releases.
- Exit codes: `0` success, `1` general failure, `2` usage/argument error, `3` I/O/environment error. Additional codes MAY be defined per subcommand and documented in `--help`.
- No interactive prompts unless `--interactive` (or equivalent) is explicitly passed and TTY is detected.
- Color and TTY behavior: enable colors only when attached to a TTY; support `--no-color` to disable.
- Required flags across all binaries: `--help`, `--version`, `--json` (where applicable), and `--quiet` to suppress non-essential output.

### II. Test-First & CI (NON-NEGOTIABLE)
Test-Driven Development is mandatory for all changes.
- Red-Green-Refactor: write failing tests before implementation; refactor only with tests green.
- CI MUST run `swift build` and `swift test` on all supported platforms/architectures where feasible.
- New flags/behavior MUST include tests for success, failure, and edge cases; JSON mode outputs MUST have schema assertions.
- No PR may merge with failing tests or without coverage of new behavior.

### III. Versioning & Releases
We use Semantic Versioning for the public CLI surface and output schemas.
- Versioning: MAJOR.MINOR.PATCH. Breaking CLI or JSON changes require a MAJOR release.
- Tags: `vX.Y.Z`. Releases are published as GitHub Releases with asset checksums.
- Deliverables: prebuilt binaries for all supported OS/architectures; include SHA-256 checksums and a plaintext CHANGELOG entry.
- Deprecations MUST be announced one MINOR release before removal, when feasible.

### IV. Cross-Platform Builds
Subtree MUST build and function on the defined matrix without code divergence.
- Targets: macOS (arm64, x86_64), Linux glibc (x86_64, arm64), Windows (arm64, x86_64).
- Source MUST avoid OS-specific assumptions (paths, encodings, newlines). Use Swift standard library and portability utilities.
- CI SHOULD produce artifacts for each target or validate via matrix builds where native toolchains exist.

### V. Exit Codes & Error Handling
All commands MUST return deterministic exit codes and clear diagnostics.
- Human-readable errors go to STDERR; JSON mode emits `{ "error": { "code": <int>, "message": <string>, "details": <object|null> } }` on STDERR.
- Verbosity controls: `--quiet` suppresses info-level logs; `--trace` may include stack traces for debugging.
- Never print secrets or tokens. Redact in logs and error messages.

## Additional Constraints

- Language/Runtime: Swift + Swift Package Manager (SPM). No alternate build systems.
- Baseline commands: `--help`, `--version`, `--json` (where applicable), `--quiet`.
- Distribution: GitHub Releases with prebuilt binaries; include SHA-256 checksums and a CHANGELOG entry.
- Dependency policy: all dependencies pinned via `Package.resolved`; reproducible builds required.
- Security: no network calls during execution unless explicitly required by a subcommand and documented.

## Development Workflow & Quality Gates

1) Tests First
- All new behavior lands with failing tests first, then implementation.
- JSON output schemas validated in tests.

2) CI Matrix
- Build and test across the supported OS/arch matrix where toolchains are available.
- Release pipelines produce artifacts and checksums; verify signatures/checksums before publish.

3) Review Gating
- PRs MUST assert compliance with all Core Principles in the description.
- Any deviation requires a documented justification and follow-up task to restore compliance.

## Governance
<!-- Example: Constitution supersedes all other practices; Amendments require documentation, approval, migration plan -->

This constitution supersedes conflicting practices. Compliance is required for all changes.

- Amendments: via PR with impact analysis (CLI flags, JSON schema, exit codes). Bump version per SemVer rules.
- Breaking changes: require migration notes and clear release notes; deprecate before removal when feasible.
- Compliance Review: reviewers verify Core Principles checkboxes in PR description; CI enforces tests and matrix builds.
- Runtime Guidance: see `.specify/templates/plan-template.md`, `spec-template.md`, and `tasks-template.md` for process checkpoints that mirror these principles.

**Version**: 1.0.0 | **Ratified**: 2025-09-22 | **Last Amended**: 2025-09-22