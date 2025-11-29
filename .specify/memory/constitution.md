<!--
Sync Impact Report - Constitution Update
═══════════════════════════════════════════════════════════════════════════════
Version Change: 1.0.0 → 2.0.0 (MAJOR - Structural overhaul)

Summary:
  Major refactor consolidating 5 original principles into 6 CLI-focused
  principles. Incorporated CLI wrapper best practices (config-driven,
  safe-by-default, deterministic). Restructured to match progressive
  disclosure pattern with Statement → Rationale → Practices → Compliance.

Core Principles (6):
  I. Spec-First & Test-Driven Development [MERGED from I, II, III]
  II. Config as Source of Truth [NEW - CLI-specific]
  III. Safe by Default [NEW - CLI-specific]
  IV. Performance by Default [NEW]
  V. Security & Privacy by Design [NEW]
  VI. Open Source Excellence [NEW]

Implementation Guidance Sections:
  - Deterministic Execution
  - Transparency & Logging
  - CI & Quality Gates
  - Agent Maintenance Rules

Enforcement: Three-tier model (MUST/SHOULD/MAY)
Governance: Minimal (project owner amendments)

Template Alignment Status:
  ⚠️ spec-template.md - Requires alignment review
  ⚠️ plan-template.md - Requires alignment review
  ⚠️ tasks-template.md - Requires alignment review
  ⚠️ .windsurf/rules - Requires alignment review
═══════════════════════════════════════════════════════════════════════════════
-->

# Subtree CLI Constitution

## Preamble

This constitution governs the **Subtree CLI** project (`/Users/csjones/Developer/subtree`). It defines the principles, practices, and quality standards for all development.

**Scope**: Subtree CLI repository only. Does NOT govern swift-plugin-subtree or other 21.dev repositories.

**Philosophy**: Principles are technology-agnostic where possible. Current technology choices (Swift 6.1, swift-argument-parser, etc.) documented in README and Package.swift to enable future migrations without constitutional amendments.

---

## Core Principles

### I. Spec-First & Test-Driven Development

**Statement**: Every feature MUST start with a specification. All code MUST follow test-driven development: tests written first, verified to fail, then implementation proceeds.

**Rationale**: Specifications ensure alignment with user needs and provide measurable success criteria. Small, independent specs enable parallel work, reduce risk, accelerate feedback cycles, and allow incremental delivery. TDD prevents regressions, enables confident refactoring, and documents expected behavior. Outside-in development ensures functionality aligns with user perspective.

**Practices - Specification Requirements**:
- **MUST** create `spec.md` for every feature before development
- **MUST** represent a single feature or small subfeature (not multiple unrelated features)
- **MUST** be independently testable (no dependencies on incomplete specs)
- **MUST** represent a deployable increment of value
- **MUST** define user scenarios with acceptance criteria in Given-When-Then format
- **MUST** include measurable success criteria
- **MUST** focus on behavior, not implementation details
- **MUST** prioritize user stories by importance (P1/P2/P3)
- **MUST NOT** combine multiple unrelated features in one spec
- **MUST NOT** create dependencies on incomplete specs
- **MUST NOT** describe implementation details instead of user-facing behavior
- **MAY** include optional "Implementation Notes" section for language-specific guidance

**Practices - Test-Driven Development**:
- **MUST** write tests first based on spec.md acceptance criteria
- **MUST** verify tests fail before any implementation
- **MUST** implement minimal code to pass the tests
- **MUST** refactor while keeping tests green
- **MUST** maintain separate unit, integration, and contract tests
- **SHOULD** develop outside-in (user's perspective first)

**Compliance**: PRs MUST include tests written first. CI blocks merges if tests missing or immediately passing. Specs combining multiple features or creating spec dependencies MUST be rejected in review.

---

### II. Config as Source of Truth

**Statement**: All behavior MUST be driven by declarative configuration (`subtree.yaml`). CLI flags MAY override config, but only in well-defined, documented ways.

**Rationale**: Declarative configuration keeps behavior predictable and reproducible. Config files are easy to review, version control, and share. This is the core value proposition of Subtree CLI — replacing ad-hoc git subtree commands with managed, trackable configuration.

**Practices - Configuration Requirements**:
- **MUST** use `subtree.yaml` as the single source of truth for subtree state
- **MUST** validate config against a well-defined schema on startup
- **MUST** fail fast with actionable errors and line/field references for invalid configs
- **MUST** explicitly declare all subtree operations in config (no hidden defaults)
- **MUST** include config version field for format evolution
- **MUST** provide migration strategy or clear upgrade instructions for breaking config changes
- **MUST** keep config and git repository state synchronized (atomic updates)
- **SHOULD** provide config examples and templates in documentation
- **SHOULD** support config validation without execution (`subtree validate`)
- **MAY** allow CLI flags to override config values for one-time operations

**Practices - Explicit Command Mapping**:
- **MUST** make wrapped git commands auditable (logged before execution)
- **MUST** clearly separate CLI responsibilities (validation, orchestration) from git responsibilities
- **MUST NOT** rely on implicit or hidden command behavior

**Compliance**: Config schema MUST be documented. CI validates config parsing. PRs changing config format MUST include migration notes.

---

### III. Safe by Default

**Statement**: Default behavior MUST be non-destructive. Destructive operations require explicit opt-in via config and/or `--force` flags.

**Rationale**: Users must trust that Subtree CLI won't destroy their work. Git repositories contain valuable history that's difficult to recover. Safe defaults prevent accidental data loss when config is misconfigured or partially written.

**Practices - Non-Destructive Defaults**:
- **MUST** require explicit `--force` flag for destructive operations
- **MUST** protect git-tracked files from overwrites unless explicitly confirmed
- **MUST** validate prerequisites before executing git operations
- **MUST** provide clear warnings before irreversible actions
- **MUST** use atomic operations (all-or-nothing commits)
- **MUST** define clear exit code semantics (0=success, non-zero=failure with documented meanings)
- **SHOULD** support `--dry-run` mode showing exact commands without executing
- **SHOULD** design operations to be idempotent (safe to run multiple times)
- **SHOULD** handle interrupts (Ctrl+C) gracefully with cleanup
- **SHOULD** report which operations were left incomplete on interruption
- **MAY** provide `--report` mode for read-only status checks

**Practices - Atomic Operations**:
- **MUST** combine related changes in single commits (subtree + config update)
- **MUST** ensure config always reflects actual repository state
- **MUST** roll back partial operations on failure where possible
- **MUST NOT** leave repository in inconsistent state

**Compliance**: Integration tests MUST verify non-destructive defaults. Code reviews MUST verify `--force` gates on destructive operations.

---

### IV. Performance by Default

**Statement**: All operations MUST complete within documented time limits. The CLI MUST minimize overhead and avoid unnecessary work.

**Rationale**: Developers expect CLI tools to be fast. Slow tools break flow, discourage usage, and cause CI timeouts. Performance is a feature.

**Practices**:
- **MUST** complete init in <1 second
- **MUST** complete add in <10 seconds for typical repositories
- **MUST** complete update check (report mode) in <5 seconds
- **MUST** complete extract in <3 seconds for typical file sets
- **MUST** complete lint/validate in <2 seconds (offline mode)
- **MUST** avoid unnecessary network calls
- **MUST** avoid redundant file system operations
- **SHOULD** provide progress indicators for operations >2 seconds
- **SHOULD** support incremental operations where possible
- **MAY** cache remote state for repeated operations

**Compliance**: Integration tests MUST verify time limits. CI SHOULD track performance trends.

---

### V. Security & Privacy by Design

**Statement**: The CLI MUST follow security best practices for shell execution, secrets handling, and user privacy.

**Rationale**: CLI tools that execute external commands and handle configuration are potential attack vectors. Shell injection, credential leakage, and unsafe interpolation are common vulnerabilities. Security must be built in, not bolted on.

**Practices - Shell Safety**:
- **MUST** avoid unsafe string interpolation when invoking commands
- **MUST** use direct process execution with argument arrays (swift-subprocess pattern)
- **MUST** never build raw shell strings with user input
- **MUST** validate and sanitize all user-provided paths
- **MUST** reject path traversal attempts (`..`, absolute paths where inappropriate)

**Practices - Secrets Handling**:
- **MUST** never log secrets or credentials
- **MUST** never store secrets in config files in plain text
- **MUST** never pass secrets via command line arguments (visible in process listings)
- **MUST** redact sensitive information in error messages
- **SHOULD** prefer environment variables for credentials
- **MAY** integrate with system keychains or secret managers

**Practices - Cross-Platform Safety**:
- **MUST** handle path differences between platforms (macOS, Linux)
- **MUST** handle case-sensitivity differences (macOS case-insensitive, Linux case-sensitive)
- **SHOULD** document platform-specific behavior differences

**Compliance**: Code reviews MUST verify shell safety. CI scans for hardcoded secrets. Security-sensitive PRs require explicit review.

---

### VI. Open Source Excellence

**Statement**: All development MUST follow open source best practices: comprehensive documentation, welcoming contributions, clear licensing, and simplicity over cleverness.

**Rationale**: Open source thrives on transparency, collaboration, and accessibility. Good documentation reduces friction. Clear architectural decisions preserve knowledge. Simplicity encourages contributions and reduces maintenance burden.

**Practices - Documentation**:
- **MUST** maintain clear README with setup and usage instructions
- **MUST** document all commands with examples
- **MUST** provide contribution guidelines (CONTRIBUTING.md)
- **MUST** include LICENSE file
- **MUST** document public APIs with inline comments
- **SHOULD** maintain architecture decision records (ADRs) for significant choices
- **SHOULD** provide issue and PR templates

**Practices - Code Quality**:
- **MUST** write clear, human-readable code (readability over cleverness)
- **MUST** apply KISS principle (simplest solution that works)
- **MUST** apply DRY principle (avoid duplication)
- **MUST** avoid unnecessary dependencies
- **SHOULD** prefer standard library solutions over external packages
- **SHOULD** respond to community contributions promptly and respectfully

**Practices - Error Messages**:
- **MUST** write all user-facing errors in plain language
- **MUST** explain what failed and suggest next actions
- **MUST** use consistent formatting (emoji prefixes for visual parsing)
- **SHOULD** include relevant context (file paths, config fields)

**Compliance**: PRs MUST include documentation updates for new features. Code reviews enforce readability.

---

## Implementation Guidance

### Deterministic Execution

**Principle**: Given the same config, environment, and inputs, the CLI MUST produce the same sequence of commands and outputs.

**Requirements**:
- **MUST** produce identical results for identical inputs
- **MUST** document any sources of non-determinism (timestamps, random IDs)
- **MUST** log each command before executing it
- **MUST** distinguish between CLI messages and wrapped command output
- **SHOULD** support reproducible builds for testing

**Rationale**: Determinism is critical for CI, automation, and debugging. Non-deterministic behavior makes failures hard to reproduce and trust hard to build.

---

### Transparency & Logging

**Principle**: The CLI MUST clearly communicate what it's doing and why.

**Requirements**:
- **MUST** log each git command before execution
- **MUST** distinguish CLI output from wrapped command output
- **MUST** provide clear success/failure summaries
- **SHOULD** support `--verbose` mode for detailed output
- **SHOULD** support `--quiet` mode for minimal output
- **MAY** support `--json` mode for machine-readable output

---

### CI & Quality Gates

**Principle**: All code changes MUST pass automated quality gates.

**Platform Coverage**:
- **MUST** test on macOS (primary development platform)
- **MUST** test on Ubuntu 20.04 LTS (CI/server platform)
- **SHOULD** test on latest stable versions

**Required Checks**:
- **MUST** pass all unit tests
- **MUST** pass all integration tests
- **MUST** pass all contract tests (CLI interface stability)
- **MUST** build successfully on all platforms
- **SHOULD** pass linting and formatting checks

**Failure Policy**:
- Merge is BLOCKED if any MUST check fails
- Developer MUST fix root cause (no bypassing)
- Re-run full CI suite after fixes

---

### Agent Maintenance Rules

**Principle**: AI agents MUST maintain `.windsurf/rules` as living documentation.

**Lifecycle**:
- Agent creates `.windsurf/rules` during or after bootstrap spec implementation
- Agent updates after each spec that triggers mandatory categories

**Mandatory Update Triggers**:
1. Project dependencies (new packages, version changes)
2. Directory structure or module organization changes
3. Architecture pattern changes
4. CI/CD pipeline changes
5. Major feature additions

**Content Requirements**:
- Current dependencies and purpose
- Directory structure and organization
- Established architectural patterns
- CI/CD pipeline overview
- Major feature areas and locations
- Naming and testing conventions

**Rationale**: Living documentation prevents drift between code reality and agent expectations.

---

## Governance

### Authority

This constitution supersedes all other development practices for Subtree CLI. Deviations MUST be explicitly justified and approved.

### Amendment Process

1. Project owner proposes amendment with rationale and impact analysis
2. Version updated (semantic versioning):
   - **MAJOR**: Backward-incompatible changes, principle removals, or structural overhaul
   - **MINOR**: New principles added or materially expanded guidance
   - **PATCH**: Clarifications, wording improvements, non-semantic refinements
3. Update dependent templates in `.specify/templates/`
4. Document changes in Sync Impact Report
5. Commit with descriptive message

**Approval**: Project owner can amend directly. Community proposes via issues.

### Compliance Review

**Continuous Enforcement**:
- **MUST**: Blocks merge
- **SHOULD**: Warning, requires override justification
- **MAY**: Informational only

**Event-Driven Review**: Triggered by:
1. Major feature additions
2. Dependency changes
3. Repeated SHOULD overrides (3+ in 30 days)
4. Annual checkpoint

### Enforcement

- PR reviewers verify constitutional alignment
- CI pipeline enforces MUST-level checks
- Windsurf rules (`.windsurf/rules/*.md`) provide AI guidance aligned with principles

---

## Version History

**Version**: 2.0.0  
**Ratified**: 2025-10-25  
**Last Amended**: 2025-11-28

**Changelog**:
- **2.0.0** (2025-11-28): Major structural overhaul. Consolidated 5 original principles into 6 CLI-focused principles. Added CLI-specific practices (config-driven, safe-by-default, atomic operations, exit codes, idempotency). Restructured with Statement → Rationale → Practices → Compliance pattern. Added Implementation Guidance sections. Three-tier enforcement model (MUST/SHOULD/MAY).
- **1.0.0** (2025-10-25): Initial constitution with 5 core principles (Spec-First, TDD, Small Specs, CI Gates, Agent Maintenance).
