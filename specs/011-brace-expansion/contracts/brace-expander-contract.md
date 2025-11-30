# Contract: BraceExpander

**Feature**: 011-brace-expansion  
**Date**: 2025-11-29

## Public API

### BraceExpander.expand(_:)

```swift
/// Expand brace patterns in a glob expression
///
/// Supports bash-style brace expansion with embedded path separators:
/// - `{a,b,c}` → `["a", "b", "c"]`
/// - `{a,b/c}` → `["a", "b/c"]`
/// - `{x,y}{1,2}` → `["x1", "x2", "y1", "y2"]` (cartesian product)
///
/// Invalid patterns are passed through unchanged (bash behavior):
/// - `{a}` (no comma) → `["{a}"]`
/// - `{}` (empty) → `["{}"]`
/// - `{a,b` (unclosed) → `["{a,b"]`
///
/// - Parameter pattern: Input pattern potentially containing braces
/// - Returns: Array of expanded patterns
/// - Throws: `BraceExpanderError.emptyAlternative` if pattern contains `{a,}`, `{,b}`, or `{a,,b}`
public static func expand(_ pattern: String) throws -> [String]
```

### BraceExpanderError

```swift
/// Errors that can occur during brace expansion
public enum BraceExpanderError: Error, Equatable {
    /// Pattern contains an empty alternative (e.g., `{a,}` or `{,b}`)
    /// Associated value is the full pattern for error reporting
    case emptyAlternative(String)
}
```

## Contract Tests

### Expansion Behavior

| Input | Expected Output | Test ID |
|-------|-----------------|---------|
| `{a,b}` | `["a", "b"]` | CE-001 |
| `{a,b,c}` | `["a", "b", "c"]` | CE-002 |
| `{a,b/c}` | `["a", "b/c"]` | CE-003 |
| `*.{h,c}` | `["*.h", "*.c"]` | CE-004 |
| `{src,test}/*.swift` | `["src/*.swift", "test/*.swift"]` | CE-005 |
| `{a,b}{1,2}` | `["a1", "a2", "b1", "b2"]` | CE-006 |
| `{x,y}{a,b}{1,2}` | 8 patterns (cartesian) | CE-007 |

### Pass-Through Behavior

| Input | Expected Output | Test ID |
|-------|-----------------|---------|
| `plain.txt` | `["plain.txt"]` | CE-010 |
| `*.swift` | `["*.swift"]` | CE-011 |
| `{a}` | `["{a}"]` | CE-012 |
| `{}` | `["{}"]` | CE-013 |
| `{a,b` | `["{a,b"]` | CE-014 |
| `a,b}` | `["a,b}"]` | CE-015 |

### Error Behavior

| Input | Expected Error | Test ID |
|-------|----------------|---------|
| `{a,}` | `.emptyAlternative("{a,}")` | CE-020 |
| `{,b}` | `.emptyAlternative("{,b}")` | CE-021 |
| `{a,,b}` | `.emptyAlternative("{a,,b}")` | CE-022 |
| `src/{,test}/*.c` | `.emptyAlternative` | CE-023 |

### Edge Cases

| Input | Expected Output | Test ID |
|-------|-----------------|---------|
| `{a,b}/{c,d/e}.swift` | 4 patterns with mixed depths | CE-030 |
| `{Sources,Tests/Unit}/**/*.swift` | 2 patterns | CE-031 |
| `{{a,b}}` | `["{a}", "{b}"]` (outer braces, inner literal) | CE-032 |
| (empty string) | `[""]` | CE-033 |
| `{a,b,c,d,e,f,g,h,i,j}` | 10 patterns | CE-034 |

## Integration Contract

### ExtractCommand Integration

When `ExtractCommand` receives patterns with braces:

1. **Before file matching**: Call `BraceExpander.expand()` on each `--from` pattern
2. **Before file matching**: Call `BraceExpander.expand()` on each `--exclude` pattern  
3. **For each expanded pattern**: Pass to existing `GlobMatcher` logic
4. **Deduplicate results**: Union of all matches (existing behavior)

```swift
// Pseudocode for integration
func matchFiles(patterns: [String], excludes: [String]) throws -> [String] {
    var expandedPatterns: [String] = []
    for pattern in patterns {
        expandedPatterns.append(contentsOf: try BraceExpander.expand(pattern))
    }
    
    var expandedExcludes: [String] = []
    for exclude in excludes {
        expandedExcludes.append(contentsOf: try BraceExpander.expand(exclude))
    }
    
    // Existing matching logic with expanded patterns
    return matchWithGlobMatcher(expandedPatterns, excluding: expandedExcludes)
}
```

## Backward Compatibility

- Patterns without braces MUST return unchanged (single-element array)
- Existing GlobMatcher brace expansion (for file extensions) continues to work
- No changes to subtree.yaml schema
- No changes to CLI flags
