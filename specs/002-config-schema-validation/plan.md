# Implementation Plan: Subtree Configuration Schema & Validation

**Branch**: `002-config-schema-validation` | **Date**: 2025-10-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-config-schema-validation/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement a comprehensive schema and validation system for subtree.yaml configuration files that enables declarative subtree management. The system validates 31 functional requirements across schema structure, type checking, logical constraints, and error reporting. Validation is format-only (no existence checks) with clear, actionable error messages. The implementation uses modular validator components organized by concern and translates YAML parsing errors to user-friendly messages.

## Technical Context

**Language/Version**: Swift 6.1  
**Primary Dependencies**: Yams 6.1.0 (YAML parsing), swift-system 1.5.0 (file operations)  
**Storage**: File-based (subtree.yaml in repository root)  
**Testing**: Swift Testing (built into Swift 6.1 toolchain)  
**Target Platform**: macOS 13+, Ubuntu 20.04 LTS
**Project Type**: Single CLI project  
**Performance Goals**: <1 second validation time for typical configs (<100 subtree entries)  
**Constraints**: Format-only validation (no network/git operations), strict schema enforcement  
**Scale/Scope**: Support configs with 1-100 subtree entries, handle files up to 1MB

### Technical Decisions from Planning

**Validation Architecture** (from planning clarification):
- Separate validator types organized by concern
- Components: `SchemaValidator`, `TypeValidator`, `FormatValidator`, `LogicValidator`
- Each validator handles specific FRs and is independently testable
- Validators coordinate through a `ConfigurationValidator` facade

**YAML Error Handling** (from planning clarification):
- Catch Yams parsing errors and translate to user-friendly messages
- Error translation maps technical parser errors to actionable guidance
- Example: "Scanner error at line 5" → "Invalid YAML syntax at line 5: unclosed string. Check for missing quotes."

**Glob Pattern Validation** (from planning clarification):
- Pattern parser approach for syntactic correctness
- Validates standard glob features: `**`, `*`, `?`, `[...]`, `{...}`
- Checks for matching braces, valid escape sequences, proper character classes
- No file system access (format-only per spec clarifications)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Spec-First Development ✅

- ✅ Feature spec exists: `specs/002-config-schema-validation/spec.md`
- ✅ User scenarios defined with Given-When-Then acceptance criteria (4 user stories, P1-P2 prioritized)
- ✅ Measurable success criteria defined (6 criteria including test coverage)
- ✅ Functional requirements are technology-agnostic (31 FRs describe behavior, not implementation)
- ✅ Bootstrap spec (001-cli-bootstrap) established test harness (Swift Testing) and CI infrastructure

### Principle II: Test-Driven Development ✅

- ✅ Acceptance criteria translate directly to tests (each FR maps to unit test)
- ✅ Test organization follows bootstrap: unit tests in SubtreeLibTests/, integration tests verify workflows
- ✅ SC-003 requires all 31 FRs have corresponding tests
- ✅ Tests will be written first, verified to fail, then implementation follows

### Principle III: Small, Independent Specs ✅

- ✅ Single feature: subtree.yaml schema and validation only
- ✅ Independently testable: validation logic can be tested without command implementation
- ✅ Deployable increment: enables future commands (add/update/remove) to use validated configs
- ✅ User stories prioritized: P1 (core validation), P2 (advanced features, documentation)
- ✅ No dependencies on incomplete specs

### Principle IV: CI & Quality Gates ✅

- ✅ Existing CI matrix from bootstrap: macOS-15, Ubuntu 20.04
- ✅ Test requirements defined: unit tests for all 31 FRs, integration tests for validation workflows
- ✅ No new CI changes needed (reuses bootstrap CI infrastructure)
- ✅ Tests must pass before merge

### Principle V: Agent Maintenance Rules ✅

- ✅ Triggers evaluation: This spec adds new dependencies (none - reuses Yams), no new architecture patterns (validation follows bootstrap patterns), no CI changes
- ⚠️ **Update required**: .windsurf/rules MUST be updated after implementation to document:
  - New SubtreeLib module: Configuration/ subdirectory for config types and validators
  - Validation architecture pattern (separate validator types)
  - Glob pattern validation approach

**GATE STATUS**: ✅ PASSED - All constitutional requirements met. Agent rules update required post-implementation.

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
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
Sources/SubtreeLib/              # Library module (all business logic)
├── Commands/                    # Existing: CLI command implementations
├── Utilities/                   # Existing: Helpers (ExitCode, etc.)
└── Configuration/               # NEW: Config schema and validation
    ├── Models/                  # Config data structures
    │   ├── SubtreeConfiguration.swift
    │   ├── SubtreeEntry.swift
    │   └── ExtractPattern.swift
    ├── Validation/              # Validators organized by concern
    │   ├── ConfigurationValidator.swift  # Facade
    │   ├── SchemaValidator.swift
    │   ├── TypeValidator.swift
    │   ├── FormatValidator.swift
    │   ├── LogicValidator.swift
    │   └── ValidationError.swift
    ├── Parsing/                 # YAML parsing and error translation
    │   ├── ConfigurationParser.swift
    │   └── YAMLErrorTranslator.swift
    └── Patterns/                # Glob pattern validation
        └── GlobPatternValidator.swift

Sources/subtree/                 # Executable (thin wrapper)
└── main.swift                   # Calls SubtreeCommand.main()

Tests/SubtreeLibTests/           # Unit tests (@testable import)
├── ConfigurationTests/          # NEW: Config validation tests
│   ├── Models/
│   │   ├── SubtreeConfigurationTests.swift
│   │   ├── SubtreeEntryTests.swift
│   │   └── ExtractPatternTests.swift
│   ├── Validation/
│   │   ├── SchemaValidatorTests.swift
│   │   ├── TypeValidatorTests.swift
│   │   ├── FormatValidatorTests.swift
│   │   ├── LogicValidatorTests.swift
│   │   └── ValidationErrorTests.swift
│   ├── Parsing/
│   │   ├── ConfigurationParserTests.swift
│   │   └── YAMLErrorTranslatorTests.swift
│   └── Patterns/
│       └── GlobPatternValidatorTests.swift
└── [Existing test files...]

Tests/IntegrationTests/          # Integration tests (run binary)
├── ConfigValidationIntegrationTests.swift  # NEW: End-to-end validation
└── [Existing test files...]
```

**Structure Decision**: Single CLI project (Option 1) extended with Configuration/ subdirectory in SubtreeLib. This follows the Library + Executable pattern established in bootstrap spec 001. All configuration logic resides in SubtreeLib for testability and future programmatic use. The modular validator structure (separate types by concern) enables independent testing of each validation category.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations** - Design maintains constitutional simplicity

---

## Post-Design Constitution Check ✅

**Re-evaluated**: 2025-10-26 after Phase 1 design completion

### Principle I: Spec-First Development ✅
- ✅ Design artifacts (data-model.md, contracts/) align with spec requirements
- ✅ No implementation details added beyond what spec requires
- ✅ All 31 FRs remain testable and technology-agnostic

### Principle II: Test-Driven Development ✅
- ✅ Test structure documented in quickstart.md (31+ unit tests, integration tests)
- ✅ Validation checkpoints defined for incremental TDD
- ✅ Each FR maps to specific test case

### Principle III: Small, Independent Specs ✅
- ✅ Design remains focused on validation only
- ✅ No scope creep beyond original spec
- ✅ Independently deployable (enables future command implementations)

### Principle IV: CI & Quality Gates ✅
- ✅ No new CI requirements (reuses bootstrap infrastructure)
- ✅ Test coverage expectations defined (40-50 tests total)
- ✅ Performance benchmarks specified (<1 second validation)

### Principle V: Agent Maintenance Rules ✅
- ✅ Agent context updated via update-agent-context.sh
- ✅ New context file created: .windsurf/rules/specify-rules.md
- ⚠️ **Action required post-implementation**: Update .windsurf/rules/bootstrap.md with Configuration/ module details

**GATE STATUS**: ✅ PASSED - Design maintains constitutional compliance. Ready for Phase 2 (task generation via /speckit.tasks).

---

## Phase Summary

### Phase 0: Research ✅
- **Output**: [research.md](./research.md)
- **Decisions**: Validator architecture, YAML error handling, glob validation, path safety
- **Status**: Complete - all unknowns resolved

### Phase 1: Design ✅
- **Outputs**: 
  - [data-model.md](./data-model.md) - Entity definitions and validation rules
  - [contracts/yaml-schema.md](./contracts/yaml-schema.md) - YAML structure contract
  - [contracts/validation-error-format.md](./contracts/validation-error-format.md) - Error message contract
  - [quickstart.md](./quickstart.md) - Build, test, and validation guide
  - .windsurf/rules/specify-rules.md - Agent context (auto-generated)
- **Status**: Complete - design artifacts ready

### Phase 2: Tasks (Not Started)
- **Next Step**: Run `/speckit.tasks` to generate tasks.md
- **Will Produce**: Dependency-ordered task breakdown for implementation

---

## Implementation Ready

All planning phases complete. The feature is ready for task generation and implementation.

**Branch**: 002-config-schema-validation  
**Artifacts Generated**:
- ✅ plan.md (this file)
- ✅ research.md
- ✅ data-model.md
- ✅ contracts/yaml-schema.md
- ✅ contracts/validation-error-format.md
- ✅ quickstart.md
- ✅ .windsurf/rules/specify-rules.md (auto-generated)

**Next Command**: `/speckit.tasks` to generate implementation tasks
