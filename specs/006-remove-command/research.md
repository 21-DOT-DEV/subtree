# Phase 0: Research & Technical Decisions

**Feature**: Remove Command | **Date**: 2025-10-28

## Overview

This document captures technical research and decisions for implementing the Remove Command. All clarifications from the planning phase are documented here with rationale and alternatives considered.

## Key Technical Decisions

### 1. Atomic Commit Strategy

**Decision**: Use existing shared `AtomicSubtreeOperation` utility with regular commit (not amend)

**Rationale**:
- Maintains consistency with Add/Update commands (same utility, different mode)
- `git rm` only stages changes without creating an initial commit
- Regular commit with both staged changes (directory removal + config update) achieves atomic requirement
- Simpler than creating dummy commit to amend

**Alternatives Considered**:
- **Custom atomic logic**: Rejected - duplicates code, breaks consistency
- **Dummy commit + amend**: Rejected - unnecessary complexity, amend pattern designed for git subtree operations that create commits
- **Modify shared utility for dual mode**: Accepted - utility supports both amend (add/update) and regular commit (remove) modes

**Implementation Notes**:
- `AtomicSubtreeOperation` enum likely already has `.remove` case (per memory)
- Remove variant should stage both changes, then create regular commit
- Commit message format defined in FR-016/017: "Remove subtree <name> (was at <short-hash>)"

---

### 2. Idempotent Directory Handling

**Decision**: Check directory existence before `git rm`, skip if missing, proceed to config cleanup

**Rationale**:
- Avoids git errors when directory already removed
- Clean control flow - explicit check is clearer than error handling
- Enables different success messages (FR-029 vs FR-030)
- Supports recovery from desync states

**Alternatives Considered**:
- **Attempt git rm, catch error**: Rejected - error handling path unclear, harder to distinguish "not found" vs other git rm failures
- **Always fail if missing**: Rejected - violates idempotent requirement (FR-011-014)

**Implementation Pattern**:
```swift
// Pseudo-code
let directoryExists = FileManager.default.fileExists(atPath: subtree.prefix)

if directoryExists {
    try GitOperations.remove(prefix: subtree.prefix)  // git rm -r
    message = "✅ Removed subtree '\(name)' (was at \(shortHash))"
} else {
    // Skip git rm, still remove config
    message = "✅ Removed subtree '\(name)' (directory already removed, config cleaned up)"
}

// Always update config and commit
try updateConfig(removing: name)
try createCommit(message: commitMessage)
```

---

### 3. Configuration File Parsing

**Decision**: Validate YAML is parseable during config loading, exit code 3 with detailed parse error

**Rationale**:
- Groups all config-related errors under exit code 3 (missing or malformed)
- Provides actionable error messages with parse details
- Fails fast before any git operations
- Consistent with FR-022 requirement

**Implementation**: 
- ConfigFileManager already handles YAML parsing (Yams library)
- Add specific error case for malformed YAML
- Surface parse error details in message: "❌ Configuration file is malformed: <parse error>"

---

### 4. Commit Failure Recovery

**Decision**: Leave changes staged with recovery instructions, exit code 1

**Rationale**:
- Matches Add Command's recovery pattern (consistency across commands)
- Preserves user control - they can inspect staged changes
- Avoids automatic rollback complexity
- Clear recovery path: complete commit or abort

**Implementation**:
- Catch commit failures after staging
- Provide recovery message (FR-019): "❌ Failed to commit removal. Changes are staged. Run 'git commit' to complete or 'git reset HEAD' to abort."
- Exit with code 1 (git operation failure category)

---

## Best Practices Applied

### Git Operations
- **Clean working tree validation**: Follow established pattern from Add/Update commands
- **Git root discovery**: Reuse existing `GitOperations.findRepositoryRoot()` utility
- **Stage then commit**: Standard git workflow for directory removal
- **No force flags**: Let git fail naturally for permission/state issues

### Error Handling
- **Exit code strategy**:
  - 0: Success (removal complete)
  - 1: Git operation failures, dirty working tree, commit failures
  - 2: Subtree name not found in configuration
  - 3: Config file missing or malformed
- **Emoji prefixes**: ❌ for errors, ✅ for success (FR-020)
- **Actionable messages**: Always suggest next step (commit/stash, run init, etc.)

### Testing Strategy
- **Unit tests**: Command validation logic, error path coverage, message formatting
- **Integration tests**: End-to-end CLI execution with GitRepositoryFixture
- **Test scenarios**:
  - Clean removal (directory exists, config updated, single commit)
  - Idempotent removal (directory missing, config cleaned, success)
  - Error cases (no config, name not found, dirty tree, non-git repo)
  - Commit message format validation
  - Exit code verification

---

## Technology Integration

### Existing Utilities to Reuse

**GitOperations.swift**:
- `findRepositoryRoot()` - Locate git root from any subdirectory
- `isCleanWorkingTree()` - Validate no uncommitted changes
- `getCurrentCommit()` - Get current HEAD (for verification)
- `remove(prefix:)` - NEW: Wrapper for `git rm -r <prefix>`

**ConfigFileManager.swift**:
- `loadConfiguration()` - Parse subtree.yaml with error handling
- `saveConfiguration()` - Atomic write (temp file + rename)
- `removeEntry(name:)` - NEW: Remove subtree entry from config

**AtomicSubtreeOperation.swift**:
- `executeAtomicSubtreeOperation(.remove)` - Handle regular commit variant
- Should accept: operation type, commit message, pre-staged changes flag

**ExitCode.swift**:
- Existing codes: success (0), gitOperationFailed (1), subtreeNotFound (2), configNotFound (3)
- Already covers all Remove command needs

---

## Performance Considerations

**Expected Performance**:
- Config validation: <10ms (YAML parse)
- Directory existence check: <5ms (filesystem stat)
- `git rm`: 10ms-2s depending on directory size
- Config update: <50ms (atomic file write)
- Commit creation: 10-100ms (git overhead)
- **Total**: <5 seconds for typical subtrees (<10,000 files) - meets SC-001

**Idempotent Path Optimization**:
- Skip `git rm` when directory missing
- Only config update + commit needed
- Target <1 second - meets SC-005

---

## Dependencies on Existing Specs

**Spec 001 (CLI Bootstrap)**:
- Established Swift Testing framework
- Defined TestHarness and CLI execution patterns
- Set up CI matrix (macOS + Ubuntu)

**Spec 002 (Config Schema)**:
- SubtreeConfiguration model with name, remote, prefix, ref, commit, squash
- Validation rules for config format

**Spec 003 (Init Command)**:
- Git repository validation pattern
- Config file location (git root)
- File operations approach

**Spec 004 (Add Command)**:
- Atomic commit pattern (to be adapted for remove)
- Exit code strategy
- Error message formatting

**Spec 005 (Update Command)**:
- Clean working tree validation
- Config commit tracking
- Batch operation patterns (not used in remove, but establishes precedent)

---

## Open Questions Resolved

All technical clarifications resolved during planning phase:

1. ✅ Atomic commit approach - Use shared utility with regular commit variant
2. ✅ Idempotent handling - Check existence, skip git rm if missing
3. ✅ Commit strategy - Regular commit (not amend) since git rm only stages
4. ✅ Config parsing errors - Exit code 3 with detailed parse error message
5. ✅ Commit failure recovery - Leave staged with recovery instructions

**Status**: Ready for Phase 1 (Design & Contracts)
