# Quickstart Guide: Extract Command Implementation

**Feature**: `008-extract-command` | **Date**: 2025-10-31  
**Phase**: 1 (Design & Contracts)

## Purpose

This guide helps developers quickly start implementing the Extract Command by providing:
- TDD workflow with concrete first tests
- Implementation order recommendations
- Key validation checkpoints
- Common pitfalls and solutions

---

## Prerequisites

Before starting implementation:

1. ✅ **Spec complete**: [spec.md](./spec.md) reviewed and clarifications documented
2. ✅ **Research complete**: [research.md](./research.md) - technical decisions made
3. ✅ **Data model defined**: [data-model.md](./data-model.md) - entities and validation rules
4. ✅ **Contracts defined**: [contracts/extract-command-contract.md](./contracts/extract-command-contract.md) - CLI interface
5. ✅ **Branch ready**: Checkout `008-extract-command` branch

**Verify prerequisites**:
```bash
# 1. On correct branch
git branch --show-current  # Should show: 008-extract-command

# 2. All specs docs exist
ls specs/008-extract-command/
# Should see: spec.md, plan.md, research.md, data-model.md, contracts/, quickstart.md

# 3. Existing tests pass
swift test
# All 310 tests should pass (baseline before Extract work)
```

---

## TDD Workflow Overview

**Constitutional Requirement**: Tests must be written BEFORE implementation.

**Recommended order** (strict TDD):
1. Write failing unit test for utility
2. Verify test fails (red)
3. Implement minimal code to pass test
4. Verify test passes (green)
5. Refactor if needed
6. Repeat for next component

**Test organization**:
- Unit tests: `Tests/SubtreeLibTests/`
- Integration tests: `Tests/IntegrationTests/`

---

## Implementation Order (TDD Phases)

### Phase 1: Configuration Model (Foundation)

**Goal**: Extend config schema to support extraction mappings

**TDD Steps**:

1. **Write test first**:
```swift
// Tests/SubtreeLibTests/ConfigurationTests/ExtractionMappingTests.swift
@Test("ExtractionMapping initializes with from and to")
func testExtractionMappingInit() {
    let mapping = ExtractionMapping(from: "src/**/*.h", to: "include/")
    #expect(mapping.from == "src/**/*.h")
    #expect(mapping.to == "include/")
    #expect(mapping.exclude == nil)
}
```

2. **Verify failure**: Run `swift test` → Should fail (ExtractionMapping doesn't exist)

3. **Implement minimal code**:
```swift
// Sources/SubtreeLib/Configuration/ExtractionMapping.swift
public struct ExtractionMapping: Codable, Equatable {
    public let from: String
    public let to: String
    public let exclude: [String]?
    
    public init(from: String, to: String, exclude: [String]? = nil) {
        self.from = from
        self.to = to
        self.exclude = exclude
    }
}
```

4. **Verify success**: Run `swift test` → Should pass

**Additional tests to write**:
- Codable conformance (encode/decode)
- Equatable conformance
- Optional exclude field handling
- YAML serialization/deserialization

**Checkpoint**:
```bash
swift test --filter ExtractionMappingTests
# All ExtractionMapping tests should pass
```

---

### Phase 2: Extend SubtreeEntry (Config Integration)

**Goal**: Add optional `extractions` array to SubtreeEntry

**TDD Steps**:

1. **Write test first**:
```swift
// Tests/SubtreeLibTests/ConfigurationTests/SubtreeEntryTests.swift
@Test("SubtreeEntry decodes with extractions array")
func testSubtreeEntryWithExtractions() async throws {
    let yaml = """
    name: my-lib
    remote: https://github.com/example/lib
    prefix: vendor/my-lib
    ref: main
    commit: abc123
    extractions:
      - from: "docs/**/*.md"
        to: "project-docs/"
    """
    
    let entry = try YAMLDecoder().decode(SubtreeEntry.self, from: yaml)
    #expect(entry.extractions?.count == 1)
    #expect(entry.extractions?[0].from == "docs/**/*.md")
}
```

2. **Verify failure**: Run test → Should fail (extractions field doesn't exist)

3. **Implement**:
```swift
// Sources/SubtreeLib/Configuration/SubtreeEntry.swift
public struct SubtreeEntry: Codable, Equatable {
    // ... existing fields ...
    public let extractions: [ExtractionMapping]?  // NEW
    
    public init(name: String, remote: String, prefix: String, ref: String, 
                commit: String?, extractions: [ExtractionMapping]? = nil) {
        // ... existing assignments ...
        self.extractions = extractions  // NEW
    }
}
```

4. **Verify success**: Run test → Should pass

**Additional tests**:
- Backward compatibility (missing extractions field → nil)
- Empty extractions array
- Multiple extraction mappings

**Checkpoint**:
```bash
swift test --filter SubtreeEntryTests
# All SubtreeEntry tests should pass, including new extraction tests
```

---

### Phase 3: Glob Pattern Matching (Core Utility)

**Goal**: Implement GlobMatcher for pattern matching

**TDD Steps**:

1. **Write test first**:
```swift
// Tests/SubtreeLibTests/Utilities/GlobMatcherTests.swift
@Test("GlobMatcher matches single-level wildcard")
func testSingleLevelWildcard() {
    let matcher = try GlobMatcher(pattern: "*.txt")
    #expect(matcher.matches("file.txt") == true)
    #expect(matcher.matches("dir/file.txt") == false)
    #expect(matcher.matches("file.md") == false)
}
```

2. **Verify failure**: Run test → Should fail (GlobMatcher doesn't exist)

3. **Implement minimal matcher**:
```swift
// Sources/SubtreeLib/Utilities/GlobMatcher.swift
public struct GlobMatcher {
    private let pattern: String
    
    public init(pattern: String) throws {
        guard !pattern.isEmpty else {
            throw GlobError.emptyPattern
        }
        self.pattern = pattern
    }
    
    public func matches(_ path: String) -> Bool {
        // Minimal implementation for single-level wildcard
        // Expand incrementally with more tests
    }
}
```

4. **Verify success**: Run test → Should pass

**Additional test cases** (write incrementally, TDD style):
- Globstar (`**`) matching
- Character classes (`[abc]`)
- Single char wildcard (`?`)
- Directory separators
- Edge cases (empty path, root path)
- Invalid patterns (unclosed brackets)

**Test order recommendation**:
1. Single-level wildcard (`*.txt`)
2. Globstar (`**/*.md`)
3. Character classes (`*.{h,c}`)
4. Combinations
5. Edge cases
6. Error cases

**Checkpoint**:
```bash
swift test --filter GlobMatcherTests
# Should have 20-30 tests covering all glob features
```

---

### Phase 4: Git Status Checking (Extend Utility)

**Goal**: Add `isFileTracked()` to GitOperations

**TDD Steps**:

1. **Write test first**:
```swift
// Tests/SubtreeLibTests/Utilities/GitOperationsTests.swift
@Test("isFileTracked returns true for tracked files")
func testIsFileTrackedForTrackedFile() async throws {
    let fixture = try await GitRepositoryFixture()
    defer { await fixture.tearDown() }
    
    // Create and track a file
    let file = fixture.repoPath.appending("/tracked.txt")
    try "content".write(toFile: file.path, atomically: true, encoding: .utf8)
    try await fixture.runGit(["add", "tracked.txt"])
    try await fixture.runGit(["commit", "-m", "Add file"])
    
    let isTracked = try await GitOperations.isFileTracked(file.path)
    #expect(isTracked == true)
}
```

2. **Verify failure**: Run test → Should fail (isFileTracked doesn't exist)

3. **Implement**:
```swift
// Sources/SubtreeLib/Utilities/GitOperations.swift
public static func isFileTracked(_ path: String) async throws -> Bool {
    let result = try await Subprocess.run(
        .named("git"),
        arguments: ["ls-files", "--error-unmatch", path]
    )
    return result.terminationStatus.isSuccess
}
```

4. **Verify success**: Run test → Should pass

**Additional tests**:
- Untracked files return false
- Non-existent files return false
- Files in subdirectories
- Error handling (not in git repo)

**Checkpoint**:
```bash
swift test --filter GitOperationsTests
# All GitOperations tests pass, including new isFileTracked tests
```

---

### Phase 5: Config Manager Extension (Persistence)

**Goal**: Add `appendExtraction()` to ConfigFileManager

**TDD Steps**:

1. **Write test first**:
```swift
// Tests/SubtreeLibTests/Utilities/ConfigFileManagerTests.swift
@Test("appendExtraction adds mapping to subtree")
func testAppendExtraction() async throws {
    let fixture = try await GitRepositoryFixture()
    defer { await fixture.tearDown() }
    
    // Create initial config with subtree
    let config = SubtreeConfig(subtrees: [
        SubtreeEntry(name: "my-lib", remote: "url", prefix: "vendor", 
                     ref: "main", commit: "abc", extractions: nil)
    ])
    try await ConfigFileManager.writeConfig(config, at: fixture.configPath)
    
    // Append extraction mapping
    let mapping = ExtractionMapping(from: "docs/**/*.md", to: "project-docs/")
    try await ConfigFileManager.appendExtraction(to: "my-lib", mapping: mapping, 
                                                  at: fixture.configPath)
    
    // Verify mapping saved
    let updated = try await ConfigFileManager.loadConfig(from: fixture.configPath)
    #expect(updated.subtrees[0].extractions?.count == 1)
    #expect(updated.subtrees[0].extractions?[0].from == "docs/**/*.md")
}
```

2. **Verify failure**: Run test → Should fail (appendExtraction doesn't exist)

3. **Implement**:
```swift
// Sources/SubtreeLib/Utilities/ConfigFileManager.swift
public static func appendExtraction(
    to subtreeName: String,
    mapping: ExtractionMapping,
    at configPath: URL
) async throws {
    // 1. Load current config
    var config = try await loadConfig(from: configPath)
    
    // 2. Find subtree (case-insensitive)
    guard let index = config.subtrees.firstIndex(where: { 
        $0.name.lowercased() == subtreeName.lowercased() 
    }) else {
        throw ConfigError.subtreeNotFound(subtreeName)
    }
    
    // 3. Append mapping (create array if needed)
    var subtree = config.subtrees[index]
    var extractions = subtree.extractions ?? []
    extractions.append(mapping)
    
    // 4. Update entry (immutable struct)
    config.subtrees[index] = SubtreeEntry(
        name: subtree.name,
        remote: subtree.remote,
        prefix: subtree.prefix,
        ref: subtree.ref,
        commit: subtree.commit,
        extractions: extractions  // Updated array
    )
    
    // 5. Atomic save
    try await writeConfig(config, at: configPath)
}
```

4. **Verify success**: Run test → Should pass

**Additional tests**:
- Append to existing extractions array
- Create extractions array if missing
- Case-insensitive subtree lookup
- Error: subtree not found
- Atomicity (temp file pattern)

**Checkpoint**:
```bash
swift test --filter ConfigFileManagerTests
# All ConfigFileManager tests pass, including appendExtraction
```

---

### Phase 6: Extract Command (CLI Integration)

**Goal**: Implement ExtractCommand with ArgumentParser

**TDD Steps**:

1. **Write integration test first**:
```swift
// Tests/IntegrationTests/ExtractIntegrationTests.swift
@Test("Extract command copies files matching pattern")
func testAdHocExtraction() async throws {
    let fixture = try await GitRepositoryFixture()
    defer { await fixture.tearDown() }
    let harness = TestHarness(workingDirectory: fixture.repoPath)
    
    // Add subtree with docs
    try await fixture.addSubtree(name: "my-lib", 
                                  files: ["docs/README.md": "content"])
    
    // Extract docs
    let result = try await harness.run(arguments: [
        "extract", "--name", "my-lib", "docs/**/*.md", "project-docs/"
    ])
    
    #expect(result.exitCode == 0)
    #expect(fixture.fileExists("project-docs/README.md"))
}
```

2. **Verify failure**: Run test → Should fail (extract command not implemented)

3. **Implement command structure**:
```swift
// Sources/SubtreeLib/Commands/ExtractCommand.swift
import ArgumentParser

public struct ExtractCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "Extract files from subtrees using glob patterns"
    )
    
    @Option(name: .long, help: "Subtree name")
    var name: String?
    
    @Flag(name: .long, help: "Execute all saved mappings for all subtrees")
    var all: Bool = false
    
    @Argument(help: "Glob pattern for files to extract")
    var sourcePattern: String?
    
    @Argument(help: "Destination directory path")
    var destination: String?
    
    @Option(name: .long, help: "Exclude files matching pattern (repeatable)")
    var exclude: [String] = []
    
    @Flag(name: .long, help: "Save extraction mapping to config")
    var persist: Bool = false
    
    @Flag(name: .long, help: "Override git-tracked file protection")
    var force: Bool = false
    
    public init() {}
    
    public func run() async throws {
        // Mode selection logic
        // Implementation TBD in incremental steps
    }
}
```

4. **Register subcommand**:
```swift
// Sources/SubtreeLib/Commands/SubtreeCommand.swift
public static let configuration = CommandConfiguration(
    subcommands: [
        InitCommand.self,
        AddCommand.self,
        UpdateCommand.self,
        RemoveCommand.self,
        ExtractCommand.self,  // NEW
        ValidateCommand.self
    ]
)
```

5. **Implement incrementally** (test-driven):
   - Mode 1: Ad-hoc extraction
   - Mode 2: Execute saved mappings (specific subtree)
   - Mode 3: Execute all mappings (all subtrees)
   - Overwrite protection
   - Error handling

**Checkpoint after each mode**:
```bash
swift test --filter ExtractIntegrationTests
# Tests for implemented modes should pass
```

---

## Validation Checkpoints

### After Each Phase

Run targeted tests to verify phase completion:

```bash
# Phase 1: Config model
swift test --filter ExtractionMappingTests

# Phase 2: SubtreeEntry
swift test --filter SubtreeEntryTests

# Phase 3: Glob matching
swift test --filter GlobMatcherTests

# Phase 4: Git status
swift test --filter GitOperationsTests

# Phase 5: Config persistence
swift test --filter ConfigFileManagerTests

# Phase 6: Extract command
swift test --filter ExtractIntegrationTests
```

### Before Committing

Run full test suite:

```bash
# All tests (baseline + new)
swift test

# Should show ~350+ tests passing (310 baseline + ~40 new)
```

### Before Pull Request

1. **All tests pass**:
```bash
swift test  # Exit 0
```

2. **CI checks locally** (using act):
```bash
act workflow_dispatch -W .github/workflows/ci-local.yml
# Should pass on Linux container
```

3. **Manual smoke test**:
```bash
# Build CLI
swift build

# Run extract command
.build/debug/subtree extract --help
# Should show extract command help

# Try ad-hoc extraction (in test repo)
.build/debug/subtree extract --name my-lib "docs/**/*.md" test-docs/
```

---

## Common Pitfalls & Solutions

### Pitfall 1: Writing Implementation Before Tests

**Problem**: Violates TDD constitutional requirement

**Solution**: Always write test first, verify it fails, then implement

**Checkpoint**: `git log` should show test commits before implementation commits

---

### Pitfall 2: Glob Pattern Complexity

**Problem**: Pattern matching edge cases (symlinks, hidden files, performance)

**Solution**: 
- Start with simple patterns (`*.txt`), add complexity incrementally
- Test each pattern type separately
- Reference rsync behavior for ambiguous cases

**Resources**: See [research.md](./research.md) Decision 1 for pattern semantics

---

### Pitfall 3: Config Schema Backward Compatibility

**Problem**: Breaking existing configs without `extractions` field

**Solution**:
- Make `extractions` optional (`[ExtractionMapping]?`)
- Test decoding configs without field (should → `nil`, not error)
- Test old commands still work (init, add, update, remove)

**Validation**:
```bash
# Old config without extractions field should still work
swift test --filter InitIntegrationTests
swift test --filter AddIntegrationTests
# Should all pass
```

---

### Pitfall 4: Not Following Symlinks

**Problem**: Broken links in extracted files

**Solution**: FileManager follows symlinks by default, copy target content

**Validation**: Create test with symlink, verify target content copied

---

### Pitfall 5: Race Conditions in Config Updates

**Problem**: Concurrent extractions corrupt config file

**Solution**: ConfigFileManager uses atomic temp file + rename pattern (already implemented)

**Validation**: Reuse existing ConfigFileManager atomicity tests

---

## Testing Strategy Summary

### Test Pyramid

```
         ┌─────────────────────┐
         │ Integration (20)    │  Full CLI execution
         ├─────────────────────┤
         │ Unit Tests (120)    │  Utilities, models
         └─────────────────────┘
```

**Target**:
- 20 integration tests (ExtractIntegrationTests.swift)
- 120 unit tests:
  - GlobMatcher: 30 tests
  - ExtractionMapping: 10 tests
  - GitOperations: 15 tests
  - ConfigFileManager: 15 tests
  - ExtractCommand logic: 50 tests

**Total new tests**: ~140 tests

---

## Quick Reference

### File Locations

```
Sources/SubtreeLib/
├── Commands/ExtractCommand.swift       # NEW
├── Configuration/ExtractionMapping.swift # NEW
├── Utilities/
│   ├── GlobMatcher.swift              # NEW
│   ├── GitOperations.swift            # EXTEND
│   └── ConfigFileManager.swift        # EXTEND

Tests/SubtreeLibTests/
├── Commands/ExtractCommandTests.swift
├── ConfigurationTests/ExtractionMappingTests.swift
└── Utilities/
    ├── GlobMatcherTests.swift
    ├── GitOperationsTests.swift       # EXTEND
    └── ConfigFileManagerTests.swift   # EXTEND

Tests/IntegrationTests/
└── ExtractIntegrationTests.swift
```

### Key Commands

```bash
# Run specific test
swift test --filter <TestName>

# Run all tests
swift test

# Build CLI
swift build

# Run CLI
.build/debug/subtree extract --help

# Local CI check (Linux)
act workflow_dispatch -W .github/workflows/ci-local.yml
```

### Documentation References

- Spec: [spec.md](./spec.md)
- Research: [research.md](./research.md)
- Data Model: [data-model.md](./data-model.md)
- CLI Contract: [contracts/extract-command-contract.md](./contracts/extract-command-contract.md)

---

## Next Steps

After completing implementation:

1. ✅ Run full test suite: `swift test`
2. ✅ Test on both platforms: macOS + Ubuntu (via CI)
3. ✅ Update documentation: README.md with extract examples
4. ✅ Update agent context: `.windsurf/rules/` (per Constitution Principle V)
5. ✅ Create PR with spec reference

**Constitution checkpoint**:
- ✅ Spec-first: spec.md written before code
- ✅ TDD: Tests written before implementation
- ✅ Small spec: Single feature (extract command)
- ✅ CI gates: All tests pass on macOS + Ubuntu
- ⏳ Agent maintenance: Update .windsurf/rules/ after merge

---

**Start here**: Phase 1 (Configuration Model) → Write first test for ExtractionMapping
