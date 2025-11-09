# Research: Extract Command

**Feature**: `008-extract-command` | **Date**: 2025-10-31  
**Phase**: 0 (Research & Technical Decisions)

## Overview

This document captures technical research and design decisions for the Extract Command implementation. All "NEEDS CLARIFICATION" items from Technical Context have been resolved through targeted research.

---

## Decision 1: Glob Pattern Matching Library

### Problem Statement

Extract Command requires robust glob pattern matching with recursive (`**`) support for file selection. Swift doesn't provide built-in glob functionality, requiring either external dependencies, subprocess calls, or custom implementation.

### Decision

**Use FileManager with custom Swift glob pattern matcher**

### Rationale

1. **Cross-platform compatibility**: Works on macOS, Linux, and future Windows support (current platforms: macOS 13+, Ubuntu 20.04 LTS)
2. **Zero external dependencies**: No third-party packages required beyond existing dependencies
3. **Full control**: Can implement exact glob semantics needed for Extract command
4. **Performance**: Native Swift code without subprocess overhead
5. **Testability**: Pure Swift implementation easily unit-testable

### Alternatives Considered

| Option | Pros | Cons | Rejected Because |
|--------|------|------|------------------|
| Unix utilities (find, shell globs) | Battle-tested, standard behavior | Unix-only, subprocess overhead, Windows incompatible | Blocks future Windows support |
| Third-party Swift package | May exist pre-built | Unmaintained risk, dependency bloat, API mismatch | No mature, maintained glob libraries found for Swift 6 |
| Pure regex matching | Flexible | Glob ≠ regex (different escaping, semantics) | Doesn't match user expectations for glob behavior |

### Implementation Approach

Create `GlobMatcher` utility with:
- Pattern parsing: Handle `**` (globstar), `*` (wildcard), `?` (single char), `[abc]` (character class)
- FileManager integration: Use `enumerator(at:includingPropertiesForKeys:)` for directory traversal
- Path matching: Convert glob patterns to Swift matching logic (not regex - direct string/path manipulation)
- Exclusion support: Apply exclude patterns after include pattern matching (per FR-034)

**Reference patterns**:
- rsync glob behavior (user expectations)
- POSIX glob(3) semantics
- Existing PathValidator for path safety validation

---

## Decision 2: Git Status Checking for Overwrite Protection

### Problem Statement

Extract Command must check if destination files are git-tracked to implement overwrite protection (FR-013: protect tracked files, FR-014: allow overwriting untracked files). Need efficient, reliable method to query git file status.

### Decision

**Extend existing GitOperations utility with `isFileTracked(_ path:) async throws -> Bool` method**

### Rationale

1. **Architectural consistency**: Reuses proven patterns from Add/Update/Remove commands
2. **Centralized git logic**: All git operations in one place (maintainability)
3. **Tested infrastructure**: GitOperations already tested and production-ready
4. **Error handling**: Consistent error handling across commands
5. **Subprocess management**: Reuses swift-subprocess integration

### Alternatives Considered

| Option | Pros | Cons | Rejected Because |
|--------|------|------|------------------|
| New GitStatusChecker utility | Separation of concerns | Duplicates subprocess logic, extra abstraction | Unnecessary complexity for single method |
| Direct subprocess in Extract | Quick implementation | Bypasses abstractions, harder to test, duplicates code | Violates DRY, inconsistent with other commands |
| libgit2 binding | No subprocess overhead | New dependency, C interop complexity | Over-engineering for simple status check |

### Implementation Approach

Add to `GitOperations.swift`:
```swift
/// Checks if a file is tracked by git
/// - Parameter path: Absolute path to file to check
/// - Returns: true if file is tracked in git index, false otherwise
/// - Throws: GitError if git command fails
public static func isFileTracked(_ path: String) async throws -> Bool {
    // Use: git ls-files --error-unmatch <path>
    // Exit code 0 = tracked, Exit code 1 = untracked
}
```

**Git command**: `git ls-files --error-unmatch <path>`
- Exit 0: File is tracked
- Exit 1: File not tracked (or doesn't exist)
- Fast operation (checks index, no tree walk)

---

## Decision 3: Config Update Strategy for Extraction Mappings

### Problem Statement

When users persist extraction mappings with `--persist` flag, the command must atomically append a new mapping to the subtree's `extractions` array in subtree.yaml. Need safe, concurrent-friendly config modification.

### Decision

**Extend ConfigFileManager with `appendExtraction(to:mapping:) async throws` method**

### Rationale

1. **Atomic operations**: ConfigFileManager uses temp file + rename pattern (proven safe)
2. **Concurrency safety**: Existing approach handles concurrent access correctly
3. **Architectural consistency**: Matches Init/Add/Update/Remove config update patterns
4. **YAML handling**: Already integrates with Yams library correctly
5. **Error handling**: Consistent error types and messages

### Alternatives Considered

| Option | Pros | Cons | Rejected Because |
|--------|------|------|------------------|
| In-memory modification | Simpler code | Risk of partial updates on crash, no atomicity | Unsafe, could corrupt config |
| Direct Yams manipulation | Minimal abstraction | Bypasses safety mechanisms, hard to test | Violates existing patterns, unsafe |
| Read-modify-write in Extract | No utility changes | Duplicates logic, breaks DRY | Inconsistent with other commands |

### Implementation Approach

Add to `ConfigFileManager.swift`:
```swift
/// Appends an extraction mapping to a subtree's extractions array
/// - Parameters:
///   - subtreeName: Name of subtree to add mapping to
///   - mapping: ExtractionMapping to append
/// - Throws: ConfigError if subtree not found or I/O fails
public static func appendExtraction(
    to subtreeName: String,
    mapping: ExtractionMapping
) async throws {
    // 1. Load current config
    // 2. Find subtree by name (case-insensitive per FR-021)
    // 3. Append mapping to extractions array (create array if missing)
    // 4. Atomic save using temp file + rename pattern
}
```

**Atomicity**: Uses existing `writeConfig()` which implements temp file + rename pattern.

---

## Decision 4: Config Schema Extension

### Problem Statement

Need to extend SubtreeEntry model to support optional `extractions` array. Each extraction needs `from` (glob), `to` (destination), and optional `exclude` (array of globs).

### Decision

**Add ExtractionMapping struct and optional extractions array to SubtreeEntry**

### Implementation

New model (`ExtractionMapping.swift`):
```swift
public struct ExtractionMapping: Codable, Equatable {
    public let from: String              // Glob pattern
    public let to: String                // Destination path
    public let exclude: [String]?        // Optional exclusion patterns
    
    public init(from: String, to: String, exclude: [String]? = nil) {
        self.from = from
        self.to = to
        self.exclude = exclude
    }
}
```

Update `SubtreeEntry.swift`:
```swift
public struct SubtreeEntry: Codable, Equatable {
    // ... existing fields ...
    public let extractions: [ExtractionMapping]?  // NEW: Optional array
}
```

**YAML Format**:
```yaml
subtrees:
  - name: my-lib
    remote: https://github.com/example/lib
    prefix: vendor/my-lib
    ref: main
    commit: abc123
    extractions:  # Optional field
      - from: "src/**/*.{h,c}"
        to: "Sources/lib/src/"
        exclude:
          - "src/**/test*/**"
          - "src/bench*.c"
      - from: "docs/**/*.md"
        to: "docs/external/"
```

---

## Decision 5: Symlink Handling

### Problem Statement

Extract Command needs defined behavior when encountering symbolic links during file traversal. Affects completeness and portability of extracted files.

### Decision

**Follow symlinks - copy target file content, not link itself**

### Rationale

1. **Self-contained extractions**: Ensures extracted files don't depend on external targets
2. **User expectations**: Matches rsync default behavior (most users familiar with)
3. **Portability**: Prevents broken links if target outside extraction scope
4. **Simplicity**: Clearer mental model ("copy what you see")
5. **Common practice**: Most CLI file operations follow symlinks by default

### Implementation

FileManager configuration:
```swift
// When traversing files for glob matching
let enumerator = fileManager.enumerator(
    at: sourceURL,
    includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey],
    options: []  // Default: follows symlinks
)
```

**Copy operation**: Use `copyItem(at:to:)` which follows symlinks by default (copies target content).

---

## Performance Considerations

### Glob Matching Optimization

**Expected workload**: 10-100 files per extraction, 3-10 mappings per subtree

**Optimization strategies**:
1. **Early termination**: Stop traversal when depth exceeds pattern requirements
2. **Path filtering**: Skip directories that can't match pattern (e.g., pattern `docs/**` skips `src/`)
3. **Lazy evaluation**: Use FileManager.DirectoryEnumerator (lazy sequence)
4. **Exclude pre-filtering**: Apply exclude patterns during traversal, not post-collection

**Performance targets**:
- Glob matching: < 1 second for 100 files
- File copying: < 3 seconds for 50 files (I/O bound)
- Config updates: < 100ms (YAML parsing + atomic write)

---

## Testing Strategy

### Unit Tests

1. **GlobMatcher**:
   - Pattern parsing (wildcards, globstar, character classes)
   - Path matching accuracy (positive/negative cases)
   - Edge cases (empty patterns, invalid syntax)
   
2. **GitOperations.isFileTracked()**:
   - Tracked files return true
   - Untracked files return false
   - Non-existent files return false
   - Error handling (not in git repo, invalid path)
   
3. **ConfigFileManager.appendExtraction()**:
   - Appends to existing array
   - Creates array if missing
   - Handles missing subtree (error)
   - Atomic behavior (temp file pattern)

### Integration Tests

1. **Ad-hoc extraction** (P1):
   - Extract files with glob pattern
   - Verify directory structure preserved
   - Verify only matched files copied
   
2. **Persistence** (P2):
   - Extract with --persist
   - Verify mapping saved to config
   - Re-run extraction without args (uses saved mapping)
   
3. **Bulk execution** (P3):
   - Multiple saved mappings
   - Verify all execute in order
   - Test --all flag (all subtrees)
   
4. **Overwrite protection** (P4):
   - Git-tracked files blocked
   - Untracked files overwritten
   - --force overrides protection
   
5. **Error handling** (P5):
   - Zero-match patterns error
   - Invalid paths error
   - Missing subtree error
   - Exclude filtering to zero error

---

## Dependencies & Reuse

### Existing Code to Reuse

| Component | Purpose | Location |
|-----------|---------|----------|
| GitOperations | Add isFileTracked() | Sources/SubtreeLib/Utilities/GitOperations.swift |
| ConfigFileManager | Add appendExtraction() | Sources/SubtreeLib/Utilities/ConfigFileManager.swift |
| PathValidator | Validate destination paths | Sources/SubtreeLib/Utilities/PathValidator.swift |
| GitRepositoryFixture | Test fixtures | Tests/IntegrationTests/GitRepositoryFixture.swift |
| TestHarness | CLI execution | Tests/IntegrationTests/TestHarness.swift |
| ExitCode | Error codes | Sources/SubtreeLib/Utilities/ExitCode.swift |

### New Code to Create

| Component | Purpose | Location |
|-----------|---------|----------|
| GlobMatcher | Pattern matching | Sources/SubtreeLib/Utilities/GlobMatcher.swift |
| ExtractionMapping | Config model | Sources/SubtreeLib/Configuration/ExtractionMapping.swift |
| ExtractCommand | Command implementation | Sources/SubtreeLib/Commands/ExtractCommand.swift |

---

## Risk Mitigation

### Risk: Glob Pattern Bugs

**Likelihood**: Medium | **Impact**: High (wrong files extracted)

**Mitigation**:
- Comprehensive unit tests (100+ test cases for pattern variations)
- Integration tests with real file structures
- Dry-run mode in backlog (user can preview before executing)

### Risk: Performance with Large File Sets

**Likelihood**: Low | **Impact**: Medium (slow extractions)

**Mitigation**:
- Performance targets defined (<3s for 50 files)
- Lazy evaluation (no upfront collection)
- Success criteria includes performance validation

### Risk: Config Corruption on Concurrent Operations

**Likelihood**: Low | **Impact**: High (broken config)

**Mitigation**:
- Atomic file operations (temp + rename pattern)
- Reuse proven ConfigFileManager
- Integration tests verify atomicity

---

## Summary

All technical unknowns resolved:
1. ✅ Glob matching: FileManager + custom Swift matcher (cross-platform)
2. ✅ Git status: Extend GitOperations with isFileTracked()
3. ✅ Config updates: Extend ConfigFileManager with appendExtraction()
4. ✅ Schema: ExtractionMapping model + optional array in SubtreeEntry
5. ✅ Symlinks: Follow symlinks (copy target content)

**Next Phase**: Phase 1 (Design & Contracts) - data-model.md, contracts/, quickstart.md
