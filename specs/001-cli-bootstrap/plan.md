# Implementation Plan: CLI Bootstrap & Test Foundation

**Branch**: `001-cli-bootstrap` | **Date**: 2025-10-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-cli-bootstrap/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Establish the foundational test and CI infrastructure for the Subtree CLI project. This bootstrap spec creates a minimal Swift CLI skeleton with six stub commands (init, add, update, remove, extract, validate), a complete testing framework using Swift Testing, an integration test harness for git repository operations, and a GitHub Actions CI pipeline covering macOS and Ubuntu platforms. The implementation uses a library + executable architecture pattern for maximum testability and follows constitutional TDD principles.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Swift 6.1  
**Primary Dependencies**: 
- swift-argument-parser 1.6.1 (CLI argument parsing)
- Yams 6.1.0 (YAML configuration)
- swift-subprocess 0.1.0+ (process execution)
- swift-system 1.5.0 (file system operations, pinned for Ubuntu 20.04 compatibility)

**Storage**: File system only (YAML config files, git repositories)  
**Testing**: Swift Testing (Swift 6 native framework with macros)  
**Target Platform**: macOS 13+ (Ventura), Ubuntu 20.04 LTS (Focal)
**Project Type**: CLI single project with library + executable structure  
**Performance Goals**: 
- Help text display: <5 seconds
- Unit test suite: <10 seconds total
- Integration test suite: <30 seconds total
- Full CI pipeline: <10 minutes

**Constraints**: 
- No linting initially (deferred to future spec)
- Stub commands return exit code 0 with informative message
- Integration tests must use swift-system and swift-subprocess
- CI must support local testing via nektos/act

**Scale/Scope**: Bootstrap foundation only - 6 stub commands, minimal test harness, basic CI workflow

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Principle I: Spec-First Development
- ✅ spec.md created before implementation
- ✅ This is the bootstrap spec that establishes test & CI harness per constitutional requirement
- ✅ User scenarios defined with Given-When-Then acceptance criteria
- ✅ Failing tests will be written before implementation

### ✅ Principle II: Test-Driven Development
- ✅ Swift Testing framework selected for TDD
- ✅ Plan includes unit tests first, then integration tests, then implementation
- ✅ Success criteria include verifying tests fail before implementation
- ✅ All 30 functional requirements are testable

### ✅ Principle III: Small, Independent Specs
- ✅ Bootstrap spec is focused solely on foundation (CLI skeleton + test harness + CI)
- ✅ No feature implementation included - only infrastructure
- ✅ Independently testable: can verify command discovery, exit codes, test harness, CI
- ✅ Five user stories prioritized P1-P5, each independently deliverable

### ✅ Principle IV: CI & Quality Gates
- ✅ CI pipeline explicitly defined: GitHub Actions, macOS + Ubuntu, Swift 6.1
- ✅ Platform matrix specified: macOS latest, Ubuntu 20.04 LTS
- ✅ Test requirements: unit tests (<10s), integration tests (<30s), build success
- ✅ Linting deferred intentionally (not required for bootstrap foundation)
- ✅ nektos/act support for local CI testing

### ✅ Principle V: Agent Maintenance Rules
- ✅ Functional requirements FR-025 to FR-030 specify `.windsurf/rules` creation
- ✅ This bootstrap implementation triggers all five update categories:
  - Dependencies: swift-argument-parser, Yams, swift-subprocess, swift-system
  - Structure: Library + executable architecture
  - Architecture: Command pattern, test harness pattern
  - CI: GitHub Actions workflow with platform matrix
  - Major features: CLI skeleton, test foundation
- ✅ Agent MUST create `.windsurf/rules` after this spec completes

### Constitutional Compliance Summary

**Status**: ✅ PASS - All five principles satisfied

This is the bootstrap spec per Constitution Principle I requirement. It establishes the test harness and CI infrastructure that all subsequent specs will use. No constitutional violations detected.

## Project Structure

### Documentation (this feature)

```text
specs/001-cli-bootstrap/
├── spec.md              # Feature specification (completed)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (N/A for bootstrap - no domain entities)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (CLI command contracts)
├── checklists/          # Quality validation
│   └── requirements.md  # Spec quality checklist (completed)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
subtree/                                    # Repository root
├── Package.swift                           # Swift Package Manager manifest
├── Sources/
│   ├── SubtreeLib/                        # Library module (all business logic)
│   │   ├── Commands/                      # Command implementations
│   │   │   ├── SubtreeCommand.swift       # Root command with subcommands
│   │   │   ├── InitCommand.swift          # init command (stub)
│   │   │   ├── AddCommand.swift           # add command (stub)
│   │   │   ├── UpdateCommand.swift        # update command (stub)
│   │   │   ├── RemoveCommand.swift        # remove command (stub)
│   │   │   ├── ExtractCommand.swift       # extract command (stub)
│   │   │   └── ValidateCommand.swift      # validate command (stub)
│   │   └── Utilities/                     # Helper utilities
│   │       └── ExitCode.swift             # Exit code constants
│   └── subtree/                           # Executable module (thin wrapper)
│       └── main.swift                     # Entry point (calls SubtreeLib)
├── Tests/
│   ├── SubtreeLibTests/                   # Unit tests (import SubtreeLib)
│   │   ├── CommandTests.swift             # Test command presence & help
│   │   └── ExitCodeTests.swift            # Test exit code behavior
│   └── IntegrationTests/                  # Integration tests (run executable)
│       ├── TestHarness.swift              # Shared test harness utilities
│       ├── GitRepositoryFixture.swift     # Temp git repo management
│       └── CLIIntegrationTests.swift      # End-to-end CLI tests
├── .github/
│   └── workflows/
│       └── ci.yml                         # GitHub Actions CI workflow
├── .windsurf/
│   └── rules                              # Agent rules file (created by this spec)
└── README.md                              # Project documentation
```

**Structure Decision**: Library + Executable pattern selected for maximum testability.

**Rationale**:
- `SubtreeLib` contains all business logic and is fully unit-testable
- `subtree` executable is a thin wrapper that just calls SubtreeLib
- Unit tests import `SubtreeLib` directly for fast, focused testing
- Integration tests execute the `subtree` binary for end-to-end validation
- This is the Swift community standard used by SwiftLint, SwiftFormat, and SwiftPM
- Enables future programmatic use of the library without CLI overhead

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No constitutional violations detected. This section is not applicable for this bootstrap spec.

---

## Planning Summary

### Phase 0: Research ✅ COMPLETE

**Output**: `research.md`

Key decisions documented:
- Swift Testing framework for modern test ergonomics
- Library + Executable architecture for testability
- swift-system + swift-subprocess for robust operations
- GitHub Actions with nektos/act support
- Stub commands with informative messages (exit 0)
- Yams for future YAML support
- Centralized exit code definitions

### Phase 1: Design & Contracts ✅ COMPLETE

**Outputs**:
- `data-model.md` - N/A for bootstrap (no persistent entities)
- `contracts/cli-commands.md` - CLI command contracts for all 6 commands
- `quickstart.md` - Build, test, and usage guide
- `.windsurf/rules/specify-rules.md` - Agent context initialized

**Agent Context Updated**: Swift 6.1 technology added to Windsurf rules

### Constitution Check Re-evaluation ✅ PASS

After Phase 1 design, all five constitutional principles remain satisfied:
- ✅ Spec-first development maintained
- ✅ TDD approach planned in contracts
- ✅ Bootstrap spec remains small and focused
- ✅ CI gates clearly defined
- ✅ Agent rules update planned (will execute after implementation)

### Next Steps

1. **Run `/speckit.tasks`** to generate actionable task list from this plan
2. **Run `/speckit.implement`** to execute TDD implementation following tasks.md
3. **After successful implementation**: Update `.windsurf/rules` per Principle V triggers

### Key Deliverables Ready for Implementation

- ✅ 6 CLI commands specified (init, add, update, remove, extract, validate)
- ✅ Unit test contracts defined (command presence, help, exit codes)
- ✅ Integration test harness specified (temp git repos, process execution)
- ✅ CI pipeline defined (GitHub Actions, macOS + Ubuntu, Swift 6.1)
- ✅ Performance targets established (<5s help, <10s unit, <30s integration, <10m CI)
- ✅ 30 functional requirements from spec.md
- ✅ Library + Executable structure with concrete file paths

**Branch**: `001-cli-bootstrap`  
**Status**: Planning phase complete, ready for task generation and implementation  
**Constitutional Compliance**: ✅ PASS - All five principles satisfied
