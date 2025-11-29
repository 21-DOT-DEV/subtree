# Feature Specification: Multi-Pattern Extraction

**Feature Branch**: `009-multi-pattern-extraction`  
**Created**: 2025-11-28  
**Status**: Draft  
**Input**: User description: "Feature: Multi-Pattern Extraction — Multiple --from patterns in single extraction with array YAML support"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Multiple CLI Patterns (Priority: P1)

As a developer managing vendor dependencies, I want to specify multiple `--from` patterns in a single extract command so that I can gather files from multiple source directories (e.g., both `include/` and `src/`) into one destination without running multiple commands.

**Why this priority**: This is the core feature — enabling multiple patterns in the CLI. Without this, users must run separate extract commands for each source pattern, which is tedious and error-prone.

**Independent Test**: Can be fully tested by running `subtree extract --name foo --from 'pattern1' --from 'pattern2' --to 'dest/'` and verifying files from both patterns are extracted.

**Acceptance Scenarios**:

1. **Given** a configured subtree with files in multiple directories, **When** user runs `subtree extract --name foo --from 'include/**/*.h' --from 'src/**/*.c' --to 'vendor/'`, **Then** all files matching either pattern are extracted to the destination directory.

2. **Given** two patterns that match the same file, **When** extraction runs, **Then** the file is extracted once (no duplicates) and no error occurs.

3. **Given** multiple patterns with different directory depths, **When** extraction runs, **Then** each file's destination path preserves its relative path from where the pattern matched.

---

### User Story 2 - Backward Compatible YAML (Priority: P1)

As a developer with existing extraction configurations, I want the system to continue supporting single-pattern string format while also accepting array format so that my existing configurations don't break.

**Why this priority**: Backward compatibility is critical — existing users should not have their workflows disrupted. This is equally important as CLI support.

**Independent Test**: Can be tested by creating configs with both string and array formats and verifying both work correctly.

**Acceptance Scenarios**:

1. **Given** an existing config with `from: "pattern"` (string format), **When** extraction runs, **Then** it works exactly as before with no changes required.

2. **Given** a new config with `from: ["pattern1", "pattern2"]` (array format), **When** extraction runs, **Then** all patterns in the array are processed.

3. **Given** a config mixing both formats across different mappings, **When** extraction runs, **Then** each mapping is processed according to its format.

---

### User Story 3 - Persist Multiple Patterns (Priority: P2)

As a developer, I want to persist a multi-pattern extraction as a single mapping so that patterns I use together stay together when I run bulk extraction later.

**Why this priority**: Persistence enables repeatable workflows, but users can work without it by specifying patterns each time.

**Independent Test**: Can be tested by running `subtree extract --from 'p1' --from 'p2' --to 'dest/' --persist` and verifying the config stores patterns as an array.

**Acceptance Scenarios**:

1. **Given** a multi-pattern extract command with `--persist`, **When** the command completes successfully, **Then** the config stores `from: ["pattern1", "pattern2"]` (array format) in a single mapping entry.

2. **Given** a persisted multi-pattern mapping, **When** user runs bulk extraction (`subtree extract --name foo`), **Then** all patterns from the array are processed together.

---

### User Story 4 - Global Excludes (Priority: P2)

As a developer, I want exclude patterns to apply across all `--from` patterns so that I can filter out unwanted files (like tests or internal headers) regardless of which source pattern matched them.

**Why this priority**: Excludes enhance usability but the core extraction works without them.

**Independent Test**: Can be tested by running extract with multiple `--from` and one `--exclude`, verifying excluded files are omitted from all source patterns.

**Acceptance Scenarios**:

1. **Given** multiple `--from` patterns and `--exclude '**/test_*'`, **When** extraction runs, **Then** files matching the exclude pattern are omitted from ALL source patterns.

2. **Given** an exclude pattern that matches files in only one source pattern, **When** extraction runs, **Then** only those specific files are excluded; other patterns are unaffected.

---

### User Story 5 - Zero-Match Warning (Priority: P3)

As a developer, I want to be warned when a pattern matches no files so that I can catch typos or outdated patterns without blocking extraction of files from other patterns.

**Why this priority**: This is an enhancement for user experience; extraction works correctly without it but may silently ignore typos.

**Independent Test**: Can be tested by running extract with one valid and one invalid pattern, verifying warning is shown but extraction succeeds.

**Acceptance Scenarios**:

1. **Given** multiple `--from` patterns where one matches files and another matches nothing, **When** extraction runs, **Then** files from matching patterns are extracted AND a warning is displayed for the zero-match pattern.

2. **Given** all `--from` patterns match no files, **When** extraction runs, **Then** command exits with error (no files to extract).

3. **Given** zero-match pattern with successful extraction from other patterns, **When** extraction completes, **Then** exit code is 0 (success) despite the warning.

---

### Edge Cases

- **Overlapping patterns**: Two patterns like `src/**/*.c` and `src/crypto/*.c` may match the same files — system extracts each file once.
- **Empty pattern array**: Config with `from: []` (empty array) should fail validation with clear error.
- **Mixed pattern types in array**: All elements in `from` array must be strings — reject arrays containing non-strings.
- **Pattern with special characters**: Patterns containing spaces or special shell characters should be properly quoted and handled.
- **Very large number of patterns**: System should handle 10+ patterns efficiently without degradation.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: CLI MUST accept multiple `--from` flags, each specifying one glob pattern.
- **FR-002**: CLI MUST process all `--from` patterns as a union — files matching ANY pattern are extracted.
- **FR-003**: If a file matches multiple patterns, it MUST be extracted exactly once (no duplicates).
- **FR-004**: Config MUST accept `from` as either a string (single pattern) or array of strings (multiple patterns).
- **FR-005**: Config parsing MUST validate that array elements are all strings; reject non-string elements with clear error.
- **FR-006**: Config parsing MUST reject empty arrays (`from: []`) with clear error message.
- **FR-007**: When `--persist` is used with multiple patterns, system MUST store them as an array in a single mapping entry.
- **FR-008**: `--exclude` patterns MUST apply globally to all `--from` patterns.
- **FR-009**: If any `--from` pattern matches zero files but others have matches, system MUST warn but continue extraction (exit code 0).
- **FR-010**: If ALL `--from` patterns match zero files, system MUST exit with error (exit code 1).
- **FR-011**: Single-pattern commands (`--from 'pattern'`) MUST continue to work exactly as before (backward compatible).
- **FR-012**: Bulk extraction with persisted multi-pattern mappings MUST process all patterns in the array together.
- **FR-013**: When `--persist` is used and a mapping to the same destination already exists, system MUST reject with error (consistent with existing extract behavior).

### Key Entities

- **ExtractionMapping**: Existing entity extended to support `from` as either `String` or `[String]` (array).
- **GlobPattern**: Represents a single glob pattern; multiple patterns are processed independently then results merged.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can extract files from 3+ source directories in a single command (vs. 3+ separate commands previously).
- **SC-002**: Existing single-pattern configurations work without modification (100% backward compatible).
- **SC-003**: Multi-pattern extraction completes in <5 seconds for typical file sets (≤100 files across all patterns).
- **SC-004**: Zero-match warnings clearly identify which pattern(s) had no matches.
- **SC-005**: 100% of multi-pattern extractions produce correct union of all matched files with no duplicates.

## Assumptions

- Users understand glob pattern syntax (carried over from existing extract command).
- Patterns are evaluated independently; no inter-pattern dependencies.
- Array order in config does not affect extraction behavior (union is commutative).
- Existing extract command infrastructure (GlobMatcher, file copying, overwrite protection) is reused.

## Clarifications

### Session 2025-11-28

- Q: When using `--persist` with multiple patterns, what should happen if a mapping to the same destination already exists? → A: Error — reject with "mapping to this destination already exists" (consistent with current extract behavior).

- Q: Should pattern prefix be stripped from extracted paths (e.g., `src/**/*.c` → `dest/foo.c`) or preserved (→ `dest/src/foo.c`)? → A: **Preserve full paths** (industry standard, matches rsync/cp behavior). Pattern prefix stripping was the original 008 behavior but is non-standard. A future `--flatten` flag (see backlog) will provide prefix stripping for users who prefer it.
