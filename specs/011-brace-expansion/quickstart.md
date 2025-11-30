# Quickstart: Brace Expansion with Embedded Path Separators

**Feature**: 011-brace-expansion  
**Date**: 2025-11-29

## Prerequisites

- Swift 6.1 toolchain installed
- Repository cloned and on `011-brace-expansion` branch

## Build & Test

```bash
# Build the project
swift build

# Run all tests (should pass before starting implementation)
swift test

# Run only BraceExpander tests (after creating test file)
swift test --filter BraceExpanderTests
```

## Implementation Order

### Phase 1: BraceExpander Utility (TDD)

1. **Create test file** (write tests first):
   ```
   Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift
   ```

2. **Create implementation file**:
   ```
   Sources/SubtreeLib/Utilities/BraceExpander.swift
   ```

3. **Test cycle**:
   ```bash
   # Run tests - should fail initially
   swift test --filter BraceExpanderTests
   
   # Implement minimal code to pass
   # Repeat until all tests pass
   ```

### Phase 2: ExtractCommand Integration

1. **Add integration tests** to `ExtractIntegrationTests.swift`

2. **Modify ExtractCommand.swift** to expand patterns

3. **Run full test suite**:
   ```bash
   swift test
   ```

## Verification Commands

### Unit Test Verification

```bash
# All BraceExpander tests pass
swift test --filter BraceExpanderTests 2>&1 | grep -E "(Test|passed|failed)"

# Expected: All tests passed
```

### Integration Test Verification

```bash
# Build release binary
swift build -c release

# Test brace expansion with extract command
.build/release/subtree extract --name test-lib \
  --from 'Sources/{Foo,Bar/Baz}.swift' \
  --to extracted/

# Verify expanded patterns work
```

### Backward Compatibility Check

```bash
# Ensure existing patterns still work
swift test --filter GlobMatcherTests
swift test --filter ExtractIntegrationTests

# All existing tests must pass
```

## Success Criteria Validation

| Criteria | Validation Command |
|----------|-------------------|
| SC-001: Multiple nested paths | `extract --from '{A,B/C}.swift'` matches both depths |
| SC-002: Backward compatible | `swift test` — all 477+ existing tests pass |
| SC-003: <10ms expansion | Add performance test with 3 brace groups |
| SC-004: Clear errors | `extract --from '{a,}'` shows helpful error |
| SC-005: Embedded separators | `extract --from 'Sources/{A,B/C}.swift'` works |

## Common Issues

### Issue: Tests not found
```bash
# Ensure test file is in correct location
ls Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift
```

### Issue: Import errors
```bash
# BraceExpander must be public and in SubtreeLib module
# Check: public struct BraceExpander
# Check: @testable import SubtreeLib in tests
```

### Issue: Backward compatibility regression
```bash
# Run full test suite, not just new tests
swift test
# All 477+ tests must pass
```
