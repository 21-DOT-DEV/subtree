# Feature Specification: Case-Insensitive Names & Validation

**Feature Branch**: `007-case-insensitive-names`  
**Created**: 2025-10-29  
**Status**: Draft  
**Input**: "Feature: Case-Insensitive Names - Portable config validation and flexible name matching"

## Clarifications

### Session 2025-10-29

- Q: What validation rules should apply to prefix paths to prevent security issues and ensure portability? → A: Strict relative paths only - reject absolute paths, reject parent traversal (../ sequences), allow forward slashes only. Spaces in path names are allowed.
- Q: Should subtree names with non-ASCII characters be allowed? → A: Allow but warn - accept non-ASCII names but display warning that case-matching won't work across variations (ASCII-only case-folding).
- Q: When validation detects corruption during a command, should the system ensure no partial state changes? → A: Validate before any operations - check for corruption at command start, before executing git operations or modifying config.
- Q: When a user provides a name with leading/trailing whitespace, what should be stored in config? → A: Trim and store normalized - remove leading/trailing whitespace before storing, user sees trimmed version in config.
- Q: What validation checks should the validate command perform? → A: Comprehensive config health check (duplicates + schema + unreachable remotes + invalid paths + consistency checks), but command should be named `lint` not `validate`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Flexible Name Matching (Priority: P1)

Users can reference subtrees by name in any case variation without remembering exact capitalization. Commands like `remove`, `update`, and future commands accept case-insensitive name matching.

**Why this priority**: Core user experience improvement - removes friction from daily workflow. Users shouldn't need to remember whether they typed `Hello-World` or `hello-world` when they added a subtree weeks ago.

**Independent Test**: Add a subtree with name `My-Library`, then successfully remove it with `subtree remove my-library`. Verify config entry is deleted.

**Acceptance Scenarios**:

1. **Given** config contains subtree named `Hello-World`, **When** user runs `subtree remove hello-world`, **Then** subtree is removed successfully
2. **Given** config contains subtree named `my-lib`, **When** user runs `subtree update MY-LIB`, **Then** subtree is updated successfully
3. **Given** config contains subtree named `VendorLib`, **When** user runs `subtree remove vendorlib`, **Then** subtree is removed successfully
4. **Given** config contains subtree named `Hello-World`, **When** user runs `subtree remove Hello-World` (exact match), **Then** subtree is removed successfully
5. **Given** config contains no subtree matching `nonexistent`, **When** user runs `subtree remove nonexistent`, **Then** error message displays "Subtree 'nonexistent' not found"

---

### User Story 2 - Duplicate Name Prevention (Priority: P2)

Users are prevented from adding subtrees with case-variant duplicate names during the `add` command. The system validates names case-insensitively before executing git operations, ensuring config integrity from the start.

**Why this priority**: Prevents config corruption at the source. Once implemented, users cannot create problematic configs through normal CLI usage.

**Independent Test**: Add subtree named `Hello-World`, then attempt to add another named `hello-world`. Verify second add fails with clear error before any git operations execute.

**Acceptance Scenarios**:

1. **Given** config contains subtree named `Hello-World`, **When** user runs `subtree add --name hello-world --remote <url>`, **Then** command fails with error "Subtree name 'hello-world' conflicts with existing 'Hello-World'" before git operations
2. **Given** config contains subtree named `my-lib`, **When** user runs `subtree add --name MY-LIB --remote <url>`, **Then** command fails with duplicate name error
3. **Given** config contains subtree named `vendor`, **When** user runs `subtree add --name Vendor --remote <url>`, **Then** command fails with duplicate name error
4. **Given** empty config, **When** user runs `subtree add --name First-Lib --remote <url>`, **Then** subtree is added successfully
5. **Given** config contains `First-Lib`, **When** user runs `subtree add --name Second-Lib --remote <url>`, **Then** subtree is added successfully (different names, no conflict)

---

### User Story 3 - Duplicate Prefix Prevention (Priority: P2)

Users are prevented from adding subtrees with case-variant duplicate prefixes during the `add` command. The system validates prefixes case-insensitively to prevent filesystem conflicts on case-insensitive filesystems (macOS/Windows).

**Why this priority**: Critical for cross-platform portability. On macOS/Windows, `vendor/lib` and `vendor/Lib` are the same path - git subtree would fail. Preventing this ensures configs work everywhere.

**Independent Test**: Add subtree with prefix `vendor/lib`, then attempt to add another with prefix `vendor/Lib`. Verify second add fails with clear error before git operations.

**Acceptance Scenarios**:

1. **Given** config contains subtree with prefix `vendor/lib`, **When** user runs `subtree add --prefix vendor/Lib --remote <url>`, **Then** command fails with error "Subtree prefix 'vendor/Lib' conflicts with existing 'vendor/lib'" before git operations
2. **Given** config contains subtree with prefix `deps/ui`, **When** user runs `subtree add --prefix DEPS/UI --remote <url>`, **Then** command fails with duplicate prefix error
3. **Given** config contains subtree with prefix `third-party/Auth`, **When** user runs `subtree add --prefix third-party/auth --remote <url>`, **Then** command fails with duplicate prefix error
4. **Given** empty config, **When** user runs `subtree add --prefix vendor/lib --remote <url>`, **Then** subtree is added successfully
5. **Given** config contains prefix `vendor/lib`, **When** user runs `subtree add --prefix vendor/auth --remote <url>`, **Then** subtree is added successfully (different prefixes, no conflict)

---

### User Story 4 - Config Corruption Detection (Priority: P3)

When users manually edit `subtree.yaml` and introduce case-variant duplicates, commands detect the corruption and provide clear guidance to fix it. The system prevents operations on corrupted configs.

**Why this priority**: Safety net for manual edits. While normal CLI usage prevents duplicates, users can still hand-edit YAML. This catches problems before they cause subtle bugs.

**Independent Test**: Manually create config with `Hello-World` and `hello-world` entries. Run any config-reading command. Verify it fails with diagnostic error listing both conflicting entries.

**Acceptance Scenarios**:

1. **Given** manually edited config contains both `Hello-World` and `hello-world` entries, **When** user runs `subtree remove hello-world`, **Then** command fails with error "Multiple subtrees match 'hello-world' (found: 'Hello-World', 'hello-world')" and guidance to manually fix
2. **Given** config contains duplicate names (manual corruption), **When** user runs `subtree add --name new-lib --remote <url>`, **Then** command validates config first and fails with corruption error before proceeding
3. **Given** config contains both `vendor/lib` and `vendor/Lib` prefixes (manual corruption), **When** user runs `subtree update some-lib`, **Then** command fails with error "Duplicate prefix detected" and guidance to fix
4. **Given** valid config with no duplicates, **When** user runs any command, **Then** validation passes silently and command proceeds normally

---

### User Story 5 - Case Preservation (Priority: P4)

The system preserves user-specified capitalization in `subtree.yaml` while performing case-insensitive matching for lookups. Users see their intentional naming choices reflected in the config file.

**Why this priority**: Respects user intent and enables team naming conventions. No magic transformations - "what you type is what you get" in the config file.

**Independent Test**: Add subtree with `--name My-Awesome-Library`. Verify `subtree.yaml` contains `name: My-Awesome-Library` (exact capitalization preserved). Then successfully update it with `subtree update my-awesome-library`.

**Acceptance Scenarios**:

1. **Given** user runs `subtree add --name My-Library --remote <url>`, **When** examining subtree.yaml, **Then** entry shows `name: My-Library` (exact capitalization preserved)
2. **Given** user runs `subtree add --name VENDOR-LIB --prefix vendor-lib --remote <url>`, **When** examining subtree.yaml, **Then** entry shows `name: VENDOR-LIB` and `prefix: vendor-lib` (both preserved exactly as typed)
3. **Given** config contains `name: Hello-World`, **When** user runs `subtree update hello-world`, **Then** subtree updates successfully and config still shows `name: Hello-World` (original case preserved)
4. **Given** config contains mixed-case names like `MyLib`, `another-lib`, `THIRD_LIB`, **When** viewing subtree.yaml, **Then** all names appear exactly as originally entered

---

### Edge Cases

- **Empty Config**: Commands handle empty `subtree.yaml` gracefully when checking for duplicates (no false positives)
- **Special Characters**: Names with hyphens, underscores, dots are matched case-insensitively (e.g., `My-Lib.v2` matches `my-lib.v2`)
- **Whitespace**: Leading/trailing whitespace in names and prefixes is trimmed before storage and comparison (normalized)
- **Unicode**: Case-insensitive matching works for ASCII only; non-ASCII names are allowed but trigger warning that case-matching won't work across variations
- **Prefix Path Format**: Prefixes must be relative paths with forward slashes only; absolute paths and parent directory traversal (`../`) are rejected; spaces in directory names are allowed
- **Multiple Matches from Manual Corruption**: When corruption creates multiple matches, system fails safely with validation error before any operations execute
- **Config File Missing**: When `subtree.yaml` doesn't exist, duplicate validation is skipped (nothing to duplicate)
- **Malformed YAML**: If config is unparseable, commands fail with YAML error before duplicate validation runs

## Requirements *(mandatory)*

### Functional Requirements

#### Name Matching
- **FR-001**: System MUST perform case-insensitive exact name matching for all commands that reference subtrees by name (`remove`, `update`, future commands)
- **FR-002**: System MUST match full subtree name only (no partial/prefix matching - `hello` does NOT match `hello-world`)
- **FR-003**: System MUST preserve original user-specified capitalization in `subtree.yaml` entries while performing case-insensitive lookups (after whitespace trimming)
- **FR-003a**: System MUST trim leading and trailing whitespace from names and prefixes before storing in config
- **FR-003b**: System MUST accept non-ASCII characters in names but display warning that case-insensitive matching only works for ASCII characters

#### Path Validation
- **FR-004**: System MUST validate that prefix paths are relative (reject absolute paths starting with `/`)
- **FR-004a**: System MUST reject prefix paths containing parent directory traversal (`../`)
- **FR-004b**: System MUST require forward slashes (`/`) as path separators (reject backslashes `\`)
- **FR-004c**: System MUST allow spaces in directory names within prefix paths

#### Duplicate Prevention (Add Command)
- **FR-005**: System MUST validate for case-insensitive duplicate names before executing `git subtree add` operations
- **FR-006**: System MUST validate for case-insensitive duplicate prefixes before executing `git subtree add` operations  
- **FR-007**: System MUST prevent add operations when case-variant duplicates are detected, returning non-zero exit code
- **FR-008**: System MUST display error messages showing both the attempted name/prefix and the conflicting existing entry

#### Config Validation
- **FR-009**: System MUST validate config for case-insensitive duplicates before executing any operations in commands that read config (`add`, `remove`, `update`)
- **FR-010**: System MUST skip config validation for commands that don't read config (`init`, `--help`, `--version`)
- **FR-011**: System MUST detect multiple case-variant matches during name lookup operations
- **FR-012**: System MUST fail operations when multiple matches exist due to manual config corruption, before any git operations or config modifications

#### Error Messages
- **FR-013**: System MUST provide error messages in "detailed with guidance" format: error statement + context + actionable fix steps
- **FR-014**: Duplicate name errors MUST display: emoji prefix, conflicting names, brief explanation, fix options
- **FR-015**: Duplicate prefix errors MUST display: emoji prefix, conflicting prefixes, brief explanation, fix options
- **FR-016**: Config corruption errors MUST display: emoji prefix, all conflicting entries found, manual fix guidance, reference to `lint` command
- **FR-017**: Non-ASCII name warnings MUST display informational message explaining case-matching limitations (ASCII-only case-folding)

#### Exit Codes
- **FR-018**: System MUST return exit code 1 for user errors (duplicate names/prefixes detected during add, invalid path formats)
- **FR-019**: System MUST return exit code 2 for config corruption errors (manual duplicates detected)
- **FR-020**: System MUST return exit code 0 for successful operations (warnings don't affect exit code)

### Key Entities

- **Subtree Entry**: Configuration entry representing a git subtree, containing:
  - **name**: User-specified identifier (case-preserved string, whitespace-trimmed)
  - **prefix**: Filesystem path where subtree lives (case-preserved string, whitespace-trimmed, validated as relative path)
  - **remote**: Git repository URL
  - **ref**: Branch/tag reference
  - **commit**: SHA of last sync
  - **squash**: Boolean indicating squash mode

- **Validation Rules**: Case-insensitive uniqueness constraints:
  - **Name uniqueness**: No two subtrees can have names that match case-insensitively
  - **Prefix uniqueness**: No two subtrees can have prefixes that match case-insensitively
  - **Path format**: Prefixes must be relative paths (no `/` prefix, no `../`, forward slashes only)
  - Comparison: Normalize both values to lowercase, then compare for equality

- **Lint Command**: Comprehensive config health check tool (referenced in error messages), performs:
  - Case-insensitive duplicate detection (names and prefixes)
  - YAML schema validation (structure, required fields, data types)
  - Path format validation (relative paths, no traversal, correct separators)
  - Unreachable remote detection (optional network checks)
  - Config consistency checks (internal data integrity)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can successfully match subtrees regardless of case in 100% of valid lookup attempts (e.g., `Hello-World` matched by `hello-world`)
- **SC-002**: 100% of case-variant duplicate names are detected and prevented during `add` operations before git commands execute
- **SC-003**: 100% of case-variant duplicate prefixes are detected and prevented during `add` operations before git commands execute
- **SC-004**: Manually corrupted configs (with case-variant duplicates) are detected with 100% accuracy when config is loaded by relevant commands, before any operations execute
- **SC-005**: Error messages guide users to resolution in ≥90% of cases (measured by reduction in follow-up support questions)
- **SC-006**: Config capitalization is preserved exactly as user entered it in 100% of add operations (after whitespace trimming)
- **SC-007**: 100% of invalid prefix paths (absolute, traversal, backslashes) are rejected before git operations with clear error messages
- **SC-008**: Leading/trailing whitespace in names and prefixes is normalized in 100% of cases before storage
- **SC-009**: Non-ASCII names trigger informational warnings in 100% of cases, educating users about case-matching limitations
- **SC-010**: Config validation adds <50ms overhead to command execution (measured via integration tests)
- **SC-011**: Configs created on macOS work without modification on Linux and vice versa (100% cross-platform portability)
