# Implementation Plan: Brace Expansion with Embedded Path Separators

**Branch**: `011-brace-expansion` | **Date**: 2025-11-29 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/011-brace-expansion/spec.md`

## Summary

Extend the existing brace expansion syntax to support embedded path separators (e.g., `{a,b/c}`) by implementing a `BraceExpander` utility that pre-expands patterns BEFORE they reach GlobMatcher. This addresses the limitation where patterns like `Sources/{A,B/C}.swift` fail because GlobMatcher splits patterns by `/` before processing braces.

**Technical Approach**: Create a standalone `BraceExpander` utility in `Sources/SubtreeLib/Utilities/` that expands brace patterns following bash semantics (cartesian product for multiple groups). Integrate into `ExtractCommand` to expand `--from` and `--exclude` patterns before passing to file matching logic.

## Technical Context

**Language/Version**: Swift 6.1  
**Primary Dependencies**: swift-argument-parser 1.6.1, Foundation (no new dependencies)  
**Storage**: N/A (pure string transformation)  
**Testing**: Swift Testing (built into Swift 6.1 toolchain)  
**Target Platform**: macOS 13+, Ubuntu 20.04 LTS  
**Project Type**: Single CLI project (Library + Executable pattern)  
**Performance Goals**: <10ms for typical patterns (per NFR-001: ≤10 alternatives, ≤3 brace groups)  
**Constraints**: 100% backward compatible with existing patterns  
**Scale/Scope**: Pattern expansion only; no filesystem access in BraceExpander

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First & TDD | ✅ | Spec complete, tests will be written first per TDD |
| II. Config as Source of Truth | ✅ | N/A — brace expansion is CLI pattern syntax, not config |
| III. Safe by Default | ✅ | Invalid patterns passed through unchanged; error only on empty alternatives |
| IV. Performance by Default | ✅ | <10ms target; warn at 100+ expanded patterns |
| V. Security & Privacy | ✅ | No shell execution; pure string manipulation |
| VI. Open Source Excellence | ✅ | KISS: single utility class, bash-compatible semantics |

**Legend**: ✅ Pass | ⬜ Not yet verified | ❌ Violation (requires justification)

## Project Structure

### Documentation (this feature)

```text
specs/011-brace-expansion/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── brace-expander-contract.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
Sources/
├── SubtreeLib/
│   ├── Commands/
│   │   └── ExtractCommand.swift    # Integration point (expand patterns before matching)
│   └── Utilities/
│       ├── GlobMatcher.swift       # Existing (unchanged)
│       └── BraceExpander.swift     # NEW: Pattern pre-expansion utility
└── subtree/
    └── EntryPoint.swift            # Unchanged

Tests/
├── SubtreeLibTests/
│   └── Utilities/
│       ├── GlobMatcherTests.swift  # Existing (unchanged)
│       └── BraceExpanderTests.swift # NEW: Unit tests
└── IntegrationTests/
    └── ExtractIntegrationTests.swift # Add brace expansion integration tests
```

**Structure Decision**: Follows existing Library + Executable pattern. BraceExpander added to `Utilities/` alongside GlobMatcher. Integration in ExtractCommand keeps the change localized.

## Design Decisions

### Integration Point
- **Decision**: Expand patterns inside `ExtractCommand` before calling file matching logic
- **Rationale**: Keeps GlobMatcher unchanged; localizes changes to extract flow
- **Alternatives Rejected**: Modifying GlobMatcher would risk regressions in well-tested code

### Testing Strategy
- **Decision**: Unit tests for BraceExpander + integration tests for ExtractCommand
- **Rationale**: Matches project's two-layer testing pattern (SubtreeLibTests + IntegrationTests)
- **Test Coverage**: Edge cases (empty, malformed, nested), cartesian product, embedded separators

### API Design
- **Decision**: `func expand(_ pattern: String) throws -> [String]` with `BraceExpanderError`
- **Rationale**: Matches existing GlobMatcherError pattern; clear error handling for empty alternatives
- **Error Cases**: `.emptyAlternative(pattern:)` for `{a,}`, `{,b}`, `{a,,b}`

## Complexity Tracking

> No violations — feature is straightforward utility addition.
