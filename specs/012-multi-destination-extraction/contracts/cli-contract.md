# CLI Contract: Multi-Destination Extraction

**Feature**: 012-multi-destination-extraction  
**Date**: 2025-11-30

## Command Changes

### `subtree extract` (Modified)

**Current `--to` option**:
```
--to <path>    Destination path (single)
```

**New `--to` option**:
```
--to <path>    Destination path (can be repeated for fan-out)
```

## Usage Examples

### Ad-Hoc Multi-Destination Extraction
```bash
# Extract to two destinations
subtree extract --name mylib --from "**/*.h" --to Lib/ --to Vendor/

# Combined with multi-pattern (from 009)
subtree extract --name mylib \
  --from "include/**/*.h" \
  --from "src/**/*.c" \
  --to Lib/ \
  --to Vendor/
```

### Persist Multi-Destination Mapping
```bash
# Save mapping with multiple destinations
subtree extract --name mylib --from "**/*.h" --to Lib/ --to Vendor/ --persist
```

### Clean Multi-Destination
```bash
# Ad-hoc clean from multiple destinations
subtree extract --clean --name mylib --from "**/*.h" --to Lib/ --to Vendor/

# Bulk clean (uses persisted mappings)
subtree extract --clean --name mylib
subtree extract --clean --all
```

## Output Format

### Extraction Success (Per-Destination)
```
✅ Extracted 5 file(s) to 'Lib/'
✅ Extracted 5 file(s) to 'Vendor/'
```

### With Persist
```
✅ Extracted 5 file(s) to 'Lib/'
✅ Extracted 5 file(s) to 'Vendor/'
📝 Saved extraction mapping to subtree.yaml
```

### Soft Limit Warning (>10 destinations)
```
⚠️  Warning: 15 destinations specified (>10)
✅ Extracted 5 file(s) to 'Dest1/'
✅ Extracted 5 file(s) to 'Dest2/'
...
```

### Fail-Fast Error (Overwrite Protection)
```
❌ Error: Git-tracked files would be overwritten

Conflicts in 'Lib/':
  • include/foo.h

Conflicts in 'Vendor/':
  • include/foo.h
  • include/bar.h

Use --force to override protection.
```

### Clean Success (Per-Destination)
```
✅ Cleaned 5 file(s) from 'Lib/'
   📁 Pruned 2 empty directories
✅ Cleaned 5 file(s) from 'Vendor/'
   📁 Pruned 1 empty directory
```

## Exit Codes

| Code | Meaning | When |
|------|---------|------|
| 0 | Success | All destinations processed successfully |
| 1 | Validation error | Empty destinations, checksum mismatch |
| 2 | User error | Invalid flag combination, overwrite protection |
| 3 | I/O error | Permission denied, filesystem error |

## Flag Interactions

| Flags | Behavior |
|-------|----------|
| `--to X --to X` | Deduplicated to single destination |
| `--to ./Lib --to Lib/` | Deduplicated after normalization |
| `--to` × >10 | Warning printed, operation continues |
| `--to` + `--persist` | Saves array to config |
| `--to` + `--clean` | Cleans all specified destinations |
| `--to` + `--force` | Bypasses protection for all destinations |

## Backward Compatibility

- Single `--to` works unchanged
- Existing bulk mode (`--name` without `--to`) works unchanged
- Existing persisted mappings with string `to` work unchanged
