# Data Model: Extract Clean Mode

**Feature**: 010-extract-clean  
**Date**: 2025-11-29

## Overview

Extract Clean Mode uses the existing data model from Extract Command (spec 008/009). No new configuration entities are required. This document describes the runtime data structures used during clean operations.

## Existing Entities (No Changes)

### ExtractionMapping (from 008-extract-command)

```yaml
# In subtree.yaml under subtree.extractions[]
extractions:
  - from: "src/**/*.c"           # String or Array of strings (009)
    to: "Sources/"
    exclude: ["**/test/**"]      # Optional
```

**Used By Clean Mode**: Clean reads the same mapping structure to determine which files to remove from `to` directory based on `from` patterns.

### SubtreeEntry (from 002-config-schema)

```yaml
subtrees:
  - name: "my-lib"
    remote: "https://..."
    ref: "main"
    prefix: "vendor/my-lib"
    extractions: [...]           # Used by clean mode
```

## New Runtime Structures

### CleanFileEntry

Runtime structure representing a file to be cleaned.

```swift
/// A file identified for cleaning
struct CleanFileEntry {
    /// Absolute path to source file in subtree (for checksum)
    let sourcePath: String
    
    /// Absolute path to destination file (to be deleted)
    let destinationPath: String
    
    /// Relative path from destination root (for display)
    let relativePath: String
}
```

**Lifecycle**:
1. Created during pattern matching (find files in destination matching `--from`)
2. Validated during checksum check (compare source vs destination hash)
3. Consumed during deletion

### CleanValidationResult

Result of checksum validation for a single file.

```swift
/// Result of validating a file before deletion
enum CleanValidationResult {
    /// Checksums match, safe to delete
    case valid
    
    /// Destination file was modified (checksum mismatch)
    case modified(sourceHash: String, destHash: String)
    
    /// Source file no longer exists in subtree
    case sourceMissing
}
```

**State Transitions**:
- `valid` → File deleted
- `modified` → Fail fast (or delete if `--force`)
- `sourceMissing` → Skip with warning (or delete if `--force`)

### DirectoryPruneQueue

Batch structure for efficient empty directory pruning.

```swift
/// Queue of directories to check for pruning after file deletion
struct DirectoryPruneQueue {
    /// Directories to check, will be sorted by depth (deepest first)
    private var directories: Set<String>
    
    /// Boundary path - never prune this directory or its ancestors
    let boundary: String
    
    mutating func add(parentOf filePath: String)
    func pruneEmpty() throws -> Int  // Returns count of pruned dirs
}
```

**Algorithm**:
1. `add(parentOf:)` collects directory paths during deletion
2. `pruneEmpty()` sorts by depth descending, removes empty dirs bottom-up
3. Stops at `boundary` (the `--to` destination root)

## Data Flow

### Ad-Hoc Clean Mode

```
Input: --name, --from, --to, [--exclude], [--force]
    │
    ▼
┌─────────────────────────────────────┐
│ 1. Load config, validate subtree    │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 2. Find matching files in DEST      │
│    (using --from patterns)          │
│    Output: [CleanFileEntry]         │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 3. For each file:                   │
│    - Compute source hash            │
│    - Compute dest hash              │
│    - Compare → CleanValidationResult│
│    - If modified: fail fast         │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 4. Delete validated files           │
│    - Add parents to DirectoryPruneQueue│
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 5. Prune empty directories          │
│    - Bottom-up to boundary          │
└─────────────────────────────────────┘
    │
    ▼
Output: Success message with count
```

### Bulk Clean Mode

```
Input: --clean --name OR --clean --all, [--force]
    │
    ▼
┌─────────────────────────────────────┐
│ For each subtree:                   │
│   For each ExtractionMapping:       │
│     - Run ad-hoc clean logic        │
│     - Collect failures              │
│   Continue to next mapping          │
└─────────────────────────────────────┘
    │
    ▼
Output: Summary (N succeeded, M failed) + failure details
Exit: Highest severity exit code
```

## Validation Rules

### Checksum Validation (FR-008 to FR-012)

| Source State | Dest State | Default Behavior | With --force |
|--------------|------------|------------------|--------------|
| Exists, matches | Exists | Delete ✅ | Delete ✅ |
| Exists, differs | Exists | Fail ❌ | Delete ✅ |
| Missing | Exists | Skip ⚠️ | Delete ✅ |
| Any | Missing | No-op | No-op |

### Directory Pruning Rules (FR-014 to FR-016)

1. Only prune directories that become empty after file deletion
2. Prune bottom-up (deepest directories first)
3. Stop at destination root boundary (never delete `--to` directory)
4. Leave directories that still contain files (even if not matched by pattern)

## Exit Codes

| Code | Meaning | Examples |
|------|---------|----------|
| 0 | Success | Files cleaned, or zero files matched |
| 1 | Validation error | Subtree not found, checksum mismatch |
| 2 | User error | `--clean` with `--persist` |
| 3 | I/O error | Permission denied, filesystem error |
