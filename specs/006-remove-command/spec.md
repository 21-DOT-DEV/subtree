# Feature Specification: Remove Command

**Feature Branch**: `006-remove-command`  
**Created**: 2025-10-28  
**Status**: Draft  
**Input**: User description: "Remove Command - Safely removes subtrees and updates configuration atomically, ensuring clean repository state and preventing orphaned configuration entries"

## Clarifications

### Session 2025-10-28

- Q: What should be removed from the repository when running `subtree remove <name>`? → A: Remove the prefix directory and config entry with validation checks (verify name exists in config, prefix directory exists, working tree is clean)
- Q: Should Remove Command support batch removal via `--all` flag? → A: No batch removal for initial implementation - only support `subtree remove <name>` for individual removal (safer, forces intentional removal)
- Q: What commit message format should Remove operations use? → A: Detailed format with last commit info: "Remove subtree <name> (was at <hash>)" with body including last commit, remote URL, and prefix location
- Q: How should the command handle the edge case where subtree directory doesn't exist but config entry does? → A: Succeed silently with cleanup - idempotent behavior (removes config entry, reports directory already removed)
- Q: How should the command handle local modifications within the subtree directory? → A: Block removal - require clean working tree (consistent with Add/Update, prevents data loss)
- Q: How should the command handle configuration file parsing errors? → A: Specific parsing error with exit code 3 and detailed message: "❌ Configuration file is malformed: <parse error details>"
- Q: How should the command handle failure during the commit creation step? → A: Leave changes staged with recovery instructions: "❌ Failed to commit removal. Changes are staged. Run 'git commit' to complete or 'git reset HEAD' to abort." Exit code 1

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Clean Subtree Removal (Priority: P1)

As a developer managing dependencies, I want to remove a subtree that's no longer needed from my repository with a single command, so I can keep my project clean without manually deleting directories and editing configuration files.

**Why this priority**: This is the core value proposition - simplifying subtree removal with automatic config cleanup. Users need a safe, reliable way to remove dependencies without leaving orphaned configuration entries.

**Independent Test**: Can be fully tested by adding a subtree, running `subtree remove <name>`, and verifying the directory is deleted, config entry is removed, and changes are captured in a single atomic commit.

**Acceptance Scenarios**:

1. **Given** I have a repository with subtree "vendor-lib" at prefix "lib/" in configuration, **When** I run `subtree remove vendor-lib`, **Then** the "lib/" directory is deleted from the working tree
2. **Given** I remove a subtree successfully, **When** I check `subtree.yaml`, **Then** the subtree entry for "vendor-lib" is removed from configuration
3. **Given** I remove a subtree successfully, **When** I check git history, **Then** exactly one commit exists containing both the directory removal AND the updated `subtree.yaml`
4. **Given** I remove a subtree, **When** the command completes, **Then** it outputs an emoji-prefixed success message showing the subtree name and the commit hash it was at before removal

---

### User Story 2 - Idempotent Removal (Priority: P2)

As a developer recovering from configuration desync, I want the remove command to succeed even if the subtree directory is already gone, so I can clean up orphaned configuration entries without manual file editing.

**Why this priority**: Enables recovery from desync situations (directory deleted manually, corrupted state) and supports idempotent scripting patterns. Lower priority than core removal but essential for robustness.

**Independent Test**: Can be fully tested by manually deleting a subtree directory, then running `subtree remove <name>` and verifying config cleanup occurs without errors.

**Acceptance Scenarios**:

1. **Given** I have a subtree "tools" in configuration but the directory "tools/" was manually deleted, **When** I run `subtree remove tools`, **Then** the command succeeds and removes the config entry
2. **Given** the subtree directory is already gone, **When** I remove the subtree, **Then** the success message indicates "(directory already removed, config cleaned up)"
3. **Given** I run `subtree remove <name>` twice in a row, **When** the second removal executes, **Then** it fails with clear error "Subtree '<name>' not found in configuration" (config already cleaned up)

---

### User Story 3 - Error Handling & Validation (Priority: P1)

As a developer using the CLI, I want clear error messages when removal operations fail or inputs are invalid, so I can quickly understand and fix problems without risking data loss.

**Why this priority**: Essential for user experience and data safety - without proper error handling and validation, the core P1 functionality becomes dangerous when things go wrong. Clean working tree requirement prevents accidental data loss.

**Independent Test**: Can be fully tested by triggering various error conditions (missing config, invalid subtree name, dirty working tree, uncommitted changes in subtree directory) and verifying error messages are clear with appropriate exit codes.

**Acceptance Scenarios**:

1. **Given** no `subtree.yaml` exists, **When** I run `subtree remove mylib`, **Then** error shows "❌ Configuration file not found. Run 'subtree init' first" and exits with code 3
2. **Given** `subtree.yaml` exists but doesn't contain "mylib", **When** I run `subtree remove mylib`, **Then** error shows "❌ Subtree 'mylib' not found in configuration" and exits with code 2
3. **Given** I have uncommitted changes anywhere in the working tree, **When** I run `subtree remove lib`, **Then** error shows "❌ Working tree has uncommitted changes. Commit or stash before removing subtrees" and exits with code 1
4. **Given** I run `subtree remove lib` outside a git repository, **When** validation runs, **Then** error shows "❌ Must be run inside a git repository" and exits with code 1
5. **Given** removal validation fails, **When** error is shown, **Then** the command exits with non-zero exit code and does not modify the repository or config

---

### Edge Cases

- **Nested subtrees**: What if removing a subtree would orphan another subtree nested inside it? → Not supported in config schema, each subtree has independent prefix
- **Shared parent directories**: What if multiple subtrees share a parent directory (e.g., "vendor/lib1", "vendor/lib2") and removing one leaves empty parent? → Leave parent directory (user can clean up manually if desired)
- **Symlinked directories**: What if the subtree prefix is a symlink? → Git tracks symlinks, removal should work normally (git handles symlink deletion)
- **Read-only files**: What if subtree directory contains read-only files? → Git removal should handle this (git rm respects file permissions)
- **Very large subtrees**: What if subtree contains thousands of files? → Git handles large deletions, but no progress indicator in initial implementation (could add to backlog)
- **Concurrent operations**: What if two `subtree remove` commands run simultaneously on different subtrees? → Atomic commit may conflict, let git handle locking
- **Detached HEAD**: Can subtrees be removed in detached HEAD state? → Yes, git operations work in detached HEAD (same as Add/Update)
- **Modified subtree files**: What if user edited files in subtree directory (tracked changes)? → Blocked by clean working tree validation (user must commit/stash first)
- **Untracked files in subtree**: What if subtree directory contains untracked files? → Git status check for clean working tree doesn't flag untracked files in removed directories (they'll be left behind - acceptable behavior)
- **Malformed config file**: What if subtree.yaml exists but contains invalid YAML syntax? → Exit with code 3 and specific parsing error: "❌ Configuration file is malformed: <parse error details>"
- **Commit creation failure**: What if git commit fails after staging removal changes (hooks reject, disk full)? → Leave changes staged, provide recovery instructions, exit code 1 (user can complete or abort manually)

## Requirements *(mandatory)*

### Functional Requirements

**Command Interface**:
- **FR-001**: Command MUST accept subtree name as positional argument: `subtree remove <name>`
- **FR-002**: Command MUST NOT support `--all` flag for batch removal in initial implementation (individual removal only for safety)

**Validation Requirements**:
- **FR-003**: Command MUST validate that current directory is within a git repository before proceeding
- **FR-004**: Command MUST validate that `subtree.yaml` exists at git repository root (exit with error suggesting `subtree init` if missing)
- **FR-005**: Command MUST validate that `subtree.yaml` is parseable and well-formed YAML (exit with error showing parse details if malformed)
- **FR-006**: Command MUST validate that the specified subtree name exists in configuration (exit with clear error if not found)
- **FR-007**: Command MUST validate that working tree is clean (no uncommitted changes anywhere) before removal
- **FR-008**: All validation checks MUST complete before any filesystem or git modifications occur

**Removal Operation**:
- **FR-009**: Command MUST remove the subtree's prefix directory from the working tree using `git rm -r <prefix>`
- **FR-010**: Command MUST remove the subtree's configuration entry from `subtree.yaml` at git repository root
- **FR-011**: Command MUST update config using atomic file operations (write to temp file, rename) to avoid corruption

**Idempotent Behavior**:
- **FR-012**: When subtree directory does not exist but config entry does exist, command MUST succeed and remove config entry only
- **FR-013**: When subtree directory is already removed, success message MUST indicate "(directory already removed, config cleaned up)"
- **FR-014**: Command MUST exit with code 0 when removal succeeds (whether directory existed or not)

**Atomic Commit**:
- **FR-015**: After removing directory and updating config, command MUST create a single atomic commit containing both changes
- **FR-016**: Atomic commit MUST use message format: "Remove subtree <name> (was at <short-hash>)" as title
- **FR-017**: Commit message body MUST include:
  - "- Last commit: <full-hash>"
  - "- From: <remote-url>"
  - "- Was at: <prefix>"
- **FR-018**: Short-hash in commit title MUST be the first 8 characters of the commit SHA-1 hash from config
- **FR-019**: When commit creation fails after staging changes, command MUST leave changes staged and provide recovery instructions: "❌ Failed to commit removal. Changes are staged. Run 'git commit' to complete or 'git reset HEAD' to abort." Exit code 1

**Error Handling**:
- **FR-020**: All error messages MUST use emoji-prefixed format:
  - ❌ (`:x:`) for error messages
  - ✅ (`:white_check_mark:`) for success messages
- **FR-021**: Command MUST exit with code 3 when config file is missing
- **FR-022**: Command MUST exit with code 3 when config file is malformed, with message: "❌ Configuration file is malformed: <parse error details>"
- **FR-023**: Command MUST exit with code 2 when specified subtree name is not found in configuration
- **FR-024**: Command MUST exit with code 1 when working tree has uncommitted changes
- **FR-025**: Command MUST exit with code 1 when not inside a git repository
- **FR-026**: Command MUST exit with code 1 when commit creation fails after staging changes
- **FR-027**: When validation fails, error message MUST clearly indicate what went wrong and suggest corrective action

**Output**:
- **FR-028**: On success, command MUST output emoji-prefixed message showing: subtree name and commit hash it was at before removal
- **FR-029**: Success message format MUST be: "✅ Removed subtree '<name>' (was at <short-hash>)" for normal removal
- **FR-030**: Success message format for idempotent removal MUST be: "✅ Removed subtree '<name>' (directory already removed, config cleaned up)"

### Key Entities

- **RemovalOperation**: Represents a subtree removal with source subtree name, config entry details (prefix, remote, last commit hash), directory existence status, and result
  - Attributes: name (string), prefix (path), remote (URL), lastCommit (SHA-1 hash), directoryExists (boolean), operationResult (success/failure)
  - Behavior: Idempotent (can run multiple times safely), atomic (single commit for both directory and config removal)

- **SubtreeConfigEntry**: Configuration entry in `subtree.yaml` to be removed
  - Attributes: name, remote, prefix, ref, commit, squash (all preserved in commit message for audit trail)
  - Lifecycle: Deleted during removal operation, preserved in commit message for recovery

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Removal operation completes in under 5 seconds for typical subtrees (<10,000 files)
- **SC-002**: 100% of successful removal operations produce exactly one git commit containing both directory removal and config update
- **SC-003**: Users can remove a subtree with a single command without needing to manually edit configuration files
- **SC-004**: Command is idempotent - running `subtree remove <name>` twice results in success on first run, clear "not found" error on second run (no partial state)
- **SC-005**: Idempotent removal (directory already gone) succeeds within 1 second and cleans up config entry
- **SC-006**: 100% of removal validation failures (missing config, invalid name, dirty tree) occur before any filesystem or git modifications
- **SC-007**: Error messages clearly identify the problem and suggest corrective action, reducing support questions to <2 per 100 remove operations
- **SC-008**: Command works reliably across all supported platforms (macOS 13+, Ubuntu 20.04 LTS) with consistent behavior
- **SC-009**: Commit messages preserve enough information for audit and recovery (last commit hash, remote URL, prefix location)
- **SC-010**: Users can successfully remove subtrees on first attempt without documentation in 90% of cases (simple command syntax)
