# CLI Contract: Extract Clean Mode

**Feature**: 010-extract-clean  
**Date**: 2025-11-29

## Command Interface

### Synopsis

```
subtree extract --clean [OPTIONS]
```

### Options

| Flag | Type | Required | Description |
|------|------|----------|-------------|
| `--clean` | Flag | Yes (for clean mode) | Trigger removal mode instead of extraction |
| `--name <name>` | String | Conditional | Subtree name (required for ad-hoc, optional with `--all`) |
| `--from <pattern>` | String[] | Conditional | Glob pattern(s) to match files (ad-hoc mode) |
| `--to <path>` | String | Conditional | Destination directory (ad-hoc mode) |
| `--exclude <pattern>` | String[] | Optional | Glob pattern(s) to exclude from matching |
| `--force` | Flag | Optional | Override checksum validation and prefix check |
| `--all` | Flag | Optional | Clean all mappings for all subtrees |

### Mode Determination

| Flags Present | Mode | Behavior |
|---------------|------|----------|
| `--clean --name --from --to` | Ad-hoc | Clean specific files matching patterns |
| `--clean --name` (no --from/--to) | Bulk single | Clean all persisted mappings for subtree |
| `--clean --all` | Bulk all | Clean all persisted mappings for all subtrees |

### Invalid Combinations

| Combination | Exit Code | Error Message |
|-------------|-----------|---------------|
| `--clean --persist` | 2 | "❌ Error: --clean and --persist cannot be used together" |
| `--clean --all --from` | 1 | "❌ Error: --all flag cannot be used with pattern arguments" |
| `--clean` (no --name, no --all) | 1 | "❌ Error: Must specify either --name or --all for clean" |

## Exit Codes

| Code | Category | Conditions |
|------|----------|------------|
| 0 | Success | Files cleaned successfully, or zero files matched |
| 1 | Validation Error | Subtree not found, checksum mismatch, invalid pattern |
| 2 | User Error | Invalid flag combination (`--clean --persist`) |
| 3 | I/O Error | Permission denied, filesystem error |

## Output Format

### Success (Ad-hoc)

```
✅ Cleaned 5 file(s) from 'my-lib' destination 'Sources/'
   📁 Pruned 2 empty directory/directories
```

### Success (Bulk)

```
Processing subtree 'my-lib' (2 mappings)...
  ✅ [1/2] src/**/*.c → Sources/ (10 files)
  ✅ [2/2] include/**/*.h → Headers/ (3 files)

Processing subtree 'other-lib' (1 mapping)...
  ✅ [1/1] docs/**/*.md → Documentation/ (5 files)

📊 Summary: 3 executed, 3 succeeded, 0 failed
```

### Error: Checksum Mismatch

```
❌ Error: File 'Sources/main.c' has been modified

   Source hash:  a1b2c3d4...
   Dest hash:    e5f6g7h8...

Suggestion: Use --force to delete modified files, or restore original content.
```

### Error: Source Missing

```
⚠️  Skipping 'Sources/removed.c': source file not found in subtree

Suggestion: Use --force to delete orphaned files.
```

### Bulk Mode Failure Summary

```
📊 Summary: 3 executed, 2 succeeded, 1 failed

❌ Failures:
  • my-lib [mapping 2]: File 'Headers/api.h' has been modified
```

## Behavioral Contracts

### BC-001: Checksum Validation

**Given** a file exists at destination  
**And** the corresponding source file exists in subtree  
**When** clean runs without `--force`  
**Then** system MUST compare `git hash-object` of both files  
**And** delete only if hashes match

### BC-002: Fail Fast on Mismatch

**Given** checksum validation fails for any file  
**When** clean runs without `--force`  
**Then** system MUST abort immediately  
**And** NOT delete any files (even those already validated)  
**And** exit with code 1

### BC-003: Force Override

**Given** `--force` flag is provided  
**When** clean runs  
**Then** system MUST skip checksum validation  
**And** delete all matching files regardless of modification status  
**And** delete files even if source is missing

### BC-004: Directory Pruning

**Given** files are successfully deleted  
**When** clean completes  
**Then** system MUST remove empty directories  
**And** prune bottom-up (deepest first)  
**And** stop at destination root (never delete `--to` directory)

### BC-005: Missing Source Handling

**Given** destination file exists but source file is missing  
**When** clean runs without `--force`  
**Then** system MUST skip the file with warning  
**And** continue to next file  
**And** NOT count as failure (exit 0 if all other files succeed)

### BC-006: Bulk Mode Continue-on-Error

**Given** multiple mappings to clean  
**When** one mapping fails (checksum mismatch)  
**Then** system MUST continue to next mapping  
**And** collect all failures  
**And** report summary at end  
**And** exit with highest severity code

### BC-007: Zero Files Matched

**Given** pattern matches zero files in destination  
**When** clean runs  
**Then** system MUST succeed (exit 0)  
**And** print message indicating zero files cleaned

### BC-008: Symlink Handling

**Given** destination file is a symlink  
**When** clean runs  
**Then** system MUST follow the symlink  
**And** delete the target file (not just the link)

### BC-009: Prefix Validation with Force

**Given** subtree directory (prefix) does not exist  
**When** clean runs with `--force`  
**Then** system MUST proceed without error  
**And** delete matching destination files without checksum validation

**When** clean runs without `--force`  
**Then** system MUST fail with error indicating prefix not found
