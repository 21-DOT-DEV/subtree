# Command Contract: subtree remove

**Feature**: Remove Command | **Phase**: 1 (Design) | **Date**: 2025-10-28

## Overview

This document defines the external contract for the `subtree remove` command - the command-line interface, exit codes, output format, and behavior guarantees. This contract is stable and forms the basis for integration tests.

---

## Command Syntax

### Basic Usage

```bash
subtree remove <name>
```

**Arguments**:
- `<name>` (required, positional) - Name of the subtree to remove (from configuration)

**Flags**: None in initial implementation

**Examples**:
```bash
# Remove a subtree by name
subtree remove vendor-lib

# Remove with different name
subtree remove my-dependency
```

---

## Exit Codes

| Code | Meaning | When Used |
|------|---------|-----------|
| 0 | Success | Subtree removed successfully (directory + config) OR idempotent success (directory already gone, config cleaned up) |
| 1 | Git operation failure | Not in git repository, dirty working tree, git rm failed, commit creation failed |
| 2 | Subtree not found | Specified subtree name does not exist in configuration |
| 3 | Configuration error | Config file missing or malformed (invalid YAML) |

**Exit Code Guarantees**:
- Exit code 0 ONLY when operation fully succeeds (config updated, commit created)
- Exit codes 1-3 indicate failure with NO side effects (no partial state)
- Validation failures (codes 1-3) occur BEFORE any filesystem/git modifications

---

## Output Format

### Success Messages

#### Normal Removal (Directory Exists)
```
✅ Removed subtree 'vendor-lib' (was at abc123de)
```

**Format**: `✅ Removed subtree '<name>' (was at <short-hash>)`
- `<name>`: Subtree name from input
- `<short-hash>`: First 8 characters of last commit SHA-1 from config

#### Idempotent Removal (Directory Missing)
```
✅ Removed subtree 'vendor-lib' (directory already removed, config cleaned up)
```

**Format**: `✅ Removed subtree '<name>' (directory already removed, config cleaned up)`
- Indicates directory was already gone
- Config entry still cleaned up successfully

### Error Messages

#### Configuration Errors
```
❌ Configuration file not found. Run 'subtree init' first
```
```
❌ Configuration file is malformed: Unexpected token at line 5
```
```
❌ Subtree 'mylib' not found in configuration
```

#### Git Errors
```
❌ Must be run inside a git repository
```
```
❌ Working tree has uncommitted changes. Commit or stash before removing subtrees
```

#### Commit Failure (Recovery Mode)
```
❌ Failed to commit removal. Changes are staged. Run 'git commit' to complete or 'git reset HEAD' to abort.
```

**Error Message Guarantees**:
- All errors use ❌ emoji prefix
- Messages are actionable (suggest next step)
- Parse errors include details when available
- No technical jargon (user-friendly language)

---

## Behavior Guarantees

### Atomicity

**Guarantee**: Removal operation produces exactly ONE commit containing BOTH:
1. Directory removal (if directory existed)
2. Configuration update (entry removed from subtree.yaml)

**Verification**:
```bash
# Check commit contains both changes
git show HEAD --name-only
# Should show: subtree.yaml AND deleted files from prefix directory (if existed)
```

**Exception**: If commit creation fails, changes left staged (documented recovery path)

### Idempotency

**Guarantee**: Command succeeds even if subtree directory already deleted

**Behavior**:
- Skips `git rm` operation (directory already gone)
- Still removes config entry
- Creates commit with config change only
- Different success message indicates idempotent path
- Exit code 0 (success)

**Verification**:
```bash
# Manually delete directory
rm -rf lib/

# Remove command still succeeds
subtree remove vendor-lib
echo $?  # Prints 0

# Config entry removed
grep -q "vendor-lib" subtree.yaml
echo $?  # Prints 1 (not found)
```

### Validation Before Modification

**Guarantee**: ALL validation checks complete BEFORE any filesystem or git changes

**Validation Order**:
1. Inside git repository check
2. Config file exists check
3. Config file parseable check
4. Working tree clean check
5. Subtree name exists check

**Implication**: Any validation failure leaves repository in EXACTLY the same state as before command execution (no partial modifications)

### Working Tree Requirement

**Guarantee**: Command fails with exit code 1 if working tree has uncommitted changes

**Rationale**: Prevents accidental data loss, consistent with Add/Update commands

**Recovery**: User must commit or stash changes before removal

---

## Git Integration

### Commit Creation

**Commit Message Format**:

```
Remove subtree vendor-lib (was at abc123de)

- Last commit: abc123def456789...
- From: https://github.com/example/lib.git
- Was at: lib/
```

**Structure**:
- **Title**: `Remove subtree <name> (was at <short-hash>)`
- **Body** (3 lines):
  - `- Last commit: <full-hash>` - Complete SHA-1 for recovery
  - `- From: <remote-url>` - Original remote URL
  - `- Was at: <prefix>` - Directory location in repository

**Guarantees**:
- Commit message is machine-parseable (consistent format)
- Contains all information needed to restore subtree if needed
- Follows same pattern as Add/Update for consistency

### Git Operations

**Executed Commands** (in order):
1. `git status --porcelain` - Verify clean working tree
2. `git rm -r <prefix>` - Remove directory (ONLY if directory exists)
3. `git add subtree.yaml` - Stage config update (ALWAYS)
4. `git commit -m "<message>"` - Create atomic commit

**Guarantees**:
- Uses standard git commands (no custom git internals manipulation)
- Respects git hooks (pre-commit, commit-msg, etc.)
- If hooks reject commit, leaves changes staged with recovery instructions

---

## File System Integration

### Configuration File

**Location**: `<git-repository-root>/subtree.yaml`

**Update Strategy**: Atomic write (temp file + rename)

**Before**:
```yaml
subtrees:
  - name: vendor-lib
    remote: https://github.com/example/lib.git
    prefix: lib
    ref: main
    commit: abc123def456...
    squash: true
  - name: other-lib
    remote: https://github.com/example/other.git
    prefix: other
    ref: main
    commit: xyz789...
    squash: false
```

**After** (removing vendor-lib):
```yaml
subtrees:
  - name: other-lib
    remote: https://github.com/example/other.git
    prefix: other
    ref: main
    commit: xyz789...
    squash: false
```

**Empty Config** (if last subtree removed):
```yaml
subtrees: []
```

### Directory Removal

**Method**: `git rm -r <prefix>` (recursive removal)

**Guarantees**:
- Removes directory and all contents
- Tracks removal in git (staged for commit)
- Fails if directory contains untracked files (git rm behavior)
  - Wait, actually: git rm only removes tracked files
  - Untracked files would be left behind (acceptable per edge case)

---

## Testing Contract

### Integration Test Scenarios

**Required Test Coverage**:

1. **Clean Removal** (US1):
   - Add subtree → Remove subtree → Verify directory gone, config updated, single commit
   - Verify exit code 0
   - Verify success message format
   - Verify commit message format

2. **Idempotent Removal** (US2):
   - Add subtree → Manually delete directory → Remove subtree → Verify success
   - Verify exit code 0
   - Verify idempotent success message
   - Verify config entry removed

3. **Error: Config Missing** (US3):
   - No subtree.yaml → Remove → Verify exit code 3, error message

4. **Error: Malformed Config** (US3):
   - Corrupt subtree.yaml → Remove → Verify exit code 3, parse error shown

5. **Error: Name Not Found** (US3):
   - Valid config without target name → Remove → Verify exit code 2, error message

6. **Error: Dirty Working Tree** (US3):
   - Uncommitted changes → Remove → Verify exit code 1, error message

7. **Error: Not in Git Repo** (US3):
   - Outside git repo → Remove → Verify exit code 1, error message

8. **Commit Message Format**:
   - Remove subtree → Verify commit message title and body format
   - Verify short hash (8 chars) and full hash preservation

### Unit Test Scenarios

**Command Validation Logic**:
- Name validation (exists in config)
- Working tree validation (clean check)
- Config parsing (valid YAML)
- Directory existence check

**Message Formatting**:
- Success message (normal vs idempotent)
- Error messages (all variants)
- Commit message (title + body)
- Short hash computation (8 chars)

---

## Compatibility & Constraints

### Platform Compatibility

**Supported Platforms**:
- macOS 13+ (arm64, x86_64)
- Ubuntu 20.04 LTS (x86_64, arm64)

**Platform-Specific Behavior**: None - identical behavior across platforms

### Git Version Requirements

**Minimum**: Git 2.0+ (git rm -r support)
**Recommended**: Git 2.30+ (modern version with performance improvements)

### Performance Constraints

**Targets** (from Success Criteria):
- Removal operation: <5 seconds for <10,000 files (SC-001)
- Idempotent removal: <1 second (SC-005)
- Validation: <1 second for all checks (SC-003)

**No Progress Indicators**: Initial implementation shows no progress for long operations (could be added to backlog)

---

## Backward Compatibility

### Config File Format

**Compatible With**: All prior versions (specs 001-005)
- Config schema established in spec 002 (unchanged)
- Remove only deletes entries (doesn't add new fields)
- Empty config (`subtrees: []`) is valid

### CLI Interface

**Stable Contract**:
- Command name: `subtree remove` (will not change)
- Positional argument: `<name>` (required, first position)
- Exit codes: 0, 1, 2, 3 (stable, will not change meaning)
- Output format: Emoji-prefixed messages (stable pattern)

**Future Additions** (backward compatible):
- Optional flags (e.g., `--force`, `--batch` if added later)
- Additional success metadata in output (additive)

---

## Security Considerations

### Input Validation

**Name Parameter**:
- Validated against config (must exist)
- No direct filesystem operations with user input
- Only operates on configured subtrees (prevents path traversal)

### File Operations

**Config Update**:
- Atomic write prevents corruption (temp file + rename)
- No race conditions (single-threaded operation)
- Preserves file permissions

**Directory Removal**:
- Uses git rm (respects gitignore, tracks removal properly)
- No direct filesystem deletion (git handles safely)
- Works with git's locking mechanisms

### Git Integration

**Commit Creation**:
- Uses standard git commands (no custom git manipulation)
- Respects git hooks (security checks, commit signing)
- No credential/authentication needed (local operation only)

---

## Summary

**Command**: `subtree remove <name>`

**Contract Guarantees**:
- ✅ Atomic operation (single commit with both directory + config)
- ✅ Idempotent (safe to run multiple times)
- ✅ Validates before modifying (no partial state on errors)
- ✅ Clear exit codes (0=success, 1=git error, 2=not found, 3=config error)
- ✅ Actionable error messages
- ✅ Consistent with Add/Update commands (patterns, exit codes, messages)
- ✅ Platform-independent behavior
- ✅ Backward compatible with existing configurations

**Next Steps**: Implementation following TDD (tests first, then code)
