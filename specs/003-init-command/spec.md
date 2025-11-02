# Feature Specification: Init Command

**Feature Branch**: `003-init-command`  
**Created**: 2025-10-27  
**Status**: Ready for Implementation  
**Input**: User description: "Create the init command so users can create a valid subtree.yaml"

## Clarifications

### Session 2025-10-27

- Q: Error message format - CLI tools use different error reporting patterns. Which format should be used? → A: Emoji-prefixed format (e.g., "❌ subtree.yaml already exists")
- Q: Schema reference URL - What should the header comment reference for documentation? → A: Link to GitHub repository README with usage examples (e.g., "# Managed by subtree CLI - https://github.com/org/subtree")
- Q: Concurrent execution behavior - How should the command handle multiple simultaneous init processes? → A: Last writer wins with atomic file operations (write to temp, rename atomically)
- Q: Symbolic link resolution - How should the command handle symbolic links when finding git root? → A: Follow symlinks to find real git root, create file at real location (matches git behavior)
- Q: Success message detail level - Should the success message show relative or absolute paths? → A: Relative path from current directory (e.g., "✅ Created subtree.yaml" or "✅ Created ../../subtree.yaml")

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - First-Time Setup (Priority: P1)

As a developer starting to use subtree CLI, I want to initialize a configuration file in my git repository so that I can begin managing subtrees declaratively.

**Why this priority**: This is the entry point for all users. Without the ability to create `subtree.yaml`, no other commands can function. This provides immediate value by setting up the configuration scaffold.

**Independent Test**: Can be fully tested by running `subtree init` in a fresh git repository and verifying that a valid `subtree.yaml` file is created at the repository root with proper schema structure.

**Acceptance Scenarios**:

1. **Given** I am in a git repository with no existing `subtree.yaml`, **When** I run `subtree init`, **Then** a `subtree.yaml` file is created at the repository root with minimal valid structure
2. **Given** I am in a git repository, **When** `subtree init` succeeds, **Then** the command outputs the path to the created file and exits with code 0
3. **Given** I am in a git repository, **When** I run `subtree init`, **Then** the created config includes a schema reference comment for documentation

---

### User Story 2 - Preventing Accidental Overwrites (Priority: P2)

As a developer with an existing `subtree.yaml`, I want the init command to protect my configuration from accidental overwrite, with an explicit opt-in to force recreation if needed.

**Why this priority**: Data protection is critical for git-overlay tools. This prevents users from losing their existing subtree configurations accidentally, following industry best practices from tools like npm, lefthook, and pre-commit.

**Independent Test**: Can be fully tested by creating a `subtree.yaml`, running `subtree init`, verifying it fails with clear error message, then running `subtree init --force` and verifying the file is recreated.

**Acceptance Scenarios**:

1. **Given** a `subtree.yaml` already exists in the repository, **When** I run `subtree init`, **Then** the command fails with exit code 1 and error message "❌ subtree.yaml already exists"
2. **Given** a `subtree.yaml` already exists, **When** I run `subtree init --force`, **Then** the existing file is overwritten with a fresh minimal config and command exits with code 0
3. **Given** a `subtree.yaml` already exists, **When** `subtree init` fails, **Then** the error message suggests using `--force` flag to overwrite

---

### User Story 3 - Git Repository Validation (Priority: P3)

As a user who might run subtree commands outside a git context, I want clear error messages when attempting to initialize outside a git repository, so I understand the tool's requirements.

**Why this priority**: Since subtree.yaml manages git subtrees, it only makes sense within a git repository. This provides helpful feedback to users who may be confused about where to run the command. While important for UX, it's lower priority than the core initialization functionality.

**Independent Test**: Can be fully tested by attempting to run `subtree init` in a directory without git initialization, verifying appropriate error message and non-zero exit code.

**Acceptance Scenarios**:

1. **Given** I am in a directory that is not a git repository, **When** I run `subtree init`, **Then** the command fails with exit code 1 and error message "❌ Must be run inside a git repository"
2. **Given** I am in a subdirectory of a git repository, **When** I run `subtree init`, **Then** the command succeeds and creates `subtree.yaml` at the git repository root (not current directory)
3. **Given** I am in a git repository root, **When** I run `subtree init`, **Then** the `subtree.yaml` is created in the current directory

### Edge Cases

- **Nested git repositories (submodules)**: If running in a directory with multiple `.git` directories in parent paths, should use the closest repository root
- **Bare git repositories**: If in a bare repository (no working tree), should fail with appropriate error since `subtree.yaml` requires a working directory
- **Permission issues**: If user lacks write permissions to repository root, should fail with clear error indicating permission problem
- **Concurrent execution**: If multiple `subtree init` processes run simultaneously, use atomic file operations (write to temporary file, then atomic rename) with last writer wins - no user-facing error since both processes write identical content
- **Symbolic links**: If repository root is accessed via symlink, follow symlinks to find the real git root location and create the file there (matches `git rev-parse --show-toplevel` behavior, ensures canonical config location)
- **Detached HEAD state**: Command should work regardless of git HEAD state (detached, branch, tag)

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: Command MUST verify current directory is within a git repository before proceeding
- **FR-002**: Command MUST determine git repository root directory (via `.git` location), resolving any symbolic links to the canonical path
- **FR-003**: Command MUST check if `subtree.yaml` exists at repository root before creating
- **FR-004**: Command MUST fail with exit code 1 if `subtree.yaml` exists and `--force` flag is not provided
- **FR-005**: Command MUST create `subtree.yaml` at repository root with minimal valid YAML structure using atomic file operations (write to temporary file, then rename)
- **FR-006**: Created config MUST include an empty `subtrees: []` array
- **FR-007**: Created config MUST include a header comment linking to GitHub repository README (e.g., "# Managed by subtree CLI - https://github.com/[org]/subtree")
- **FR-008**: Command MUST support `--force` flag to overwrite existing `subtree.yaml`
- **FR-009**: Command MUST output emoji-prefixed success message with relative file path from current directory when config is created (e.g., "✅ Created subtree.yaml" if at root, "✅ Created ../../subtree.yaml" if in subdirectory)
- **FR-010**: Command MUST provide emoji-prefixed error messages for failure scenarios using ❌ for errors, ℹ️ for info, and ✅ for success (e.g., "❌ subtree.yaml already exists", "❌ Must be run inside a git repository", "❌ Permission denied")
- **FR-011**: Command MUST exit with code 0 on success, non-zero on failure
- **FR-012**: Command MUST work correctly when executed from any subdirectory within the git repository

### Key Entities

- **subtree.yaml**: Configuration file containing array of subtree definitions; located at git repository root; must be valid YAML with `subtrees` key
- **Git Repository Root**: The directory containing `.git` folder; used as anchor point for all subtree path references and config file location
- **Minimal Config Structure**: A valid but empty configuration consisting of schema reference comment and empty subtrees array

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: Command completes initialization in under 1 second for typical repositories
- **SC-002**: Users can successfully initialize configuration on first attempt without consulting documentation
- **SC-003**: Error messages are clear enough that users understand and resolve issues without external help
- **SC-004**: Created `subtree.yaml` validates successfully against schema (as checked by future `validate` command)
- **SC-005**: Command works reliably across all supported platforms (macOS 13+, Ubuntu 20.04 LTS)
- **SC-006**: 100% of initialization attempts either succeed with valid config or fail with clear actionable error message
