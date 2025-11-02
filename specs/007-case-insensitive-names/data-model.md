# Data Model: Case-Insensitive Names & Validation

**Feature**: 007-case-insensitive-names | **Phase**: 1 | **Date**: 2025-10-29

## Overview

This feature adds validation infrastructure without introducing new entities. It extends existing `SubtreeConfig` and `Subtree` models with validation methods and introduces utility types for validation logic.

## Existing Entities (No Schema Changes)

### Subtree Entry

**Location**: `Sources/SubtreeLib/Configuration/SubtreeConfig.swift`

**Schema** (unchanged):
```swift
struct Subtree: Codable, Equatable {
    let name: String        // Case-preserved, whitespace-trimmed
    let prefix: String      // Case-preserved, whitespace-trimmed, validated
    let remote: String      // Git repository URL
    let ref: String         // Branch/tag reference
    let commit: String?     // SHA of last sync
    let squash: Bool        // Squash mode flag
}
```

**Notes**:
- No fields added - validation is behavioral, not structural
- `name` and `prefix` already stored as strings
- Trimming happens during input processing (AddCommand), not in model
- Case preservation is automatic (store exactly what user provides after trimming)

### SubtreeConfig

**Location**: `Sources/SubtreeLib/Configuration/SubtreeConfig.swift`

**Schema** (unchanged):
```swift
struct SubtreeConfig: Codable {
    var subtrees: [Subtree]
}
```

**Extensions** (new validation methods):
```swift
extension SubtreeConfig {
    /// Find subtree by case-insensitive name match
    /// Returns: Optional<Subtree> - the matched subtree or nil
    /// Throws: ValidationError.multipleMatches if corruption detected
    func findSubtree(name: String) throws -> Subtree? {
        let matches = subtrees.filter { 
            $0.name.lowercased() == name.lowercased() 
        }
        
        guard matches.count <= 1 else {
            throw ValidationError.multipleMatches(
                name: name,
                found: matches.map(\.name)
            )
        }
        
        return matches.first
    }
    
    /// Validate config for case-insensitive duplicates (names + prefixes)
    /// Throws: ValidationError if duplicates detected
    func validate() throws {
        try validateNoDuplicateNames()
        try validateNoDuplicatePrefixes()
    }
    
    private func validateNoDuplicateNames() throws {
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
    
    private func validateNoDuplicatePrefixes() throws {
        for i in 0..<subtrees.count {
            for j in (i+1)..<subtrees.count {
                if subtrees[i].prefix.lowercased() == subtrees[j].prefix.lowercased() {
                    throw ValidationError.duplicatePrefix(
                        attempted: subtrees[i].prefix,
                        existing: subtrees[j].prefix
                    )
                }
            }
        }
    }
}
```

## New Utility Types

### ValidationError

**Location**: `Sources/SubtreeLib/Utilities/ValidationError.swift`

**Purpose**: Structured error types for all validation failures with formatted messages

```swift
enum ValidationError: LocalizedError {
    // Duplicate detection
    case duplicateName(attempted: String, existing: String)
    case duplicatePrefix(attempted: String, existing: String)
    case multipleMatches(name: String, found: [String])
    
    // Path validation
    case absolutePath(String)
    case parentTraversal(String)
    case invalidSeparator(String)
    
    // Not found
    case subtreeNotFound(String)
    
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
            
        case .duplicatePrefix(let attempted, let existing):
            return """
            ❌ Error: Subtree prefix '\(attempted)' conflicts with existing '\(existing)'
               Prefixes are matched case-insensitively to prevent filesystem conflicts.
               
               To fix:
               • Choose a different prefix with --prefix
               • Remove the existing subtree first
            """
            
        case .multipleMatches(let name, let found):
            let foundList = found.map { "'\($0)'" }.joined(separator: ", ")
            return """
            ❌ Error: Multiple subtrees match '\(name)' (found: \(foundList))
               Case-insensitive duplicates indicate manual config corruption.
               
               To fix:
               • Edit subtree.yaml and remove duplicate entries
               • Keep only one version
               • Run 'subtree lint' to verify config integrity
            """
            
        case .absolutePath(let path):
            return """
            ❌ Error: Prefix '\(path)' must be a relative path
               Absolute paths (starting with '/') are not allowed.
               
               To fix:
               • Use a relative path like 'vendor/lib' instead of '/vendor/lib'
            """
            
        case .parentTraversal(let path):
            return """
            ❌ Error: Prefix '\(path)' contains parent directory traversal
               Paths with '../' are not allowed for security reasons.
               
               To fix:
               • Use a path relative to repository root without '../'
            """
            
        case .invalidSeparator(let path):
            return """
            ❌ Error: Prefix '\(path)' uses invalid path separator
               Use forward slashes ('/') for cross-platform compatibility.
               
               To fix:
               • Replace backslashes with forward slashes: '\(path.replacingOccurrences(of: "\\", with: "/"))'
            """
            
        case .subtreeNotFound(let name):
            return "❌ Error: Subtree '\(name)' not found"
        }
    }
    
    var exitCode: Int {
        switch self {
        case .duplicateName, .duplicatePrefix, .absolutePath, .parentTraversal, .invalidSeparator, .subtreeNotFound:
            return 1  // User error
        case .multipleMatches:
            return 2  // Config corruption
        }
    }
}
```

### PathValidator

**Location**: `Sources/SubtreeLib/Utilities/PathValidator.swift`

**Purpose**: Validate prefix path format (relative, no traversal, forward slashes)

```swift
struct PathValidator {
    /// Validate that prefix is a safe relative path
    /// Throws: ValidationError if path is invalid
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
        
        // Reject backslashes (Windows separator)
        guard !path.contains("\\") else {
            throw ValidationError.invalidSeparator(path)
        }
        
        // Valid: relative path with forward slashes (spaces allowed)
    }
}
```

### NameValidator

**Location**: `Sources/SubtreeLib/Utilities/NameValidator.swift`

**Purpose**: Validate name format and check for non-ASCII characters

```swift
struct NameValidator {
    /// Check if name contains non-ASCII characters
    /// Returns: true if non-ASCII found (triggers warning)
    static func containsNonASCII(_ name: String) -> Bool {
        return name.unicodeScalars.contains { !$0.isASCII }
    }
    
    /// Generate warning message for non-ASCII names
    static func nonASCIIWarning(for name: String) -> String {
        return """
        ⚠️  Warning: Name '\(name)' contains non-ASCII characters
           Case-insensitive matching only works for ASCII characters (A-Z).
           Names differing only in non-ASCII case will be treated as duplicates.
        """
    }
}
```

### String Extensions

**Location**: `Sources/SubtreeLib/Utilities/StringExtensions.swift`

**Purpose**: Reusable string operations for validation

```swift
extension String {
    /// Trim leading and trailing whitespace
    func normalized() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Case-insensitive equality check
    func matchesCaseInsensitive(_ other: String) -> Bool {
        return self.lowercased() == other.lowercased()
    }
}
```

## Validation Rules Summary

### Name Validation
- **Uniqueness**: Case-insensitive (FR-005)
- **Format**: Any string after whitespace trimming (FR-003a)
- **Non-ASCII**: Allowed with warning (FR-003b, FR-017)

### Prefix Validation
- **Uniqueness**: Case-insensitive (FR-006)
- **Format**: Relative path with forward slashes (FR-004, FR-004a, FR-004b)
- **Security**: No absolute paths, no parent traversal (FR-004, FR-004a)
- **Spaces**: Allowed in directory names (FR-004c)

### Validation Timing
- **Config load**: Validate before operations in add/remove/update (FR-009)
- **Config save**: Validate duplicates before adding new entry (FR-005, FR-006)
- **Lookup**: Check for multiple matches during name resolution (FR-011, FR-012)

## State Transitions

**No state changes** - validation is read-only. Commands use validation results to decide whether to proceed.

```
[Load Config] → [Validate] → {Pass: Continue | Fail: Exit with error}
                    ↓
              [Check Duplicates]
              [Check Format]
              [Check Corruption]
```

## Exit Code Mapping

| Scenario | Exit Code | Error Type |
|----------|-----------|------------|
| Duplicate name during add | 1 | User error (ValidationError.duplicateName) |
| Duplicate prefix during add | 1 | User error (ValidationError.duplicatePrefix) |
| Invalid path format | 1 | User error (ValidationError.absolutePath, etc.) |
| Multiple matches (corruption) | 2 | Config corruption (ValidationError.multipleMatches) |
| Subtree not found | 1 | User error (ValidationError.subtreeNotFound) |
| Successful operation | 0 | N/A |

**Non-ASCII warnings**: Exit code 0 (warnings don't fail operations per FR-020)

## Testing Requirements

### Unit Tests (Utilities/)
- `NameValidatorTests`: Non-ASCII detection, warning formatting
- `PathValidatorTests`: Absolute paths, traversal, backslashes, valid paths with spaces
- `ValidationErrorTests`: Error messages, exit codes
- `SubtreeConfigTests`: findSubtree(), validate(), duplicate detection

### Integration Tests (Commands/)
- `AddCommandTests`: Duplicate prevention (names + prefixes), path validation, non-ASCII warnings
- `RemoveCommandTests`: Case-insensitive lookup, multiple match detection
- `UpdateCommandTests`: Case-insensitive lookup, multiple match detection

**Test Coverage Target**: 100% of validation code paths (all error types, all success paths)
