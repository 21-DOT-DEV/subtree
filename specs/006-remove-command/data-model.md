# Data Model: Remove Command

**Feature**: Remove Command | **Phase**: 1 (Design) | **Date**: 2025-10-28

## Overview

This document defines the data entities, their relationships, and state transitions for the Remove Command feature. The Remove Command operates on existing configuration entries and produces removal operations that result in atomic commits.

---

## Core Entities

### 1. RemovalOperation

**Purpose**: Represents a complete subtree removal operation with all context needed for execution and reporting.

**Attributes**:
- `name`: String - Subtree name from user input (e.g., "vendor-lib")
- `prefix`: String - Directory path from config (e.g., "lib/" or "vendor/lib1")
- `remote`: String - Remote URL from config (e.g., "https://github.com/example/lib.git")
- `lastCommit`: String - Full SHA-1 hash from config before removal (e.g., "abc123def456...")
- `directoryExists`: Bool - Whether prefix directory exists at operation start
- `operationResult`: OperationResult - Success or failure with details

**Derived Values**:
- `shortHash`: String (computed) - First 8 characters of `lastCommit` for messages
- `commitMessage`: String (computed) - Formatted per FR-016/017

**Validation Rules**:
- `name` must exist in loaded configuration (validated before instantiation)
- `prefix`, `remote`, `lastCommit` loaded from config entry for `name`
- `directoryExists` determined via filesystem check before git operations

**State**: Immutable value type capturing operation context

---

### 2. SubtreeConfigEntry (Existing from Spec 002)

**Purpose**: Represents one entry in `subtree.yaml` configuration file.

**Attributes**:
- `name`: String - Unique identifier for subtree
- `remote`: String - Git remote URL
- `prefix`: String - Local directory path (relative to repo root)
- `ref`: String - Branch, tag, or commit ref to track
- `commit`: String - Last known commit SHA-1 (full hash)
- `squash`: Bool - Whether squash mode was used

**Lifecycle in Remove Context**:
- **Before**: Entry exists in configuration
- **During**: Entry used to populate RemovalOperation attributes
- **After**: Entry deleted from configuration
- **Preserved**: All fields included in commit message body for audit trail

**Validation**:
- Loaded and validated by ConfigFileManager
- Must parse successfully (exit code 3 if malformed per FR-022)

---

### 3. SubtreeConfiguration (Existing from Spec 002)

**Purpose**: Root configuration object containing all subtree entries.

**Attributes**:
- `subtrees`: Array<SubtreeConfigEntry> - All configured subtrees

**Operations for Remove**:
- `findEntry(name:)` -> SubtreeConfigEntry? - Locate entry by name
- `removeEntry(name:)` -> SubtreeConfiguration - Return new config without entry

**Validation**:
- Must contain at least the named entry being removed
- After removal, may be empty (valid configuration with zero subtrees)

---

## Operation Flow & State Transitions

### Remove Operation Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Validation Phase (No State Changes)                      │
├─────────────────────────────────────────────────────────────┤
│   • Validate inside git repository                          │
│   • Validate config file exists and parseable               │
│   • Validate working tree is clean                          │
│   • Validate subtree name exists in config                  │
│                                                              │
│   Failure → Exit with specific code (1, 2, or 3)            │
│   Success → Proceed to Removal Phase                        │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Removal Phase (File System Operations)                   │
├─────────────────────────────────────────────────────────────┤
│   • Load config entry for name → Create RemovalOperation    │
│   • Check directory existence (sets directoryExists flag)   │
│   •  IF directoryExists:                                    │
│        → Execute git rm -r <prefix> (stages deletion)       │
│   •  ELSE:                                                  │
│        → Skip git rm (already gone, idempotent behavior)    │
│   • Update config: Remove entry from subtrees array         │
│   • Write updated config to disk (atomic file operations)   │
│   • Stage config change: git add subtree.yaml               │
│                                                              │
│   Failure → Exit with code 1, surface git/filesystem error  │
│   Success → Proceed to Commit Phase                         │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Commit Phase (Git Commit Creation)                       │
├─────────────────────────────────────────────────────────────┤
│   • Format commit message from RemovalOperation             │
│   • Create regular git commit (NOT amend) with both:        │
│       - Directory removal (if staged)                       │
│       - Config update (always staged)                       │
│   •  IF commit succeeds:                                    │
│        → Output success message (variant based on           │
│          directoryExists flag)                              │
│        → Exit code 0                                        │
│   •  ELSE commit fails:                                     │
│        → Leave changes staged                               │
│        → Output recovery instructions                       │
│        → Exit code 1                                        │
└─────────────────────────────────────────────────────────────┘
```

### State Transition Table

| Current State | Condition | Next State | Exit Code |
|--------------|-----------|------------|-----------|
| **Start** | Not in git repo | Error | 1 |
| **Start** | Config missing | Error | 3 |
| **Start** | Config malformed | Error | 3 |
| **Start** | Dirty working tree | Error | 1 |
| **Start** | Name not in config | Error | 2 |
| **Start** | All validations pass | Load Config | - |
| **Load Config** | Entry found | Check Directory | - |
| **Check Directory** | Directory exists | Stage Removal | - |
| **Check Directory** | Directory missing | Skip to Config Update | - |
| **Stage Removal** | git rm succeeds | Update Config | - |
| **Stage Removal** | git rm fails | Error | 1 |
| **Update Config** | Config write succeeds | Create Commit | - |
| **Update Config** | Config write fails | Error | 1 |
| **Create Commit** | Commit succeeds | Success | 0 |
| **Create Commit** | Commit fails | Error (staged) | 1 |

---

## Entity Relationships

```
┌──────────────────────────────┐
│ SubtreeConfiguration         │
│ ────────────────────────────│
│ + subtrees: [Entry]          │
│ + findEntry(name)            │
│ + removeEntry(name)          │
└────────────┬─────────────────┘
             │ 1
             │ contains
             │ 0..*
             ▼
┌──────────────────────────────┐       ┌──────────────────────────────┐
│ SubtreeConfigEntry           │       │ RemovalOperation             │
│ ────────────────────────────│◄──────│ ────────────────────────────│
│ + name: String               │ used  │ + name: String               │
│ + remote: String             │  by   │ + prefix: String             │
│ + prefix: String             │       │ + remote: String             │
│ + ref: String                │       │ + lastCommit: String         │
│ + commit: String             │       │ + directoryExists: Bool      │
│ + squash: Bool               │       │ + operationResult: Result    │
└──────────────────────────────┘       │ + shortHash (computed)       │
                                        │ + commitMessage (computed)   │
                                        └──────────────────────────────┘
```

**Relationship Notes**:
- RemovalOperation is constructed FROM a SubtreeConfigEntry
- RemovalOperation is independent (value type) after construction
- SubtreeConfigEntry is deleted from configuration during removal
- Both entities' data preserved in commit message for audit

---

## Validation Rules

### SubtreeConfiguration Level

**Loading**:
- File must exist at `<git-root>/subtree.yaml` (FR-004)
- File must be valid YAML syntax (FR-005)
- Subtrees array may be empty (valid after removing last subtree)

**Name Lookup**:
- Requested name must exist in subtrees array (FR-006)
- Name comparison is case-sensitive
- Exit code 2 if name not found (FR-023)

### RemovalOperation Level

**Construction**:
- All attributes loaded from valid SubtreeConfigEntry
- `directoryExists` determined via filesystem check
- No validation failures possible (entry already validated)

**Commit Message Format**:
- Title: `Remove subtree <name> (was at <shortHash>)` (FR-015)
- Body (FR-017):
  ```
  - Last commit: <fullHash>
  - From: <remote>
  - Was at: <prefix>
  ```
- Short hash: First 8 characters of commit SHA-1

---

## Data Storage

### File System

**Config File**:
- Location: `<git-repository-root>/subtree.yaml`
- Format: YAML
- Atomic Updates: Write to temp file, rename (prevents corruption)
- Example before removal:
  ```yaml
  subtrees:
    - name: vendor-lib
      remote: https://github.com/example/lib.git
      prefix: lib
      ref: main
      commit: abc123def456...
      squash: true
  ```
- Example after removal (if last entry):
  ```yaml
  subtrees: []
  ```

### Git Storage

**Commit Object**:
- Contains: Directory removal + config update
- Commit message: Formatted per FR-015/016/017
- Parent: Previous HEAD
- Tree: Repo state without subtree directory, with updated config

---

## Error Cases

### Config-Related Errors

| Error Condition | Exit Code | Message Pattern |
|----------------|-----------|-----------------|
| Config file missing | 3 | ❌ Configuration file not found. Run 'subtree init' first |
| Config malformed (invalid YAML) | 3 | ❌ Configuration file is malformed: <parse error> |
| Subtree name not found | 2 | ❌ Subtree '<name>' not found in configuration |

### Git-Related Errors

| Error Condition | Exit Code | Message Pattern |
|----------------|-----------|-----------------|
| Not in git repository | 1 | ❌ Must be run inside a git repository |
| Dirty working tree | 1 | ❌ Working tree has uncommitted changes. Commit or stash before removing |
| git rm failure | 1 | ❌ Failed to remove directory: <git error> |
| Commit creation failure | 1 | ❌ Failed to commit removal. Changes are staged. Run 'git commit' to complete or 'git reset HEAD' to abort. |

---

## Success Cases

### Normal Removal

**Input**: `subtree remove vendor-lib`
**Preconditions**: Directory exists, config clean, working tree clean
**Output**: `✅ Removed subtree 'vendor-lib' (was at abc123de)`
**Side Effects**:
- Directory `lib/` deleted
- Config entry removed
- Single commit created with both changes

### Idempotent Removal

**Input**: `subtree remove vendor-lib`
**Preconditions**: Directory already deleted manually, config entry exists
**Output**: `✅ Removed subtree 'vendor-lib' (directory already removed, config cleaned up)`
**Side Effects**:
- No directory operation (already gone)
- Config entry removed
- Single commit created with config change only

---

## Performance Characteristics

**Time Complexity**:
- Config lookup: O(n) where n = number of subtrees (typically <100)
- Directory check: O(1) filesystem stat
- git rm: O(m) where m = files in directory
- Config update: O(n) to serialize, O(1) to write
- Commit: O(1) git overhead

**Space Complexity**:
- RemovalOperation: O(1) - fixed attributes
- Config in memory: O(n) for all entries
- Staged changes: O(m) for directory size

**Targets** (from SC-001, SC-005):
- Normal removal: <5 seconds for <10,000 files
- Idempotent removal: <1 second (no git rm)

---

**Status**: Data model complete, ready for contract definition
