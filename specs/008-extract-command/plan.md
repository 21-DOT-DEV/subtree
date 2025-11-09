# Implementation Plan: Extract Command

**Branch**: `008-extract-command` | **Date**: 2025-10-31 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/008-extract-command/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement Extract command to copy files from added subtrees to project structure using glob patterns with smart overwrite protection. Supports ad-hoc extraction with optional persistence to config, bulk execution of saved mappings, git-aware file protection, and exclusion patterns. Technical approach uses cross-platform FileManager with Swift pattern matching for glob support, extends existing GitOperations for file tracking checks, and reuses ConfigFileManager for atomic config updates.

## Technical Context

**Language/Version**: Swift 6.1  
**Primary Dependencies**: swift-argument-parser 1.6.1 (CLI), Yams 6.1.0 (YAML), swift-subprocess 0.1.0+ (process execution), swift-system 1.5.0 (file operations)  
**Storage**: subtree.yaml configuration file (YAML format)  
**Testing**: Swift Testing (Swift 6 native framework with @Test/@Suite macros)  
**Target Platform**: macOS 13+, Ubuntu 20.04 LTS (future Windows support planned via cross-platform approach)
**Project Type**: Single project (CLI tool with library + executable pattern)  
**Performance Goals**: Ad-hoc extraction <3 seconds for 10-50 files, glob matching 100% accuracy, pattern validation <1 second  
**Constraints**: No git staging (manual only), git-tracked files protected by default, zero-match patterns must error, strict validation  
**Scale/Scope**: Typical usage: 5-20 subtrees per repo, 3-10 extraction mappings per subtree, 10-100 files per extraction

**Key Design Decisions** (from clarification session):
1. **Glob matching**: FileManager + Swift pattern matching (cross-platform, no Unix dependency for future Windows support)
2. **Git status checks**: Extend existing GitOperations utility with `isFileTracked()` method
3. **Config updates**: Reuse ConfigFileManager with new `appendExtraction()` method for atomic array operations

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Spec-First Development
**Status**: ✅ PASS

- Spec.md exists with complete user scenarios (5 stories, P1-P5)
- Acceptance criteria defined in Given-When-Then format
- 39 functional requirements (technology-agnostic)
- 8 measurable success criteria
- 5 clarifications documented

### Principle II: Test-Driven Development
**Status**: ✅ PASS

- Acceptance scenarios defined for all 5 user stories
- Integration tests required for each priority level
- Unit tests required for utilities (glob matching, git status, config updates)
- Contract tests required for CLI interface
- TDD discipline: tests before implementation

### Principle III: Small, Independent Specs
**Status**: ✅ PASS

- Single feature: Extract command only
- Independently testable (no incomplete dependencies)
- Depends only on Add Command (already complete per agents.md)
- User stories prioritized and independently implementable
- Scope bounded: file extraction only, no git commits

### Principle IV: CI & Quality Gates
**Status**: ✅ PASS

- Existing CI pipeline: GitHub Actions (macOS-15 + Ubuntu 20.04)
- Tests will run on both platforms
- Integration into existing test suite (SubtreeLibTests, IntegrationTests)
- CI badge in README.md tracks status
- No merge until green

### Principle V: Agent Maintenance Rules
**Status**: ⚠️ REVIEW REQUIRED (post-implementation)

**Update triggers for .windsurf/rules after implementation**:
1. ✅ Major feature area: New Extract command (6th command in CLI)
2. ✅ Project dependencies: None added (reuses existing)
3. ✅ Directory structure: Potential new utilities (GlobMatcher, ExtractionMapping model)
4. ✅ Architecture patterns: Config schema extension (extractions array)
5. ⏳ CI/CD pipeline: No changes expected

**Required updates**:
- Add Extract command to feature list
- Document extraction mappings in config schema
- Add glob pattern utilities to utilities section

### Overall Gate Status
**✅ ALL GATES PASS** - Proceed with Phase 0 research

---

## Post-Design Constitution Re-Check

*Re-evaluated after Phase 1 (Design & Contracts) completion*

### Principle I: Spec-First Development
**Status**: ✅ PASS (Unchanged)

- Design artifacts created: research.md, data-model.md, contracts/, quickstart.md
- All design decisions traced back to spec requirements
- No implementation details added without spec justification

### Principle II: Test-Driven Development
**Status**: ✅ PASS (Enhanced)

- quickstart.md provides TDD workflow with concrete first tests
- Test organization documented (unit + integration)
- Test pyramid defined: 140 new tests (20 integration, 120 unit)

### Principle III: Small, Independent Specs
**Status**: ✅ PASS (Unchanged)

- Scope remains bounded: Extract command only
- Dependencies still limited to completed Add command
- Design decisions support independent testability

### Principle IV: CI & Quality Gates
**Status**: ✅ PASS (Unchanged)

- No changes to CI pipeline required
- Tests will integrate into existing suite
- Local validation commands documented in quickstart.md

### Principle V: Agent Maintenance Rules
**Status**: ✅ PASS (Action Required Post-Implementation)

**Agent context updated**: `.windsurf/rules/specify-rules.md` created with:
- Language: Swift 6.1
- Frameworks: swift-argument-parser, Yams, swift-subprocess, swift-system
- Database: subtree.yaml (YAML format)
- Project type: Single project (CLI tool with library + executable pattern)

**Pending post-implementation**:
- Update .windsurf/rules/ with Extract command feature area
- Document ExtractionMapping in config schema section
- Add GlobMatcher to utilities section

### Overall Post-Design Gate Status
**✅ ALL GATES PASS** - Ready for implementation (Phase 2)

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
├── SubtreeLib/                 # Library module (all business logic)
│   ├── Commands/
│   │   ├── SubtreeCommand.swift
│   │   ├── InitCommand.swift
│   │   ├── AddCommand.swift
│   │   ├── UpdateCommand.swift
│   │   ├── RemoveCommand.swift
│   │   └── ExtractCommand.swift     # NEW: This feature
│   ├── Configuration/
│   │   ├── SubtreeConfig.swift
│   │   ├── SubtreeEntry.swift
│   │   └── ExtractionMapping.swift  # NEW: This feature
│   └── Utilities/
│       ├── ExitCode.swift
│       ├── GitOperations.swift      # EXTEND: Add isFileTracked()
│       ├── ConfigFileManager.swift  # EXTEND: Add appendExtraction()
│       ├── GlobMatcher.swift        # NEW: This feature
│       └── PathValidator.swift      # EXISTING: Reuse for destination validation
└── subtree/                    # Executable module (thin wrapper)
    └── EntryPoint.swift

Tests/
├── SubtreeLibTests/            # Unit tests
│   ├── Commands/
│   │   └── ExtractCommandTests.swift      # NEW: This feature
│   ├── ConfigurationTests/
│   │   └── ExtractionMappingTests.swift   # NEW: This feature
│   └── Utilities/
│       ├── GitOperationsTests.swift       # EXTEND: Test isFileTracked()
│       ├── ConfigFileManagerTests.swift   # EXTEND: Test appendExtraction()
│       └── GlobMatcherTests.swift         # NEW: This feature
└── IntegrationTests/           # Integration tests
    ├── ExtractIntegrationTests.swift      # NEW: This feature
    ├── GitRepositoryFixture.swift         # EXISTING: Reuse
    └── TestHarness.swift                  # EXISTING: Reuse
```

**Structure Decision**: Single project using Library + Executable pattern (Swift standard for CLI tools). All business logic in SubtreeLib for testability, thin wrapper in subtree executable. Extract command integrates into existing structure by adding new command class, new config model (ExtractionMapping), and new utility (GlobMatcher), while extending existing utilities (GitOperations, ConfigFileManager).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations** - All constitutional gates pass. No complexity justification required.

---

## Planning Summary

**Planning completed**: 2025-10-31  
**Branch**: `008-extract-command`  
**Status**: ✅ Ready for implementation

### Artifacts Generated

**Phase 0 (Research)**:
- ✅ [research.md](./research.md) - 5 technical decisions documented with rationale

**Phase 1 (Design & Contracts)**:
- ✅ [data-model.md](./data-model.md) - Entity definitions, validation rules, relationships
- ✅ [contracts/extract-command-contract.md](./contracts/extract-command-contract.md) - Complete CLI interface specification
- ✅ [quickstart.md](./quickstart.md) - TDD workflow and implementation guide
- ✅ `.windsurf/rules/specify-rules.md` - Agent context updated

### Key Technical Decisions

1. **Glob Matching**: FileManager + custom Swift pattern matcher (cross-platform, future Windows support)
2. **Git Status**: Extend GitOperations utility with `isFileTracked()` method
3. **Config Updates**: Extend ConfigFileManager with `appendExtraction()` for atomic operations
4. **Symlinks**: Follow symlinks (copy target content, ensures self-contained extractions)
5. **Exclude Patterns**: Separate `exclude` array with glob patterns (rsync-style)

### Implementation Scope

**New components**:
- ExtractCommand (CLI command)
- ExtractionMapping (config model)
- GlobMatcher (pattern matching utility)

**Extended components**:
- SubtreeEntry (+ optional extractions array)
- GitOperations (+ isFileTracked method)
- ConfigFileManager (+ appendExtraction method)

**Test requirements**: ~140 new tests (20 integration, 120 unit)

### Constitutional Compliance

✅ **All 5 principles pass** pre-design and post-design checks:
- I. Spec-First Development
- II. Test-Driven Development
- III. Small, Independent Specs
- IV. CI & Quality Gates
- V. Agent Maintenance Rules

### Next Steps

1. **Proceed with implementation** following [quickstart.md](./quickstart.md) TDD workflow
2. **Create tasks.md** using `/speckit.tasks` command (generates detailed task breakdown)
3. **Update .windsurf/rules/** after successful implementation (per Constitution Principle V)

**Recommended workflow**:
```bash
# Generate task breakdown
/speckit.tasks

# Start implementation (TDD workflow in quickstart.md)
# Phase 1: Configuration Model
# Phase 2: Extend SubtreeEntry  
# Phase 3: Glob Pattern Matching
# Phase 4: Git Status Checking
# Phase 5: Config Manager Extension
# Phase 6: Extract Command CLI
```

---

**Planning Complete** - Implementation-ready design with comprehensive testing strategy
