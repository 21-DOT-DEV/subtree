# Implementation Plan: Remove Command

**Branch**: `006-remove-command` | **Date**: 2025-10-28 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/006-remove-command/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement `subtree remove <name>` command that safely removes subtrees from the repository with automatic configuration cleanup. The command removes the subtree's prefix directory, updates `subtree.yaml` atomically, and creates a single commit containing both changes. Supports idempotent behavior (succeeds even if directory already removed), comprehensive validation (clean working tree, config exists, name exists), and clear error messages with specific exit codes.

**Key Technical Approach**:
- Reuse existing `AtomicSubtreeOperation` utility for consistency with Add/Update commands
- Check directory existence before `git rm` to enable idempotent behavior
- Create regular commit (not amend) since `git rm` only stages changes without creating initial commit
- Validate all preconditions before any filesystem/git modifications

## Technical Context

**Language/Version**: Swift 6.1
**Primary Dependencies**: 
- swift-argument-parser 1.6.1 (CLI framework)
- Yams 6.1.0 (YAML parsing)
- swift-subprocess 0.1.0+ (process execution for git commands)
- swift-system 1.5.0 (file operations, Ubuntu 20.04 compatible)
- swift-testing 0.6.0+ (test framework)

**Storage**: File-based (subtree.yaml at git repository root)
**Testing**: Swift Testing framework (built into Swift 6.1, macro-based)
**Target Platform**: macOS 13+, Ubuntu 20.04 LTS
**Project Type**: Single Swift Package Manager CLI tool
**Performance Goals**: 
- Removal operation completes in <5 seconds for typical subtrees (<10,000 files)
- Idempotent removal (directory already gone) succeeds within 1 second
- 100% of validation failures occur before filesystem/git modifications

**Constraints**: 
- Must work from any subdirectory within git repository (find git root)
- Must maintain atomic operations (single commit for directory + config)
- Must be idempotent (safe to run multiple times)
- Must follow clean working tree validation pattern (consistent with Add/Update)

**Scale/Scope**: 
- Typical use: 1-20 subtrees per repository
- Support repositories with up to 100 subtrees
- Handle subtree directories with up to 10,000 files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Spec-First Development ✅

- ✅ Feature defined in spec.md with user scenarios and acceptance criteria
- ✅ Spec includes 3 prioritized user stories (US1-P1: Clean Removal, US2-P2: Idempotent Removal, US3-P1: Error Handling)
- ✅ Functional requirements are technology-agnostic (30 requirements)
- ✅ Success criteria are measurable (10 criteria)
- ✅ Spec follows Given-When-Then format for acceptance scenarios

### Principle II: Test-Driven Development ✅

- ✅ Acceptance scenarios define failing tests to be written first
- ✅ Test strategy: Unit tests (command logic, validation), Integration tests (CLI execution with git fixtures)
- ✅ Tests will verify: clean removal, idempotent behavior, error handling, exit codes, commit atomicity
- ✅ Swift Testing framework already established in bootstrap spec (001-cli-bootstrap)

### Principle III: Small, Independent Specs ✅

- ✅ Single feature: Remove command only
- ✅ Independently testable: Can add subtrees, then test removal in isolation
- ✅ Deployable increment: Completes Phase 2 core operations (after Add and Update)
- ✅ No dependencies on incomplete specs (builds on completed 001-004)
- ✅ User stories prioritized by importance (P1 for core + error handling, P2 for idempotent recovery)

### Principle IV: CI & Quality Gates ✅

- ✅ CI matrix established: macOS-15, Ubuntu 20.04 LTS
- ✅ Test requirements: Unit + Integration tests must pass
- ✅ Platform coverage: Tests run on both macOS and Linux
- ✅ Merge policy: CI must pass before merge (defined in ci.yml)

### Principle V: Agent Maintenance Rules ✅

- ✅ .windsurf/rules/ exists (architecture.md, bootstrap.md, ci-cd.md, compliance.md)
- ⚠️ **UPDATE REQUIRED**: After implementation, add Remove command to architecture.md (new command pattern)
- ✅ Update trigger applies: Major feature area (new core command)

**Overall Status**: ✅ PASS - All gates satisfied, one maintenance update required post-implementation

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
│   ├── Commands/
│   │   ├── SubtreeCommand.swift      # Root command
│   │   ├── InitCommand.swift         # Init subcommand (complete)
│   │   ├── AddCommand.swift          # Add subcommand (complete)
│   │   ├── UpdateCommand.swift       # Update subcommand (complete)
│   │   └── RemoveCommand.swift       # NEW: Remove subcommand
│   ├── Configuration/
│   │   ├── SubtreeConfiguration.swift
│   │   └── ConfigFileManager.swift
│   └── Utilities/
│       ├── GitOperations.swift
│       ├── AtomicSubtreeOperation.swift  # Shared atomic commit utility
│       ├── ExitCode.swift
│       └── [other utilities]
└── subtree/                 # Executable module (thin wrapper)
    └── EntryPoint.swift     # Calls SubtreeCommand.main()

Tests/
├── SubtreeLibTests/         # Unit tests (@testable import)
│   ├── Commands/
│   │   └── RemoveCommandTests.swift       # NEW: Remove command unit tests
│   ├── ConfigurationTests/
│   └── Utilities/
└── IntegrationTests/        # Integration tests (run binary + git fixtures)
    ├── RemoveIntegrationTests.swift       # NEW: Remove command integration tests
    ├── GitRepositoryFixture.swift         # Existing: Temp git repo helper
    └── TestHarness.swift                  # Existing: CLI execution helper
```

**Structure Decision**: Single Swift Package Manager project using Library + Executable pattern (established in spec 001-cli-bootstrap). Remove command follows existing command structure:
- `RemoveCommand.swift` in `Sources/SubtreeLib/Commands/`
- Reuses shared utilities (GitOperations, AtomicSubtreeOperation, ConfigFileManager)
- Unit tests in `Tests/SubtreeLibTests/Commands/`
- Integration tests in `Tests/IntegrationTests/`

## Complexity Tracking

> No constitutional violations - all gates passed. No complexity justification required.
