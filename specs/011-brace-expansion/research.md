# Research: Brace Expansion with Embedded Path Separators

**Feature**: 011-brace-expansion  
**Date**: 2025-11-29

## Research Tasks

### 1. Bash Brace Expansion Semantics

**Task**: Understand exact bash behavior for brace expansion

**Findings**:
- Brace expansion occurs BEFORE pathname expansion (globbing)
- `{a,b,c}` expands to separate words: `a b c`
- Multiple groups produce cartesian product: `{a,b}{1,2}` → `a1 a2 b1 b2`
- Path separators inside braces are allowed: `{a,b/c}` → `a b/c`
- No comma = no expansion: `{a}` stays as literal `{a}`
- Empty braces `{}` stay literal
- Unclosed braces stay literal: `{a,b` stays as `{a,b`
- Empty alternatives ARE valid in bash: `{a,}` → `a ` (a and empty string)

**Decision**: Follow bash semantics EXCEPT for empty alternatives (error for safety)

**Rationale**: Empty path components can cause unexpected filesystem behavior. Safer to error.

### 2. Existing GlobMatcher Implementation

**Task**: Understand why embedded path separators don't work

**Findings**:
- GlobMatcher splits pattern by `/` into segments BEFORE processing
- `Sources/{A,B/C}.swift` becomes segments: `["Sources", "{A,B/C}.swift"]`
- Brace expansion in `matchSingleSegment` only matches if entire remaining string equals one alternative
- The alternative `B/C` in segment `{A,B/C}.swift` cannot match a path with different depth

**Decision**: Pre-expand braces BEFORE GlobMatcher receives the pattern

**Rationale**: Keeps GlobMatcher unchanged; expansion produces valid patterns that GlobMatcher can match.

### 3. Swift String Parsing Patterns

**Task**: Best practices for parsing brace expressions in Swift

**Findings**:
- Character-by-character iteration with index tracking (used by GlobMatcher)
- Recursive descent for nested structures (not needed for flat braces)
- String.Index API for safe Unicode handling

**Decision**: Use same pattern as GlobMatcher's `parseBraceExpansion` for consistency

**Rationale**: Proven pattern in codebase; familiar to contributors.

### 4. Cartesian Product Algorithm

**Task**: Efficient cartesian product for multiple brace groups

**Findings**:
- Iterative approach: Start with `[""]`, for each group, expand each existing pattern
- Recursive approach: Expand first group, recursively expand rest
- Memory: O(n) where n = total expanded patterns

**Decision**: Iterative approach with early termination check

**Rationale**: Simpler to understand; can check pattern count and warn at 100+

**Algorithm**:
```
func expand(pattern) -> [String]:
  groups = findBraceGroups(pattern)
  if groups.isEmpty: return [pattern]
  
  results = [""]
  for group in groups:
    newResults = []
    for partial in results:
      for alternative in group.alternatives:
        newResults.append(partial + prefixBefore(group) + alternative)
    results = newResults
    if results.count > 100: warn()
  return results.map { $0 + suffixAfter(lastGroup) }
```

## Summary

| Topic | Decision | Rationale |
|-------|----------|-----------|
| Bash compatibility | Follow except empty alternatives | Safety over strict compatibility |
| Integration | Pre-expand before GlobMatcher | Keeps existing code unchanged |
| Parsing | Character iteration with Index | Matches existing GlobMatcher style |
| Cartesian product | Iterative with count check | Simple + allows warning at 100+ |

## No Outstanding Unknowns

All NEEDS CLARIFICATION items resolved. Ready for Phase 1 design.
