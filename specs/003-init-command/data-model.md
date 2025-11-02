# Data Model: Init Command

**Feature**: 003-init-command | **Date**: 2025-10-27

## Overview

The init command creates a minimal YAML configuration file. While the command itself doesn't process subtree entries, it establishes the config file structure that future commands will populate.

## Entities

### 1. SubtreeConfig

**Purpose**: Root structure of `subtree.yaml` file

**Fields**:
- `subtrees`: Array of subtree entries (empty for init command)

**Validation Rules**:
- MUST be valid YAML syntax
- `subtrees` key MUST exist
- `subtrees` value MUST be an array (can be empty)

**Swift Representation**:
```swift
struct SubtreeConfig: Codable {
    var subtrees: [SubtreeEntry]
    
    init() {
        self.subtrees = []
    }
}
```

**YAML Format**:
```yaml
# Managed by subtree CLI - https://github.com/21-DOT-DEV/subtree
subtrees: []
```

---

### 2. SubtreeEntry

**Purpose**: Individual subtree configuration (not created by init, but defines schema)

**Fields**:
- `name`: String - Human-readable identifier
- `prefix`: String - Local path where subtree content lives
- `url`: String - Remote git repository URL
- `branch`: String - Remote branch to track

**Note**: Init command creates empty array, but schema definition ensures forward compatibility with add/update commands.

**Swift Representation**:
```swift
struct SubtreeEntry: Codable {
    let name: String
    let prefix: String
    let url: String
    let branch: String
}
```

---

### 3. GitRepository

**Purpose**: Represents git repository context (conceptual, not persisted)

**Properties**:
- `rootPath`: String - Absolute path to repository root (resolved via git)
- `isValid`: Bool - Whether current directory is in a git repository

**Operations**:
- `findRoot()` - Execute `git rev-parse --show-toplevel`
- `isRepository()` - Check if in valid git context

**Swift Representation**:
```swift
struct GitRepository {
    let rootPath: String
    
    static func findRoot() async throws -> GitRepository {
        let result = try await executeGitCommand(["rev-parse", "--show-toplevel"])
        guard result.exitCode == 0 else {
            throw GitError.notInRepository
        }
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return GitRepository(rootPath: path)
    }
}
```

---

### 4. ConfigFile

**Purpose**: Represents the subtree.yaml file on disk (conceptual, not persisted separately)

**Properties**:
- `path`: String - Absolute path to config file (always `{gitRoot}/subtree.yaml`)
- `exists`: Bool - Whether file already exists
- `content`: String - YAML content to write

**Operations**:
- `create()` - Atomically write config file
- `exists()` - Check if config file present
- `generatePath()` - Construct path from git root

**Swift Representation**:
```swift
struct ConfigFile {
    let path: String
    let content: String
    
    static func at(gitRoot: String) -> ConfigFile {
        let path = "\(gitRoot)/subtree.yaml"
        let config = SubtreeConfig()
        let yamlContent = try! YAMLEncoder().encode(config)
        let header = "# Managed by subtree CLI - https://github.com/21-DOT-DEV/subtree\n"
        let content = header + yamlContent
        
        return ConfigFile(path: path, content: content)
    }
    
    func createAtomically() async throws {
        let tempPath = "\(path).tmp.\(UUID().uuidString)"
        try content.write(toFile: tempPath, atomically: true, encoding: .utf8)
        try FileManager.default.moveItem(atPath: tempPath, toPath: path)
    }
    
    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }
}
```

---

## Relationships

```
GitRepository (1) ──> (1) ConfigFile
   │
   └─ Determines location of config file
   
ConfigFile (1) ──> (1) SubtreeConfig
   │
   └─ Contains YAML serialization of config
   
SubtreeConfig (1) ──> (*) SubtreeEntry
   │
   └─ Contains array of entries (empty for init)
```

---

## State Transitions

### ConfigFile States

1. **Non-existent** (initial state)
   - `exists() == false`
   - Transitions to "Exists" on successful `create()`
   
2. **Exists**
   - `exists() == true`
   - Init command fails unless `--force` flag provided
   - `--force` transitions back through "Non-existent" (file recreated)

### GitRepository States

1. **Unknown** (before detection)
   - Haven't checked git context yet
   
2. **Not a Repository**
   - `findRoot()` throws `GitError.notInRepository`
   - Command fails with error message
   
3. **Valid Repository**
   - `findRoot()` succeeds
   - `rootPath` contains canonical path
   - Command proceeds to file creation

---

## Validation Rules

### SubtreeConfig
- ✅ MUST serialize to valid YAML
- ✅ MUST include `subtrees` key
- ✅ `subtrees` MUST be an array
- ✅ Empty array is valid for initial config

### ConfigFile
- ✅ Path MUST be `{gitRoot}/subtree.yaml` (exact filename)
- ✅ Content MUST include header comment with GitHub URL
- ✅ Content MUST be valid UTF-8
- ✅ File MUST be created atomically (temp + rename)

### GitRepository
- ✅ `rootPath` MUST be absolute path
- ✅ `rootPath` MUST resolve symlinks to canonical location
- ✅ `rootPath` MUST be writable by current user

---

## Error Conditions

### GitRepository Errors
- **NotInRepository**: Current directory not in git repository
  - User message: "❌ Must be run inside a git repository"
  - Exit code: 1

- **GitCommandFailed**: `git rev-parse` failed unexpectedly
  - User message: "❌ Failed to determine repository root: {error}"
  - Exit code: 1

### ConfigFile Errors
- **AlreadyExists**: File exists and --force not provided
  - User message: "❌ subtree.yaml already exists"
  - Hint: "Use --force to overwrite"
  - Exit code: 1

- **PermissionDenied**: Cannot write to repository root
  - User message: "❌ Permission denied: cannot create subtree.yaml"
  - Exit code: 1

- **WriteFailure**: I/O error during file creation
  - User message: "❌ Failed to create subtree.yaml: {error}"
  - Exit code: 1

---

## Implementation Notes

### YAML Serialization
- Use `Yams` library (existing dependency)
- Encode `SubtreeConfig` struct to YAML
- Prepend header comment as string (YAML comments not in data model)
- Ensure consistent formatting (array indicators, spacing)

### Atomic File Creation
- Write to temporary file with UUID suffix
- Use atomic rename operation (POSIX atomic)
- Clean up temp file on error
- Last writer wins if concurrent execution

### Path Handling
- Use absolute paths internally
- Convert to relative paths only for display
- Resolve symlinks via git command
- Use `swift-system` for cross-platform file operations

---

## Testing Considerations

### Unit Test Data
- Mock `SubtreeConfig` with empty array
- Mock `GitRepository` with test paths
- Mock `ConfigFile` with sample content

### Integration Test Scenarios
- Fresh git repository (no existing config)
- Existing config without --force
- Existing config with --force
- Not in git repository
- Permission denied scenario
- Symlinked repository root
- Subdirectory execution

### Assertions
- Verify YAML structure matches schema
- Verify header comment present
- Verify file created at correct location
- Verify atomic operation (no partial writes)
- Verify emoji-prefixed messages in output

---

## Future Extensions

While init command only creates empty config, the data model supports future commands:

- **add command**: Append `SubtreeEntry` to `subtrees` array
- **remove command**: Remove `SubtreeEntry` from array
- **update command**: Modify existing `SubtreeEntry`
- **validate command**: Check config structure and field values

The minimal schema established by init ensures forward compatibility with these operations.
