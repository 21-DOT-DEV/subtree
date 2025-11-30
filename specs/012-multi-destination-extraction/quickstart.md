# Quickstart: Multi-Destination Extraction (Fan-Out)

**Feature**: 012-multi-destination-extraction  
**Date**: 2025-11-30

## Build & Test

```bash
# Build
swift build

# Run all tests
swift test

# Run specific test file (once created)
swift test --filter ExtractMultiDestTests
```

## Manual Verification

### Setup Test Environment

```bash
# Create test repository
cd /tmp && rm -rf test-multi-dest && mkdir test-multi-dest && cd test-multi-dest
git init

# Initialize subtree config
.build/debug/subtree init

# Create mock subtree structure
mkdir -p vendor/mylib/include vendor/mylib/src
echo "// header.h" > vendor/mylib/include/header.h
echo "// source.c" > vendor/mylib/src/source.c
git add . && git commit -m "Setup"

# Add subtree entry manually (or use subtree add)
cat >> subtree.yaml << 'EOF'
subtrees:
  - name: mylib
    remote: https://example.com/mylib.git
    prefix: vendor/mylib
    ref: main
EOF
git add subtree.yaml && git commit -m "Add mylib config"
```

### Test Multi-Destination Extraction

```bash
# Basic fan-out to two destinations
.build/debug/subtree extract --name mylib --from "**/*" --to Lib/ --to Vendor/

# Expected output:
# ✅ Extracted 2 file(s) to 'Lib/'
# ✅ Extracted 2 file(s) to 'Vendor/'

# Verify files exist in both locations
ls -la Lib/include/ Lib/src/
ls -la Vendor/include/ Vendor/src/
```

### Test Path Normalization / Deduplication

```bash
# These should deduplicate to single destination
.build/debug/subtree extract --name mylib --from "**/*" --to Lib/ --to ./Lib --to Lib

# Expected: Only one "Extracted" line for Lib/
```

### Test Persist with Array

```bash
# Save multi-destination mapping
.build/debug/subtree extract --name mylib --from "**/*.h" --to Headers/ --to Backup/ --persist

# Verify YAML has array format
cat subtree.yaml | grep -A5 "extractions"
# Should show: to: ["Headers/", "Backup/"]
```

### Test Fail-Fast Protection

```bash
# Create conflict
mkdir -p Conflict/include
echo "tracked file" > Conflict/include/header.h
git add Conflict/ && git commit -m "Add tracked conflict"

# This should fail before any writes
.build/debug/subtree extract --name mylib --from "**/*.h" --to Clean/ --to Conflict/

# Expected: Error listing conflicts, no files in Clean/
ls Clean/  # Should be empty or not exist
```

### Test Clean Mode

```bash
# Extract first
.build/debug/subtree extract --name mylib --from "**/*" --to ToClean1/ --to ToClean2/

# Clean all destinations
.build/debug/subtree extract --clean --name mylib --from "**/*" --to ToClean1/ --to ToClean2/

# Expected output:
# ✅ Cleaned 2 file(s) from 'ToClean1/'
# ✅ Cleaned 2 file(s) from 'ToClean2/'
```

### Test Soft Limit Warning

```bash
# Create many destinations (>10)
.build/debug/subtree extract --name mylib --from "**/*.h" \
  --to D1/ --to D2/ --to D3/ --to D4/ --to D5/ \
  --to D6/ --to D7/ --to D8/ --to D9/ --to D10/ \
  --to D11/

# Expected: Warning about >10 destinations, then success
```

## Test Coverage Checklist

| Test | Command | Expected |
|------|---------|----------|
| Basic fan-out | `--to A/ --to B/` | Files in both |
| Deduplication | `--to A/ --to ./A` | Single copy |
| Persist array | `--persist` | YAML array |
| Fail-fast | Tracked conflict | Error, no partial |
| Clean multi-dest | `--clean --to A/ --to B/` | Both cleaned |
| Soft limit | `>10 --to` flags | Warning |
| Backward compat | Single `--to` | Works unchanged |

## CI Validation

```bash
# Run full test suite
swift test 2>&1 | tail -20

# Check exit code
echo "Exit code: $?"
```
