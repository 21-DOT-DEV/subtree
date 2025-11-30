# Research: Extract Clean Mode

**Feature**: 010-extract-clean  
**Date**: 2025-11-29

## Overview

Research findings for implementing the `--clean` flag in ExtractCommand. All technical unknowns resolved through pre-implementation research and planning questions.

## Research Items

### 1. Git Hash-Object for Checksum Comparison

**Decision**: Use `git hash-object -t blob <file>` for content checksums

**Rationale**:
- Git's native content addressing (SHA-1 hash of blob content)
- Consistent with how git tracks file content
- No external dependencies required
- Already available in git (standard tool)

**Alternatives Considered**:
- SHA256 via Swift's CryptoKit — rejected: not git-compatible, adds complexity
- MD5 — rejected: cryptographically weak, not git-compatible
- File size + mtime — rejected: unreliable, false positives

**Implementation**:
```swift
// In GitOperations.swift
public static func hashObject(file: String) async throws -> String {
    let result = try await run(arguments: ["hash-object", "-t", "blob", file])
    guard result.exitCode == 0 else {
        throw GitError.commandFailed("hash-object failed: \(result.stderr)")
    }
    return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
}
```

### 2. Directory Pruning Strategy

**Decision**: Batch post-process with bottom-up traversal

**Rationale**:
- Efficient: Single pass after all files deleted
- Correct: Handles shared parent directories (multiple files in same dir)
- Safe: Bottom-up ensures children checked before parents

**Algorithm**:
1. During file deletion, collect all parent directory paths
2. Deduplicate paths (Set)
3. Sort by depth (deepest first)
4. For each directory: if empty, delete and add parent to queue
5. Stop at destination root (never delete the `--to` directory itself)

**Alternatives Considered**:
- Per-file pruning — rejected: inefficient, repeated directory checks
- Shell `find -empty -delete` — rejected: external dependency, less control
- No pruning — rejected: leaves cruft, poor UX

### 3. ExtractCommand Architecture

**Decision**: Extend existing ExtractCommand with `--clean` flag

**Rationale**:
- CLI consistency: `extract --clean` is intuitive inverse of `extract`
- Code reuse: Shares `--name`, `--from`, `--to`, `--force`, `--exclude` args
- Maintenance: Single command file, easier to keep in sync

**Implementation Pattern**:
```swift
// Add flag
@Flag(name: .long, help: "Remove extracted files instead of copying")
var clean: Bool = false

// Branch in run()
if clean {
    try await runCleanMode()
} else {
    // existing extraction logic
}
```

**Alternatives Considered**:
- Separate CleanCommand — rejected: duplicates argument definitions, inconsistent UX
- Subcommand (`extract clean`) — rejected: breaks existing CLI pattern

### 4. Symlink Handling

**Decision**: Follow symlinks (delete target file)

**Rationale**:
- Symmetric with extraction: Extract copies target content → Clean deletes target
- Prevents orphaned target files after clean
- Consistent with rsync default behavior

**Implementation**:
- Use `FileManager.default.removeItem(atPath:)` which follows symlinks by default
- Checksum validation uses resolved path for hash-object

### 5. Error Handling in Bulk Mode

**Decision**: Continue-on-error per mapping, collect failures, report at end

**Rationale**:
- Consistent with existing bulk extract behavior
- Users want to clean as much as possible, not abort on first failure
- Summary report gives complete picture of what needs attention

**Exit Code Priority**: 3 (I/O) > 2 (user error) > 1 (validation)

## Dependencies

All dependencies already present in project:
- swift-subprocess: Process execution for `git hash-object`
- FileManager: File deletion and directory operations
- swift-argument-parser: `--clean` flag (existing pattern)

No new dependencies required.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Accidental file deletion | Medium | High | Checksum validation, `--force` gate |
| Performance on large file sets | Low | Medium | Batch pruning, early exit on mismatch |
| Symlink edge cases | Low | Medium | Follow symlinks (symmetric with extract) |
| Missing source files | Medium | Low | Skip with warning, `--force` to delete |

## Conclusion

All technical unknowns resolved. Implementation can proceed using:
1. `git hash-object` for checksum validation
2. Batch directory pruning (bottom-up)
3. ExtractCommand extension (not new command)
4. Symlink following (symmetric behavior)
5. Continue-on-error for bulk mode
