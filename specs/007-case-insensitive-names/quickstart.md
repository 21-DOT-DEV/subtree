# Quickstart: Case-Insensitive Names & Validation

**Feature**: 007-case-insensitive-names | **Phase**: Implementation Ready

## For Implementers

### TL;DR

Add 5 validation utilities to `Sources/SubtreeLib/Utilities/`, extend `SubtreeConfig` with validation methods, modify 3 commands (Add, Remove, Update) to call validation before git operations. ~300 lines of validation code, ~600 lines of tests.

### Implementation Order (TDD)

1. **Phase 1: Validation Utilities** (Unit Tests First)
   - `ValidationError.swift` + tests (error messages, exit codes)
   - `PathValidator.swift` + tests (absolute, traversal, backslashes)
   - `NameValidator.swift` + tests (non-ASCII detection)
   - `StringExtensions.swift` + tests (normalized(), matchesCaseInsensitive())

2. **Phase 2: Config Extension** (Unit Tests First)
   - Extend `SubtreeConfig` with `findSubtree()` + tests
   - Add `validate()`, `validateNoDuplicateNames()`, `validateNoDuplicatePrefixes()` + tests

3. **Phase 3: Add Command** (Integration Tests First)
   - Add validation calls before git operations
   - Test: duplicate name/prefix detection, path validation, non-ASCII warnings

4. **Phase 4: Remove Command** (Integration Tests First)
   - Replace exact match with `config.findSubtree()`
   - Test: case-insensitive removal, multiple match detection

5. **Phase 5: Update Command** (Integration Tests First)
   - Replace exact match with `config.findSubtree()`
   - Test: case-insensitive update, case preservation

### Quick Validation Checklist

Before merging, verify:

```bash
# All 310 tests pass (verified: ✅)
swift test

# No regressions in existing commands (verified: ✅)
swift test --filter AddIntegrationTests
swift test --filter RemoveIntegrationTests
swift test --filter UpdateCommandIntegrationTests

# New validation tests pass (verified: ✅)
swift test --filter SubtreeValidationErrorTests
swift test --filter PathValidatorTests
swift test --filter NameValidatorTests
swift test --filter StringExtensionsTests

# CI passes on both platforms (verified: ✅)
git push  # Triggers ci.yml (macOS-15 + Ubuntu 20.04)
```

## For Reviewers

### What Changed

**Added** (5 new files):
- `Sources/SubtreeLib/Utilities/ValidationError.swift` (~100 lines)
- `Sources/SubtreeLib/Utilities/PathValidator.swift` (~30 lines)
- `Sources/SubtreeLib/Utilities/NameValidator.swift` (~20 lines)
- `Sources/SubtreeLib/Utilities/StringExtensions.swift` (~10 lines)
- `Tests/SubtreeLibTests/Utilities/*Tests.swift` (~250 lines total)

**Modified** (4 files):
- `Sources/SubtreeLib/Configuration/SubtreeConfig.swift` (+60 lines)
- `Sources/SubtreeLib/Commands/AddCommand.swift` (+40 lines)
- `Sources/SubtreeLib/Commands/RemoveCommand.swift` (+15 lines)
- `Sources/SubtreeLib/Commands/UpdateCommand.swift` (+15 lines)

**Total**: ~540 lines added (50% tests)

### Critical Review Points

1. **Validation happens BEFORE git operations** - check AddCommand.swift
2. **Case preservation** - config stores user's exact capitalization
3. **Exit codes** - 0=success, 1=user error, 2=corruption
4. **Error messages** - all follow "emoji + context + fix steps" format
5. **Non-ASCII warnings** - exit code 0 (warnings don't fail)
6. **No breaking changes** - existing commands work identically

### Test Coverage

```bash
# Should be ~100% for validation utilities
swift test --enable-code-coverage
xcrun llvm-cov report .build/debug/SubtreePackageTests.xctest/Contents/MacOS/SubtreePackageTests \
  -instr-profile=.build/debug/codecov/default.profdata \
  -ignore-filename-regex=".build|Tests" \
  Sources/SubtreeLib/Utilities/
```

Expected: >95% coverage for all validation utilities.

## For Users (Post-Merge)

### What's New

**Case-insensitive name matching** - Remove and update subtrees without remembering exact case:
```bash
# Added with: subtree add --name Hello-World ...
subtree remove hello-world  # Works! (was case-sensitive before)
subtree update HELLO-WORLD  # Works! (was case-sensitive before)
```

**Duplicate prevention** - Can't create configs that won't work across platforms:
```bash
subtree add --name Hello-World --remote ...  # ✅ Added
subtree add --name hello-world --remote ...  # ❌ Error: conflicts with 'Hello-World'
```

**Path validation** - Prevents security issues and filesystem conflicts:
```bash
subtree add --prefix /vendor/lib ...       # ❌ Error: must be relative
subtree add --prefix ../vendor/lib ...     # ❌ Error: no parent traversal
subtree add --prefix vendor\lib ...        # ❌ Error: use forward slashes
subtree add --prefix vendor/lib ...        # ✅ Works
subtree add --prefix "vendor/my lib" ...   # ✅ Works (spaces allowed)
```

**Non-ASCII support** - International names work with helpful warnings:
```bash
subtree add --name Библиотека --remote ...
# ⚠️  Warning: Name 'Библиотека' contains non-ASCII characters
#    Case-insensitive matching only works for ASCII characters.
# ✅ Subtree added successfully (warning doesn't fail)
```

### Migration Guide

**No migration needed** - Existing configs work without changes.

**Recommended** - If you have case-variant duplicates (very rare), fix them:
```bash
# Check for issues (after lint command is implemented)
subtree lint

# If corruption found, manually edit subtree.yaml
# Keep one version, remove duplicates
```

## Common Pitfalls

### For Implementers

❌ **Don't**: Add validation AFTER git operations
```swift
// WRONG - validation after git operations
try gitOperations.addSubtree(...)
try config.validate()  // Too late!
```

✅ **Do**: Validate BEFORE any git operations
```swift
// CORRECT - validate first
try config.validate()
try gitOperations.addSubtree(...)
```

❌ **Don't**: Fail on non-ASCII warnings
```swift
// WRONG - exit code 1 for warnings
if NameValidator.containsNonASCII(name) {
    throw ValidationError.nonASCII(name)  // Don't throw!
}
```

✅ **Do**: Warn but continue (exit code 0)
```swift
// CORRECT - print warning, don't fail
if NameValidator.containsNonASCII(name) {
    print(NameValidator.nonASCIIWarning(for: name), to: &stderr)
}
// Continue with operation
```

❌ **Don't**: Modify stored case during lookup
```swift
// WRONG - changes config case
let subtree = config.subtrees.first { ... }
subtree.name = providedName.lowercased()  // Breaks case preservation!
```

✅ **Do**: Preserve original case in config
```swift
// CORRECT - lookup case-insensitive, keep original
let subtree = try config.findSubtree(name: providedName)
// subtree.name still has original capitalization
```

## Validation Quick Reference

### String Operations

```swift
// Normalize (trim whitespace)
let normalized = " Hello-World ".normalized()  // "Hello-World"

// Case-insensitive match
"Hello-World".matchesCaseInsensitive("hello-world")  // true

// Non-ASCII detection
NameValidator.containsNonASCII("Café")  // true
NameValidator.containsNonASCII("Hello")  // false
```

### Path Validation

```swift
// Validate prefix paths
try PathValidator.validate("vendor/lib")          // ✅ Pass
try PathValidator.validate("/vendor/lib")         // ❌ absolutePath
try PathValidator.validate("../vendor/lib")       // ❌ parentTraversal
try PathValidator.validate("vendor\\lib")         // ❌ invalidSeparator
try PathValidator.validate("vendor/my lib")       // ✅ Pass (spaces OK)
```

### Duplicate Detection

```swift
// Check config for duplicates
let config = try ConfigFileManager.load()
try config.validate()  // Throws if duplicates found

// Find subtree (case-insensitive)
let subtree = try config.findSubtree(name: "hello-world")
// Returns subtree named "Hello-World" if it exists
// Throws ValidationError.multipleMatches if corruption detected
// Returns nil if not found
```

### Error Handling

```swift
do {
    try config.validate()
} catch let error as ValidationError {
    print(error.localizedDescription)  // Formatted error with guidance
    exit(error.exitCode)               // 1=user error, 2=corruption
}
```

## Performance Notes

- **Validation overhead**: <50ms for typical configs (5-50 subtrees)
- **O(n²) duplicate detection**: Acceptable for n < 1000
- **No network calls**: All validation is local/offline
- **Regex path validation**: <1ms per path

## Next Steps

After implementation:
1. Update `.windsurf/rules` (add validation patterns, modified commands)
2. Update `agents.md` (feature status, validation capabilities)
3. Update `README.md` (document new validation behavior)
4. Consider adding validation examples to docs/

**Deferred to future specs**:
- Comprehensive `lint` command (Phase 3 per roadmap)
- Remote validation (check if upstream changed)
- Repair mode (auto-fix config issues)
