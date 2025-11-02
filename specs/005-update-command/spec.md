# Feature Specification: Update Command

**Feature Branch**: `005-update-command`  
**Created**: 2025-10-28  
**Status**: Draft  
**Input**: User description: "Update Command - Updates subtrees to latest versions with flexible commit strategies, enabling users to keep dependencies current with report-only mode for CI/CD safety checks"

## Clarifications

### Session 2025-10-28

- Q: How should merge conflicts during subtree updates be handled? → A: Fail with clear guidance - Exit with error code 1, leave repository in conflicted state with clear message showing conflict markers and instructions to resolve
- Q: What format should report mode use for change summary (commit count or date difference)? → A: Both commit count and date (e.g., "5 commits behind (2 weeks old)")
- Q: What exit code should batch update (`--all`) return when some subtrees succeed and some fail? → A: Exit code 1 if any subtree fails, continue processing all subtrees
- Q: Should network failures trigger automatic retry logic? → A: No automatic retries (fail immediately), defer retry feature to backlog
- Q: What commit message format should be used for update operations? → A: Tag-aware format - For tags: "Update subtree example-lib (v1.2.0 -> v1.3.0)" with tag and commit details; For branches: "Update subtree example-lib" with commit hashes, URL, and prefix location

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Selective Update with Default Squash (Priority: P1)

A developer needs to update a specific subtree dependency that has new bug fixes available. They want to pull in the latest changes from the configured branch while maintaining a clean, single-commit history in their repository.

**Why this priority**: Core functionality that delivers immediate value - updating a single subtree is the most common use case and provides a complete, testable MVP.

**Independent Test**: Can be fully tested by adding a subtree, making upstream commits, running `subtree update <name>`, and verifying the subtree directory contains new commits and config tracks the update with a single squashed commit.

**Acceptance Scenarios**:

1. **Given** a repository with subtree "vendor-lib" at commit abc123 tracking ref "main", **When** user runs `subtree update vendor-lib` and upstream has new commit def456, **Then** vendor-lib directory is updated to def456, config is updated with new commit hash, and changes appear as single squashed commit
2. **Given** a repository with subtree "tools" at commit xyz789, **When** user runs `subtree update tools` and no new commits exist upstream, **Then** command reports "Already up to date" and exits with code 0
3. **Given** a repository with subtree "dep" tracking tag "v1.2.3", **When** user runs `subtree update dep`, **Then** command reports "Already up to date" (tags don't change) and exits with code 0

---

### User Story 2 - Bulk Update All Subtrees (Priority: P2)

A developer wants to update all subtrees in their repository to ensure all dependencies are current before a release. They need a single command that processes all configured subtrees.

**Why this priority**: High-value convenience feature that builds on P1 - enables batch operations but requires the single-update foundation to work first.

**Independent Test**: Can be fully tested by adding multiple subtrees with available updates, running `subtree update --all`, and verifying all subtrees are updated in sequence with proper status reporting.

**Acceptance Scenarios**:

1. **Given** repository with 3 subtrees where 2 have updates available, **When** user runs `subtree update --all`, **Then** both outdated subtrees are updated, third shows "Already up to date", and summary reports "2 updated, 1 skipped"
2. **Given** repository with 5 subtrees all up-to-date, **When** user runs `subtree update --all`, **Then** all report "Already up to date" and summary shows "0 updated, 5 skipped"
3. **Given** repository with no subtrees configured, **When** user runs `subtree update --all`, **Then** command reports "No subtrees configured" and exits with code 0

---

### User Story 3 - Report Mode for CI/CD (Priority: P2)

A CI/CD pipeline needs to check if subtree dependencies have available updates without modifying the repository. The check should provide detailed information about what updates exist and exit with a specific code for automation.

**Why this priority**: Critical for automation use cases - enables "update check" workflows in CI without requiring write access or risking repository changes.

**Independent Test**: Can be fully tested by running `subtree update --report` with various subtree states (up-to-date, updates available) and verifying output format, exit codes, and that no repository changes occur.

**Acceptance Scenarios**:

1. **Given** repository with subtree "lib" at commit abc123 where upstream has commit def456, **When** user runs `subtree update lib --report`, **Then** output shows "lib: abc123 → def456 (5 commits behind, 2 weeks old)" and exits with code 5
2. **Given** repository with subtree "tools" already up-to-date, **When** user runs `subtree update tools --report`, **Then** output shows "tools: Up to date" and exits with code 0
3. **Given** repository with 3 subtrees where 1 has updates, **When** user runs `subtree update --all --report`, **Then** output lists all 3 with status, summary shows "1 update available", and exits with code 5

---

### User Story 4 - Preserve Full History with No-Squash (Priority: P3)

A developer wants to update a subtree while preserving the complete commit history from upstream, useful for debugging or understanding detailed change history.

**Why this priority**: Lower priority alternative workflow - squash is the sensible default, but preserving full history has legitimate use cases for certain projects.

**Independent Test**: Can be fully tested by running `subtree update --no-squash` and verifying git log shows individual commits from upstream rather than a single squashed commit.

**Acceptance Scenarios**:

1. **Given** subtree "lib" with 5 new commits upstream, **When** user runs `subtree update lib --no-squash`, **Then** git log shows all 5 individual commits with original messages and authors
2. **Given** subtree "tools" added with `--squash` originally, **When** user runs `subtree update tools --no-squash`, **Then** update uses no-squash mode (squash/no-squash can change per operation)
3. **Given** subtree with upstream merge commits, **When** user runs `subtree update --no-squash`, **Then** full merge structure is preserved in repository history

---

### User Story 5 - Error Handling and Validation (Priority: P1)

Users need clear, actionable error messages when update operations fail due to invalid state, missing configuration, or git operation failures.

**Why this priority**: Essential for user experience - without proper error handling, the core P1 functionality becomes unusable when things go wrong.

**Independent Test**: Can be fully tested by triggering various error conditions (missing config, invalid subtree name, dirty working tree) and verifying error messages are clear and exit codes are correct.

**Acceptance Scenarios**:

1. **Given** no subtree.yaml exists, **When** user runs `subtree update mylib`, **Then** error shows "❌ Configuration file not found. Run 'subtree init' first" and exits with code 3
2. **Given** subtree.yaml exists but doesn't contain "mylib", **When** user runs `subtree update mylib`, **Then** error shows "❌ Subtree 'mylib' not found in configuration" and exits with code 2
3. **Given** dirty working tree (uncommitted changes), **When** user runs `subtree update lib`, **Then** error shows "❌ Working tree has uncommitted changes. Commit or stash before updating" and exits with code 1
4. **Given** git subtree operation fails (e.g., network error), **When** update is in progress, **Then** error surfaces git failure message and exits with code 1

---

### Edge Cases

- What happens when upstream branch no longer exists (e.g., renamed from "main" to "master")?
- **Merge conflicts**: Exit with error code 1, leave repository in conflicted state with clear message showing conflict markers and instructions to resolve manually
- What if subtree.yaml is corrupted or has invalid YAML syntax during update check?
- How does report mode handle network failures when fetching remote information?
- What happens when updating a subtree that was manually modified in the working tree?
- How does `--all` behave if one subtree update fails midway through the batch?
- What if the configured ref exists but the commit hash in config doesn't exist upstream (history rewritten)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support updating individual subtrees by name via `subtree update <name>`
- **FR-002**: System MUST support updating all configured subtrees via `subtree update --all`
- **FR-003**: System MUST default to squash mode (single commit per update) unless `--no-squash` flag is provided
- **FR-004**: System MUST always update to the latest commit of the ref specified in subtree.yaml for that subtree
- **FR-005**: System MUST update the subtree's commit hash in subtree.yaml after successful update
- **FR-006**: System MUST support report mode via `--report` flag that shows update status without modifying repository
- **FR-007**: Report mode MUST display current commit, available commit, and change summary showing both commit count AND date difference (e.g., "5 commits behind (2 weeks old)") for each subtree
- **FR-008**: Report mode MUST exit with code 5 if any updates are available, code 0 if all up-to-date
- **FR-009**: System MUST exit with code 0 when subtree is already up-to-date (no update needed)
- **FR-010**: System MUST commit update directly to current branch (no topic branch creation)
- **FR-011**: System MUST validate subtree.yaml exists before attempting update operations
- **FR-012**: System MUST validate requested subtree name exists in configuration
- **FR-013**: System MUST validate working tree is clean (no uncommitted changes) before update
- **FR-014**: System MUST handle network failures gracefully with clear error messages (no automatic retries, fail immediately)
- **FR-015**: System MUST surface git operation failures with actionable error information
- **FR-016**: When `--all` encounters an error on one subtree, it MUST report error, continue with remaining subtrees, and exit with code 1 if any failures occurred
- **FR-017**: System MUST generate tag-aware commit messages with metadata:
  - For tag refs: "Update subtree <name> (v1.2.0 -> v1.3.0)" with body including tag version, commit hash, remote URL, and prefix location
  - For branch/commit refs: "Update subtree <name>" with body including previous commit, new commit, remote URL, and prefix location
  - Body must include squash mode used for the update
- **FR-018**: Report mode MUST complete checks in under 5 seconds for typical repositories (1-20 subtrees, <1000 commits delta per subtree)

### Key Entities

- **Update Operation**: Represents a subtree update with source subtree name, target ref, current commit, new commit, squash mode, and result status
- **Update Report**: Contains subtree name, current commit, available commit, update status (up-to-date, behind, ahead, diverged), and change summary
- **Batch Update Result**: Summary of multiple update operations with counts of updated, skipped, and failed subtrees

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Update check in report mode completes in under 5 seconds for repositories with up to 20 subtrees
- **SC-002**: Users understand update status without applying changes - report mode clearly shows which subtrees have updates
- **SC-003**: 100% of applied updates are tracked in config with correct commit hash after operation completes
- **SC-004**: Update operations exit with code 5 when report mode detects updates, enabling CI/CD integration
- **SC-005**: Users can successfully update a single subtree on first attempt with minimal command syntax
- **SC-006**: Batch update with `--all` processes all subtrees and provides summary of results
- **SC-007**: Error messages are actionable - users know exactly what to do when update fails
