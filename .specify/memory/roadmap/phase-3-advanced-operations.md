# Phase 3 — Advanced Operations & Safety

**Status:** ACTIVE  
**Last Updated:** 2025-11-30

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

### 3. Multi-Pattern Extraction ✅ COMPLETE

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
  - Zero-match warnings for patterns that don't match any files
  - Full relative path preservation (industry standard)
- **Delivered**: All 5 user stories (multiple CLI patterns, backward-compatible YAML, persist arrays, global excludes, zero-match warnings), 439 tests passing

### 4. Extract Clean Mode ✅ COMPLETE

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
  - Checksum validation via `git hash-object` prevents accidental deletion of modified files
  - Bulk mode: `extract --clean --name foo` or `--clean --all` for all subtrees
  - Continue-on-error for bulk operations with failure summary
- **Delivered**: All 5 user stories (ad-hoc clean, force override, bulk clean, multi-pattern, error handling), 477 tests passing

### 5. Brace Expansion: Embedded Path Separators ✅ COMPLETE

- **Purpose & user value**: Extends existing brace expansion (`*.{h,c}`) to support embedded path separators (e.g., `Sources/{A,B/C}.swift`), enabling extraction from directories at different depths with a single pattern
- **Success metrics**:
  - Patterns like `Sources/{A,B/C}.swift` correctly match files at different directory depths
  - Multiple brace groups expand as cartesian product (bash behavior)
  - 100% backward compatible with existing patterns
- **Dependencies**: Multi-Pattern Extraction, Extract Command (existing GlobMatcher)
- **Notes**:
  - GlobMatcher already supports basic `{a,b}` for extensions; this adds pre-expansion for path separators
  - Pre-expansion at CLI level via `BraceExpander` utility (bash semantics)
  - Only applies to `--from` and `--exclude` patterns (`--to` is destination path, not glob)
  - Example: `Sources/Crypto/{PrettyBytes,SecureBytes,BoringSSL/RNG_boring}.swift` → 3 patterns
  - Nested braces, escaping, numeric ranges deferred to backlog
- **Delivered**: All 4 user stories (basic expansion, multiple groups, pass-through, empty alternative errors), 526 tests passing

### 6. Multi-Destination Extraction (Fan-Out) ⏳ PLANNED

- **Purpose & user value**: Allows extracting matched files to multiple destinations simultaneously (e.g., `--to Lib/ --to Vendor/`), enabling distribution of extracted files to multiple locations without repeated commands
- **Success metrics**:
  - Multiple `--to` flags supported in single command
  - Each matched file copied to every `--to` destination (fan-out)
  - `--from` and `--to` counts independent (no positional pairing)
  - Works with all existing extract modes (ad-hoc, bulk, clean)
- **Dependencies**: Multi-Pattern Extraction
- **Notes**:
  - Fan-out semantics: N files × M destinations = N×M copy operations
  - Directory structure preserved at each destination
  - YAML schema: `to: ["path1/", "path2/"]` for persisted mappings
  - Atomic per-destination: all files to one destination succeed or fail together

### 7. Lint Command ⏳ PLANNED

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
  3. Multi-Pattern Extraction ✅
  4. Extract Clean Mode ✅
  5. Brace Expansion in Patterns ✅
  6. Multi-Destination Extraction ⏳
  7. Lint Command ⏳ (final Phase 3 feature)
- **Rationale**: Brace Expansion and Multi-Destination extend pattern capabilities before Lint validates all operations
- **Cross-phase dependencies**: Requires Phase 2 Add Command for subtrees to exist

## Phase-Specific Metrics & Success Criteria

This phase is successful when:
- All seven features complete and tested
- Extract supports multiple patterns and cleanup operations
- Lint provides comprehensive integrity validation
- 600+ tests pass on macOS and Ubuntu (currently 526, growing)

## Risks & Assumptions

- **Assumptions**: Users understand glob pattern syntax
- **Risks & mitigations**: 
  - Glob complexity → clear pattern validation errors, consider dry-run mode
  - Accidental file deletion → checksum validation + `--force` gate

## Phase Notes

- 2025-11-30: Brace Expansion complete (011-brace-expansion) with 526 tests; 4 user stories delivered
- 2025-11-29: Added Brace Expansion and Multi-Destination Extraction features
- 2025-11-29: Extract Clean Mode complete (010-extract-clean) with 477 tests; dry-run/preview mode deferred to Phase 5 backlog
- 2025-11-27: Added Multi-Pattern Extraction and Extract Clean Mode features before Lint Command
- 2025-10-29: Case-Insensitive Names added to Phase 3
- 2025-10-28: Extract Command completed with 411 tests
