# CLI Contract: Update Command

**Feature**: 005-update-command | **Date**: 2025-10-28  
**Purpose**: Define CLI interface contract for subtree update operations

## Command Syntax

### Base Command

```bash
subtree update [OPTIONS] [NAME]
```

**Description**: Updates one or all subtrees to their latest versions

**Arguments**:
- `NAME` (optional) - Name of specific subtree to update. Mutually exclusive with `--all`.

**Options**:
- `--all` - Update all configured subtrees
- `--report` - Check for updates without applying (read-only mode)
- `--no-squash` - Preserve full upstream history instead of squashing
- `--help`, `-h` - Show command help

**Mutual Exclusions**:
- Cannot specify both `NAME` and `--all`
- `--no-squash` only valid without `--report` (report mode doesn't modify repository)

---

## Usage Examples

### Single Subtree Update

```bash
# Update specific subtree (default squash)
subtree update vendor-lib

# Update with full history preservation
subtree update vendor-lib --no-squash
```

**Expected Behavior**:
- Fetches latest commit for subtree's configured ref
- Updates subtree directory with new content
- Updates subtree.yaml with new commit hash
- Creates single atomic commit

### Bulk Update

```bash
# Update all subtrees
subtree update --all

# Update all with full history
subtree update --all --no-squash
```

**Expected Behavior**:
- Processes each subtree sequentially
- Continues on error (doesn't abort)
- Shows progress for each subtree
- Displays summary at end

### Report Mode (CI/CD)

```bash
# Check if specific subtree has updates
subtree update vendor-lib --report

# Check all subtrees for updates
subtree update --all --report
```

**Expected Behavior**:
- No repository modifications
- Shows current vs. available commits
- Shows commits behind and time delta
- Exits with code 5 if updates available

---

## Output Formats

### Successful Single Update

```
🔄 Updating subtree vendor-lib...
✅ Updated vendor-lib (abc1234 → def4567)
   - 5 commits behind (2 weeks old)
   - Updated in: Vendor/lib
```

### Already Up-to-Date

```
✅ vendor-lib is already up to date
```

### Batch Update Summary

```
🔄 Updating 3 subtrees...

✅ vendor-lib updated (abc1234 → def4567)
✅ tools already up to date
❌ dep failed: network error

Summary:
  Updated: 1
  Skipped: 1
  Failed: 1
```

### Report Mode Output

```
📊 Update Report:

vendor-lib: abc1234 → def4567 (5 commits behind, 2 weeks old)
tools: Up to date
dep: ccc9999 → ddd8888 (12 commits behind, 1 month old)

Summary: 2 updates available
```

### Error Messages

```
❌ Configuration file not found. Run 'subtree init' first
❌ Subtree 'mylib' not found in configuration
❌ Working tree has uncommitted changes. Commit or stash before updating
❌ Failed to connect to remote: network unreachable
❌ Merge conflict detected. Resolve conflicts and commit manually
```

---

## Exit Codes

| Code | Meaning | Scenario |
|------|---------|----------|
| 0 | Success | Update completed or report shows all up-to-date |
| 1 | Failure | Git operation failed, validation error, or conflicts |
| 2 | Invalid Input | Subtree name not found, invalid arguments |
| 3 | Missing Config | No subtree.yaml file |
| 5 | Updates Available | Report mode detected available updates |

**Batch Update Exit Codes**:
- Exit 0: All subtrees updated or skipped (no failures)
- Exit 1: One or more subtrees failed (continues processing all)

---

## Help Output

### Main Command Help

```bash
$ subtree update --help
```

```
Update subtrees to their latest versions

USAGE:
  subtree update [OPTIONS] [NAME]

ARGUMENTS:
  NAME    Name of specific subtree to update

OPTIONS:
  --all           Update all configured subtrees
  --report        Check for updates without applying
  --no-squash     Preserve full upstream history
  -h, --help      Show help information

EXAMPLES:
  # Update specific subtree
  subtree update vendor-lib

  # Update all subtrees
  subtree update --all

  # Check for updates (CI mode)
  subtree update --all --report

  # Update with full history
  subtree update vendor-lib --no-squash

For more information, run: subtree --help
```

---

## Validation Rules

### Pre-Command Validation

Performed before any git operations:

1. **Arguments**: Exactly one of NAME or --all required
2. **Config Exists**: subtree.yaml must exist (exit 3 if missing)
3. **Subtree Valid**: NAME must exist in config (exit 2 if not found)
4. **Git Repository**: Must be inside valid git repo (exit 1 if not)
5. **Clean Tree**: No uncommitted changes unless --report (exit 1 if dirty)

### Report Mode Specific

1. **Read-Only**: No git modifications allowed
2. **Network Access**: Can fail gracefully if remote unreachable
3. **No Working Tree Check**: --report doesn't require clean tree

### Update Mode Specific

1. **Clean Required**: Working tree must be clean
2. **Prefix Exists**: Subtree directory must exist before update
3. **Atomic Commit**: Single commit must contain subtree + config changes

---

## Behavioral Contracts

### Atomicity Guarantee

**Contract**: Each update operation produces exactly one commit containing both subtree changes and config update.

**Verification**:
```bash
# After update, check last commit
git show --stat HEAD

# Should show:
# - Files in subtree prefix (subtree content)
# - subtree.yaml (config update)
```

**Failure Mode**: If git subtree fails mid-operation, no config update occurs (no orphaned state).

---

### Report Mode Read-Only Guarantee

**Contract**: Report mode makes zero modifications to local repository.

**Verification**:
```bash
# Before report
git status
git log -1 --format=%H

# Run report
subtree update --all --report

# After report (should be identical)
git status  # No changes
git log -1 --format=%H  # Same commit hash
```

**Implementation**: Uses `git ls-remote` only, never `git fetch` or working tree operations.

---

### Batch Update Continue-on-Error

**Contract**: When using --all, failures on individual subtrees don't stop processing of remaining subtrees.

**Verification**:
```bash
# With 3 subtrees where middle one fails
subtree update --all

# Should see:
# ✅ subtree1 updated
# ❌ subtree2 failed: error message
# ✅ subtree3 updated  # Proves continuation
```

**Exit Code**: Returns 1 if any failures, even if some succeeded.

---

## Performance Contracts

### Report Mode Speed

**Contract**: Report mode completes in <5 seconds for repositories with up to 20 subtrees.

**Measurement**:
```bash
time subtree update --all --report
# Should complete in <5s with 20 subtrees
```

**Implementation**: Parallel `git ls-remote` calls (where possible), no full fetches.

---

### Update Mode Speed

**Contract**: Single subtree update completes in <10 seconds for typical repositories (<1000 commits delta).

**Measurement**:
```bash
time subtree update vendor-lib
# Should complete in <10s for reasonable update sizes
```

**Note**: Large updates (1000+ commits) may exceed this target.

---

## Backward Compatibility

### Version Constraints

- **Minimum Git**: 2.30+ (for modern git subtree support)
- **Minimum Swift**: 6.1 (language requirement)
- **Platform**: macOS 13+, Ubuntu 20.04 LTS

### Config Format

- Must read subtree.yaml written by Init (003) and Add (004)
- Must preserve all fields when updating commit hashes
- Must maintain YAML formatting and comments

### CLI Stability

- Subcommand name (`update`) is stable
- Flag names (`--all`, `--report`, `--no-squash`) are stable
- Exit codes follow established convention
- Output format may evolve (scripts should parse exit codes, not output text)

---

## Error Recovery

### Merge Conflicts

**Contract**: On conflict, leave repository in conflicted state with clear instructions.

**Output**:
```
❌ Merge conflict detected in vendor-lib

To resolve:
  1. Review conflicts in: Vendor/lib/
  2. Resolve conflicts manually
  3. Run: git add <resolved-files>
  4. Run: git commit
  5. Update subtree.yaml with new commit hash
```

**Exit Code**: 1

---

### Network Failures

**Contract**: On network error, fail immediately with clear message (no retries).

**Output**:
```
❌ Failed to update vendor-lib: network unreachable
   Remote: https://github.com/example/lib.git
   
Retry by running: subtree update vendor-lib
```

**Exit Code**: 1

---

## Future Contract Extensions

**Deferred to Backlog** (not in current contract):

1. `--dry-run` flag - Simulate update without committing
2. `--retry N` flag - Automatic retry with exponential backoff
3. `--branch NAME` flag - Create topic branch for update (PR workflow)
4. `--interactive` flag - Prompt before each update in batch mode

Current contract is stable for MVP implementation.
