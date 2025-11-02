# Feature Specification: Add Command

**Feature Branch**: `004-add-command`  
**Created**: 2025-10-27  
**Status**: Draft  
**Input**: User description: "Add Command - Add subtrees to repository via CLI flags with atomic commits"

## Clarifications

### Session 2025-10-27

- Q: Atomic commit strategy - How should add operations create commits? → A: Option A (commit-amend pattern): Execute `git subtree add` → update config → `git commit --amend` for single atomic commit
- Q: `--all` flag commit granularity - One commit per subtree or single mega-commit? → A: Removed `--all` from initial scope, moved to backlog (requires subtree detection logic)
- Q: Workflow support - Config-First vs CLI-First? → A: CLI-First only (flags create config entry), Config-First workflow moved to backlog
- Q: Required flags and defaults - Which flags required, which have defaults? → A: Only `--remote` required; `--name` defaults to repo name from URL, `--prefix` defaults to name, `--ref` defaults to 'main'
- Q: Duplicate detection - How to detect if subtree already added? → A: Option C - Check config for duplicate name OR prefix before attempting add
- Q: Commit message format - What message format for the atomic commit? → A: Custom format: `Add subtree <name>\n- Added from <ref-type>: <ref> (commit: <short-hash>)\n- From: <remote-url>\n- In: <prefix>`
- Q: Config file location - Where to update subtree.yaml when run from subdirectory? → A: Option A - Always update at git root (matches init command, ensures single canonical config)
- Q: URL validation timing - When to validate remote URL and ref existence? → A: Option C - No upfront validation, let git fail naturally and surface error messages (avoid duplicate validation, network calls, stale results)
- Q: Commit amend failure recovery - What if git subtree add succeeds but commit amend fails? → A: Option B - Leave subtree commit intact, show error with manual recovery steps (user edits subtree.yaml and runs git commit --amend)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Minimal Subtree Addition (Priority: P1)

As a developer managing dependencies, I want to add a subtree to my repository with minimal typing by only specifying the remote URL, so I can quickly integrate external libraries without remembering complex git commands or repetitive configuration.

**Why this priority**: This is the core value proposition - simplifying git subtree operations. With smart defaults, users can add subtrees in one command instead of manually running `git subtree add` and editing `subtree.yaml`.

**Independent Test**: Can be fully tested by running `subtree add --remote <url>` in a git repository with initialized config, verifying the subtree is added, config entry created, and single atomic commit produced.

**Acceptance Scenarios**:

1. **Given** I have a git repository with `subtree.yaml` initialized, **When** I run `subtree add --remote https://github.com/example/lib.git`, **Then** the subtree is added to directory `lib/` with default squash enabled
2. **Given** I add a subtree with only `--remote` flag, **When** the operation completes, **Then** a new entry appears in `subtree.yaml` with name 'lib', prefix 'lib', ref 'main', and the commit hash from the subtree merge
3. **Given** I add a subtree successfully, **When** I check git history, **Then** exactly one commit exists containing both the subtree files AND the updated `subtree.yaml`
4. **Given** I add a subtree, **When** the command completes, **Then** it outputs an emoji-prefixed success message showing the subtree name, prefix, and commit hash

---

### User Story 2 - Override Smart Defaults (Priority: P2)

As a developer with specific naming conventions or directory structures, I want to override the default name, prefix, or ref when adding a subtree, so I can maintain my project's organization standards.

**Why this priority**: While smart defaults cover most cases, flexibility is essential for real-world projects with established conventions. Users must be able to control placement and naming without editing config files.

**Independent Test**: Can be fully tested by running `subtree add` with override flags and verifying the config entry uses the provided values instead of defaults.

**Acceptance Scenarios**:

1. **Given** I want a custom directory structure, **When** I run `subtree add --remote https://github.com/example/lib.git --prefix vendor/example-lib`, **Then** the subtree is added to `vendor/example-lib/` directory
2. **Given** I want a specific name, **When** I run `subtree add --remote https://github.com/example/lib.git --name my-lib`, **Then** the config entry uses name 'my-lib' and prefix 'my-lib' (prefix still defaults from name)
3. **Given** I want to track a specific branch, **When** I run `subtree add --remote https://github.com/example/lib.git --ref develop`, **Then** the subtree is added from the 'develop' branch and config reflects ref 'develop'
4. **Given** I provide multiple overrides, **When** I run `subtree add --remote <url> --name custom --prefix src/deps/custom --ref v2.0`, **Then** all values are used in the config entry and subtree operation

---

### User Story 3 - No-Squash Mode (Priority: P3)

As a developer who wants to preserve complete upstream history, I want to disable squashing when adding a subtree, so I can maintain full git history and bisectability from the upstream project.

**Why this priority**: Most users benefit from squashed history (cleaner, fewer commits), but advanced users may need full history for debugging or compliance. This is a less common but important use case.

**Independent Test**: Can be fully tested by running `subtree add --no-squash` and verifying the git log contains individual commits from the upstream repository instead of a single squashed commit.

**Acceptance Scenarios**:

1. **Given** I want full upstream history, **When** I run `subtree add --remote https://github.com/example/lib.git --no-squash`, **Then** the git subtree operation executes without the `--squash` flag
2. **Given** I use `--no-squash`, **When** the operation completes, **Then** the config entry contains `squash: false` to track this preference
3. **Given** I use `--no-squash`, **When** I view git log for the subtree directory, **Then** I see all individual commits from the upstream repository history

---

### User Story 4 - Duplicate Prevention (Priority: P4)

As a developer managing multiple subtrees, I want the tool to prevent accidentally adding the same subtree twice, so I avoid duplicate directories and conflicting configuration entries.

**Why this priority**: Duplicate prevention protects users from mistakes but isn't part of the happy path. Critical for data safety but lower priority than core add functionality.

**Independent Test**: Can be fully tested by adding a subtree, then attempting to add it again (or another subtree with same name/prefix) and verifying appropriate error with non-zero exit code.

**Acceptance Scenarios**:

1. **Given** I have already added `subtree add --remote https://github.com/example/lib.git` (name 'lib'), **When** I run the same command again, **Then** the command fails with error "❌ Subtree with name 'lib' already exists in configuration"
2. **Given** I have a subtree with prefix 'vendor/lib', **When** I attempt to add a different subtree with `--prefix vendor/lib`, **Then** the command fails with error "❌ Subtree with prefix 'vendor/lib' already exists in configuration"
3. **Given** duplicate detection fails, **When** the error is shown, **Then** the command exits with non-zero exit code and does not modify the repository or config
4. **Given** a subtree exists with name 'lib' but I provide `--name different-lib`, **When** the prefixes don't conflict, **Then** the add succeeds (only name/prefix checked, not remote URL)

---

### User Story 5 - Error Handling & Validation (Priority: P5)

As a developer using the CLI, I want clear error messages when operations fail or inputs are invalid, so I can quickly understand and fix problems without debugging git internals.

**Why this priority**: Robust error handling is essential for good UX but comes after core functionality is working. Users need helpful errors, but the feature must work correctly first.

**Independent Test**: Can be fully tested by triggering various failure scenarios (invalid URL, network failure, missing config, etc.) and verifying appropriate error messages with non-zero exit codes.

**Acceptance Scenarios**:

1. **Given** I run `subtree add --remote invalid-url`, **When** the URL format is invalid, **Then** the command fails with error "❌ Invalid remote URL format: invalid-url"
2. **Given** I run `subtree add --remote https://github.com/nonexistent/repo.git`, **When** git cannot fetch from the remote, **Then** the command fails with the git error message and exits non-zero
3. **Given** I run `subtree add --remote <url>` in a directory without `subtree.yaml`, **When** the config file is missing, **Then** the command fails with error "❌ Configuration file not found. Run 'subtree init' first."
4. **Given** I run `subtree add --remote <url>` outside a git repository, **When** git operations fail, **Then** the command fails with error "❌ Must be run inside a git repository"
5. **Given** git subtree add succeeds but commit amend fails, **When** the error occurs, **Then** the subtree commit remains intact and command shows recovery instructions: manually edit subtree.yaml and run `git commit --amend`

---

### Edge Cases

- **URL parsing edge cases**: How to extract name from `git@github.com:user/repo.git` format? → Extract 'repo' from final path segment, handle both https and git@ formats
- **Conflicting defaults**: If user provides `--name lib` but not `--prefix`, does prefix default to 'lib'? → Yes, prefix always defaults from name whether name is auto-derived or explicitly set
- **Empty repository**: What if the remote URL points to an empty repository? → Let git subtree fail with its error message, surface to user
- **Detached HEAD**: Can subtrees be added in detached HEAD state? → Yes, git subtree supports this, command should work
- **Working directory changes**: What if user has uncommitted changes? → Let git decide (git subtree may require clean working directory), surface error if git fails
- **Name extraction from URL**: What if URL doesn't follow standard patterns (e.g., `file:///local/path.git`)? → Extract final path segment, strip `.git` extension, fallback to error if extraction produces empty string
- **Ref doesn't exist**: What if --ref specifies a branch/tag that doesn't exist on remote? → Let git subtree fail, surface the error (ref validation is git's responsibility)
- **Very long paths**: What if prefix would exceed filesystem limits? → Let filesystem operations fail naturally, surface error message
- **Special characters in names**: What if derived name contains invalid characters for file paths (e.g., `/`, `:`)? → Sanitize name by replacing invalid characters with hyphens, document sanitization rules
- **Concurrent add operations**: What if two `subtree add` commands run simultaneously? → Atomic commit amend may conflict, let git handle locking, surface merge conflict if it occurs

## Requirements *(mandatory)*

### Functional Requirements

**Command Interface**:
- **FR-001**: Command MUST accept `--remote <url>` flag as the only required parameter
- **FR-002**: Command MUST accept optional `--name <name>` flag to override the auto-derived name
- **FR-003**: Command MUST accept optional `--prefix <path>` flag to override the auto-derived prefix
- **FR-004**: Command MUST accept optional `--ref <ref>` flag to override the default ref ('main')
- **FR-005**: Command MUST accept optional `--no-squash` flag to disable squash mode (squash enabled by default)

**Smart Defaults**:
- **FR-006**: When `--name` is not provided, command MUST derive name from remote URL by extracting the final path segment and removing `.git` extension
- **FR-007**: When name derivation produces invalid filesystem characters, command MUST sanitize by replacing all characters EXCEPT alphanumeric (a-z, A-Z, 0-9), hyphens (-), and underscores (_) with hyphens. Invalid characters include but not limited to: `/`, `:`, `\`, `*`, `?`, `"`, `<`, `>`, `|`, whitespace. Regex: replace `[^a-zA-Z0-9_-]+` with `-`
- **FR-008**: When `--prefix` is not provided, command MUST default prefix to the name value (auto-derived or explicitly provided)
- **FR-009**: When `--ref` is not provided, command MUST default to 'main' as the branch/tag to add
- **FR-010**: Squash mode MUST be enabled by default unless `--no-squash` flag is present

**Duplicate Detection**:
- **FR-011**: Before executing git subtree operation, command MUST check `subtree.yaml` at git repository root for existing entry with matching name
- **FR-012**: Before executing git subtree operation, command MUST check `subtree.yaml` at git repository root for existing entry with matching prefix
- **FR-013**: If duplicate name OR duplicate prefix found, command MUST fail with emoji-prefixed error message identifying the conflict
- **FR-014**: Duplicate detection MUST happen before any git operations to avoid partial state

**Git Subtree Operation**:
- **FR-015**: Command MUST execute `git subtree add` with the specified remote, prefix, ref, and squash setting
- **FR-016**: When squash is enabled (default), command MUST pass `--squash` flag to git subtree
- **FR-017**: When `--no-squash` is used, command MUST NOT pass `--squash` flag to git subtree
- **FR-018**: Command MUST capture the commit hash produced by the git subtree add operation

**Configuration Update**:
- **FR-019**: After successful git subtree add, command MUST update `subtree.yaml` at git repository root to add new subtree entry
- **FR-020**: New config entry MUST include: name, remote, prefix, ref (branch or tag), commit (hash from subtree merge), and squash boolean
- **FR-021**: Config update MUST use atomic file operations (write to temp file, rename) to avoid corruption

**Atomic Commit**:
- **FR-022**: After updating `subtree.yaml`, command MUST use `git commit --amend` to include config changes in the subtree commit
- **FR-023**: The resulting commit MUST contain both subtree files AND the updated `subtree.yaml` in a single atomic commit
- **FR-024**: Atomic commit MUST use custom message format: `Add subtree <name>` as title, followed by bullet list: `- Added from <ref-type>: <ref> (commit: <short-hash>)`, `- From: <remote-url>`, `- In: <prefix>`
- **FR-025**: Ref-type in commit message MUST be derived from the ref value using these rules:
  - 'tag' if ref matches pattern: starts with 'v' followed by digits (e.g., v1.0.0, v0.7.0) OR matches semver without 'v' prefix (e.g., 1.0.0, 0.7.0)
  - 'branch' for all other cases (e.g., main, develop, feature/xyz)
  - Regex pattern: `^v?\d+\.\d+(\.\d+)?` (optional 'v', major.minor or major.minor.patch)
- **FR-026**: Short-hash in commit message MUST be the first 8 characters of the commit SHA-1 hash

**Validation**:
- **FR-027**: Command MUST validate that current directory is within a git repository before proceeding
- **FR-028**: Command MUST validate that `subtree.yaml` exists at git repository root before proceeding (exit with error suggesting `subtree init` if missing)
- **FR-029**: Command MUST validate remote URL format supports https://, git@, and file:// schemes (basic format check only; reachability and ref existence delegated to git subtree operation)

**Error Handling**:
- **FR-030**: All error messages MUST use emoji-prefixed format with standard emojis:
  - ❌ (`:x:`) for error messages
  - ✅ (`:white_check_mark:`) for success messages
  - ℹ️ (`:information_source:`) for informational messages (if needed)
  - Example: "❌ Subtree with name 'lib' already exists in configuration"
- **FR-031**: When git subtree operation fails, command MUST surface the git error message and exit non-zero
- **FR-032**: When commit amend fails after successful git subtree add and config update, command MUST leave subtree commit intact and provide recovery guidance: "Subtree added successfully but failed to update config in commit. Manually edit subtree.yaml to add entry, then run: git commit --amend"
- **FR-033**: Command MUST exit with code 0 on success, non-zero on any failure

**Output**:
- **FR-034**: On success, command MUST output emoji-prefixed message showing: subtree name, prefix path, ref, and commit hash
- **FR-035**: Success message format MUST be: "✅ Added subtree '<name>' at <prefix> (ref: <ref>, commit: <short-hash>)"

### Key Entities

- **SubtreeEntry**: Configuration entry in `subtree.yaml`
  - Required attributes: name (string), remote (URL string), prefix (relative path), ref (branch/tag string), commit (SHA-1 hash), squash (boolean)
  - Relationships: One entry per added subtree, persisted atomically with git commit

- **GitSubtreeOperation**: The `git subtree add` command execution
  - Attributes: remote URL, prefix path, ref (branch/tag), squash flag, resulting commit hash
  - Side effects: Creates subtree files in working directory, produces git commit

- **AtomicCommit**: The commit-amend operation combining subtree merge and config update
  - Attributes: original commit hash (from git subtree), amended commit hash (after config update), commit message (preserved from original)
  - Ensures: Single commit contains both subtree files and configuration changes

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can add a subtree with only one flag (`--remote`) and see it successfully integrated in under 10 seconds for typical repositories
- **SC-002**: 100% of successful add operations produce exactly one git commit containing both subtree files and updated configuration
- **SC-003**: Users attempting to add duplicate subtrees (by name or prefix) receive clear error messages within 1 second without any git operations executed
- **SC-004**: Name derivation from URLs works correctly for 100% of standard GitHub/GitLab/Bitbucket URL formats (https and git@)
- **SC-005**: Smart defaults (name/prefix/ref) allow 90% of users to add subtrees without needing override flags
- **SC-006**: Error messages clearly identify the problem and suggest fixes, reducing support questions to <2 per 100 add operations
- **SC-007**: Command works reliably across all supported platforms (macOS 13+, Ubuntu 20.04 LTS) with consistent behavior
