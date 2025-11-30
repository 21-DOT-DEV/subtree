# Implementation Plan: Multi-Destination Extraction (Fan-Out)

**Branch**: `012-multi-destination-extraction` | **Date**: 2025-11-30 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/012-multi-destination-extraction/spec.md`

## Summary

Enable multiple `--to` destination flags in a single extract command, with YAML config supporting both string (legacy) and array (new) formats. Files matching source patterns are copied to EVERY destination (fan-out semantics). Implementation mirrors 009-multi-pattern-extraction: `to` changes from `String` to `[String]` internally with custom `Codable` for backward compatibility.

## Technical Context

**Language/Version**: Swift 6.1  
**Primary Dependencies**: swift-argument-parser 1.6.1, Yams 6.1.0  
**Storage**: YAML config file (`subtree.yaml`)  
**Testing**: Swift Testing (built into Swift 6.1 toolchain)  
**Target Platform**: macOS 13+, Ubuntu 20.04 LTS  
**Project Type**: CLI (Library + Executable pattern)  
**Performance Goals**: Multi-destination extraction <5 seconds for ≤100 files × ≤5 destinations  
**Constraints**: Backward compatible with existing single-destination configs  
**Scale/Scope**: Soft limit 10 destinations (warn above, still allow)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First & TDD | ✅ | Spec complete (17 FRs, 6 clarifications), tests written per user story |
| II. Config as Source of Truth | ✅ | Extends subtree.yaml schema, backward compatible |
| III. Safe by Default | ✅ | Fail-fast validation, existing --force gates preserved |
| IV. Performance by Default | ✅ | <5s target for typical extractions |
| V. Security & Privacy | ✅ | No new shell invocations, reuses existing safe patterns |
| VI. Open Source Excellence | ✅ | KISS (mirrors 009 pattern), DRY (reuses extraction infrastructure) |

**Legend**: ✅ Pass | ⬜ Not yet verified | ❌ Violation (requires justification)

## Project Structure

### Documentation (this feature)

```text
specs/012-multi-destination-extraction/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file
├── research.md          # Phase 0 output (009 pattern analysis)
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
│   │   └── ExtractCommand.swift       # MODIFY: Accept multiple --to flags, fan-out logic
│   ├── Configuration/
│   │   ├── ExtractionMapping.swift    # MODIFY: Union type for to field (mirror from)
│   │   └── Models/
│   │       └── SubtreeEntry.swift     # No changes
│   └── Utilities/
│       ├── ConfigFileManager.swift    # MODIFY: Handle array format for to in persist
│       ├── PathNormalizer.swift       # ADD: Normalize trailing slash + ./
│       └── GlobMatcher.swift          # No changes
└── subtree/                           # Executable (no changes)

Tests/
├── SubtreeLibTests/
│   ├── ExtractionMappingTests.swift   # MODIFY: Add tests for to array parsing
│   └── PathNormalizerTests.swift      # ADD: Unit tests for normalization
└── IntegrationTests/
    └── ExtractMultiDestTests.swift    # ADD: Integration tests per user story
```

**Structure Decision**: Extends existing Library + Executable pattern. Changes mirror 009-multi-pattern-extraction: modify `ExtractionMapping.swift` (data model), `ExtractCommand.swift` (CLI + fan-out), and `ConfigFileManager.swift` (persistence). New `PathNormalizer.swift` utility for destination deduplication.

## Implementation Phases

### Phase 1: Data Model + CLI + Persist (Mechanical — Reuse 009)

**Goal**: Core multi-destination functionality

**User Stories**: US1 (Multiple CLI Destinations), US2 (Persist Multi-Destination)

**Scope**:
- Modify `ExtractionMapping` with `to: [String]` internally (mirror `from`)
- Modify `ExtractCommand` to accept repeated `--to` flags
- Add `PathNormalizer` for destination deduplication
- Update extraction loop to copy to each destination
- Modify `ConfigFileManager` for array persist format
- Unit tests for parsing, integration tests for CLI

### Phase 2: Behavioral Integration (New Logic)

**Goal**: Fail-fast, clean mode, bulk mode integration

**User Stories**: US3 (Clean Mode), US4 (Fail-Fast), US5 (Bulk Mode)

**Scope**:
- Upfront validation across ALL destinations before any writes
- Aggregate conflict errors across destinations
- Clean mode support for multi-destination
- Per-destination progress output (FR-017)
- Soft limit warning for >10 destinations (FR-016)
- Integration tests for behavioral scenarios

## Complexity Tracking

No constitution violations. All changes extend existing patterns established in 009.
