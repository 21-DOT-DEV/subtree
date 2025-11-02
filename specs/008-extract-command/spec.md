# Feature Specification: Extract Command

**Feature Branch**: `008-extract-command`  
**Created**: 2025-10-31  
**Status**: Draft  
**Input**: User description: "Copies files from subtrees to project structure using glob patterns with smart overwrite protection, enabling selective integration of upstream files (source code, docs, templates, configs) without manual copying"

## Clarifications

### Session 2025-10-31

- Q: When running bulk extraction (--all) and one mapping fails, should the system stop immediately or continue processing remaining mappings? → A: Continue all - process every mapping, collect failures, report at end with summary, exit with highest severity code (2 > 1, 3 > 2)
- Q: Should extraction mappings support excluding specific files/patterns from the match, and if so, what structure? → A: Separate exclude array - optional `exclude: [pattern1, pattern2]` field under each mapping using glob patterns (matches rsync --exclude behavior)
- Q: How should users specify exclude patterns during ad-hoc extraction via CLI? → A: Multiple `--exclude` flags (rsync-style) - users can repeat flag for each pattern, e.g., `--exclude "pattern1" --exclude "pattern2"`, which maps to exclude array when persisted
- Q: If from pattern matches files but all are filtered out by exclude patterns (net 0 files), should it succeed or fail? → A: Error (exit 1) - treat as zero-match validation error, fail with message indicating all matches were excluded by exclusion patterns
- Q: How should symbolic links be handled during file extraction? → A: Follow symlinks - copy the target file content, not the link itself (matches rsync default behavior, ensures extracted files are complete and self-contained)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ad-hoc File Extraction (Priority: P1)

As a developer, I want to extract specific files from an added subtree to my project structure using a simple command, so I can quickly integrate upstream files (documentation, templates, configs) without manual copying or ongoing maintenance.

**Why this priority**: This is the core value proposition - enabling selective file integration from subtrees. Without this, the Extract command has no functionality. This story delivers immediate value: copy files from subtree to project with a single command.

**Independent Test**: Can be fully tested by adding a subtree, running extract with a glob pattern and destination, and verifying files are copied to the correct location with proper directory structure preserved.

**Acceptance Scenarios**:

1. **Given** a repository with an added subtree containing documentation files, **When** I run `subtree extract --name my-lib "docs/**/*.md" project-docs/`, **Then** all Markdown files from the subtree's docs/ directory are copied to project-docs/ with directory structure preserved relative to the glob match
2. **Given** a subtree with template files, **When** I run `subtree extract --name utils "templates/**" .templates/`, **Then** all files under templates/ are copied to .templates/ preserving subdirectory structure
3. **Given** a subtree with configuration files, **When** I extract specific configs using a glob pattern, **Then** only files matching the pattern are copied to the destination
4. **Given** a subtree with source files including tests, **When** I run `subtree extract --name lib "src/**/*.c" Sources/ --exclude "src/**/test*/**" --exclude "src/bench*.c"`, **Then** only C files NOT matching exclude patterns are copied

---

### User Story 2 - Persistent Extraction Mappings (Priority: P2)

As a developer, I want to save extraction mappings to the config file using a `--persist` flag, so I can repeat common extractions without retyping commands and ensure consistent file integration across team members.

**Why this priority**: Enables repeatability and team consistency. After P1 proves ad-hoc extraction works, P2 adds persistence for ongoing workflows. Delivers value: "learn by doing" - run command once with --persist, reuse forever.

**Independent Test**: Can be tested by running an extraction with `--persist`, verifying the mapping is saved to subtree.yaml, and confirming the saved mapping can be executed later without specifying source/destination again.

**Acceptance Scenarios**:

1. **Given** a repository with a subtree, **When** I run `subtree extract --name my-lib "docs/**/*.md" project-docs/ --persist`, **Then** the extraction executes AND the mapping is saved to subtree.yaml under the subtree's extractions array
2. **Given** a subtree with multiple saved extraction mappings, **When** I view subtree.yaml, **Then** I see an array of extractions with from/to patterns for each mapping
3. **Given** an extraction without --persist flag, **When** the command completes, **Then** files are copied but NO mapping is saved to config

---

### User Story 3 - Bulk Extraction Execution (Priority: P3)

As a developer, I want to execute all saved extraction mappings with simple commands (`subtree extract --name my-lib` for one subtree, `subtree extract --all` for all subtrees), so I can sync all extracted files after updating subtrees without manual repetition.

**Why this priority**: Builds on P2's persistence to enable bulk operations. Delivers workflow efficiency: update subtree, then re-extract all mappings with one command. Less critical than basic extraction but high value for ongoing maintenance.

**Independent Test**: Can be tested by creating multiple saved mappings (P2), then running extract without positional arguments and verifying all mappings execute in order.

**Acceptance Scenarios**:

1. **Given** a subtree with 3 saved extraction mappings, **When** I run `subtree extract --name my-lib`, **Then** all 3 mappings execute in order and files are extracted to their respective destinations
2. **Given** multiple subtrees with saved extraction mappings, **When** I run `subtree extract --all`, **Then** all mappings for all subtrees execute
3. **Given** a subtree with no saved mappings, **When** I run `subtree extract --name my-lib` (no positional args), **Then** command succeeds with message indicating no mappings found (exit code 0)

---

### User Story 4 - Git-Aware Overwrite Protection (Priority: P4)

As a developer, I want the Extract command to protect git-tracked files from being overwritten by default, so I don't accidentally lose committed work, while still allowing overwrites with an explicit `--force` flag when intentional.

**Why this priority**: Safety feature that prevents data loss. Important but less critical than basic functionality (P1-P3). Users expect version-controlled files to be protected. Enables confident extraction without fear of losing work.

**Independent Test**: Can be tested by extracting files to destinations with existing git-tracked files, verifying extraction fails with clear error, then retrying with --force and confirming override works.

**Acceptance Scenarios**:

1. **Given** a git-tracked file exists at the destination path, **When** I run extraction without --force, **Then** the command fails with error message indicating which files are protected and suggesting --force flag
2. **Given** an untracked file exists at the destination, **When** I run extraction without --force, **Then** the file is overwritten (untracked files are not protected)
3. **Given** git-tracked files at destination, **When** I run extraction with --force flag, **Then** all files are overwritten including git-tracked ones
4. **Given** multiple files to extract with mixed git status, **When** extraction runs without --force, **Then** untracked files are overwritten, tracked files are skipped, and error message lists all protected files

---

### User Story 5 - Glob Pattern Validation and Error Handling (Priority: P5)

As a developer, I want clear error messages when glob patterns match zero files, when subtrees don't exist, or when destinations are invalid, so I can quickly identify and fix problems without debugging.

**Why this priority**: Quality of life and debugging experience. Catches user errors early (typos, wrong patterns, missing subtrees). Less critical than core functionality but prevents frustration and silent failures.

**Independent Test**: Can be tested by running extract commands with invalid inputs (non-existent subtree, zero-match patterns, invalid paths) and verifying appropriate error messages and exit codes.

**Acceptance Scenarios**:

1. **Given** a glob pattern that matches zero files, **When** I run extraction, **Then** command fails with error indicating pattern matched 0 files and suggests checking pattern syntax
1a. **Given** a from pattern that matches files but all are excluded by exclude patterns, **When** I run extraction, **Then** command fails with error indicating 0 files remain after exclusion filtering
2. **Given** a non-existent subtree name, **When** I run extraction, **Then** command fails with error indicating subtree not found in config
3. **Given** an invalid destination path (e.g., contains `..` or absolute path), **When** I run extraction, **Then** command fails with path safety validation error
4. **Given** a destination directory that doesn't exist, **When** I run extraction, **Then** the directory is created automatically before copying files
5. **Given** a subtree that doesn't exist on filesystem (prefix not found), **When** I run extraction, **Then** command fails with error indicating subtree directory not found at expected prefix

---

### Edge Cases

- **What happens when destination path is inside the subtree itself?** Extraction should fail with error preventing circular/conflicting operations
- **What happens when glob pattern matches files outside the subtree prefix?** Only files within the subtree's prefix should be considered; glob matching is scoped to subtree directory
- **What happens when two extracted files would have same name at destination (name collision)?** First file wins, subsequent conflicts fail with error listing collisions
- **What happens when extraction is interrupted mid-copy?** Partial state (some files copied, some not) - not atomic. Users must re-run extraction
- **What happens when running bulk extraction (--all) and one mapping fails?** System continues processing all remaining mappings (does not abort), collects all failures, reports comprehensive summary at end listing each failed mapping with its error, and exits with highest severity exit code encountered (priority: 3 > 2 > 1). Successful extractions remain completed.
- **What happens when user lacks filesystem permissions for destination?** Extraction fails with permission error before any files are copied
- **What happens when destination is a file (not directory)?** Extraction fails with error indicating destination must be directory
- **What happens when preserved directory structure would create deeply nested paths?** Paths are created as needed (no depth limit); only OS path length limits apply
- **What happens when a symlink is encountered during extraction?** System follows symlinks and copies target file content (not the link itself), ensuring extracted files are complete and self-contained

## Requirements *(mandatory)*

### Functional Requirements

**Command Interface**:

- **FR-001**: System MUST accept subtree name via `--name` flag for ad-hoc extractions
- **FR-002**: System MUST accept source glob pattern as first positional argument for ad-hoc extractions
- **FR-003**: System MUST accept destination path as second positional argument for ad-hoc extractions
- **FR-004**: System MUST support `--persist` flag to save extraction mappings to subtree.yaml
- **FR-005**: System MUST support `--all` flag to execute all saved mappings for all subtrees (no --name required)
- **FR-006**: System MUST execute all saved mappings for specific subtree when --name provided without positional arguments
- **FR-007**: System MUST support `--force` flag to override git-tracked file protection
- **FR-036**: System MUST support optional `--exclude` flag (repeatable) to specify glob patterns for excluding files from ad-hoc extractions
- **FR-037**: When `--exclude` flags are provided with `--persist`, system MUST save all exclude patterns as array in config's `exclude` field

**File Matching and Copying**:

- **FR-008**: System MUST support glob patterns including `**` (globstar) for recursive matching
- **FR-009**: System MUST preserve directory structure relative to the glob match base when copying files
- **FR-010**: System MUST copy only files within the subtree's configured prefix directory
- **FR-011**: System MUST create destination directories automatically if they don't exist
- **FR-012**: System MUST fail with error when glob pattern matches zero files (strict validation)
- **FR-033**: System MUST support optional `exclude` array in extraction mappings containing glob patterns to exclude specific files from matches
- **FR-034**: When `exclude` patterns are present, system MUST apply exclusions AFTER `from` pattern matching (files matching both `from` and any `exclude` pattern are filtered out)
- **FR-035**: Exclude patterns MUST support same glob syntax as `from` patterns (including `**`, `*`, character classes)
- **FR-038**: System MUST treat zero remaining files after exclusion filtering as validation error (exit code 1), providing message indicating all matches were excluded
- **FR-039**: System MUST follow symbolic links during extraction, copying the target file content rather than preserving the symlink itself (ensures extracted files are self-contained)

**Overwrite Protection**:

- **FR-013**: System MUST protect git-tracked files from being overwritten by default (without --force)
- **FR-014**: System MUST allow overwriting untracked files (not in git index) by default
- **FR-015**: System MUST overwrite all files (including git-tracked) when --force flag is used
- **FR-016**: System MUST provide clear error messages listing all protected files when overwrite is blocked

**Config Persistence**:

- **FR-017**: System MUST store extraction mappings in subtree.yaml under each subtree's `extractions` array
- **FR-018**: System MUST support multiple extraction mappings per subtree (array structure)
- **FR-019**: Each extraction mapping MUST store `from` (glob pattern) and `to` (destination path) fields, and MAY optionally store `exclude` (array of glob patterns to exclude from matches)
- **FR-020**: System MUST append new mappings when --persist is used (not replace existing mappings)

**Validation and Error Handling**:

- **FR-021**: System MUST validate subtree exists in config before extraction
- **FR-022**: System MUST validate subtree directory exists at configured prefix before extraction
- **FR-023**: System MUST validate destination path safety (no `..`, no absolute paths outside repository)
- **FR-024**: System MUST fail with actionable error message when validation fails
- **FR-025**: System MUST NOT stage extracted files to git automatically (manual staging only)

**Exit Codes**:

- **FR-026**: System MUST exit with code 0 on successful extraction
- **FR-027**: System MUST exit with code 1 on validation errors (missing subtree, invalid path, zero matches)
- **FR-028**: System MUST exit with code 2 on overwrite protection errors (git-tracked files blocked)
- **FR-029**: System MUST exit with code 3 on I/O errors (permission denied, filesystem errors)

**Bulk Extraction Failure Handling**:

- **FR-030**: When executing bulk extraction (--all or --name without positional args) with multiple mappings, system MUST continue processing all mappings even if some fail (no abort on first failure)
- **FR-031**: System MUST collect all failures during bulk extraction and report comprehensive summary at end listing each failed mapping with specific error details
- **FR-032**: System MUST exit with highest severity exit code encountered during bulk extraction (exit code priority: 3 > 2 > 1), ensuring scripts detect worst failure case

### Key Entities

- **Extraction Mapping**: Represents a saved file extraction configuration with source glob pattern (from), destination path (to), and optional exclusion patterns (exclude array). Stored as array element under subtree's `extractions` field in subtree.yaml. Multiple mappings can exist per subtree, executed in array order. Example: `{from: "src/**/*.c", to: "Sources/", exclude: ["src/**/test*/**", "src/bench*.c"]}`
  
- **Glob Pattern**: User-specified pattern for matching files within subtree prefix, supports standard glob syntax including `**` for recursive matching, `*` for single-level wildcards, and character classes. Matching is scoped to subtree directory only.

- **Destination Path**: Target location in project repository where extracted files are copied. Must be relative path within repository, safety-validated to prevent escaping repository boundaries. Directory structure is created automatically if missing.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Ad-hoc file extraction completes in under 3 seconds for typical file sets (10-50 files)
- **SC-002**: Glob patterns match expected files with 100% accuracy (no false positives/negatives from pattern engine)
- **SC-003**: Git-tracked files are protected from overwrite 100% of the time unless --force is explicitly used
- **SC-004**: Users can extract, persist, and re-run common extractions without consulting documentation after initial learning
- **SC-005**: Zero match glob patterns are detected and reported 100% of the time (no silent failures)
- **SC-006**: Bulk extraction (--all) successfully processes all subtrees with saved mappings without manual intervention
- **SC-007**: Error messages provide actionable guidance (specific file conflicts, suggested fixes) 100% of the time
- **SC-008**: Directory structure is preserved correctly relative to glob match base for all extraction scenarios
