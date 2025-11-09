# Research: Update Command

**Feature**: 005-update-command | **Date**: 2025-10-28  
**Purpose**: Resolve technical unknowns and establish implementation patterns

## Research Questions & Decisions

### Q1: How to detect if subtree needs updating?

**Decision**: Use `git ls-remote` to query remote ref without modifying local repository

**Rationale**:
- Truly read-only operation (critical for report mode)
- No fetch required (faster, no local state changes)
- Returns commit hash for comparison with config
- Standard git plumbing command with predictable output

**Pattern**:
```bash
# Get remote commit for ref
git ls-remote <remote-url> <ref>

# Example output:
# abc1234... refs/heads/main
# Parse commit hash, compare with subtree.yaml entry
```

**Alternatives Considered**:
- `git fetch --dry-run`: Still modifies FETCH_HEAD, not truly read-only
- `git fetch` to tracking branches: Violates no-modification requirement
- Manual HTTP API calls: Complex, auth handling, not portable

---

### Q2: How to reuse Add Command's atomic commit pattern?

**Decision**: Extend existing `AtomicSubtreeOperation` enum with update case, reuse `executeAtomicSubtreeOperation()` utility

**Rationale**:
- Proven pattern from Add Command (004)
- Consistent atomic commit behavior across commands
- Code reuse reduces bugs and maintenance
- Follows DRY principle

**Pattern** (from Add Command implementation):
```swift
enum AtomicSubtreeOperation {
    case add(name: String, remote: String, ref: String, prefix: String, squash: Bool)
    case update(name: String, squash: Bool)  // NEW
}

func executeAtomicSubtreeOperation(_ operation: AtomicSubtreeOperation) async throws {
    // 1. Execute git subtree command (creates initial commit)
    // 2. Update subtree.yaml with new state
    // 3. Amend commit to include config changes atomically
}
```

**Alternatives Considered**:
- Separate update-specific atomic logic: Duplicates code, risks divergence
- Manual commit management in UpdateCommand: Error-prone, harder to test
- Two separate commits: Violates spec requirement for atomic updates

---

### Q3: How to calculate "commits behind" and date difference for report mode?

**Decision**: Use `git rev-list --count` for commit count, `git log` for date comparison

**Rationale**:
- `git rev-list --count <local>..<remote>`: Standard way to count commits between refs
- Date from `git log -1 --format=%ci <remote-hash>`: ISO format, easy to parse
- Both work with commit hashes (no need for local refs)
- Portable across git versions

**Pattern**:
```bash
# Count commits behind
git rev-list --count <local-commit>..<remote-commit>

# Get commit date
git log -1 --format=%ci <remote-commit>

# Calculate difference in Swift
let difference = remoteDate.timeIntervalSince(localDate)
let weeks = Int(difference / (60 * 60 * 24 * 7))
```

**Alternatives Considered**:
- GitHub/GitLab API: Requires authentication, not portable, network-dependent
- Parse full git log: Slower, unnecessary data transfer
- Date-only comparison: Doesn't show commit count (less actionable)

---

### Q4: How to handle tag vs branch refs in commit messages?

**Decision**: Detect tag pattern (v-prefix, semver), format message accordingly

**Rationale**:
- Tags typically follow semver (v1.2.3) - easy to detect
- Version transitions (v1.2.0 → v1.3.0) more meaningful than commit hashes for tags
- Branch updates show commit hashes (mutable, hash is source of truth)
- Aligns with user mental model (tags = versions, branches = commits)

**Pattern**:
```swift
func isTag(_ ref: String) -> Bool {
    // Check for v-prefix semver: v1.2.3, v1.0.0-beta
    return ref.hasPrefix("v") && ref.matches(semverPattern)
}

func formatCommitMessage(entry: SubtreeEntry, oldHash: String, newHash: String) -> String {
    if isTag(entry.ref) {
        // Tag format: Update subtree example-lib (v1.2.0 -> v1.3.0)
        return """
        Update subtree \(entry.name) (\(oldRef) -> \(entry.ref))
        
        - Updated to tag: \(entry.ref) (commit: \(newHash))
        - From: \(entry.remote)
        - In: \(entry.prefix)
        """
    } else {
        // Branch/commit format: Update subtree example-lib
        return """
        Update subtree \(entry.name)
        
        - Updated to commit: \(newHash)
        - Previous commit: \(oldHash)
        - From: \(entry.remote)
        - In: \(entry.prefix)
        """
    }
}
```

**Alternatives Considered**:
- Always show commit hashes: Loses semantic meaning for versioned dependencies
- Query git for tag info: Extra network/git calls, slower
- User-specified format: Over-engineering, adds complexity

---

### Q5: How to handle batch update (`--all`) failures?

**Decision**: Continue-on-error pattern with final exit code 1 if any failures

**Rationale**:
- Maximizes progress (update what you can)
- Clear failure signal for CI (exit code 1)
- Matches user expectation from clarification
- Summary shows success/failure counts

**Pattern**:
```swift
struct BatchUpdateResult {
    var updated: [String] = []
    var skipped: [String] = []  // Already up-to-date
    var failed: [(String, Error)] = []
    
    var exitCode: Int32 {
        failed.isEmpty ? 0 : 1
    }
}

func updateAll() async throws -> Never {
    let result = BatchUpdateResult()
    
    for entry in config.subtrees {
        do {
            if try await needsUpdate(entry) {
                try await updateSubtree(entry)
                result.updated.append(entry.name)
            } else {
                result.skipped.append(entry.name)
            }
        } catch {
            result.failed.append((entry.name, error))
            print("❌ Failed to update \(entry.name): \(error)")
            // Continue with next subtree
        }
    }
    
    printSummary(result)
    throw ExitCode(result.exitCode)
}
```

**Alternatives Considered**:
- Fail-fast on first error: Leaves other subtrees outdated, poor UX
- Exit 0 if any succeed: Hides failures, breaks CI detection
- Separate exit code for partial success: Over-engineering, unclear semantics

---

## Best Practices Applied

### Git Operations
- Use plumbing commands (`ls-remote`, `rev-list`) for predictable parsing
- Avoid porcelain commands where possible (output format may change)
- Handle remote authentication failures gracefully
- No automatic retries (fail-fast, let user/CI retry)

### Error Handling
- Use Swift errors for all failure cases
- Surface git stderr output directly (don't obscure messages)
- Exit codes: 0=success, 1=failure, 2=invalid input, 3=missing config, 5=updates available (report mode)
- Emoji-prefixed error messages for visual clarity

### Testing Strategy
- Unit tests for update detection logic (mock git responses)
- Integration tests with GitRepositoryFixture (real git operations)
- Test all 5 user stories independently
- Performance tests for report mode (<5 seconds requirement)

### Code Reuse
- Extend GitOperations utility with update-specific methods
- Reuse ConfigFileManager for atomic config updates
- Leverage CommitMessageFormatter for tag-aware messages
- Share validation logic with Add Command (clean working tree, config exists)

---

## Dependencies on Existing Code

**From Add Command (004)**:
- `AtomicSubtreeOperation` enum (extend with update case)
- `executeAtomicSubtreeOperation()` function
- Atomic commit-amend pattern
- Config validation utilities

**From Init Command (003)**:
- `ConfigFileManager` for YAML reading/writing
- Git repository validation

**From Bootstrap (001)**:
- `GitOperations` utility (extend with `lsRemote()`, `revListCount()`)
- `ExitCode` for standardized exit codes
- Test infrastructure (TestHarness, GitRepositoryFixture)

---

## Open Questions / Future Work

**Deferred to Backlog**:
1. Dry-run mode (simulate updates without committing)
2. Network retry with exponential backoff
3. Interactive conflict resolution
4. Progress indicators for long-running updates

**No blocking unknowns remain** - ready for Phase 1 design.
