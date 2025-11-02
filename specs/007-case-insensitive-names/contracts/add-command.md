# Contract: Add Command (Modified)

**Feature**: 007-case-insensitive-names | **Command**: `subtree add`

## Modifications

This feature adds validation to the existing Add Command. Core functionality remains unchanged.

## Command Signature

```bash
subtree add --name <name> --prefix <prefix> --remote <url> [--ref <ref>] [--no-squash]
```

## Behavioral Changes

### 1. Name Validation (New)

**Before git operations**, validate name for:
- Case-insensitive duplicates (FR-005)
- Whitespace normalization (FR-003a)
- Non-ASCII character detection (FR-003b)

**Success Path**:
```
Input: --name "My-Lib" (no duplicates)
→ Normalize: trim whitespace
→ Check duplicates: case-insensitive comparison
→ Check non-ASCII: warn if detected
→ Proceed with git subtree add
```

**Failure Path** (Duplicate Name):
```
Input: --name "hello-world" (config has "Hello-World")
→ Normalize: "hello-world"
→ Check duplicates: match found ("Hello-World")
→ Error: ValidationError.duplicateName
→ Exit code: 1
→ Git operations: NOT executed
```

**Non-ASCII Warning Path**:
```
Input: --name "Библиотека"
→ Normalize: "Библиотека"
→ Check duplicates: passed
→ Check non-ASCII: detected
→ Warning: display non-ASCII warning to stderr
→ Proceed with git subtree add
→ Exit code: 0 (warning doesn't fail)
```

### 2. Prefix Validation (New)

**Before git operations**, validate prefix for:
- Case-insensitive duplicates (FR-006)
- Path format security (FR-004, FR-004a, FR-004b, FR-004c)
- Whitespace normalization (FR-003a)

**Success Path**:
```
Input: --prefix "vendor/lib" (valid relative path, no duplicates)
→ Normalize: trim whitespace
→ Validate format: relative, forward slashes, no traversal
→ Check duplicates: case-insensitive comparison
→ Proceed with git subtree add
```

**Failure Path** (Invalid Format):
```
Input: --prefix "/absolute/path"
→ Normalize: "/absolute/path"
→ Validate format: absolute path detected
→ Error: ValidationError.absolutePath
→ Exit code: 1
→ Git operations: NOT executed
```

**Failure Path** (Duplicate Prefix):
```
Input: --prefix "vendor/LIB" (config has "vendor/lib")
→ Normalize: "vendor/LIB"
→ Validate format: passed
→ Check duplicates: match found ("vendor/lib")
→ Error: ValidationError.duplicatePrefix
→ Exit code: 1
→ Git operations: NOT executed
```

### 3. Config Validation on Load (New)

**Before any operations**, validate loaded config for corruption:

**Success Path**:
```
Load subtree.yaml
→ Parse YAML
→ Validate: no case-insensitive duplicates
→ Proceed with add operation
```

**Failure Path** (Corrupted Config):
```
Load subtree.yaml
→ Parse YAML
→ Validate: found "Hello-World" AND "hello-world"
→ Error: ValidationError.multipleMatches
→ Exit code: 2
→ Git operations: NOT executed
```

## Test Contracts

### US2-001: Duplicate Name Prevention
```swift
@Test("Add fails with duplicate name (case-insensitive)")
func testDuplicateNamePrevention() async throws {
    // Given: Config contains "Hello-World"
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    try await fixture.run(["add", "--name", "Hello-World", "--remote", testRepoURL])
    
    // When: Attempt to add "hello-world"
    let result = try await fixture.run(["add", "--name", "hello-world", "--remote", testRepoURL])
    
    // Then: Command fails before git operations
    #expect(result.exitCode == 1)
    #expect(result.stderr.contains("conflicts with existing 'Hello-World'"))
    
    // And: Config still has only one entry
    let config = try ConfigFileManager.load(from: fixture.repoPath)
    #expect(config.subtrees.count == 1)
}
```

### US3-001: Duplicate Prefix Prevention
```swift
@Test("Add fails with duplicate prefix (case-insensitive)")
func testDuplicatePrefixPrevention() async throws {
    // Given: Config contains prefix "vendor/lib"
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    try await fixture.run(["add", "--prefix", "vendor/lib", "--remote", testRepoURL])
    
    // When: Attempt to add prefix "vendor/Lib"
    let result = try await fixture.run(["add", "--prefix", "vendor/Lib", "--remote", testRepoURL])
    
    // Then: Command fails before git operations
    #expect(result.exitCode == 1)
    #expect(result.stderr.contains("conflicts with existing 'vendor/lib'"))
    
    // And: Config still has only one entry
    let config = try ConfigFileManager.load(from: fixture.repoPath)
    #expect(config.subtrees.count == 1)
}
```

### Path Validation: Absolute Path
```swift
@Test("Add rejects absolute paths")
func testAbsolutePathRejection() async throws {
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    
    let result = try await fixture.run(["add", "--prefix", "/vendor/lib", "--remote", testRepoURL])
    
    #expect(result.exitCode == 1)
    #expect(result.stderr.contains("must be a relative path"))
}
```

### Path Validation: Parent Traversal
```swift
@Test("Add rejects parent directory traversal")
func testParentTraversalRejection() async throws {
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    
    let result = try await fixture.run(["add", "--prefix", "../vendor/lib", "--remote", testRepoURL])
    
    #expect(result.exitCode == 1)
    #expect(result.stderr.contains("parent directory traversal"))
}
```

### Path Validation: Backslashes
```swift
@Test("Add rejects backslashes in paths")
func testBackslashRejection() async throws {
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    
    let result = try await fixture.run(["add", "--prefix", "vendor\\lib", "--remote", testRepoURL])
    
    #expect(result.exitCode == 1)
    #expect(result.stderr.contains("forward slashes"))
}
```

### Non-ASCII Warning
```swift
@Test("Add warns for non-ASCII names but succeeds")
func testNonASCIIWarning() async throws {
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    
    let result = try await fixture.run(["add", "--name", "Библиотека", "--remote", testRepoURL])
    
    #expect(result.exitCode == 0)  // Success despite warning
    #expect(result.stderr.contains("contains non-ASCII characters"))
    #expect(result.stderr.contains("Warning"))
}
```

### Config Corruption Detection
```swift
@Test("Add fails when config has duplicate names")
func testConfigCorruptionDetection() async throws {
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    
    // Manually corrupt config with duplicate names
    var config = try ConfigFileManager.load(from: fixture.repoPath)
    config.subtrees.append(Subtree(name: "Hello-World", prefix: "vendor/a", ...))
    config.subtrees.append(Subtree(name: "hello-world", prefix: "vendor/b", ...))
    try ConfigFileManager.save(config, to: fixture.repoPath)
    
    // Attempt any add operation
    let result = try await fixture.run(["add", "--name", "new-lib", "--remote", testRepoURL])
    
    #expect(result.exitCode == 2)  // Config corruption
    #expect(result.stderr.contains("Multiple subtrees match"))
}
```

## Error Messages

**Duplicate Name** (Exit code 1):
```
❌ Error: Subtree name 'my-lib' conflicts with existing 'My-Lib'
```

**Duplicate Prefix** (Exit code 1):
```
❌ Error: Prefix 'vendor/lib' conflicts with existing 'Vendor/Lib'
```

**Config Corruption** (Exit code 1):
```
❌ Error: Subtree name 'My-Lib' conflicts with existing 'my-lib'
```

**Non-ASCII Warning** (Exit code 0, stderr):
```
⚠️  Warning: Subtree name 'Библиотека' contains non-ASCII characters.
   Case-insensitive matching may not work as expected across all platforms.
```

## Backward Compatibility

**No breaking changes**:
- All existing flags work identically
- Atomic commit pattern preserved
- Error messages enhanced (more helpful, not different semantics)
- Existing valid configs continue to work

**New validation is additive**:
- Catches errors that would have caused problems later
- Prevents creation of invalid configs
- Improves cross-platform portability
