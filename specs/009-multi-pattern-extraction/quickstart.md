# Quickstart: Multi-Pattern Extraction

**Feature**: 009-multi-pattern-extraction  
**Date**: 2025-11-28

## Prerequisites

- Subtree CLI built and in PATH
- A git repository with at least one configured subtree
- Subtree contains files in multiple directories (for testing)

## Validation Steps

### Step 1: Verify Single Pattern Still Works

```bash
# Setup: Create test subtree with known files
cd /tmp && mkdir -p test-repo && cd test-repo
git init
subtree init

# Add a test subtree (use any public repo with multiple dirs)
subtree add --remote https://github.com/bitcoin-core/secp256k1.git --name secp256k1

# Test single pattern (should work exactly as before)
subtree extract --name secp256k1 --from 'include/**/*.h' --to 'vendor/headers/'

# Verify: Check files extracted
ls vendor/headers/
```

**Expected**: Files extracted, command succeeds.

---

### Step 2: Test Multiple Patterns CLI

```bash
# Test multiple --from flags
subtree extract --name secp256k1 \
  --from 'include/**/*.h' \
  --from 'src/**/*.c' \
  --to 'vendor/multi/'

# Verify: Check files from BOTH patterns
ls vendor/multi/
find vendor/multi/ -name "*.h" | wc -l  # Should have .h files
find vendor/multi/ -name "*.c" | wc -l  # Should have .c files
```

**Expected**: Files from both patterns extracted to same destination.

---

### Step 3: Test Backward Compatible YAML

```bash
# Create config with legacy format
cat >> subtree.yaml << 'EOF'
# Under secp256k1 subtree entry:
# extractions:
#   - from: "include/**/*.h"
#     to: "legacy-test/"
EOF

# Run bulk extraction
subtree extract --name secp256k1

# Verify: Legacy format still works
ls legacy-test/
```

**Expected**: Legacy string format parsed and executed correctly.

---

### Step 4: Test Array YAML Format

```bash
# Manually edit subtree.yaml to add array format:
# extractions:
#   - from:
#       - "include/**/*.h"
#       - "src/secp256k1.c"
#     to: "array-test/"

# Run bulk extraction
subtree extract --name secp256k1

# Verify: Array format works
ls array-test/
```

**Expected**: Array format parsed and all patterns processed.

---

### Step 5: Test Persist with Multiple Patterns

```bash
# Persist a multi-pattern extraction
subtree extract --name secp256k1 \
  --from 'include/**/*.h' \
  --from 'src/**/*.c' \
  --to 'persist-test/' \
  --persist

# Verify: Check subtree.yaml for array format
grep -A 5 "persist-test" subtree.yaml

# Should show:
# - from:
#     - "include/**/*.h"
#     - "src/**/*.c"
#   to: "persist-test/"
```

**Expected**: Patterns stored as array in single mapping entry.

---

### Step 6: Test Zero-Match Warning

```bash
# Use a pattern that won't match anything
subtree extract --name secp256k1 \
  --from 'include/**/*.h' \
  --from 'nonexistent/**/*.xyz' \
  --to 'warning-test/'

# Should show:
# ⚠️ Pattern 'nonexistent/**/*.xyz' matched no files
# ✅ Extracted N files...
```

**Expected**: Warning displayed, extraction succeeds, exit code 0.

---

### Step 7: Test All Patterns Empty

```bash
# All patterns match nothing
subtree extract --name secp256k1 \
  --from 'fake/**/*.nothing' \
  --from 'also-fake/**/*.nope' \
  --to 'should-fail/'

echo "Exit code: $?"
```

**Expected**: Error message, exit code 1, no files created.

---

## Cleanup

```bash
cd /tmp && rm -rf test-repo
```

## Success Criteria Validation

| Criterion | How to Verify | Pass? |
|-----------|---------------|-------|
| SC-001: 3+ directories in one command | Step 2 with 3 patterns | ⬜ |
| SC-002: Backward compatible | Steps 1, 3 | ⬜ |
| SC-003: <5 seconds | Time steps 2, 5 | ⬜ |
| SC-004: Zero-match warnings clear | Step 6 | ⬜ |
| SC-005: Union with no duplicates | Step 2, check for dups | ⬜ |
