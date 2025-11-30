# Feature Specification: Multi-Destination Extraction (Fan-Out)

**Feature Branch**: `012-multi-destination-extraction`  
**Created**: 2025-11-30  
**Status**: Draft  
**Input**: User description: "Multi-Destination Extraction (Fan-Out) — Allows extracting matched files to multiple destinations simultaneously (e.g., --to Lib/ --to Vendor/), enabling distribution of extracted files to multiple locations without repeated commands"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Multiple CLI Destinations (Priority: P1)

As a developer distributing vendor files to multiple project locations, I want to specify multiple `--to` destinations in a single extract command so that I can copy matched files to several directories (e.g., both `Lib/` and `Vendor/`) without running multiple commands.

**Why this priority**: This is the core feature — enabling multiple destinations in the CLI. Without this, users must run separate extract commands for each destination, which is tedious and error-prone.

**Independent Test**: Can be fully tested by running `subtree extract --name foo --from '*.h' --to 'Lib/' --to 'Vendor/'` and verifying files appear in both destinations.

**Acceptance Scenarios**:

1. **Given** a configured subtree with header files, **When** user runs `subtree extract --name foo --from '**/*.h' --to 'Lib/' --to 'Vendor/'`, **Then** all matched files are copied to both `Lib/` and `Vendor/` directories.

2. **Given** multiple `--to` destinations with different depths, **When** extraction runs, **Then** each destination receives the same files with their relative paths preserved.

3. **Given** multiple `--from` patterns and multiple `--to` destinations, **When** extraction runs, **Then** the union of matched files is copied to every destination (fan-out semantics).

---

### User Story 2 - Persist Multi-Destination Mappings (Priority: P1)

As a developer, I want to persist a multi-destination extraction as a single mapping so that destinations I use together stay together when I run bulk extraction later.

**Why this priority**: Persistence enables repeatable workflows — equally critical as CLI support for practical usage.

**Independent Test**: Can be tested by running `subtree extract --from '*.h' --to 'Lib/' --to 'Vendor/' --persist` and verifying the config stores destinations as an array.

**Acceptance Scenarios**:

1. **Given** a multi-destination extract command with `--persist`, **When** the command completes successfully, **Then** the config stores `to: ["Lib/", "Vendor/"]` (array format) in a single mapping entry.

2. **Given** a persisted multi-destination mapping, **When** user runs bulk extraction (`subtree extract --name foo`), **Then** files are extracted to all destinations from the stored array.

3. **Given** an existing config with single-destination `to: "path/"` (string format), **When** extraction runs, **Then** it works exactly as before (backward compatible).

---

### User Story 3 - Clean Mode with Multiple Destinations (Priority: P2)

As a developer, I want `--clean` to remove files from all specified destinations so that cleanup is symmetric with extraction.

**Why this priority**: Clean mode parity ensures users don't need to run separate cleanup commands per destination.

**Independent Test**: Can be tested by running `subtree extract --clean --name foo --from '*.h' --to 'Lib/' --to 'Vendor/'` and verifying files are removed from both destinations.

**Acceptance Scenarios**:

1. **Given** files previously extracted to multiple destinations, **When** user runs `subtree extract --clean --name foo --from '**/*.h' --to 'Lib/' --to 'Vendor/'`, **Then** matching files are removed from both destinations.

2. **Given** a persisted multi-destination mapping, **When** user runs `subtree extract --clean --name foo`, **Then** files are removed from all destinations in the stored array.

3. **Given** clean mode with checksum validation, **When** one destination has modified files, **Then** clean fails before removing any files (fail-fast across all destinations).

---

### User Story 4 - Fail-Fast Overwrite Protection (Priority: P2)

As a developer, I want the system to validate all destinations upfront before copying any files so that I don't end up with partial extraction state.

**Why this priority**: Prevents confusing partial state where some destinations have files and others don't.

**Independent Test**: Can be tested by creating a git-tracked file conflict in one destination and verifying extraction fails before modifying any destination.

**Acceptance Scenarios**:

1. **Given** two destinations where `Lib/` is clear but `Vendor/foo.h` is git-tracked, **When** extraction runs without `--force`, **Then** the command fails with an error listing all conflicts and no files are copied to either destination.

2. **Given** overwrite protection triggered by any destination, **When** user provides `--force` flag, **Then** extraction proceeds to all destinations, overwriting conflicting files.

3. **Given** multiple destinations with multiple conflicts, **When** extraction fails, **Then** the error message lists all conflicting files across all destinations.

---

### User Story 5 - Bulk Mode Interaction (Priority: P3)

As a developer using `--all` to process all subtrees, I want multi-destination mappings to work correctly in bulk mode with continue-on-error semantics.

**Why this priority**: Ensures bulk mode remains consistent with existing behavior while supporting new multi-destination mappings.

**Independent Test**: Can be tested by configuring multiple subtrees with multi-destination mappings and running `subtree extract --all`.

**Acceptance Scenarios**:

1. **Given** multiple subtrees each with multi-destination mappings, **When** user runs `subtree extract --all`, **Then** each mapping extracts to all its destinations.

2. **Given** bulk mode where one subtree's mapping fails (e.g., protection triggered), **When** extraction runs, **Then** other subtrees complete successfully and failures are summarized at the end.

3. **Given** bulk clean mode with multi-destination mappings, **When** user runs `subtree extract --clean --all`, **Then** files are removed from all destinations for each mapping.

---

### Edge Cases

- **Empty destination array**: Config with `to: []` (empty array) should fail validation with clear error.
- **Duplicate destinations**: `--to 'Lib/' --to 'Lib/'` should deduplicate to single destination (no double-copy).
- **Overlapping destinations**: `--to 'Lib/' --to 'Lib/Sub/'` extracts to both (file may appear at `Lib/foo.h` AND `Lib/Sub/foo.h`). No deduplication based on path hierarchy — each destination is independent.
- **Mixed `to` formats in config**: Some mappings with string, others with array — both work correctly.
- **Single `--to` backward compatibility**: Existing commands with single `--to` continue to work unchanged.
- **Destination with trailing slash**: `--to 'Lib'` and `--to 'Lib/'` should be treated equivalently.
- **Non-existent destination directories**: Directories should be created as needed (existing behavior).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: CLI MUST accept multiple `--to` flags, each specifying one destination path.
- **FR-002**: CLI MUST copy matched files to EVERY specified destination (fan-out semantics: N files × M destinations).
- **FR-003**: Directory structure MUST be preserved identically at each destination.
- **FR-004**: Config MUST accept `to` as either a string (single destination) or array of strings (multiple destinations).
- **FR-005**: Config parsing MUST validate that array elements are all strings; reject non-string elements with clear error.
- **FR-006**: Config parsing MUST reject empty arrays (`to: []`) with clear error message.
- **FR-007**: When `--persist` is used with multiple destinations, system MUST store them as an array in a single mapping entry.
- **FR-008**: Single-destination commands (`--to 'path/'`) MUST continue to work exactly as before (backward compatible).
- **FR-009**: Bulk extraction with persisted multi-destination mappings MUST extract to all destinations in the array.
- **FR-010**: Duplicate destinations MUST be deduplicated after normalizing trailing slashes and leading `./` (e.g., `Lib`, `Lib/`, `./Lib/` collapse to one).
- **FR-011**: CLI MUST warn (but not fail) when more than 10 destinations are specified.
- **FR-012**: `--clean` mode MUST remove files from ALL specified destinations (symmetric with extraction).
- **FR-013**: Overwrite protection MUST validate ALL destinations upfront before any copy operations (fail-fast).
- **FR-014**: When protection fails, error MUST list all conflicting files across all destinations.
- **FR-015**: `--force` flag MUST bypass protection for all destinations.
- **FR-016**: In bulk mode (`--all`), multi-destination mappings MUST follow continue-on-error semantics per subtree.
- **FR-017**: Progress output MUST show per-destination summaries (e.g., `✅ Extracted 5 files to Lib/` then `✅ Extracted 5 files to Vendor/`).

### Key Entities

- **ExtractionMapping**: Extended to support `to` as either `String` or `[String]` (array), mirroring `from` array support.
- **Destination**: Represents a single target path; multiple destinations are processed independently with same source files.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can extract files to 3+ destinations in a single command (vs. 3+ separate commands previously).
- **SC-002**: Existing single-destination configurations work without modification (100% backward compatible).
- **SC-003**: Multi-destination extraction completes in <5 seconds for typical file sets (≤100 files × ≤5 destinations).
- **SC-004**: Fail-fast protection catches all conflicts before any files are copied, leaving no partial state.
- **SC-005**: Clean mode removes files from all destinations symmetrically with extraction.

## Assumptions

- Users understand that fan-out copies the same files to multiple locations (not different files to different locations).
- Destination order in config does not affect extraction behavior (parallel/sequential is implementation detail).
- Existing extract command infrastructure (GlobMatcher, file copying, overwrite protection) is reused.
- `--from` and `--to` counts are independent — no positional pairing between source patterns and destinations.

## Clarifications

### Session 2025-11-30

- Q: When using `--persist` with multiple destinations, should this create a single mapping with destination array or multiple separate mappings? → A: **Single mapping** with `to: ["path1/", "path2/"]` array format, mirroring `from` array semantics.

- Q: How should `--clean` mode work with multiple destinations? → A: **Clean all specified destinations** — symmetric with extraction behavior.

- Q: If extracting to one destination succeeds but another has overwrite protection conflicts, what should happen? → A: **Fail-fast** — validate all destinations upfront before any copy operations. No partial state; user gets single error listing all conflicts.

- Q: Should there be a limit on the number of destinations? → A: **Soft limit 10** — warn above threshold but still allow the operation. Prevents accidental abuse while remaining permissive for real-world use.

- Q: How should path deduplication handle equivalent paths? → A: **Normalize trailing slash + leading `./`** — `Lib`, `Lib/`, `./Lib/` all collapse to one destination. Simple, predictable, covers common cases without filesystem calls.

- Q: How should progress be reported for multi-destination operations? → A: **Per-destination summary** — show `✅ Extracted N files to <dest>/` for each destination. Provides visibility without verbose per-file output.
