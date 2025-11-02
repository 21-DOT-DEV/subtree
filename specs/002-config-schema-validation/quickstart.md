# Quickstart: Subtree Configuration Schema & Validation

**Feature**: 002-config-schema-validation | **Date**: 2025-10-26

## Purpose

Quick reference for building, testing, and validating the subtree.yaml schema and validation implementation.

---

## Prerequisites

- Swift 6.1 toolchain installed
- macOS 13+ or Ubuntu 20.04 LTS
- Existing dependencies: Yams 6.1.0, swift-system 1.5.0

---

## Build

### Full Build

```bash
swift build
```

### Build Just the Library

```bash
swift build --target SubtreeLib
```

### Release Build

```bash
swift build -c release
```

---

## Test

### Run All Tests

```bash
swift test
```

### Run Only Configuration Tests

```bash
swift test --filter ConfigurationTests
```

### Run Specific Test Suite

```bash
# Schema validation tests
swift test --filter SchemaValidatorTests

# Type validation tests
swift test --filter TypeValidatorTests

# Format validation tests
swift test --filter FormatValidatorTests

# Logic validation tests
swift test --filter LogicValidatorTests

# Glob pattern tests
swift test --filter GlobPatternValidatorTests

# Parser tests
swift test --filter ConfigurationParserTests
```

### Run Integration Tests

```bash
swift test --filter ConfigValidationIntegrationTests
```

### Verbose Test Output

```bash
swift test --verbose
```

---

## Validation Checkpoints

### Checkpoint 1: Models Defined (Data Structures)

**Files Created**:
- `Sources/SubtreeLib/Configuration/Models/SubtreeConfiguration.swift`
- `Sources/SubtreeLib/Configuration/Models/SubtreeEntry.swift`
- `Sources/SubtreeLib/Configuration/Models/ExtractPattern.swift`

**Verification**:
```bash
# Should build without errors
swift build --target SubtreeLib

# Model tests should pass
swift test --filter SubtreeConfigurationTests
swift test --filter SubtreeEntryTests
swift test --filter ExtractPatternTests
```

**Expected Output**: 3 tests passing (one per model)

---

### Checkpoint 2: Parser Implemented

**Files Created**:
- `Sources/SubtreeLib/Configuration/Parsing/ConfigurationParser.swift`
- `Sources/SubtreeLib/Configuration/Parsing/YAMLErrorTranslator.swift`

**Verification**:
```bash
# Parser tests should pass
swift test --filter ConfigurationParserTests
swift test --filter YAMLErrorTranslatorTests
```

**Expected Output**: Multiple tests passing for:
- Valid YAML parsing
- Invalid YAML error translation
- Missing file handling
- Empty file handling

**Manual Test**:
```bash
# Create test config
cat > /tmp/test-config.yaml << 'EOF'
subtrees:
  - name: test
    remote: https://github.com/org/repo
    prefix: Vendors/test
    commit: 1234567890abcdef1234567890abcdef12345678
EOF

# Parse manually (if parser is exposed)
# Or use integration test harness
swift test --filter ConfigurationParserTests
```

---

### Checkpoint 3: Validators Implemented

**Files Created**:
- `Sources/SubtreeLib/Configuration/Validation/ConfigurationValidator.swift`
- `Sources/SubtreeLib/Configuration/Validation/SchemaValidator.swift`
- `Sources/SubtreeLib/Configuration/Validation/TypeValidator.swift`
- `Sources/SubtreeLib/Configuration/Validation/FormatValidator.swift`
- `Sources/SubtreeLib/Configuration/Validation/LogicValidator.swift`
- `Sources/SubtreeLib/Configuration/Validation/ValidationError.swift`

**Verification**:
```bash
# All validator tests should pass
swift test --filter SchemaValidatorTests
swift test --filter TypeValidatorTests
swift test --filter FormatValidatorTests
swift test --filter LogicValidatorTests
swift test --filter ValidationErrorTests
```

**Expected Output**: 31+ tests passing (one per FR minimum)

---

### Checkpoint 4: Glob Pattern Validation

**Files Created**:
- `Sources/SubtreeLib/Configuration/Patterns/GlobPatternValidator.swift`

**Verification**:
```bash
# Glob pattern tests should pass
swift test --filter GlobPatternValidatorTests
```

**Expected Output**: Tests passing for:
- Valid patterns (`**`, `*`, `?`, `[...]`, `{...}`)
- Invalid patterns (unclosed braces, unclosed brackets)
- Complex patterns with multiple features

**Manual Test Cases**:
```swift
// Valid patterns
"src/**/*.{h,c}"           // ✅
"include/[a-z]*.h"         // ✅
"src/**/test?.c"           // ✅

// Invalid patterns
"src/{a,b"                 // ❌ unclosed brace
"include/[a-z"             // ❌ unclosed bracket
```

---

### Checkpoint 5: Integration Tests Pass

**Files Created**:
- `Tests/IntegrationTests/ConfigValidationIntegrationTests.swift`

**Verification**:
```bash
# All integration tests should pass
swift test --filter ConfigValidationIntegrationTests
```

**Expected Scenarios Tested**:
- Valid configuration loads successfully
- Invalid configurations produce clear errors
- Multiple errors collected together
- Extract patterns validated correctly
- YAML syntax errors translated to user-friendly messages

---

### Final Checkpoint: Full Test Suite

**Verification**:
```bash
# All tests should pass
swift test

# Expect output like:
# Test Suite 'All tests' passed at 2025-10-26 12:00:00.000
#   Executed 40 tests, with 0 failures (0 unexpected) in 0.5 seconds
```

**Test Count Expectations**:
- Minimum 31 unit tests (one per FR)
- Additional tests for edge cases
- Integration tests for user scenarios
- Total: 40-50 tests

---

## Manual Validation

### Create Test Configurations

```bash
mkdir -p /tmp/subtree-config-tests
cd /tmp/subtree-config-tests
```

### Test 1: Valid Minimal Config

```bash
cat > valid-minimal.yaml << 'EOF'
subtrees:
  - name: minimal
    remote: https://github.com/org/repo
    prefix: Vendors/minimal
    commit: 1234567890abcdef1234567890abcdef12345678
EOF

# Validate (once validate command implemented)
subtree validate --config valid-minimal.yaml
# Expected: Success message
```

### Test 2: Valid Config with Extracts

```bash
cat > valid-extracts.yaml << 'EOF'
subtrees:
  - name: secp256k1
    remote: https://github.com/bitcoin-core/secp256k1
    prefix: Vendors/secp256k1
    commit: bf4f0bc877e4d6771e48611cc9e66ab9db576bac
    tag: v0.7.0
    squash: true
    extracts:
      - from: include/*.h
        to: Sources/libsecp256k1/include/
      - from: src/**/*.{h,c}
        to: Sources/libsecp256k1/src/
        exclude:
          - src/**/bench*/**
          - src/**/test*/**
EOF

# Validate
subtree validate --config valid-extracts.yaml
# Expected: Success message
```

### Test 3: Invalid - Missing Required Field

```bash
cat > invalid-missing-field.yaml << 'EOF'
subtrees:
  - name: incomplete
    remote: https://github.com/org/repo
    prefix: Vendors/incomplete
    # Missing: commit
EOF

# Validate
subtree validate --config invalid-missing-field.yaml
# Expected: Error pointing to missing commit field
```

### Test 4: Invalid - Wrong Commit Format

```bash
cat > invalid-commit.yaml << 'EOF'
subtrees:
  - name: bad-commit
    remote: https://github.com/org/repo
    prefix: Vendors/bad
    commit: short123
EOF

# Validate
subtree validate --config invalid-commit.yaml
# Expected: Error about commit format (expected 40 chars, got 8)
```

### Test 5: Invalid - Both Tag and Branch

```bash
cat > invalid-tag-branch.yaml << 'EOF'
subtrees:
  - name: conflict
    remote: https://github.com/org/repo
    prefix: Vendors/conflict
    commit: 1234567890abcdef1234567890abcdef12345678
    tag: v1.0.0
    branch: main
EOF

# Validate
subtree validate --config invalid-tag-branch.yaml
# Expected: Error about mutual exclusivity
```

### Test 6: Invalid - Duplicate Names

```bash
cat > invalid-duplicates.yaml << 'EOF'
subtrees:
  - name: lib
    remote: https://github.com/org/repo1
    prefix: Vendors/lib1
    commit: 1234567890abcdef1234567890abcdef12345678
  - name: lib
    remote: https://github.com/org/repo2
    prefix: Vendors/lib2
    commit: abcdef1234567890abcdef1234567890abcdef12
EOF

# Validate
subtree validate --config invalid-duplicates.yaml
# Expected: Error about duplicate name 'lib'
```

### Test 7: Invalid - Unsafe Path

```bash
cat > invalid-path.yaml << 'EOF'
subtrees:
  - name: unsafe
    remote: https://github.com/org/repo
    prefix: ../outside/repo
    commit: 1234567890abcdef1234567890abcdef12345678
EOF

# Validate
subtree validate --config invalid-path.yaml
# Expected: Error about unsafe path component '..'
```

### Test 8: Invalid - Malformed YAML

```bash
cat > invalid-yaml.yaml << 'EOF'
subtrees:
  - name: bad
    remote: "https://unclosed-quote.com
    prefix: Vendors/bad
    commit: 1234567890abcdef1234567890abcdef12345678
EOF

# Validate
subtree validate --config invalid-yaml.yaml
# Expected: User-friendly YAML syntax error
```

---

## Performance Benchmarks

### Validation Performance Test

```bash
# Create large config (100 subtrees)
cat > large-config.yaml << 'EOF'
subtrees:
EOF

for i in {1..100}; do
  cat >> large-config.yaml << EOF
  - name: lib$i
    remote: https://github.com/org/repo$i
    prefix: Vendors/lib$i
    commit: $(printf '%040d' $i | tr '0' 'a')
EOF
done

# Time validation
time subtree validate --config large-config.yaml
# Expected: <1 second (per SC-002)
```

---

## CI Validation

### Local CI Test (macOS)

```bash
# Full build and test
swift build -c release
swift test

# Verify all tests pass
echo "Exit code: $?"  # Should be 0
```

### Local CI Test (Ubuntu via Docker)

```bash
docker run -v $(pwd):/workspace -w /workspace swift:6.1 bash -c "swift build && swift test"
```

### GitHub Actions

CI will automatically run on push to branch. Check:
- macOS-15 platform tests
- Ubuntu 20.04 platform tests

---

## Success Criteria Verification

### SC-001: Users can create valid configs successfully

✅ **Verify**: Test cases 1 and 2 above parse without errors

### SC-002: Validation errors are clear and fast (<1 second)

✅ **Verify**: 
- Test cases 3-8 produce clear error messages
- Performance benchmark completes in <1 second

### SC-003: All 31 FRs have tests

✅ **Verify**: 
```bash
swift test --verbose | grep -c "Test.*passed"
# Expected: ≥31
```

### SC-004: YAML errors are user-friendly

✅ **Verify**: Test case 8 shows friendly message, not "Scanner error"

### SC-005: All constraint violations caught

✅ **Verify**: Test cases 3-8 catch all violations before git operations

### SC-006: Schema documentation has examples

✅ **Verify**: Check `contracts/yaml-schema.md` has examples for all field combinations

---

## Troubleshooting

### Build Errors

**Problem**: "No such module 'Yams'"

**Solution**: 
```bash
swift package update
swift build
```

### Test Failures

**Problem**: Parser tests fail

**Check**:
1. Yams dependency version (should be 6.1.0)
2. Test YAML syntax (use online validator)
3. Error translator mappings

**Problem**: Validator tests fail

**Check**:
1. Validation rules match FR specifications
2. Error messages include all required components
3. Format validators use correct regex/patterns

### Performance Issues

**Problem**: Validation takes >1 second

**Investigate**:
1. Enable profiling: `swift test --enable-code-coverage`
2. Check for unnecessary file I/O
3. Verify format-only validation (no git operations)

---

## Next Steps

After all checkpoints pass:

1. **Review**: Check code against data-model.md and contracts/
2. **Document**: Update .windsurf/rules with new Configuration/ module
3. **Integrate**: Commands can now use validated configs
4. **Merge**: Open PR with all tests passing

---

## References

- **Spec**: [spec.md](./spec.md)
- **Plan**: [plan.md](./plan.md)
- **Data Model**: [data-model.md](./data-model.md)
- **Contracts**: [contracts/yaml-schema.md](./contracts/yaml-schema.md)
- **Research**: [research.md](./research.md)
