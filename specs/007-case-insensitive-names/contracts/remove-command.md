# Contract: Remove Command (Modified)

**Feature**: 007-case-insensitive-names | **Command**: `subtree remove`

## Modifications

This feature adds case-insensitive name matching to the existing Remove Command. Core functionality remains unchanged.

## Command Signature

```bash
subtree remove <name>
```

## Behavioral Changes

### 1. Case-Insensitive Name Lookup (New)

**Before git operations**, match name case-insensitively:

**Success Path** (Single Match):
```
Input: "hello-world" (config has "Hello-World")
→ Normalize input: trim whitespace
→ Lookup: case-insensitive match
→ Match found: "Hello-World"
→ Proceed with git subtree split + removal
→ Remove config entry for "Hello-World"
```

**Success Path** (Exact Match):
```
Input: "Hello-World" (config has "Hello-World")
→ Normalize input: trim whitespace
→ Lookup: case-insensitive match
→ Match found: "Hello-World"
→ Proceed with removal
```

**Failure Path** (Not Found):
```
Input: "nonexistent"
→ Normalize input: trim whitespace
→ Lookup: case-insensitive match
→ No match found
→ Error: ValidationError.subtreeNotFound
→ Exit code: 1
→ Git operations: NOT executed
```

**Failure Path** (Multiple Matches):
```
Input: "hello-world" (config has "Hello-World" AND "hello-world")
→ Normalize input: trim whitespace
→ Lookup: case-insensitive match
→ Multiple matches found (config corruption)
→ Error: ValidationError.multipleMatches
→ Exit code: 2
→ Git operations: NOT executed
```

### 2. Config Validation on Load (New)

**Before any operations**, validate loaded config for corruption:

**Success Path**:
```
Load subtree.yaml
→ Parse YAML
→ Validate: no case-insensitive duplicates
→ Proceed with remove operation
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

### US1-001: Case-Insensitive Removal
```swift
@Test("Remove finds subtree with different case")
func testCaseInsensitiveRemoval() async throws {
    // Given: Config contains "Hello-World"
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    try await fixture.run(["add", "--name", "Hello-World", "--remote", testRepoURL])
    
    // When: Remove with lowercase "hello-world"
    let result = try await fixture.run(["remove", "hello-world"])
    
    // Then: Removal succeeds
    #expect(result.exitCode == 0)
    
    // And: Config entry is removed
    let config = try ConfigFileManager.load(from: fixture.repoPath)
    #expect(config.subtrees.isEmpty)
}
```

### US1-002: Exact Case Match Works
```swift
@Test("Remove works with exact case match")
func testExactCaseRemoval() async throws {
    // Given: Config contains "Hello-World"
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    try await fixture.run(["add", "--name", "Hello-World", "--remote", testRepoURL])
    
    // When: Remove with exact case "Hello-World"
    let result = try await fixture.run(["remove", "Hello-World"])
    
    // Then: Removal succeeds
    #expect(result.exitCode == 0)
    
    // And: Config entry is removed
    let config = try ConfigFileManager.load(from: fixture.repoPath)
    #expect(config.subtrees.isEmpty)
}
```

### US1-003: Not Found Error
```swift
@Test("Remove fails when subtree not found")
func testRemoveNotFound() async throws {
    // Given: Empty config
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    
    // When: Attempt to remove nonexistent subtree
    let result = try await fixture.run(["remove", "nonexistent"])
    
    // Then: Command fails with clear error
    #expect(result.exitCode == 1)
    #expect(result.stderr.contains("not found"))
}
```

### US4-001: Multiple Matches Detection
```swift
@Test("Remove fails when multiple case-variant matches exist")
func testMultipleMatchesDetection() async throws {
    // Given: Manually corrupted config with duplicate names
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    
    var config = try ConfigFileManager.load(from: fixture.repoPath)
    config.subtrees.append(Subtree(name: "Hello-World", prefix: "vendor/a", ...))
    config.subtrees.append(Subtree(name: "hello-world", prefix: "vendor/b", ...))
    try ConfigFileManager.save(config, to: fixture.repoPath)
    
    // When: Attempt to remove with case-insensitive name
    let result = try await fixture.run(["remove", "hello-world"])
    
    // Then: Command fails with corruption error
    #expect(result.exitCode == 2)
    #expect(result.stderr.contains("Multiple subtrees match"))
    #expect(result.stderr.contains("'Hello-World'"))
    #expect(result.stderr.contains("'hello-world'"))
    #expect(result.stderr.contains("subtree lint"))
}
```

### Whitespace Trimming
```swift
@Test("Remove trims whitespace from input")
func testWhitespaceTrimming() async throws {
    // Given: Config contains "My-Lib"
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    try await fixture.run(["add", "--name", "My-Lib", "--remote", testRepoURL])
    
    // When: Remove with extra whitespace
    let result = try await fixture.run(["remove", "  My-Lib  "])
    
    // Then: Removal succeeds (whitespace trimmed)
    #expect(result.exitCode == 0)
    
    let config = try ConfigFileManager.load(from: fixture.repoPath)
    #expect(config.subtrees.isEmpty)
}
```

## Error Messages

**Subtree Not Found** (Exit code 1):
```
❌ Error: Subtree 'nonexistent' not found
```

**Config Corruption - Duplicate Names** (Exit code 1):
```
❌ Error: Subtree name 'My-Lib' conflicts with existing 'my-lib'
```

**Config Corruption - Duplicate Prefixes** (Exit code 1):
```
❌ Error: Prefix 'Vendor/Shared' conflicts with existing 'vendor/shared'
```

## Backward Compatibility

**No breaking changes**:
- Exact case matches continue to work
- Case-insensitive matching is **additive** (expands what works)
- Error messages enhanced (more helpful)
- Atomic removal pattern preserved (subtree + config in one commit)
- Exit codes preserved (0=success, 1=user error, 2=corruption, 3=git failure)

**Benefits**:
- Users don't need to remember exact capitalization
- Consistent with modern CLI tools (git, npm, cargo)
- Catches config corruption before operations
