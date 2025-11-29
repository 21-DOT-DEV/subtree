# Implementation Plan: Multi-Pattern Extraction

**Branch**: `009-multi-pattern-extraction` | **Date**: 2025-11-28 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/009-multi-pattern-extraction/spec.md`

## Summary

Enable multiple `--from` glob patterns in a single extract command, with YAML config supporting both string (legacy) and array (new) formats. Patterns are processed as a union — files matching ANY pattern are extracted. Implementation uses a union type with custom `Codable` decoding to maintain backward compatibility.

## Technical Context

**Language/Version**: Swift 6.1  
**Primary Dependencies**: swift-argument-parser 1.6.1, Yams 6.1.0  
**Storage**: YAML config file (`subtree.yaml`)  
**Testing**: Swift Testing (built into Swift 6.1 toolchain)  
**Target Platform**: macOS 13+, Ubuntu 20.04 LTS  
**Project Type**: CLI (Library + Executable pattern)  
**Performance Goals**: Multi-pattern extraction <5 seconds for ≤100 files  
**Constraints**: Backward compatible with existing single-pattern configs  
**Scale/Scope**: Support 10+ patterns efficiently

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First & TDD | ✅ | Spec complete (13 FRs), tests written per user story |
| II. Config as Source of Truth | ✅ | Extends subtree.yaml schema, backward compatible |
| III. Safe by Default | ✅ | Non-destructive (copy only), existing --force gates preserved |
| IV. Performance by Default | ✅ | <5s target for typical extractions |
| V. Security & Privacy | ✅ | No new shell invocations, reuses existing safe patterns |
| VI. Open Source Excellence | ✅ | KISS (extends existing types), DRY (reuses GlobMatcher) |

**Legend**: ✅ Pass | ⬜ Not yet verified | ❌ Violation (requires justification)

## Project Structure

### Documentation (this feature)

```text
specs/009-multi-pattern-extraction/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (CLI contract)
├── checklists/          # Quality checklists
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
Sources/
├── SubtreeLib/                        # Library (all business logic)
│   ├── Commands/
│   │   └── ExtractCommand.swift       # MODIFY: Accept multiple --from flags
│   ├── Configuration/
│   │   ├── ExtractionMapping.swift    # MODIFY: Union type for from field
│   │   └── Models/
│   │       └── SubtreeEntry.swift     # No changes (already uses [ExtractionMapping])
│   └── Utilities/
│       ├── ConfigFileManager.swift    # MODIFY: Handle array format for persist
│       └── GlobMatcher.swift          # No changes (reuse existing)
└── subtree/                           # Executable (no changes)

Tests/
├── SubtreeLibTests/
│   └── ExtractionMappingTests.swift   # ADD: Unit tests for union type parsing
└── IntegrationTests/
    └── ExtractMultiPatternTests.swift # ADD: Integration tests per user story
```

**Structure Decision**: Extends existing Library + Executable pattern. Changes are minimal and focused on three files: `ExtractionMapping.swift` (data model), `ExtractCommand.swift` (CLI), and `ConfigFileManager.swift` (persistence).

## Implementation Phases

### Phase 1: P1 User Stories (CLI + YAML)

**Goal**: Core multi-pattern functionality

**User Stories**: US1 (Multiple CLI Patterns), US2 (Backward Compatible YAML)

**Scope**:
- Modify `ExtractionMapping` with union type (`String | [String]`)
- Modify `ExtractCommand` to accept repeated `--from` flags
- Update extraction logic to process patterns as union
- Unit tests for parsing, integration tests for CLI

### Phase 2: P2 User Stories (Persist + Excludes)

**Goal**: Persistence and exclude integration

**User Stories**: US3 (Persist Multiple Patterns), US4 (Global Excludes)

**Scope**:
- Modify `ConfigFileManager.appendExtraction` for array format
- Verify excludes apply globally (may already work)
- Integration tests for persist and exclude scenarios

### Phase 3: P3 User Stories (Warnings)

**Goal**: UX polish

**User Stories**: US5 (Zero-Match Warning)

**Scope**:
- Add per-pattern match tracking
- Display warnings for zero-match patterns
- Integration tests for warning scenarios

## Complexity Tracking

No constitution violations. All changes extend existing patterns.
