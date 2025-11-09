# CLI Contract: Init Command

**Feature**: 003-init-command | **Date**: 2025-10-27

## Command Signature

```bash
subtree init [--force]
```

## Purpose

Initialize a minimal `subtree.yaml` configuration file at the git repository root to enable declarative subtree management.

---

## Arguments

**None** - Command takes no positional arguments

---

## Flags

### `--force`

**Type**: Boolean flag (no value)  
**Required**: No  
**Default**: Not set (false)

**Purpose**: Overwrite existing `subtree.yaml` file if present

**Behavior**:
- When NOT provided: Command fails if `subtree.yaml` exists
- When provided: Command overwrites existing `subtree.yaml` with fresh minimal config

**Example**:
```bash
$ subtree init --force
✅ Created subtree.yaml
```

---

## Exit Codes

| Code | Condition | Description |
|------|-----------|-------------|
| 0 | Success | Config file created successfully |
| 1 | Not in git repository | Current directory not in a git repository |
| 1 | File exists | `subtree.yaml` exists and --force not provided |
| 1 | Permission denied | Cannot write to repository root |
| 1 | I/O error | File creation failed |

---

## Output

### Success Scenario

**Condition**: Config file created successfully

**stdout**:
```
✅ Created subtree.yaml
```
*or*
```
✅ Created ../../subtree.yaml
```

**stderr**: Empty

**Exit code**: 0

**Notes**:
- Path shown is relative to current working directory
- If at repository root: shows just filename
- If in subdirectory: shows relative path with `../`

---

### Error Scenarios

#### Not in Git Repository

**Condition**: Command run outside git repository

**stdout**: Empty

**stderr**:
```
❌ Must be run inside a git repository
```

**Exit code**: 1

---

#### File Already Exists

**Condition**: `subtree.yaml` exists and --force not provided

**stdout**: Empty

**stderr**:
```
❌ subtree.yaml already exists
Use --force to overwrite
```

**Exit code**: 1

**Notes**:
- Second line is a hint for users
- --force flag allows overwriting

---

#### Permission Denied

**Condition**: User lacks write permissions to repository root

**stdout**: Empty

**stderr**:
```
❌ Permission denied: cannot create subtree.yaml
```

**Exit code**: 1

---

#### I/O Error

**Condition**: File creation failed (disk full, etc.)

**stdout**: Empty

**stderr**:
```
❌ Failed to create subtree.yaml: {error details}
```

**Exit code**: 1

**Notes**:
- `{error details}` includes system error message
- Example: "No space left on device"

---

## File Output

### Created File: `subtree.yaml`

**Location**: Git repository root (determined via `git rev-parse --show-toplevel`)

**Content**:
```yaml
# Managed by subtree CLI - https://github.com/21-DOT-DEV/subtree
subtrees: []
```

**Format**:
- Line 1: Header comment with GitHub repository URL
- Line 2: Empty subtrees array in YAML format

**Properties**:
- **Encoding**: UTF-8
- **Line endings**: LF (Unix-style)
- **Permissions**: Default for created files (respects umask)

---

## Behavior Specification

### Pre-Execution Checks

1. **Git Repository Validation**
   - Execute `git rev-parse --show-toplevel`
   - If fails: Output "❌ Must be run inside a git repository", exit 1
   - If succeeds: Store repository root path

2. **File Existence Check**
   - Check if `{gitRoot}/subtree.yaml` exists
   - If exists AND --force NOT provided: Output "❌ subtree.yaml already exists", exit 1
   - If exists AND --force provided: Proceed to creation (will overwrite)
   - If not exists: Proceed to creation

### File Creation Process

1. **Generate Content**
   - Create header comment with GitHub URL
   - Serialize empty `SubtreeConfig` struct to YAML using Yams
   - Combine header + YAML content

2. **Atomic Write**
   - Write content to temporary file: `subtree.yaml.tmp.{UUID}`
   - Atomically rename temp file to `subtree.yaml`
   - Cleanup temp file on error

3. **Success Output**
   - Calculate relative path from current directory to config file
   - Output "✅ Created {relativePath}"
   - Exit with code 0

### Error Handling

- **Git command fails**: Check exit code, output appropriate error
- **Permission denied**: Catch I/O error, output permission message
- **Write failure**: Catch I/O error, output generic failure message
- **Temp file cleanup**: Best effort cleanup, don't fail command if cleanup fails

---

## Examples

### Example 1: First-Time Init (At Repository Root)

```bash
$ cd /Users/dev/myproject
$ git status  # Verify in git repo
On branch main
...

$ subtree init
✅ Created subtree.yaml

$ echo $?
0

$ cat subtree.yaml
# Managed by subtree CLI - https://github.com/21-DOT-DEV/subtree
subtrees: []
```

---

### Example 2: Init from Subdirectory

```bash
$ cd /Users/dev/myproject/src/components
$ pwd
/Users/dev/myproject/src/components

$ subtree init
✅ Created ../../subtree.yaml

$ ls ../../subtree.yaml
../../subtree.yaml
```

---

### Example 3: File Already Exists

```bash
$ subtree init
❌ subtree.yaml already exists
Use --force to overwrite

$ echo $?
1

$ subtree init --force
✅ Created subtree.yaml

$ echo $?
0
```

---

### Example 4: Not in Git Repository

```bash
$ cd /tmp/not-a-repo
$ subtree init
❌ Must be run inside a git repository

$ echo $?
1
```

---

### Example 5: Permission Denied

```bash
$ cd /Users/dev/readonly-repo
$ subtree init
❌ Permission denied: cannot create subtree.yaml

$ echo $?
1
```

---

## Testing Contract

### Unit Tests

**GitOperations**:
- ✅ `findGitRoot()` with valid repository returns path
- ✅ `findGitRoot()` outside repository throws error
- ✅ `findGitRoot()` resolves symlinks correctly

**ConfigFileManager**:
- ✅ `generateMinimalConfig()` returns valid YAML with header
- ✅ `configPath()` constructs correct path from git root
- ✅ `createAtomically()` creates file with correct content
- ✅ `exists()` returns true when file present, false otherwise

### Integration Tests

**Success Cases**:
- ✅ Init in empty git repository creates file at root
- ✅ Init from subdirectory creates file at repository root
- ✅ Init with --force overwrites existing file
- ✅ Success message shows relative path correctly

**Error Cases**:
- ✅ Init outside git repository fails with correct message
- ✅ Init with existing file (no --force) fails with correct message
- ✅ Init with permission issues fails with correct message

**Edge Cases**:
- ✅ Init in symlinked repository creates file at canonical location
- ✅ Concurrent init processes don't corrupt file
- ✅ Init works in detached HEAD state
- ✅ Init works with nested git repositories (uses closest)

---

## Compatibility

### Platform Requirements

- **macOS**: 13.0+ (Ventura and later)
- **Linux**: Ubuntu 20.04 LTS and compatible distributions

### Dependencies

- **git**: Must be installed and accessible in PATH
- **File system**: Must support atomic rename operation

### Terminal Requirements

- **Emoji support**: Modern terminals (iTerm2, Terminal.app, GNOME Terminal, etc.)
- **UTF-8 encoding**: For proper emoji display

---

## Versioning

**Command Version**: 1.0.0 (initial implementation)

**Breaking Changes**: None (initial version)

**Backwards Compatibility**: N/A (first implementation)

---

## Related Commands

- `subtree validate` - Verify subtree.yaml structure (future)
- `subtree add` - Add subtree entry to config (future)
- `subtree remove` - Remove subtree entry from config (future)

---

## Implementation Checklist

- [ ] Implement `InitCommand` struct conforming to `ParsableCommand`
- [ ] Add `--force` flag with proper ArgumentParser attributes
- [ ] Integrate git repository detection via `GitOperations`
- [ ] Integrate config file creation via `ConfigFileManager`
- [ ] Implement emoji-prefixed output messages
- [ ] Implement relative path calculation for success message
- [ ] Add unit tests for all components
- [ ] Add integration tests for all scenarios
- [ ] Verify CI passes on macOS and Ubuntu
- [ ] Update `.windsurf/rules` after successful implementation
