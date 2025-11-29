# Phase 3 — Advanced Operations & Safety

**Status:** ACTIVE  
**Last Updated:** 2025-11-27

## Goal

Enable portable configuration validation, selective file extraction with comprehensive safety features, and configuration integrity checking.

## Key Features

### 1. Case-Insensitive Names & Validation ✅ COMPLETE

- **Purpose & user value**: Enables flexible name matching for all commands (add, remove, update) while preventing duplicate names/prefixes across case variations, ensuring configs work portably across macOS (case-insensitive) and Linux (case-sensitive) filesystems
- **Success metrics**:
  - Users can remove/update subtrees without remembering exact case (e.g., `remove hello-world` matches `Hello-World`)
  - 100% of case-variant duplicate names detected during add
  - 100% of case-variant duplicate prefixes detected during add
  - Configs portable across all platforms
- **Dependencies**: Add Command, Remove Command, Update Command
- **Notes**: Case-insensitive lookup for name matching, case-insensitive duplicate validation, stores original case in config

### 2. Extract Command ✅ COMPLETE

- **Purpose & user value**: Copies files from subtrees to project structure using glob patterns with smart overwrite protection, enabling selective integration of upstream files without manual copying
- **Success metrics**:
  - Ad-hoc extraction completes in <3 seconds for typical file sets
  - Glob patterns match expected files with 100% accuracy
  - Git-tracked files protected unless `--force` explicitly used
- **Dependencies**: Add Command
- **Notes**: Supports ad-hoc (`--from/--to`) and bulk (`--all`) modes, `--persist` for saving mappings, `--force` for overrides, directory structure preserved
- **Delivered**: All 5 user stories (ad-hoc extraction, persistent mappings, bulk execution, overwrite protection, validation & errors), 411 tests passing

### 3. Multi-Pattern Extraction ⏳ NEXT

- **Purpose & user value**: Allows specifying multiple glob patterns in a single extraction, enabling users to gather files from multiple source directories (e.g., both `include/` and `src/`) into one destination without running multiple commands
- **Success metrics**:
  - Users can specify multiple `--from` patterns in single command
  - YAML config supports both string (legacy) and array (new) formats for backward compatibility
  - Global `--exclude` patterns apply to all source patterns
  - 100% backward compatible with existing single-pattern extractions
- **Dependencies**: Extract Command
- **Notes**: 
  - CLI: Repeated `--from` flags (native swift-argument-parser support)
  - YAML: Both `from: "pattern"` and `from: ["pattern1", "pattern2"]` supported
  - Excludes are global (apply to all patterns)

### 4. Extract Clean Mode ⏳ PLANNED

- **Purpose & user value**: Removes previously extracted files from destination based on source glob patterns, enabling users to clean up extracted files when no longer needed or before re-extraction with different patterns
- **Success metrics**:
  - Files removed only when checksum matches source (safety by default)
  - `--force` flag overrides checksum validation
  - Empty directories pruned after file removal
  - Works with both ad-hoc patterns and persisted mappings (bulk mode parity)
- **Dependencies**: Extract Command, Multi-Pattern Extraction
- **Notes**:
  - `--clean` flag triggers removal mode (opposite of extraction)
  - Pattern matches files in source (subtree) directory
  - Corresponding files removed from destination directory
  - Checksum validation prevents accidental deletion of modified files
  - Bulk mode: `extract --clean --name foo` cleans all persisted mappings

### 5. Lint Command ⏳ PLANNED

- **Purpose & user value**: Validates subtree integrity and synchronization state offline and with remote checks, enabling users to detect configuration drift, missing subtrees, or desync between config and repository state
- **Success metrics**:
  - Offline validation completes in <2 seconds
  - 100% of config/repository mismatches detected and reported clearly
  - Repair mode fixes discrepancies without manual intervention
  - Remote validation detects divergence from upstream within 10 seconds
- **Dependencies**: Add Command
- **Notes**: Renamed from "validate" for clarity, offline mode (commit hash checks), `--with-remote` for upstream comparison, `--repair` mode

## Dependencies & Sequencing

- **Local ordering**: 
  1. Case-Insensitive Names ✅
  2. Extract Command ✅
  3. Multi-Pattern Extraction ⏳ (next)
  4. Extract Clean Mode ⏳ (after multi-pattern, leverages array patterns)
  5. Lint Command ⏳ (final Phase 3 feature)
- **Rationale**: Multi-pattern extraction is simpler and immediately useful; Clean mode benefits from multi-pattern support; Lint validates all previous operations
- **Cross-phase dependencies**: Requires Phase 2 Add Command for subtrees to exist

## Phase-Specific Metrics & Success Criteria

This phase is successful when:
- All five features complete and tested
- Extract supports multiple patterns and cleanup operations
- Lint provides comprehensive integrity validation
- 450+ tests pass on macOS and Ubuntu

## Risks & Assumptions

- **Assumptions**: Users understand glob pattern syntax
- **Risks & mitigations**: 
  - Glob complexity → clear pattern validation errors, consider dry-run mode
  - Accidental file deletion → checksum validation + `--force` gate

## Phase Notes

- 2025-11-27: Added Multi-Pattern Extraction and Extract Clean Mode features before Lint Command
- 2025-10-29: Case-Insensitive Names added to Phase 3
- 2025-10-28: Extract Command completed with 411 tests
