# Research: Init Command

**Feature**: 003-init-command | **Date**: 2025-10-27

## Purpose

This document consolidates research findings and technical decisions for implementing the `subtree init` command. All clarifications from the specification process are recorded here with rationale and implementation guidance.

## Technical Decisions

### 1. GitHub Repository Reference

**Decision**: Use `21-DOT-DEV/subtree` as the canonical repository reference

**Rationale**: This is the actual GitHub organization and repository name for this project. The header comment in generated `subtree.yaml` files will link to `https://github.com/21-DOT-DEV/subtree` for documentation.

**Implementation Impact**:
- Header comment template: `# Managed by subtree CLI - https://github.com/21-DOT-DEV/subtree`
- Hardcoded in `ConfigFileManager` utility
- Can be extracted to a constant for maintainability

---

### 2. Git Repository Root Detection

**Decision**: Execute `git rev-parse --show-toplevel` command via swift-subprocess

**Rationale**: 
- **Canonical**: This is how git itself reports repository root
- **Handles edge cases**: Automatically resolves symlinks, worktrees, submodules
- **Reliable**: Git does the work, no manual directory walking
- **Standard**: Matches behavior of other git-adjacent tools

**Alternatives Considered**:
- Walking up directory tree looking for `.git` - Error-prone, doesn't handle all git configurations (bare repos, worktrees, git files)
- Using libgit2 bindings - Adds complex dependency for simple operation

**Implementation**:
```swift
// Pseudo-code
func findGitRoot() async throws -> String {
    let result = try await subprocess.run(
        executable: "/usr/bin/git",
        arguments: ["rev-parse", "--show-toplevel"]
    )
    guard result.exitCode == 0 else {
        throw GitError.notInRepository
    }
    return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
}
```

**Error Handling**:
- Non-zero exit code → "❌ Must be run inside a git repository"
- Command not found → System error (git not installed)
- Empty output → Parsing error

---

### 3. YAML File Generation

**Decision**: Use Yams library for YAML generation with manual header comment prepending

**Rationale**:
- **Existing dependency**: Yams 6.1.0 already in Package.swift
- **Type safety**: Encode Swift struct to YAML, guaranteed valid syntax
- **Maintainable**: Schema changes only require struct updates
- **Header comments**: YAML comments aren't part of data structure, so prepend as string

**Alternatives Considered**:
- Hand-crafted string templates - Fragile, error-prone if schema evolves
- Custom YAML encoder - Reinventing wheel, more code to maintain

**Implementation**:
```swift
// Pseudo-code
struct SubtreeConfig: Codable {
    let subtrees: [SubtreeEntry]
}

func generateMinimalConfig() throws -> String {
    let config = SubtreeConfig(subtrees: [])
    let yamlContent = try YAMLEncoder().encode(config)
    let header = "# Managed by subtree CLI - https://github.com/21-DOT-DEV/subtree\n"
    return header + yamlContent
}
```

**Format**:
```yaml
# Managed by subtree CLI - https://github.com/21-DOT-DEV/subtree
subtrees: []
```

---

### 4. Error Message Format

**Decision**: Emoji-prefixed messages (❌ for errors, ✅ for success, ℹ️ for info)

**Rationale**:
- **User preference**: Confirmed in clarification process
- **Visual distinction**: Emojis provide immediate visual feedback
- **Modern CLI UX**: Increasingly common in developer tools
- **Terminal compatibility**: Widely supported in modern terminals

**Alternatives Considered**:
- Plain text prefixes ("Error:") - Traditional, less visual
- No prefixes - Harder to scan quickly
- Full sentence format - Too verbose

**Implementation**:
```swift
enum MessageType {
    case error   // ❌
    case success // ✅
    case info    // ℹ️
    
    var emoji: String {
        switch self {
        case .error: return "❌"
        case .success: return "✅"
        case .info: return "ℹ️"
        }
    }
}

func formatMessage(_ type: MessageType, _ text: String) -> String {
    "\(type.emoji) \(text)"
}
```

**Examples**:
- `❌ subtree.yaml already exists`
- `❌ Must be run inside a git repository`
- `❌ Permission denied`
- `✅ Created subtree.yaml`
- `✅ Created ../../subtree.yaml`

---

### 5. Concurrent Execution Strategy

**Decision**: Atomic file operations (write to temp, rename) with last writer wins

**Rationale**:
- **No data loss**: Both processes write identical content (empty config)
- **Filesystem atomicity**: Rename operation is atomic on POSIX systems
- **Simple**: No locking overhead, no user-facing errors
- **Matches git**: Git uses similar strategy for concurrent operations

**Alternatives Considered**:
- File locking with wait/fail - Adds complexity, potential for deadlocks
- First writer wins - Requires coordination, more complex to implement
- No special handling - Risk of partial writes/corruption

**Implementation**:
```swift
// Pseudo-code
func createConfigFile(at path: String, content: String) async throws {
    let tempPath = "\(path).tmp.\(UUID().uuidString)"
    
    // Write to temporary file
    try content.write(toFile: tempPath, atomically: true, encoding: .utf8)
    
    // Atomic rename (overwrites if exists)
    try FileManager.default.moveItem(atPath: tempPath, toPath: path)
}
```

**Platform Notes**:
- macOS: `rename(2)` is atomic
- Linux: `rename(2)` is atomic on same filesystem
- Both platforms supported ✅

---

### 6. Symbolic Link Resolution

**Decision**: Follow symlinks to canonical repository root location

**Rationale**:
- **Matches git behavior**: `git rev-parse --show-toplevel` resolves symlinks
- **Consistency**: Config always at canonical location regardless of access path
- **No surprises**: Users expect git tools to behave like git
- **Prevents duplicates**: One config location, not multiple perceived roots

**Alternatives Considered**:
- Error on symlink - Too strict, breaks legitimate use cases
- Create at symlinked location - Could cause duplicate configs
- Warn but proceed - Verbose, adds noise to output

**Implementation**:
- Use `git rev-parse --show-toplevel` (automatically resolves symlinks)
- No additional code needed beyond git command execution

---

### 7. Success Message Path Format

**Decision**: Show relative path from current working directory

**Rationale**:
- **User context**: Shows where file was created relative to user's position
- **Helpful**: If in subdirectory, shows `../../subtree.yaml` so user knows where to look
- **Matches git**: Git shows relative paths in output
- **Concise**: Simple filename when at root, relative when elsewhere

**Alternatives Considered**:
- Absolute path - Too verbose, less useful context
- Filename only - Doesn't help users in subdirectories
- Both paths - Redundant, clutters output

**Implementation**:
```swift
// Pseudo-code
func relativePath(from: String, to: String) -> String {
    // Use Foundation's URL.relativePath or manual calculation
    let fromURL = URL(fileURLWithPath: from)
    let toURL = URL(fileURLWithPath: to)
    return toURL.relativePath(from: fromURL) ?? toURL.lastPathComponent
}

// Usage
let currentDir = FileManager.default.currentDirectoryPath
let configPath = "\(gitRoot)/subtree.yaml"
let relativePath = relativePath(from: currentDir, to: configPath)
print("✅ Created \(relativePath)")
```

**Examples**:
- At root: `✅ Created subtree.yaml`
- In subdirectory: `✅ Created ../../subtree.yaml`
- Deep nesting: `✅ Created ../../../subtree.yaml`

---

## Best Practices Integrated

### Git Command Execution
- Use `swift-subprocess` (already a dependency)
- Capture stdout/stderr separately
- Check exit codes before using output
- Trim whitespace from git output
- Handle command not found errors

### File Operations
- Use atomic operations (temp file + rename)
- Check permissions before writing
- Provide clear error messages for I/O failures
- Clean up temp files on error
- Use `swift-system` for cross-platform file operations

### Error Handling
- Use Swift errors with descriptive messages
- Map technical errors to user-friendly messages
- Include emoji prefixes for visual distinction
- Provide actionable guidance (e.g., "Use --force to overwrite")
- Exit with appropriate exit codes (0 = success, 1 = error)

### Testing Strategy
- Unit tests for each utility function
- Integration tests for end-to-end CLI behavior
- Test edge cases: no git, existing file, permissions, symlinks
- Use GitRepositoryFixture for git-dependent tests
- Verify emoji prefixes in output assertions

---

## Implementation Checklist

**Utilities to Create**:
- [ ] `GitOperations.swift` - Git repository detection and path resolution
- [ ] `ConfigFileManager.swift` - YAML file creation with atomic operations

**Command to Implement**:
- [ ] `InitCommand.swift` - ArgumentParser command with --force flag

**Tests to Write**:
- [ ] `GitOperationsTests.swift` - Unit tests for git detection
- [ ] `ConfigFileManagerTests.swift` - Unit tests for file creation
- [ ] `InitCommandIntegrationTests.swift` - End-to-end CLI tests

**Integration Points**:
- [ ] Register `InitCommand` as subcommand in `SubtreeCommand`
- [ ] Ensure emoji output works in CI environments
- [ ] Verify cross-platform compatibility (macOS + Ubuntu)

---

## Open Questions

**None** - All technical decisions have been clarified through the specification and planning process.
