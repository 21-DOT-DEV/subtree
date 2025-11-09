# CLI Command Contracts

**Feature**: 001-cli-bootstrap  
**Date**: 2025-10-26  
**Purpose**: Define command-line interface contracts for all subtree commands

## Command Structure

All commands follow the pattern:
```
subtree [global-options] <command> [command-options] [arguments]
```

## Root Command: `subtree`

**Usage**: `subtree [--help] [--version]`

**Description**: Git subtree management tool

**Global Options**:
- `--help, -h`: Show help message
- `--version`: Show version information

**Subcommands**:
- `init`: Initialize subtree configuration
- `add`: Add a new subtree
- `update`: Update an existing subtree
- `remove`: Remove a subtree
- `extract`: Extract a subtree to a separate repository
- `validate`: Validate subtree configuration

**Exit Codes**:
- `0`: Success or help displayed
- `1`: General error
- `2`: Command misuse (invalid arguments)

**Examples**:
```bash
# Show help
subtree --help
subtree -h

# Show version
subtree --version

# Run subcommand
subtree init
subtree add <url> <path>
```

---

## Stub Command Standard (Bootstrap Phase)

All stub commands in bootstrap phase follow this pattern:

**Behavior**:
- Print to stdout: `Command '<command-name>' not yet implemented`
- Return exit code 0
- No other side effects

**Example**:
```bash
$ subtree init
Command 'init' not yet implemented
$ echo $?
0
```

**Rationale**: Exit code 0 prevents script failures during bootstrap. Message format is consistent across all 6 stub commands. Future specs will replace stubs with real implementations.

---

## Command: `init`

**Status**: Stub (bootstrap phase)

**Usage**: `subtree init [--help]`

**Description**: Initialize subtree configuration in the repository

**Options**:
- `--help, -h`: Show command help

**Arguments**: None

**Output** (stub): 
```
Command 'init' not yet implemented
```

**Exit Codes**:
- `0`: Stub execution or help

**Future Behavior** (to be implemented in subsequent spec):
- Create `subtree.yaml` configuration file
- Verify git repository exists
- Set up initial configuration structure

**Examples**:
```bash
# Show help
subtree init --help

# Run command (stub)
subtree init
# Output: Command 'init' not yet implemented
```

---

## Command: `add`

**Status**: Stub (bootstrap phase)

**Usage**: `subtree add [--help]`

**Description**: Add a new subtree to the repository

**Options**:
- `--help, -h`: Show command help

**Arguments**: None (stub)

**Output** (stub):
```
Command 'add' not yet implemented
```

**Exit Codes**:
- `0`: Stub execution or help

**Future Behavior** (to be implemented in subsequent spec):
- Add subtree from remote repository
- Update subtree.yaml configuration
- Create git subtree merge commit

**Examples**:
```bash
# Show help
subtree add --help

# Run command (stub)
subtree add
# Output: Command 'add' not yet implemented
```

---

## Command: `update`

**Status**: Stub (bootstrap phase)

**Usage**: `subtree update [--help]`

**Description**: Update an existing subtree

**Options**:
- `--help, -h`: Show command help

**Arguments**: None (stub)

**Output** (stub):
```
Command 'update' not yet implemented
```

**Exit Codes**:
- `0`: Stub execution or help

**Future Behavior** (to be implemented in subsequent spec):
- Pull latest changes from subtree remote
- Update subtree.yaml with new commit hash
- Create git subtree merge commit

**Examples**:
```bash
# Show help
subtree update --help

# Run command (stub)
subtree update
# Output: Command 'update' not yet implemented
```

---

## Command: `remove`

**Status**: Stub (bootstrap phase)

**Usage**: `subtree remove [--help]`

**Description**: Remove a subtree from the repository

**Options**:
- `--help, -h`: Show command help

**Arguments**: None (stub)

**Output** (stub):
```
Command 'remove' not yet implemented
```

**Exit Codes**:
- `0`: Stub execution or help

**Future Behavior** (to be implemented in subsequent spec):
- Remove subtree files from repository
- Update subtree.yaml configuration
- Create git commit removing subtree

**Examples**:
```bash
# Show help
subtree remove --help

# Run command (stub)
subtree remove
# Output: Command 'remove' not yet implemented
```

---

## Command: `extract`

**Status**: Stub (bootstrap phase)

**Usage**: `subtree extract [--help]`

**Description**: Extract a subtree to a separate repository

**Options**:
- `--help, -h`: Show command help

**Arguments**: None (stub)

**Output** (stub):
```
Command 'extract' not yet implemented
```

**Exit Codes**:
- `0`: Stub execution or help

**Future Behavior** (to be implemented in subsequent spec):
- Create new repository from subtree history
- Preserve git history for subtree path
- Generate instructions for migrating to extracted repo

**Examples**:
```bash
# Show help
subtree extract --help

# Run command (stub)
subtree extract
# Output: Command 'extract' not yet implemented
```

---

## Command: `validate`

**Status**: Stub (bootstrap phase)

**Usage**: `subtree validate [--help]`

**Description**: Validate subtree configuration

**Options**:
- `--help, -h`: Show command help

**Arguments**: None (stub)

**Output** (stub):
```
Command 'validate' not yet implemented
```

**Exit Codes**:
- `0`: Stub execution or help

**Future Behavior** (to be implemented in subsequent spec):
- Verify subtree.yaml format
- Check subtree paths exist
- Validate git repository state

**Examples**:
```bash
# Show help
subtree validate --help

# Run command (stub)
subtree validate
# Output: Command 'validate' not yet implemented
```

---

## Help Text Format

All help text follows swift-argument-parser conventions:

```
OVERVIEW: <brief description>

USAGE: subtree <command> [<options>]

OPTIONS:
  -h, --help              Show help information

SUBCOMMANDS:
  <command-name>          <command-description>

See 'subtree help <subcommand>' for detailed help.
```

## Testing Requirements

Each command must have:
1. Help text test (verify `--help` works)
2. Stub execution test (verify command runs and prints stub message)
3. Exit code test (verify exit code is 0)

## Contract Stability

These contracts define the user-facing API. Changes to command names, option flags, or behavior are **breaking changes** requiring:
- Major version bump
- Migration guide
- Deprecation period (where possible)
