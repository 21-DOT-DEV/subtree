# Quickstart: Extract Clean Mode

**Feature**: 010-extract-clean  
**Date**: 2025-11-29

## Prerequisites

1. Git repository with subtree.yaml initialized
2. At least one subtree added via `subtree add`
3. Files previously extracted via `subtree extract`

## Basic Usage

### Ad-hoc Clean (Single Pattern)

Remove previously extracted documentation files:

```bash
# Clean markdown files from docs subtree
subtree extract --clean --name docs --from "**/*.md" --to project-docs/
```

### Ad-hoc Clean (Multiple Patterns)

Remove files matching multiple patterns:

```bash
# Clean headers AND source files
subtree extract --clean --name mylib \
  --from "include/**/*.h" \
  --from "src/**/*.c" \
  --to vendor/
```

### With Exclusions

Skip certain files:

```bash
# Clean C files except tests
subtree extract --clean --name lib \
  --from "src/**/*.c" \
  --to Sources/ \
  --exclude "**/test_*.c"
```

### Bulk Clean (One Subtree)

Clean all persisted mappings for a subtree:

```bash
subtree extract --clean --name mylib
```

### Bulk Clean (All Subtrees)

Clean all mappings across all subtrees:

```bash
subtree extract --clean --all
```

## Common Workflows

### Workflow 1: Re-extract with Different Patterns

```bash
# 1. Clean old extraction
subtree extract --clean --name lib --from "src/**/*.c" --to Sources/

# 2. Re-extract with new pattern
subtree extract --name lib --from "src/**/*.cpp" --to Sources/ --persist
```

### Workflow 2: Clean After Subtree Removal

```bash
# 1. Remove the subtree
subtree remove --name deprecated-lib

# 2. Clean extracted files (need --force since subtree is gone)
subtree extract --clean --force --name deprecated-lib
```

### Workflow 3: Verify Before Cleaning

```bash
# See what extraction mapping exists
cat subtree.yaml | grep -A5 "extractions:"

# Clean with same patterns
subtree extract --clean --name mylib --from "docs/**/*.md" --to Documentation/
```

## Handling Errors

### Modified File Detection

```bash
$ subtree extract --clean --name lib --from "*.c" --to src/
❌ Error: File 'src/main.c' has been modified

   Source hash:  a1b2c3d4e5f6...
   Dest hash:    f6e5d4c3b2a1...

# Option 1: Restore original file, then clean
git checkout src/main.c
subtree extract --clean --name lib --from "*.c" --to src/

# Option 2: Force delete (loses your changes!)
subtree extract --clean --force --name lib --from "*.c" --to src/
```

### Missing Source Files

```bash
$ subtree extract --clean --name lib --from "*.c" --to src/
⚠️  Skipping 'src/deleted.c': source file not found in subtree
✅ Cleaned 4 file(s)

# To also delete orphaned files:
subtree extract --clean --force --name lib --from "*.c" --to src/
```

## Validation Commands

### Verify Clean Mode Works

```bash
# Build and test
swift build
swift test --filter ExtractClean

# Run clean help
.build/debug/subtree extract --help | grep -A2 "\-\-clean"
```

### Test Checksum Validation

```bash
# Setup test
subtree extract --name test-lib --from "*.txt" --to test-dest/

# Modify a file
echo "modified" >> test-dest/file.txt

# Verify clean detects modification
subtree extract --clean --name test-lib --from "*.txt" --to test-dest/
# Should fail with checksum mismatch error
```

### Test Directory Pruning

```bash
# Extract nested files
subtree extract --name lib --from "a/b/c/*.txt" --to deep/path/

# Clean and verify pruning
subtree extract --clean --name lib --from "a/b/c/*.txt" --to deep/path/
ls -la deep/  # Should show empty directories removed
```

## Exit Code Reference

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Files cleaned (or zero matched) |
| 1 | Validation error | Check subtree name, patterns, checksum |
| 2 | User error | Fix flag combination |
| 3 | I/O error | Check permissions, disk space |

## Tips

1. **Always extract first**: Clean mode finds files in destination that match source patterns
2. **Check your patterns**: Use same patterns you used for extraction
3. **Backup modified files**: `--force` permanently deletes modified files
4. **Empty directories**: Automatically pruned up to (not including) destination root
5. **Bulk mode is safer**: Uses persisted mappings, less chance of pattern typos
