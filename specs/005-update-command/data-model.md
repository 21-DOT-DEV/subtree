# Data Model: Update Command

**Feature**: 005-update-command | **Date**: 2025-10-28  
**Purpose**: Define entities, relationships, and validation rules

## Core Entities

### UpdateOperation

Represents a single subtree update operation with all required metadata.

**Fields**:
- `subtreeName: String` - Name of subtree being updated (from config)
- `currentCommit: String` - Current commit hash before update
- `targetCommit: String` - New commit hash after update
- `ref: String` - Branch or tag being tracked
- `squash: Bool` - Whether to squash commits (default: true)
- `remote: String` - Git remote URL
- `prefix: String` - Local directory path
- `status: UpdateStatus` - Result of update attempt

**Validation Rules**:
- `subtreeName` must exist in subtree.yaml
- `currentCommit` must match config entry's commit
- `targetCommit` must be valid git commit hash
- `ref` must exist on remote
- `prefix` must be valid relative path

**State Transitions**:
```
pending -> checking -> (up-to-date | needs-update) -> updating -> (success | failed)
```

**Relationships**:
- Belongs to SubtreeConfiguration (via subtreeName lookup)
- Produces UpdateReport when complete

---

### UpdateReport

Contains status information for report mode (read-only checks).

**Fields**:
- `subtreeName: String` - Name of subtree checked
- `currentCommit: String` - Local commit hash
- `availableCommit: String?` - Remote commit hash (nil if error)
- `status: UpdateStatus` - up-to-date, behind, ahead, diverged, error
- `commitsBehind: Int?` - Number of commits behind (nil if error or up-to-date)
- `daysBehind: Int?` - Days since local commit (nil if error or up-to-date)
- `error: String?` - Error message if check failed

**Validation Rules**:
- `status` must be consistent with commit comparison
- If `status == .behind`, both `commitsBehind` and `daysBehind` must be non-nil
- If `status == .error`, `error` must be non-nil

**Relationships**:
- Derived from SubtreeEntry
- Used by BatchUpdateResult for summary

---

### BatchUpdateResult

Aggregates results from multiple subtree updates (`--all` mode).

**Fields**:
- `updated: [String]` - Names of successfully updated subtrees
- `skipped: [String]` - Names of subtrees already up-to-date
- `failed: [(String, String)]` - Names and error messages for failed updates

**Computed Properties**:
- `exitCode: Int32` - Returns 1 if any failures, 0 otherwise
- `totalCount: Int` - Sum of all categories
- `successCount: Int` - updated + skipped

**Validation Rules**:
- All arrays combined must equal total subtrees in config
- No duplicate names across arrays
- `failed` errors must be non-empty strings

**Relationships**:
- Contains multiple UpdateOperation results
- Displayed as summary to user

---

### UpdateStatus (Enum)

Represents possible states of an update operation.

**Cases**:
- `upToDate` - Local commit matches remote
- `behind` - Remote has new commits
- `ahead` - Local has commits not on remote (rare, possible with force-push)
- `diverged` - Both have unique commits (conflict scenario)
- `error` - Failed to determine status (network, invalid ref, etc.)

**Usage**:
- UpdateOperation.status
- UpdateReport.status
- Drives user-facing messages and exit codes

---

## Existing Entities (Reused)

### SubtreeConfiguration

Defined in 003-init-command, extended by 004-add-command.

**Relevant Fields for Update**:
- `subtrees: [SubtreeEntry]` - List of configured subtrees

**Update Operations**:
- Read entries to get update targets
- Write updated commit hashes after successful updates

---

### SubtreeEntry

Defined in 003-init-command, extended by 004-add-command.

**Relevant Fields for Update**:
- `name: String` - Unique identifier
- `remote: String` - Git URL to fetch from
- `ref: String` - Branch or tag to track
- `prefix: String` - Local directory
- `commit: String?` - Current commit hash (updated by this command)
- `squash: Bool?` - Whether originally added with squash

**Update Operations**:
- `commit` field is updated with new commit hash
- All other fields remain unchanged during update

---

## Validation Rules

### Pre-Update Validation

Before starting any update operation:

1. **Config Exists**: subtree.yaml must be readable and valid YAML
2. **Subtree Exists**: Requested subtree name must be in config
3. **Clean Working Tree**: No uncommitted changes in repository
4. **Git Repository**: Must be inside a valid git repository
5. **Prefix Exists**: Local subtree directory must exist

### During Update Validation

While performing update:

1. **Remote Accessible**: `git ls-remote` succeeds for remote URL
2. **Ref Exists**: Specified ref exists on remote
3. **Commit Hash Valid**: New commit is a valid git object
4. **No Conflicts**: Update operation doesn't create merge conflicts (if conflict, fail with error)

### Post-Update Validation

After successful update:

1. **Config Updated**: subtree.yaml contains new commit hash
2. **Atomic Commit**: Exactly one commit created (subtree + config)
3. **Directory Updated**: Subtree prefix contains new content
4. **No Dirty State**: Working tree clean after update

---

## Data Flow

### Report Mode Flow

```
User Input (subtree name or --all)
  ↓
Load SubtreeConfiguration
  ↓
For each SubtreeEntry:
  1. Execute git ls-remote → get remote commit
  2. Compare with entry.commit → calculate status
  3. If behind: git rev-list --count → commitsBehind
  4. If behind: git log → daysBehind
  5. Create UpdateReport
  ↓
Display UpdateReport(s)
  ↓
Exit code 5 if any updates available, 0 otherwise
```

### Update Mode Flow

```
User Input (subtree name or --all)
  ↓
Validate Pre-conditions (config, clean tree, etc.)
  ↓
For each SubtreeEntry to update:
  1. Create UpdateOperation (status: pending)
  2. Check if update needed → UpdateOperation.status = needs-update
  3. Execute git subtree pull (creates commit)
  4. Update SubtreeEntry.commit in config
  5. Amend commit to include config change (atomic)
  6. UpdateOperation.status = success
  ↓
If --all: Create BatchUpdateResult summary
  ↓
Exit code 0 (success) or 1 (any failures)
```

---

## Relationships Diagram

```
SubtreeConfiguration
  │
  └─── contains ──→ SubtreeEntry (1 to many)
                         │
                         │ inspected by
                         ↓
                    UpdateOperation ────generates───→ UpdateReport
                         │
                         │ aggregated by
                         ↓
                    BatchUpdateResult
```

---

## Storage

**Read from**:
- `subtree.yaml` - SubtreeConfiguration and SubtreeEntry data

**Write to**:
- `subtree.yaml` - Updated SubtreeEntry.commit values
- `.git/` - Git commits (via git subtree command)

**In-memory only**:
- UpdateOperation
- UpdateReport
- BatchUpdateResult
- UpdateStatus

---

## Error Cases

### Configuration Errors

| Error | Exit Code | Entity State |
|-------|-----------|--------------|
| No subtree.yaml | 3 | N/A - command aborts |
| Invalid YAML syntax | 3 | N/A - command aborts |
| Subtree name not found | 2 | N/A - command aborts |

### Git Operation Errors

| Error | Exit Code | Entity State |
|-------|-----------|--------------|
| Network failure | 1 | UpdateOperation.status = error |
| Ref doesn't exist | 1 | UpdateOperation.status = error |
| Merge conflict | 1 | Repository in conflicted state |
| Permission denied | 1 | UpdateOperation.status = error |

### Validation Errors

| Error | Exit Code | Entity State |
|-------|-----------|--------------|
| Dirty working tree | 1 | N/A - command aborts |
| Not in git repository | 1 | N/A - command aborts |
| Subtree directory missing | 1 | N/A - command aborts |

---

## Future Extensions

**Deferred to Backlog**:
1. UpdateOperation.dryRun flag (simulate without committing)
2. UpdateOperation.retryCount (automatic retry logic)
3. SubtreeEntry.updateStrategy (auto-update, pin version, etc.)
4. UpdateHistory log (track update attempts over time)

No data model changes needed for core MVP.
