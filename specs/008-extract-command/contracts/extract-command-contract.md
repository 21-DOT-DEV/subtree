# CLI Contract: Extract Command

**Feature**: `008-extract-command` | **Date**: 2025-10-31  
**Phase**: 1 (Design & Contracts)

## Command Interface

### Base Command

```
subtree extract [OPTIONS] [SOURCE_PATTERN] [DESTINATION]
```

---

## Modes of Operation

### Mode 1: Ad-hoc Extraction (Positional Arguments Required)

**Usage**:
```bash
subtree extract --name <SUBTREE_NAME> <SOURCE_PATTERN> <DESTINATION> [OPTIONS]
```

**Description**: Extract files matching glob pattern from subtree to destination directory.

**Arguments**:
- `SOURCE_PATTERN`: Glob pattern for files to extract (e.g., `"docs/**/*.md"`)
- `DESTINATION`: Relative path to destination directory (e.g., `project-docs/`)

**Required Flags**:
- `--name <NAME>`: Subtree name (case-insensitive lookup)

**Optional Flags**:
- `--exclude <PATTERN>`: Exclude files matching pattern (repeatable)
- `--persist`: Save extraction mapping to subtree.yaml
- `--force`: Override git-tracked file protection

**Examples**:
```bash
# Extract all markdown files from docs/
subtree extract --name my-lib "docs/**/*.md" project-docs/

# Extract source files excluding tests
subtree extract --name secp256k1 "src/**/*.{h,c}" Sources/lib/ \
  --exclude "src/**/test*/**" \
  --exclude "src/bench*.c"

# Extract and persist mapping for future reuse
subtree extract --name utils "templates/**" .templates/ --persist

# Force overwrite git-tracked files
subtree extract --name my-lib "configs/**" configs/ --force
```

---

### Mode 2: Execute Saved Mappings (Specific Subtree)

**Usage**:
```bash
subtree extract --name <SUBTREE_NAME>
```

**Description**: Execute all saved extraction mappings for the specified subtree.

**Required Flags**:
- `--name <NAME>`: Subtree name (case-insensitive lookup)

**Positional Arguments**: None (presence of SOURCE_PATTERN triggers Mode 1)

**Optional Flags**:
- `--force`: Override git-tracked file protection for all mappings

**Examples**:
```bash
# Execute all saved mappings for my-lib
subtree extract --name my-lib

# Execute saved mappings, overriding protection
subtree extract --name secp256k1 --force
```

**Behavior**:
- Executes mappings in array order (as defined in subtree.yaml)
- If no saved mappings exist: success with informational message (exit 0)
- If any mapping fails: continue processing remaining mappings, report all failures at end
- Exit code: highest severity encountered (3 > 2 > 1)

---

### Mode 3: Execute All Saved Mappings (All Subtrees)

**Usage**:
```bash
subtree extract --all
```

**Description**: Execute all saved extraction mappings for all subtrees.

**Required Flags**:
- `--all`: Process all subtrees with saved mappings

**Positional Arguments**: None

**Optional Flags**:
- `--force`: Override git-tracked file protection for all mappings

**Examples**:
```bash
# Execute all saved mappings across all subtrees
subtree extract --all

# Execute all, overriding protection
subtree extract --all --force
```

**Behavior**:
- Iterates through all subtrees in config
- For each subtree with `extractions` array: execute all mappings
- Skip subtrees without `extractions` field (no error)
- If any mapping fails: continue processing remaining mappings, report all failures at end
- Exit code: highest severity encountered (3 > 2 > 1)

---

## Flags Reference

### --name <NAME>

**Purpose**: Specify subtree to extract from

**Required**: Yes for ad-hoc extraction (Mode 1), yes for specific subtree execution (Mode 2)

**Incompatible with**: `--all`

**Validation**:
- Name must exist in subtree.yaml (case-insensitive lookup)
- Subtree directory must exist at configured prefix

**Examples**:
```bash
subtree extract --name my-lib "src/**/*.h" include/
subtree extract --name My-Lib  # Case-insensitive
```

---

### --all

**Purpose**: Execute all saved mappings for all subtrees

**Required**: Yes for bulk execution (Mode 3)

**Incompatible with**: `--name`, positional arguments (SOURCE_PATTERN, DESTINATION)

**Examples**:
```bash
subtree extract --all
subtree extract --all --force
```

---

### --exclude <PATTERN>

**Purpose**: Exclude files matching glob pattern from extraction

**Repeatable**: Yes (multiple --exclude flags allowed)

**Available in**: Mode 1 only (ad-hoc extraction)

**Behavior**:
- Applied AFTER `from` pattern matching
- Files matching both `from` and any `exclude` are filtered out
- Supports same glob syntax as SOURCE_PATTERN

**Examples**:
```bash
# Single exclusion
subtree extract --name lib "src/**/*.c" Sources/ --exclude "src/**/test*/**"

# Multiple exclusions
subtree extract --name lib "**/*.swift" Sources/ \
  --exclude "**/Tests/**" \
  --exclude "**/Mocks/**" \
  --exclude "**/*+Testing.swift"
```

---

### --persist

**Purpose**: Save extraction mapping to subtree.yaml for future reuse

**Available in**: Mode 1 only (ad-hoc extraction)

**Behavior**:
- Appends mapping to subtree's `extractions` array
- Creates `extractions` array if it doesn't exist
- Saves all --exclude patterns (if provided) to `exclude` field
- Config update is atomic (temp file + rename pattern)

**Examples**:
```bash
# Extract once, save for future reuse
subtree extract --name my-lib "docs/**/*.md" project-docs/ --persist

# With exclusions (saved to config)
subtree extract --name lib "src/**/*.c" Sources/ \
  --exclude "src/**/test*/**" \
  --persist
```

---

### --force

**Purpose**: Override git-tracked file protection

**Available in**: All modes

**Behavior**:
- Allows overwriting git-tracked files at destination
- Without --force: git-tracked files cause error (exit 2)
- With --force: all files overwritten regardless of git status
- Untracked files always overwritten (no protection)

**Examples**:
```bash
# Override protection for ad-hoc extraction
subtree extract --name lib "configs/**" configs/ --force

# Override protection for saved mappings
subtree extract --name my-lib --force
subtree extract --all --force
```

---

## Exit Codes

| Code | Meaning | Examples |
|------|---------|----------|
| 0 | Success | All files extracted successfully |
| 1 | Validation error | Missing subtree, invalid path, zero matches, pattern syntax error |
| 2 | Overwrite protection | Git-tracked files blocked (suggest --force) |
| 3 | I/O error | Permission denied, disk full, filesystem errors |

**Bulk execution exit codes** (Mode 2 & 3):
- Exit code = highest severity encountered across all mappings
- Priority: 3 (I/O) > 2 (protection) > 1 (validation)
- Example: If 1 mapping fails with exit 1 and another with exit 2 → exit 2

---

## Output Behavior

### stdout (Success)

**Ad-hoc extraction**:
```
Extracted 15 files from my-lib to project-docs/
```

**With persistence**:
```
Extracted 15 files from my-lib to project-docs/
Saved extraction mapping to subtree.yaml
```

**Saved mappings (specific subtree)**:
```
Executing 3 saved mappings for my-lib...
  ✓ Extracted 10 files: docs/**/*.md → project-docs/
  ✓ Extracted 5 files: src/**/*.h → include/
  ✓ Extracted 3 files: configs/** → configs/
Completed 3 mappings for my-lib
```

**Saved mappings (all subtrees)**:
```
Executing saved mappings for all subtrees...
my-lib:
  ✓ Extracted 10 files: docs/**/*.md → project-docs/
secp256k1:
  ✓ Extracted 45 files: src/**/*.{h,c} → Sources/lib/src/
  ✓ Extracted 12 files: include/**/*.h → Sources/lib/include/
Completed 3 mappings across 2 subtrees
```

**No saved mappings**:
```
No saved extraction mappings found for my-lib
```

### stderr (Errors)

**Missing subtree**:
```
Error: Subtree 'unknown-lib' not found in subtree.yaml
Run 'subtree add' to add this subtree first
```

**Zero matches**:
```
Error: Pattern 'nonexistent/**/*.xyz' matched 0 files in my-lib
Check pattern syntax and subtree contents
```

**All matches excluded**:
```
Error: Pattern 'src/**/*.c' matched 45 files, but all were excluded by exclusion patterns
0 files remain after applying exclusions
```

**Overwrite protection**:
```
Error: Cannot overwrite git-tracked files without --force flag
Protected files:
  - project-docs/README.md
  - project-docs/guide.md
Run with --force to override protection
```

**Invalid path**:
```
Error: Destination path '../outside' is invalid
Paths must be relative and within repository boundaries
```

**Permission denied**:
```
Error: Permission denied writing to project-docs/
Check filesystem permissions
```

**Bulk execution failures**:
```
Executing 3 saved mappings for my-lib...
  ✓ Extracted 10 files: docs/**/*.md → project-docs/
  ✗ Error: Pattern 'src/**/*.xyz' matched 0 files
  ✓ Extracted 5 files: configs/** → configs/
Completed with errors: 1 failed, 2 succeeded
```

---

## Validation Rules

### Input Validation (Before Execution)

1. **Mode selection**:
   - `--all` → Mode 3 (no other args allowed)
   - `--name` + no positional args → Mode 2
   - `--name` + positional args → Mode 1
   - Missing both --all and --name → error

2. **Subtree validation**:
   - Name exists in config (case-insensitive)
   - Prefix directory exists on filesystem

3. **Pattern validation**:
   - SOURCE_PATTERN is non-empty
   - Valid glob syntax (no unclosed brackets, valid escaping)
   - --exclude patterns are valid glob syntax

4. **Path validation**:
   - DESTINATION is non-empty
   - Relative path (no leading `/`)
   - No `..` components (path traversal prevention)
   - Within repository boundaries

### Runtime Validation (During Execution)

1. **Match validation**:
   - Pattern matches at least 1 file (before exclusions)
   - At least 1 file remains after applying exclusions
   - Both conditions must hold (zero files → exit 1)

2. **Overwrite validation**:
   - Check git status for each destination file
   - If tracked and no --force → error (exit 2)
   - If untracked or --force → proceed

3. **Filesystem validation**:
   - Destination directory writable
   - Sufficient disk space
   - No name collisions (multiple sources → same dest filename)

---

## Behavioral Guarantees

### 1. Directory Structure Preservation

**Rule**: Preserve structure relative to glob match base

**Example**:
```
Pattern: "docs/**/*.md"
Match base: docs/

Subtree structure:
  vendor/my-lib/docs/guide/intro.md
  vendor/my-lib/docs/api/reference.md

Extracted structure:
  project-docs/guide/intro.md    # Relative to 'docs/'
  project-docs/api/reference.md
```

### 2. Execution Order (Bulk Operations)

**Rule**: Mappings execute in array order (as defined in subtree.yaml)

**Guarantee**: Deterministic execution order enables intentional overwrites

**Example**:
```yaml
extractions:
  - from: "templates/**"
    to: ".templates/"
  - from: "templates/custom.txt"  # Runs second, can override
    to: ".templates/"
```

### 3. Atomicity

**Config updates**: Atomic (temp file + rename pattern)

**File copying**: NOT atomic
- Partial state possible if interrupted (some files copied, some not)
- User must re-run extraction to complete
- No rollback mechanism

### 4. Overwrite Protection

**Default**: Git-tracked files protected, untracked files overwritten

**With --force**: All files overwritten

**Guarantee**: No accidental overwrite of committed work without explicit --force

### 5. Pattern Scoping

**Rule**: Glob patterns scoped to subtree's prefix directory only

**Guarantee**: Cannot extract files outside subtree boundaries

**Example**:
```
Subtree prefix: vendor/my-lib/
Pattern: "**/*.md"
Scope: vendor/my-lib/**/*.md (automatically scoped)
Cannot match: vendor/other-lib/**/*.md (outside prefix)
```

### 6. Symlink Handling

**Rule**: Follow symlinks, copy target file content

**Guarantee**: Extracted files are self-contained (no broken links)

**Behavior**: If symlink points to file, copy file content (not symlink itself)

---

## Error Recovery

### Recoverable Errors

1. **Zero matches**: User fixes pattern, re-runs command
2. **Overwrite protection**: User adds --force or stages files
3. **Permission denied**: User fixes permissions, re-runs

### Non-Recoverable Errors

1. **Disk full**: User frees space, re-runs (partial state possible)
2. **Interrupted copy**: User re-runs extraction (idempotent for untracked files)

### Bulk Execution Error Handling

**Behavior**: Continue on error, report all failures at end

**Rationale**: Maximize useful work completion (get all successful extractions)

**Exit code**: Highest severity encountered (enables scripting)

---

## Testing Contract

### Unit Test Coverage

1. **Mode selection**: Validate correct mode based on flags/args
2. **Pattern parsing**: Valid and invalid glob syntax
3. **Path validation**: Relative, absolute, traversal attempts
4. **Git status**: Tracked, untracked, non-existent files
5. **Exclusion logic**: Include + exclude combinations

### Integration Test Coverage

1. **Mode 1 (ad-hoc)**: Extract with various patterns, verify results
2. **Mode 2 (saved)**: Execute saved mappings, verify all run
3. **Mode 3 (bulk)**: Execute across multiple subtrees
4. **Persistence**: Save with --persist, verify config updated
5. **Overwrite protection**: Test blocked/allowed scenarios
6. **Error handling**: Test all validation errors, verify exit codes
7. **Bulk failures**: Test failure collection and reporting

---

## Summary

**Three modes of operation**:
1. Ad-hoc extraction with SOURCE_PATTERN + DESTINATION
2. Execute saved mappings for specific subtree (--name only)
3. Execute all saved mappings across all subtrees (--all)

**Key flags**:
- `--name`: Specify subtree (required for Mode 1 & 2)
- `--all`: Execute all mappings (Mode 3)
- `--exclude`: Filter matched files (repeatable, Mode 1 only)
- `--persist`: Save mapping to config (Mode 1 only)
- `--force`: Override git-tracked file protection (all modes)

**Exit codes**: 0 (success), 1 (validation), 2 (protection), 3 (I/O)

**Guarantees**:
- Structure preservation (relative to glob match)
- Overwrite protection (git-tracked files safe by default)
- Pattern scoping (limited to subtree prefix)
- Symlinks followed (copy target content)
- Atomic config updates (but not file copying)
