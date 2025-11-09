# Contract: Update Command (Modified)

**Feature**: 007-case-insensitive-names | **Command**: `subtree update`

## Modifications

This feature adds case-insensitive name matching to the existing Update Command. Core functionality remains unchanged.

## Command Signature

```bash
subtree update <name> [--squash | --no-squash]
```

## Behavioral Changes

### 1. Case-Insensitive Name Lookup (New)

**Before git operations**, match name case-insensitively:

**Success Path** (Single Match):
```
Input: "my-lib" (config has "My-Lib")
→ Normalize input: trim whitespace
→ Lookup: case-insensitive match
→ Match found: "My-Lib"
→ Proceed with git subtree pull
→ Update config commit hash for "My-Lib"
```

**Success Path** (Exact Match):
```
Input: "My-Lib" (config has "My-Lib")
→ Normalize input: trim whitespace
→ Lookup: case-insensitive match
→ Match found: "My-Lib"
→ Proceed with update
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
Input: "my-lib" (config has "My-Lib" AND "my-lib")
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
→ Proceed with update operation
```

**Failure Path** (Corrupted Config):
```
Load subtree.yaml
→ Parse YAML
→ Validate: found "My-Lib" AND "my-lib"
→ Error: ValidationError.multipleMatches
→ Exit code: 2
→ Git operations: NOT executed
```

## Test Contracts

### US1-001: Case-Insensitive Update
```swift
@Test("Update finds subtree with different case")
func testCaseInsensitiveUpdate() async throws {
    // Given: Config contains "My-Lib"
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    try await fixture.run(["add", "--name", "My-Lib", "--remote", testRepoURL])
    
    // When: Update with uppercase "MY-LIB"
    let result = try await fixture.run(["update", "MY-LIB"])
    
    // Then: Update succeeds
    #expect(result.exitCode == 0)
    
    // And: Config entry still named "My-Lib" (case preserved)
    let config = try ConfigFileManager.load(from: fixture.repoPath)
    let subtree = try #require(config.subtrees.first)
    #expect(subtree.name == "My-Lib")  // Original case preserved
}
```

### US1-002: Exact Case Match Works
```swift
@Test("Update works with exact case match")
func testExactCaseUpdate() async throws {
    // Given: Config contains "VendorLib"
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    try await fixture.run(["add", "--name", "VendorLib", "--remote", testRepoURL])
    
    // When: Update with exact case "VendorLib"
    let result = try await fixture.run(["update", "VendorLib"])
    
    // Then: Update succeeds
    #expect(result.exitCode == 0)
}
```

### US1-003: Not Found Error
```swift
@Test("Update fails when subtree not found")
func testUpdateNotFound() async throws {
    // Given: Empty config
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    
    // When: Attempt to update nonexistent subtree
    let result = try await fixture.run(["update", "nonexistent"])
    
    // Then: Command fails with clear error
    #expect(result.exitCode == 1)
    #expect(result.stderr.contains("not found"))
}
```

### US4-001: Multiple Matches Detection
```swift
@Test("Update fails when multiple case-variant matches exist")
func testMultipleMatchesDetection() async throws {
    // Given: Manually corrupted config with duplicate names
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    
    var config = try ConfigFileManager.load(from: fixture.repoPath)
    config.subtrees.append(Subtree(name: "VendorLib", prefix: "vendor/a", ...))
    config.subtrees.append(Subtree(name: "vendorlib", prefix: "vendor/b", ...))
    try ConfigFileManager.save(config, to: fixture.repoPath)
    
    // When: Attempt to update with case-insensitive name
    let result = try await fixture.run(["update", "VENDORLIB"])
    
    // Then: Command fails with corruption error
    #expect(result.exitCode == 2)
    #expect(result.stderr.contains("Multiple subtrees match"))
    #expect(result.stderr.contains("'VendorLib'"))
    #expect(result.stderr.contains("'vendorlib'"))
    #expect(result.stderr.contains("subtree lint"))
}
```

### Whitespace Trimming
```swift
@Test("Update trims whitespace from input")
func testWhitespaceTrimming() async throws {
    // Given: Config contains "my-lib"
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    try await fixture.run(["add", "--name", "my-lib", "--remote", testRepoURL])
    
    // When: Update with extra whitespace
    let result = try await fixture.run(["update", "  my-lib  "])
    
    // Then: Update succeeds (whitespace trimmed)
    #expect(result.exitCode == 0)
}
```

### Case Preservation During Update
```swift
@Test("Update preserves original case in config")
func testCasePreservation() async throws {
    // Given: Config contains "Hello-World"
    let fixture = try await GitRepositoryFixture()
    try await fixture.run(["init"])
    try await fixture.run(["add", "--name", "Hello-World", "--remote", testRepoURL])
    
    // When: Update with lowercase "hello-world"
    let result = try await fixture.run(["update", "hello-world"])
    
    // Then: Update succeeds
    #expect(result.exitCode == 0)
    
    // And: Config still shows "Hello-World" (original case preserved)
    let config = try ConfigFileManager.load(from: fixture.repoPath)
    let subtree = try #require(config.subtrees.first)
    #expect(subtree.name == "Hello-World")
}
```

## Error Messages

**Subtree Not Found** (Exit code 1):
```
❌ Error: Subtree 'nonexistent' not found
```

**Config Corruption - Duplicate Names** (Exit code 1):
```
❌ Error: Subtree name 'lib-alpha' conflicts with existing 'Lib-Alpha'
```

**Config Corruption - Duplicate Prefixes** (Exit code 1):
```
❌ Error: Prefix 'Libraries/Core' conflicts with existing 'libraries/core'
```

## Backward Compatibility

**No breaking changes**:
- Exact case matches continue to work
- Case-insensitive matching is **additive** (expands what works)
- Error messages enhanced (more helpful)
- Atomic update pattern preserved (subtree + config in one commit)
- Exit codes preserved (0=success, 1=user error, 2=corruption, 5=no updates available)
- Squash behavior unchanged

**Benefits**:
- Users don't need to remember exact capitalization
- Consistent with Remove command behavior
- Catches config corruption before operations
- Original case always preserved in config (FR-003)
