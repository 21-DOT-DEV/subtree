# CLI Contract: Multi-Pattern Extraction

**Feature**: 009-multi-pattern-extraction  
**Date**: 2025-11-28

## Command Signature

### Current (Single Pattern)
```
subtree extract --name <name> --from <pattern> --to <destination> [--exclude <pattern>]... [--persist] [--force]
```

### Extended (Multiple Patterns)
```
subtree extract --name <name> --from <pattern>... --to <destination> [--exclude <pattern>]... [--persist] [--force]
```

**Change**: `--from` becomes repeatable (array option).

## Options

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `--name` | String | Yes (ad-hoc) | Subtree name |
| `--from` | [String] | Yes (ad-hoc) | Glob pattern(s) — can be repeated |
| `--to` | String | Yes (ad-hoc) | Destination directory |
| `--exclude` | [String] | No | Exclude pattern(s) — applies to ALL --from patterns |
| `--persist` | Flag | No | Save mapping to config |
| `--force` | Flag | No | Override git-tracked file protection |
| `--all` | Flag | No | Execute all persisted mappings |

## Examples

### Single Pattern (Unchanged)
```bash
subtree extract --name secp256k1-zkp --from 'include/**/*.h' --to 'vendor/headers/'
```

### Multiple Patterns (New)
```bash
subtree extract --name secp256k1-zkp \
  --from 'include/**/*.h' \
  --from 'src/**/*.c' \
  --to 'vendor/source/'
```

### With Exclude (Global)
```bash
subtree extract --name secp256k1-zkp \
  --from 'include/**/*.h' \
  --from 'src/**/*.c' \
  --exclude '**/test_*' \
  --to 'vendor/source/'
```

### Persist Multi-Pattern
```bash
subtree extract --name secp256k1-zkp \
  --from 'include/**/*.h' \
  --from 'src/**/*.c' \
  --to 'vendor/source/' \
  --persist
```

## Exit Codes

| Code | Meaning | When |
|------|---------|------|
| 0 | Success | Files extracted (even with zero-match warnings) |
| 1 | User Error | Invalid pattern, all patterns match nothing |
| 2 | System Error | I/O failure, git operation failed |
| 3 | Config Error | Invalid config, missing subtree |

## Output Format

### Success (Multiple Patterns)
```
✅ Extracted 15 files from secp256k1-zkp to vendor/source/
   - include/**/*.h: 8 files
   - src/**/*.c: 7 files
```

### Success with Warning
```
⚠️ Pattern 'docs/**/*.md' matched no files
✅ Extracted 15 files from secp256k1-zkp to vendor/source/
   - include/**/*.h: 8 files
   - src/**/*.c: 7 files
```

### Error (All Patterns Empty)
```
❌ No files matched any pattern
   - include/**/*.h: 0 files
   - src/**/*.c: 0 files
```

## Backward Compatibility

| Scenario | Before | After | Behavior |
|----------|--------|-------|----------|
| Single `--from` | ✅ Works | ✅ Works | Identical |
| Config `from: "pattern"` | ✅ Works | ✅ Works | Identical |
| Config `from: [...]` | ❌ Invalid | ✅ Works | New feature |
| Multiple `--from` | ❌ Last wins | ✅ Union | New feature |
