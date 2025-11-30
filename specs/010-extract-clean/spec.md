# Feature Specification: Extract Clean Mode

**Feature Branch**: `010-extract-clean`  
**Created**: 2025-11-29  
**Status**: Complete  
**Input**: User description: "Removes previously extracted files from destination based on source glob patterns, enabling users to clean up extracted files when no longer needed or before re-extraction with different patterns"

## Clarifications

### Session 2025-11-29

- Q: When the destination file has been modified (checksum doesn't match), what should the default behavior be? → A: Fail fast - abort entire clean operation on first mismatch. Checksum uses `git hash-object` for comparison (leverages git's existing content addressing).
- Q: Should there be a preview/dry-run mode since --clean removes files? → A: Defer to backlog - not included in this feature. Rely on checksum safety + `--force` for overrides.
- Q: How should --clean interact with bulk flags (--name, --all)? → A: Full parity - supports both `--clean --name <subtree>` and `--clean --all` to clean persisted mappings.
- Q: For bulk mode with multiple mappings, what happens on mismatch? → A: Stop per-mapping, continue to next - fail one mapping, continue processing others, report all failures at end (consistent with existing extract bulk behavior).
- Q: How aggressive should empty directory pruning be? → A: Prune up to destination root - remove any directory that becomes empty after file removal, up to (but not including) the `--to` destination root.
- Q: What if source files in subtree no longer exist (can't verify checksum)? → A: Skip with warning, require `--force` to delete orphaned files - safe by default, explicit override available.
- Q: Should --clean support --exclude patterns like extraction does? → A: Yes, full parity - `--clean` accepts `--exclude` patterns, removes only files matching `--from` but not `--exclude`.
- Q: Should --force bypass subtree prefix validation (allowing clean after subtree removed)? → A: Yes, bypass - `--force` allows clean even if subtree directory is gone (no checksum needed).
- Q: If destination file is a symlink, what should clean do? → A: Follow symlinks - delete the target file that the symlink points to (symmetric with extract behavior).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ad-hoc Clean with Checksum Validation (Priority: P1)

As a developer, I want to remove previously extracted files from my project using a `--clean` flag with the same pattern syntax as extraction, so I can clean up files when they're no longer needed while ensuring I don't accidentally delete files I've modified.

**Why this priority**: This is the core value proposition - enabling safe file removal using familiar patterns. Without this, the clean mode has no functionality. Checksum validation prevents accidental data loss.

**Independent Test**: Can be fully tested by extracting files, running clean with the same pattern, and verifying files are removed only when checksums match source.

**Acceptance Scenarios**:

1. **Given** previously extracted files that match source checksums, **When** I run `subtree extract --clean --name my-lib --from "docs/**/*.md" --to project-docs/`, **Then** all matching files are removed from project-docs/ and empty directories are pruned
2. **Given** an extracted file that was modified (checksum differs), **When** I run clean without --force, **Then** the command fails immediately with error indicating which file was modified and suggesting --force flag
3. **Given** extracted files, **When** clean completes successfully, **Then** empty directories up to (but not including) the destination root are automatically pruned
4. **Given** a file at destination that matches the pattern but source file no longer exists in subtree, **When** I run clean without --force, **Then** the file is skipped with warning message indicating source not found

---

### User Story 2 - Force Clean Override (Priority: P2)

As a developer, I want to use `--force` to clean files regardless of checksum validation, so I can remove extracted files even when they've been modified or when source files no longer exist.

**Why this priority**: Enables users to override safety checks when intentional. Builds on P1's core clean functionality. Critical for cleanup after upstream breaking changes.

**Independent Test**: Can be tested by modifying an extracted file, running clean with --force, and verifying the modified file is removed.

**Acceptance Scenarios**:

1. **Given** a modified extracted file (checksum differs), **When** I run `subtree extract --clean --force --name my-lib --from "docs/**/*.md" --to project-docs/`, **Then** the file is removed despite checksum mismatch
2. **Given** a destination file where source no longer exists in subtree, **When** I run clean with --force, **Then** the orphaned file is removed
3. **Given** multiple files with mixed checksum status, **When** clean runs with --force, **Then** all matching files are removed regardless of checksum validation

---

### User Story 3 - Bulk Clean from Persisted Mappings (Priority: P3)

As a developer, I want to clean all files for persisted extraction mappings with simple commands (`subtree extract --clean --name my-lib` for one subtree, `subtree extract --clean --all` for all subtrees), so I can remove all extracted files before re-extraction or project cleanup without manual repetition.

**Why this priority**: Builds on P1's ad-hoc clean to enable bulk operations. Provides workflow parity with existing bulk extract. High value for project cleanup and re-extraction workflows.

**Independent Test**: Can be tested by creating multiple saved mappings, running clean with --name or --all, and verifying all mappings are processed.

**Acceptance Scenarios**:

1. **Given** a subtree with 3 saved extraction mappings, **When** I run `subtree extract --clean --name my-lib`, **Then** all 3 mappings are cleaned in order and matching files are removed from their respective destinations
2. **Given** multiple subtrees with saved extraction mappings, **When** I run `subtree extract --clean --all`, **Then** all mappings for all subtrees are cleaned
3. **Given** bulk clean where one mapping fails (checksum mismatch), **When** clean runs without --force, **Then** that mapping fails, remaining mappings continue processing, and summary reports all failures at end
4. **Given** a subtree with no saved mappings, **When** I run `subtree extract --clean --name my-lib`, **Then** command succeeds with message indicating no mappings found (exit code 0)

---

### User Story 4 - Multi-Pattern Clean (Priority: P4)

As a developer, I want to specify multiple `--from` patterns in a single clean command (same as extraction), so I can clean files from multiple source directories without running multiple commands.

**Why this priority**: Provides feature parity with multi-pattern extraction (spec 009). Users expect consistent behavior between extract and clean modes.

**Independent Test**: Can be tested by extracting with multiple patterns, then cleaning with same patterns and verifying all matching files are removed.

**Acceptance Scenarios**:

1. **Given** files extracted with multiple patterns, **When** I run `subtree extract --clean --name my-lib --from "include/**/*.h" --from "src/**/*.c" --to Sources/`, **Then** files matching any pattern are cleaned
2. **Given** extracted files including test files, **When** I run `subtree extract --clean --name my-lib --from "src/**/*.c" --to Sources/ --exclude "**/test_*.c"`, **Then** only non-test C files are removed
3. **Given** persisted mappings with array of from patterns, **When** bulk clean runs, **Then** all patterns in the array are processed for each mapping

---

### User Story 5 - Clean Error Handling (Priority: P5)

As a developer, I want clear error messages when cleaning fails (zero matches, subtree not found, permission errors), so I can quickly identify and fix problems.

**Why this priority**: Quality of life and debugging experience. Catches user errors early. Less critical than core functionality but prevents frustration.

**Independent Test**: Can be tested by running clean with invalid inputs and verifying appropriate error messages and exit codes.

**Acceptance Scenarios**:

1. **Given** a glob pattern that matches zero files in destination, **When** I run clean, **Then** command succeeds with message indicating 0 files matched (no files to clean is not an error)
2. **Given** a non-existent subtree name, **When** I run clean, **Then** command fails with error indicating subtree not found in config
3. **Given** a permission error while deleting a file, **When** clean runs, **Then** command fails with clear I/O error message

---

### Edge Cases

- **What happens when destination file exists but pattern doesn't match any source files?** Clean only removes files that exist at destination AND match the pattern - non-matching destination files are untouched
- **What happens when directory to prune contains files not matched by pattern?** Only empty directories are pruned - directories with remaining files are left intact
- **What happens when running --clean with --persist?** Invalid combination - --persist is for saving mappings during extraction, not applicable during clean. Command fails with error
- **What happens when checksum verification fails mid-bulk-clean?** That mapping fails, other mappings continue. Final exit code reflects highest severity encountered
- **What happens when destination path doesn't exist?** Clean succeeds with message indicating no files found (destination doesn't exist = nothing to clean)
- **What happens when using --clean with ad-hoc patterns but subtree has been removed (prefix gone)?** Without `--force`: fails with error indicating subtree directory not found. With `--force`: proceeds to delete matching destination files without checksum validation
- **What happens when destination file is a symlink?** System follows the symlink and deletes the target file (symmetric with extraction which copies target content)

## Requirements *(mandatory)*

> **Note**: FR-028 and FR-029 were added during clarification session and maintain their IDs for traceability.

### Functional Requirements

**Command Interface**:

- **FR-001**: System MUST accept `--clean` flag to trigger removal mode (opposite of extraction)
- **FR-002**: System MUST support `--clean` with ad-hoc patterns (`--from`/`--to`) for single-command clean operations
- **FR-003**: System MUST support `--clean --name <subtree>` to clean all persisted mappings for one subtree
- **FR-004**: System MUST support `--clean --all` to clean all persisted mappings for all subtrees
- **FR-005**: System MUST support `--force` flag with `--clean` to override checksum validation
- **FR-006**: System MUST reject `--clean` combined with `--persist` (invalid combination) with clear error message
- **FR-007**: System MUST support multiple `--from` patterns with `--clean` (feature parity with extraction)
- **FR-028**: System MUST support `--exclude` flag (repeatable) with `--clean` to filter which files are removed

**Checksum Validation**:

- **FR-008**: System MUST compare destination file content to source file content using `git hash-object` before deletion
- **FR-009**: System MUST fail fast (abort entire operation) on first checksum mismatch when running without --force
- **FR-010**: System MUST provide error message identifying the mismatched file and suggesting --force flag
- **FR-011**: System MUST skip destination files where source file no longer exists in subtree, with warning message
- **FR-012**: System MUST delete files with missing sources when --force flag is used

**File Removal**:

- **FR-013**: System MUST only remove files at destination that match the specified glob pattern(s)
- **FR-014**: System MUST prune empty directories after file removal, up to (but not including) the `--to` destination root
- **FR-015**: System MUST NOT remove directories that still contain files (even if empty after pattern matching)
- **FR-016**: System MUST NOT remove the destination root directory itself (only contents)
- **FR-029**: System MUST follow symlinks during clean, deleting the target file (symmetric with extraction which copies target content)

**Bulk Clean Behavior**:

- **FR-017**: When cleaning multiple persisted mappings, system MUST continue processing remaining mappings if one fails (continue-on-error per mapping)
- **FR-018**: System MUST collect all failures during bulk clean and report comprehensive summary at end
- **FR-019**: System MUST exit with highest severity exit code encountered during bulk clean (priority: 3 > 2 > 1)

**Validation and Error Handling**:

- **FR-020**: System MUST validate subtree exists in config before clean operation
- **FR-021**: System MUST validate subtree directory exists at configured prefix before clean, UNLESS `--force` flag is used (source not required when skipping checksum validation)
- **FR-022**: System MUST treat zero matching files at destination as success (nothing to clean is not an error)
- **FR-023**: System MUST provide actionable error messages for all failure cases

**Exit Codes**:

- **FR-024**: System MUST exit with code 0 on successful clean (including when zero files matched)
- **FR-025**: System MUST exit with code 1 on validation errors (missing subtree, invalid path, checksum mismatch)
- **FR-026**: System MUST exit with code 2 on user-facing errors (--clean with --persist combination)
- **FR-027**: System MUST exit with code 3 on I/O errors (permission denied, filesystem errors)

### Key Entities

- **Checksum**: Content hash computed using `git hash-object` for both source (subtree) and destination files. Used to verify destination file hasn't been modified before deletion. Mismatch indicates user modification.

- **Orphaned Destination File**: A file at destination path that matches the clean pattern but whose corresponding source file no longer exists in the subtree. Skipped by default (warning), removed with --force.

- **Directory Pruning Boundary**: The `--to` destination root directory. Empty directories are pruned up to but not including this boundary after file removal.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Ad-hoc clean operation completes in under 3 seconds for typical file sets (10-50 files)
- **SC-002**: Checksum validation correctly identifies 100% of modified files (no false positives/negatives)
- **SC-003**: Modified files are protected from deletion 100% of the time unless --force is explicitly used
- **SC-004**: Empty directory pruning correctly identifies and removes all eligible directories without affecting non-empty directories
- **SC-005**: Bulk clean (--all) successfully processes all subtrees with saved mappings, continuing through failures
- **SC-006**: Error messages provide actionable guidance (specific file conflicts, suggested fixes) 100% of the time
- **SC-007**: Users can clean extracted files using same pattern syntax as extraction without consulting documentation
