# Research: Case-Insensitive Names & Validation

**Feature**: 007-case-insensitive-names | **Phase**: 0 | **Date**: 2025-10-29

## Purpose

Resolve technical unknowns and establish implementation patterns for case-insensitive name matching, duplicate validation, and path security. No NEEDS CLARIFICATION markers exist in Technical Context - all decisions informed by Swift best practices and security standards.

## Research Areas

### 1. Case-Insensitive String Comparison in Swift

**Decision**: Use `.lowercased()` for ASCII-only case-folding

**Rationale**:
- Swift's `.lowercased()` with default locale handles ASCII case-folding correctly
- Explicitly documented in spec: ASCII-only matching (non-ASCII byte-for-byte)
- Avoids complex Unicode case-folding that varies by locale
- Performance: O(n) where n = string length, fast for typical names (<50 chars)

**Alternatives Considered**:
- **Full Unicode case-folding** (`localizedLowercaseString`) - Rejected: locale-dependent, complex edge cases, spec explicitly limits to ASCII
- **Custom ASCII-only lowercasing** - Rejected: reinventing the wheel, `.lowercased()` already handles ASCII correctly
- **Case-insensitive regex** - Rejected: overkill for exact matching, slower than direct string comparison

**Implementation Pattern**:
```swift
func matchesCaseInsensitive(_ other: String) -> Bool {
    return self.lowercased() == other.lowercased()
}
```

---

### 2. Path Validation & Security

**Decision**: Regex-based validation with explicit rejection rules

**Rationale**:
- Prevents path traversal attacks (`../`)
- Prevents absolute path confusion (`/vendor`)
- Enforces forward slash convention (cross-platform consistency)
- Regex provides clear, testable validation logic

**Validation Rules** (FR-004, FR-004a, FR-004b, FR-004c):
1. **No leading slash**: `^/` → reject (absolute paths)
2. **No parent traversal**: `\.\.(/|$)` → reject (`../` sequences)
3. **No backslashes**: `\\` → reject (Windows path separator)
4. **Allow spaces**: Spaces in path names are valid

**Implementation Pattern**:
```swift
struct PathValidator {
    static func validate(_ path: String) throws {
        // Reject absolute paths
        guard !path.starts(with: "/") else {
            throw ValidationError.absolutePath(path)
        }
        
        // Reject parent directory traversal
        let traversalPattern = #"\.\.(/|$)"#
        if path.range(of: traversalPattern, options: .regularExpression) != nil {
            throw ValidationError.parentTraversal(path)
        }
        
        // Reject backslashes
        guard !path.contains("\\") else {
            throw ValidationError.invalidSeparator(path)
        }
    }
}
```

**Alternatives Considered**:
- **URL validation**: Rejected - prefixes are filesystem paths, not URLs
- **FileManager path checking**: Rejected - runtime checks don't prevent security issues, need validation before operations
- **Allowlist approach**: Rejected - overly restrictive, regex rejection is more flexible

---

### 3. Duplicate Detection Strategy

**Decision**: O(n²) iteration with early exit for config validation

**Rationale**:
- Typical config size: 5-50 subtrees (n is small)
- O(n²) acceptable for n < 1000 (SC-010: <50ms validation overhead)
- Early exit on first duplicate (fail fast)
- Simple, maintainable code without complex data structures

**Implementation Pattern**:
```swift
struct DuplicateValidator {
    static func checkDuplicateNames(_ subtrees: [Subtree]) throws {
        for i in 0..<subtrees.count {
            for j in (i+1)..<subtrees.count {
                if subtrees[i].name.lowercased() == subtrees[j].name.lowercased() {
                    throw ValidationError.duplicateName(
                        attempted: subtrees[i].name,
                        existing: subtrees[j].name
                    )
                }
            }
        }
    }
}
```

**Alternatives Considered**:
- **Hash set (O(n))**: Rejected - loses original case info needed for error messages, premature optimization
- **Sorted array + binary search (O(n log n))**: Rejected - complexity not justified for small n
- **Lazy validation on access**: Rejected - spec requires validation before operations (clarification #3)

---

### 4. Whitespace Normalization

**Decision**: Trim during input processing, store normalized

**Rationale**:
- Whitespace in names/prefixes is almost always unintentional (clarification #4)
- Trim once during add command, avoid repeated trimming on every lookup
- Matches standard CLI behavior (git, npm, cargo all trim arguments)

**Implementation Pattern**:
```swift
extension String {
    func normalized() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// In AddCommand:
let normalizedName = providedName.normalized()
let normalizedPrefix = providedPrefix.normalized()
```

**Alternatives Considered**:
- **Preserve + trim for comparison**: Rejected per clarification #4 (trim and store)
- **Reject with error**: Rejected - overly strict, users expect trimming
- **Normalize all whitespace**: Rejected - internal whitespace is valid (e.g., "My Lib" is OK)

---

### 5. Non-ASCII Name Handling

**Decision**: Accept with warning, no blocking

**Rationale**:
- Maximum flexibility for international users (clarification #2: Option B)
- Warning educates users about case-matching limitations
- Exit code 0 (warnings don't fail operations per FR-020)

**Warning Message Pattern**:
```
⚠️  Warning: Name 'Библиотека' contains non-ASCII characters
   Case-insensitive matching only works for ASCII characters (A-Z).
   Names differing only in non-ASCII case (e.g., 'café' vs 'CAFÉ') will be treated as duplicates.
```

**Implementation Pattern**:
```swift
func checkNonASCII(name: String) -> Bool {
    return name.unicodeScalars.contains { !$0.isASCII }
}

// In AddCommand, after validation passes:
if checkNonASCII(name: normalizedName) {
    print(warningMessage(for: normalizedName), to: &StandardError.shared)
}
```

**Alternatives Considered**:
- **Reject non-ASCII**: Rejected - too restrictive, international users need flexibility
- **Silent acceptance**: Rejected - users won't understand case-matching behavior
- **Full Unicode case-folding**: Rejected - locale-dependent, complex, spec limits to ASCII

---

### 6. Config Validation Timing

**Decision**: Validate upfront (before any operations)

**Rationale**:
- Prevents partial state changes (clarification #3: Option B)
- Simpler error recovery (no rollback needed)
- Matches "before git operations" pattern in spec (US2, US3)
- Fast (<50ms per SC-010) so no performance concerns

**Validation Flow**:
```
1. Load subtree.yaml
2. Parse YAML → SubtreeConfig
3. Run validation: checkDuplicateNames(), checkDuplicatePrefixes()
4. If validation fails → exit with error code 2
5. If validation passes → proceed with command logic
```

**Implementation Pattern**:
```swift
// In commands that read config (Add, Remove, Update):
func run() throws {
    let config = try ConfigFileManager.load()
    
    // Validate BEFORE any operations
    try DuplicateValidator.checkDuplicateNames(config.subtrees)
    try DuplicateValidator.checkDuplicatePrefixes(config.subtrees)
    
    // Proceed with command logic
    // ...
}
```

**Alternatives Considered**:
- **Lazy validation**: Rejected - can't detect all duplicates without full scan
- **Transactional rollback**: Rejected - overly complex, validation is cheap
- **Validate after operations**: Rejected - violates "before operations" requirement (FR-009, FR-012)

---

### 7. Error Message Formatting

**Decision**: Structured format with emoji, context, and actionable guidance

**Rationale**:
- Matches modern CLI conventions (cargo, npm, git 2.x)
- Clarification #6: Option B (detailed with guidance)
- Spec defines exact format (FR-012, FR-013, FR-014, FR-015, FR-016)

**Error Format Template**:
```
❌ Error: [brief problem statement]
   [optional context line]
   
   To fix:
   • [action 1]
   • [action 2]
```

**Implementation Pattern**:
```swift
enum ValidationError: LocalizedError {
    case duplicateName(attempted: String, existing: String)
    
    var errorDescription: String? {
        switch self {
        case .duplicateName(let attempted, let existing):
            return """
            ❌ Error: Subtree name '\(attempted)' conflicts with existing '\(existing)'
               Names are matched case-insensitively to ensure config portability.
               
               To fix:
               • Choose a different name with --name
               • Remove the existing subtree first
            """
        }
    }
}
```

**Alternatives Considered**:
- **Simple errors**: Rejected - users need guidance to fix problems (clarification #6)
- **Verbose with rationale**: Rejected - buries actionable steps in explanation
- **Structured JSON output**: Rejected - CLI is human-first, not machine-parseable

---

## Implementation Dependencies

**No external dependencies needed** - all decisions use Swift standard library features:
- `String.lowercased()` - Foundation
- `String.range(of:options:)` - Foundation (regex support)
- `String.trimmingCharacters(in:)` - Foundation
- `UnicodeScalar.isASCII` - Swift standard library

**Existing project utilities to use**:
- `ConfigFileManager` - for loading/saving subtree.yaml
- `ExitCode` enum - for consistent exit codes (extend with new cases)
- `GitOperations` - no changes needed (validation happens before git operations)

---

## Summary

All technical decisions resolved. Ready for Phase 1 (Design):
1. **Case-insensitive matching**: `.lowercased()` comparison (ASCII-only)
2. **Path validation**: Regex-based rejection of absolute paths, traversal, backslashes
3. **Duplicate detection**: O(n²) iteration with early exit (acceptable for small n)
4. **Whitespace**: Trim and store normalized during input processing
5. **Non-ASCII**: Accept with warning (exit code 0)
6. **Validation timing**: Upfront before any operations
7. **Error messages**: Structured format with emoji + context + fix steps

**No blockers** - proceed to data model and contract design.
