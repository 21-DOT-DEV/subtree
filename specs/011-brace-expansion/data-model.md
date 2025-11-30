# Data Model: Brace Expansion

**Feature**: 011-brace-expansion  
**Date**: 2025-11-29

## Entities

### BraceExpander

A stateless utility for expanding brace patterns in glob expressions.

**Type**: `public struct BraceExpander`

**Purpose**: Pre-expand patterns like `{a,b,c}` and `{a,b/c}` before glob matching

**API**:
```swift
public struct BraceExpander {
    /// Expand brace patterns in a glob expression
    /// - Parameter pattern: Input pattern potentially containing braces
    /// - Returns: Array of expanded patterns (or single-element array if no braces)
    /// - Throws: BraceExpanderError.emptyAlternative if pattern contains {a,} or {,b}
    public static func expand(_ pattern: String) throws -> [String]
}
```

### BraceExpanderError

Error type for brace expansion failures.

**Type**: `public enum BraceExpanderError: Error, Equatable`

**Cases**:
| Case | Description | Example |
|------|-------------|---------|
| `emptyAlternative(String)` | Pattern contains empty alternative | `{a,}`, `{,b}`, `{a,,b}` |

**Rationale**: Only one error case needed. Invalid braces (unclosed, single-item, empty braces) are passed through as literals per bash semantics.

### BraceGroup (Internal)

Represents a single brace expression found during parsing.

**Type**: `private struct BraceGroup` (internal to BraceExpander)

**Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `startIndex` | `String.Index` | Position of `{` in pattern |
| `endIndex` | `String.Index` | Position of `}` in pattern |
| `alternatives` | `[String]` | Comma-separated values inside braces |

## Data Flow

```
Input Pattern
     │
     ▼
┌─────────────────┐
│  BraceExpander  │
│    .expand()    │
└─────────────────┘
     │
     ▼
Parse brace groups
     │
     ├── No valid groups found?
     │         │
     │         ▼
     │   Return [original pattern]
     │
     ├── Empty alternative detected?
     │         │
     │         ▼
     │   throw BraceExpanderError.emptyAlternative
     │
     ▼
Cartesian product expansion
     │
     ▼
[Expanded Patterns]
     │
     ▼
GlobMatcher (existing)
```

## Validation Rules

### Valid Patterns (expand)
- `{a,b}` → `["a", "b"]`
- `{a,b,c}` → `["a", "b", "c"]`
- `{a,b/c}` → `["a", "b/c"]` (embedded separator)
- `*.{h,c}` → `["*.h", "*.c"]`
- `{src,test}/*.swift` → `["src/*.swift", "test/*.swift"]`
- `{a,b}{1,2}` → `["a1", "a2", "b1", "b2"]` (cartesian product)

### Literal Pass-Through (no expansion)
- `{a}` → `["{a}"]` (no comma)
- `{}` → `["{}"]` (empty braces)
- `{a,b` → `["{a,b"]` (unclosed)
- `a,b}` → `["a,b}"]` (no opening)
- `plain.txt` → `["plain.txt"]` (no braces)

### Error (throw)
- `{a,}` → throw `.emptyAlternative("{a,}")`
- `{,b}` → throw `.emptyAlternative("{,b}")`
- `{a,,b}` → throw `.emptyAlternative("{a,,b}")`

## State Transitions

N/A — BraceExpander is stateless. Each call to `expand()` is independent.

## Scale Considerations

- **Warning threshold**: >100 expanded patterns triggers warning to stderr
- **No hard limit**: Large expansions allowed but discouraged
- **Memory**: O(n) where n = number of expanded patterns
- **Time**: O(n × m) where m = pattern length
