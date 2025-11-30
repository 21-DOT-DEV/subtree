# Implementation Plan: Extract Clean Mode

**Branch**: `010-extract-clean` | **Date**: 2025-11-29 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/010-extract-clean/spec.md`

## Summary

Add `--clean` flag to the existing `ExtractCommand` that removes previously extracted files from destination directories. Uses `git hash-object` for checksum validation to prevent accidental deletion of modified files. Supports ad-hoc patterns, bulk mode (persisted mappings), and `--force` override. Empty directories are pruned after file removal using a batch post-process approach.

## Technical Context

**Language/Version**: Swift 6.1  
**Primary Dependencies**: swift-argument-parser 1.6.1, Yams 6.1.0, swift-subprocess  
**Storage**: subtree.yaml (existing config format)  
**Testing**: Swift Testing (built into Swift 6.1)  
**Target Platform**: macOS 13+, Ubuntu 20.04 LTS  
**Project Type**: Single CLI tool (library + executable)  
**Performance Goals**: <3 seconds for 10-50 files (per spec SC-001)  
**Constraints**: Checksum validation before each deletion, atomic per-mapping in bulk mode  
**Scale/Scope**: Typical file sets of 10-50 files per extraction mapping

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First & TDD | ✅ | Spec complete with 9 clarifications, tests written first |
| II. Config as Source of Truth | ✅ | Uses existing subtree.yaml extraction mappings |
| III. Safe by Default | ✅ | Checksum validation default, `--force` gates destructive ops |
| IV. Performance by Default | ✅ | <3s target, batch directory pruning for efficiency |
| V. Security & Privacy | ✅ | Uses git hash-object (no shell interpolation), path validation |
| VI. Open Source Excellence | ✅ | Extends existing command, KISS approach, clear error messages |

## Project Structure

### Documentation (this feature)

```text
specs/010-extract-clean/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (CLI contract)
├── checklists/          # Quality checklists
│   └── requirements.md  # Spec quality validation (complete)
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
Sources/
├── SubtreeLib/
│   ├── Commands/
│   │   └── ExtractCommand.swift    # MODIFY: Add --clean flag + clean logic
│   ├── Configuration/
│   │   └── SubtreeConfiguration.swift  # (no changes needed)
│   └── Utilities/
│       ├── GitOperations.swift     # MODIFY: Add hashObject() method
│       └── DirectoryPruner.swift   # NEW: Batch empty directory pruning
└── subtree/
    └── EntryPoint.swift            # (no changes)

Tests/
├── IntegrationTests/
│   └── ExtractCleanIntegrationTests.swift  # NEW: Clean mode integration tests
└── SubtreeLibTests/
    ├── Commands/
    │   └── ExtractCleanTests.swift         # NEW: Clean mode unit tests
    └── Utilities/
        ├── GitOperationsHashTests.swift    # NEW: hashObject() tests
        └── DirectoryPrunerTests.swift      # NEW: Pruning logic tests
```

**Structure Decision**: Extends existing ExtractCommand (Option A from planning questions) to maintain CLI consistency. New utility `DirectoryPruner` for batch pruning logic (Option B from planning questions). `hashObject()` added to existing `GitOperations` (Option A from planning questions).

## Key Architecture Decisions

### 1. ExtractCommand Extension (not separate command)

**Decision**: Add `--clean` flag to existing `ExtractCommand`  
**Rationale**: 
- Maintains CLI symmetry (`extract` vs `extract --clean`)
- Reuses existing argument definitions (`--name`, `--from`, `--to`, `--force`, `--exclude`)
- Consistent with user mental model (extraction operations in one place)

### 2. Checksum via GitOperations.hashObject()

**Decision**: Add `hashObject(file:)` to `GitOperations.swift`  
**Rationale**:
- `git hash-object` is a git operation (like existing `isFileTracked`)
- Consolidates git-related utilities
- Enables reuse across commands if needed

### 3. Batch Directory Pruning

**Decision**: Collect parent directories during deletion, prune in single pass (deepest first)  
**Rationale**:
- Efficient (avoids repeated directory checks)
- Handles shared parent directories correctly
- Bottom-up traversal ensures proper pruning order

## Complexity Tracking

No constitution violations requiring justification.
