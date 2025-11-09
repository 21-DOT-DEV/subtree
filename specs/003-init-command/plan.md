# Implementation Plan: Init Command

**Branch**: `003-init-command` | **Date**: 2025-10-27 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-init-command/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement the `subtree init` command to create a minimal valid `subtree.yaml` configuration file at the git repository root. The command uses emoji-prefixed messages, requires git repository context, protects against accidental overwrites with a `--force` flag, and creates the file atomically using temporary file operations. Git root detection uses `git rev-parse --show-toplevel` for canonical path resolution, and YAML generation leverages the existing Yams library dependency.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Swift 6.1  
**Primary Dependencies**: swift-argument-parser 1.6.1, Yams 6.1.0, swift-subprocess 0.1.0+, swift-system 1.5.0  
**Storage**: File system (subtree.yaml at git repository root)  
**Testing**: Swift Testing (built into Swift 6.1), TestHarness for CLI execution, GitRepositoryFixture for git operations  
**Target Platform**: macOS 13+, Ubuntu 20.04 LTS
**Project Type**: CLI tool (single project structure)  
**Performance Goals**: Complete initialization in <1 second for typical repositories  
**Constraints**: Must detect git repository, atomic file operations, cross-platform compatibility  
**Scale/Scope**: Single command with 1 flag (--force), 12 functional requirements, emoji-prefixed output

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Spec-First Development ✅
- **Status**: PASS
- **Evidence**: Feature spec exists at `specs/003-init-command/spec.md` with 3 prioritized user stories, 12 functional requirements, and acceptance criteria in Given-When-Then format

### II. Test-Driven Development ✅
- **Status**: PASS (Planned)
- **Evidence**: Spec defines testable acceptance scenarios. Tests will be written first using existing Swift Testing framework and TestHarness before implementation
- **Test Strategy**: Unit tests for git detection, YAML generation, file operations; integration tests for end-to-end CLI behavior

### III. Small, Independent Specs ✅
- **Status**: PASS
- **Evidence**: Single feature (init command only), independently testable, no dependencies on other incomplete specs. Builds on existing bootstrap infrastructure (Phase 11 complete)

### IV. CI & Quality Gates ✅
- **Status**: PASS
- **Evidence**: Existing CI pipeline (ci.yml) with macOS-15 and Ubuntu 20.04 coverage. All tests must pass before merge. No bypassing checks.

### V. Agent Maintenance Rules ✅
- **Status**: PASS (Update Planned)
- **Evidence**: `.windsurf/rules/` exists. This spec adds first real command implementation (trigger: major feature area). Rules will be updated after successful implementation to document init command pattern.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
Sources/
├── SubtreeLib/              # Library module (all business logic)
│   ├── Commands/            # ArgumentParser command implementations
│   │   ├── SubtreeCommand.swift       # Main command (existing)
│   │   └── InitCommand.swift          # NEW: Init command implementation
│   └── Utilities/           # Helper utilities
│       ├── ExitCode.swift             # Exit code definitions (existing)
│       ├── GitOperations.swift        # NEW: Git repository detection
│       └── ConfigFileManager.swift    # NEW: YAML file creation/management
└── subtree/                 # Executable module (thin wrapper)
    └── main.swift           # Calls SubtreeCommand.main() (existing)

Tests/
├── SubtreeLibTests/         # Unit tests (@testable import SubtreeLib)
│   ├── CommandTests.swift           # Command structure tests (existing)
│   ├── ExitCodeTests.swift          # Exit code tests (existing)
│   ├── GitOperationsTests.swift     # NEW: Git detection unit tests
│   └── ConfigFileManagerTests.swift # NEW: YAML generation unit tests
└── IntegrationTests/        # Integration tests (execute CLI binary)
    ├── TestHarness.swift              # CLI execution helper (existing)
    ├── GitRepositoryFixture.swift     # Git repo test fixture (existing)
    ├── GitFixtureTests.swift          # Git fixture tests (existing)
    ├── SubtreeIntegrationTests.swift  # General integration tests (existing)
    └── InitCommandIntegrationTests.swift # NEW: Init command e2e tests
```

**Structure Decision**: Swift Package Manager CLI structure using Library + Executable pattern (established in bootstrap spec 001). All business logic in `SubtreeLib` for testability. New utilities will be added to support git operations and config file management. Integration tests use existing TestHarness and GitRepositoryFixture infrastructure.

## Complexity Tracking

> **No violations** - All constitutional principles satisfied

**Status**: ✅ No complexity justifications required

---

## Phase Summary

### Phase 0: Research ✅
- **Status**: Complete
- **Output**: [`research.md`](./research.md)
- **Key Decisions**: 
  - Git detection via `git rev-parse --show-toplevel`
  - YAML generation using Yams library
  - Emoji-prefixed messages
  - Atomic file operations
  - Symlink resolution strategy

### Phase 1: Design ✅
- **Status**: Complete
- **Outputs**:
  - [`data-model.md`](./data-model.md) - SubtreeConfig, GitRepository, ConfigFile entities
  - [`contracts/cli-contract.md`](./contracts/cli-contract.md) - CLI interface specification
  - [`quickstart.md`](./quickstart.md) - Build, test, and validation guide

### Phase 2: Tasks
- **Status**: Not started (requires `/speckit.tasks` command)
- **Next Step**: Run `/speckit.tasks` to generate `tasks.md`

---

## Implementation Readiness

✅ **Ready for implementation** - All planning artifacts complete:
- [x] Technical context defined
- [x] Constitution check passed
- [x] Research completed (all clarifications resolved)
- [x] Data model documented
- [x] CLI contract specified
- [x] Quickstart guide created

**Next Command**: `/speckit.tasks` to generate task breakdown
