# Data Model: Extract Command

**Feature**: `008-extract-command` | **Date**: 2025-10-31  
**Phase**: 1 (Design & Contracts)

## Overview

This document defines the data entities, relationships, validation rules, and state transitions for the Extract Command feature. Models extend existing configuration schema.

---

## Entity: ExtractionMapping

**Purpose**: Represents a saved file extraction configuration defining source pattern, destination, and optional exclusions.

### Fields

| Field | Type | Required | Description | Validation Rules |
|-------|------|----------|-------------|------------------|
| `from` | String | Yes | Glob pattern matching files in subtree | Non-empty, valid glob syntax |
| `to` | String | Yes | Destination path (relative to repo root) | Non-empty, relative path, no `..`, within repo |
| `exclude` | [String]? | No | Array of glob patterns to exclude from matches | Each pattern: valid glob syntax |

### Relationships

- **Belongs to**: SubtreeEntry (one-to-many)
- **Stored in**: subtree.yaml under `subtrees[].extractions[]`

### Validation Rules

1. **from pattern**:
   - MUST be non-empty string
   - MUST be valid glob syntax (no unclosed brackets, valid escaping)
   - Scoped to subtree's prefix directory (automatically prepended during matching)

2. **to path**:
   - MUST be non-empty string
   - MUST be relative path (no leading `/`)
   - MUST NOT contain `..` (path traversal prevention)
   - MUST be within repository boundaries
   - Will be created if doesn't exist (no validation for existence)

3. **exclude patterns** (if present):
   - Each pattern MUST be valid glob syntax
   - Empty array is valid (same as omitting field)
   - Applied AFTER `from` matching (filter out matched files)

### Example YAML

```yaml
# Minimal mapping
- from: "docs/**/*.md"
  to: "project-docs/"

# With exclusions
- from: "src/**/*.{h,c}"
  to: "Sources/lib/"
  exclude:
    - "src/**/test*/**"
    - "src/**/bench*/**"
    - "src/precompute_*.c"
```

### Swift Representation

```swift
public struct ExtractionMapping: Codable, Equatable {
    public let from: String
    public let to: String
    public let exclude: [String]?
    
    public init(from: String, to: String, exclude: [String]? = nil) {
        self.from = from
        self.to = to
        self.exclude = exclude
    }
}
```

---

## Entity: SubtreeEntry (Extended)

**Purpose**: Configuration entry for a managed subtree. Extended to support optional extraction mappings.

### New Field

| Field | Type | Required | Description | Validation Rules |
|-------|------|----------|-------------|------------------|
| `extractions` | [ExtractionMapping]? | No | Array of saved extraction mappings | Each mapping validated per ExtractionMapping rules |

### Updated Relationships

- **Has many**: ExtractionMapping (one-to-many, optional)
- **Ordering**: Extraction mappings execute in array order

### Validation Rules

1. **extractions array** (if present):
   - Can be empty array (valid but no-op for extraction)
   - Order matters: executed sequentially
   - Each mapping validated independently
   - No uniqueness constraint (duplicate mappings allowed - user may want redundancy)

2. **Backward compatibility**:
   - Field is optional: existing configs without `extractions` field remain valid
   - Parsing: Missing field → `nil` (not error)
   - Serialization: `nil` → field omitted from YAML

### Example YAML

```yaml
subtrees:
  - name: secp256k1
    remote: https://github.com/bitcoin-core/secp256k1
    prefix: vendor/secp256k1
    ref: master
    commit: 1234abc
    extractions:  # NEW: Optional field
      - from: "src/**/*.{h,c}"
        to: "Sources/libsecp256k1/src/"
        exclude:
          - "src/**/test*/**"
          - "src/**/bench*/**"
      - from: "include/**/*.h"
        to: "Sources/libsecp256k1/include/"
  
  - name: utils
    remote: https://github.com/example/utils
    prefix: vendor/utils
    ref: main
    commit: 5678def
    # No extractions field - valid
```

### Swift Representation (Updated)

```swift
public struct SubtreeEntry: Codable, Equatable {
    public let name: String
    public let remote: String
    public let prefix: String
    public let ref: String
    public let commit: String?
    public let extractions: [ExtractionMapping]?  // NEW: Optional array
    
    // ... existing methods ...
}
```

---

## Entity: GlobPattern (Utility Type)

**Purpose**: Internal representation of parsed glob pattern for matching operations. Not persisted to config.

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `pattern` | String | Original glob pattern string |
| `components` | [PatternComponent] | Parsed pattern components |
| `hasGlobstar` | Bool | True if pattern contains `**` |

### Pattern Components (Enum)

```swift
enum PatternComponent {
    case literal(String)           // Exact match: "foo"
    case wildcard                  // Single-level: *
    case globstar                  // Recursive: **
    case singleChar                // Any char: ?
    case characterClass([Character]) // One of: [abc]
}
```

### Operations

- `matches(path: String) -> Bool`: Check if path matches pattern
- `parse(pattern: String) throws -> GlobPattern`: Parse string to components

### Validation

- Pattern syntax validated at parse time (throws on invalid syntax)
- Unclosed brackets → error
- Invalid escape sequences → error
- Empty pattern → error

---

## State Transitions

### Extraction Mapping Lifecycle

```
[Not Exists] 
    ↓ (ad-hoc extraction with --persist)
[Saved in Config] 
    ↓ (edit subtree.yaml manually or re-run with --persist)
[Updated in Config]
    ↓ (remove subtree or manual edit)
[Removed from Config]
```

**States**:
1. **Not Exists**: Mapping not in config (ad-hoc extraction only)
2. **Saved in Config**: Mapping persisted, can be executed with `--name` or `--all`
3. **Updated in Config**: Mapping modified (manual edit or replaced)
4. **Removed from Config**: Mapping deleted (subtree removed or manual edit)

**Transitions**:
- **Save**: `subtree extract --name X "pattern" dest/ --persist` → appends mapping
- **Execute**: `subtree extract --name X` → runs all saved mappings (no state change)
- **Update**: Manual YAML edit only (no command support in this spec)
- **Remove**: Manual YAML edit or `subtree remove X` (removes entire subtree with mappings)

---

## Relationships Diagram

```
SubtreeConfig
    ↓ contains (1:N)
SubtreeEntry
    ↓ has (1:N, optional)
ExtractionMapping
```

**Cardinality**:
- 1 SubtreeConfig → N SubtreeEntry (1:N)
- 1 SubtreeEntry → N ExtractionMapping (1:N, optional)
- ExtractionMapping doesn't reference other entities (leaf node)

---

## Validation Summary

### Config-Level Validation

Performed by ConfigFileManager when loading subtree.yaml:

1. **Schema validation**: YAML structure matches expected format
2. **Required fields**: name, remote, prefix, ref present for each subtree
3. **Type validation**: Arrays are arrays, strings are strings
4. **Extraction mapping validation**: Each mapping has required fields (from, to)

### Command-Level Validation

Performed by ExtractCommand before execution:

1. **Subtree exists**: Name lookup in config (case-insensitive)
2. **Prefix exists**: Subtree directory found at configured prefix
3. **Pattern validity**: Glob patterns parse without errors
4. **Path safety**: Destination paths validated (relative, no `..`, within repo)
5. **Zero-match check**: Pattern matches at least 1 file after exclusions (strict validation)

### Runtime Validation

Performed during extraction:

1. **Git tracking check**: Query git index for destination file status
2. **Overwrite protection**: Block if git-tracked and no --force
3. **Filesystem permissions**: Check write access to destination
4. **Name collisions**: Detect multiple source files mapping to same destination filename

---

## Data Invariants

### Must Always Hold

1. **Config-code consistency**: SubtreeEntry.extractions in config ↔ ExtractionMapping objects in memory
2. **Array ordering**: Extraction mappings execute in declared order
3. **Pattern scoping**: Glob patterns always scoped to subtree's prefix directory
4. **Path safety**: Destination paths never escape repository boundaries
5. **Atomicity**: Config updates are atomic (temp file + rename pattern)

### May Be Violated (Error Cases)

1. **Pattern matches files**: Pattern may match zero files (validation error, not invariant)
2. **Destination writability**: Destination may lack write permissions (I/O error)
3. **Git tracking status**: Destination files may be tracked (overwrite protection error)

---

## Performance Characteristics

### Space Complexity

| Entity | Size | Count | Total |
|--------|------|-------|-------|
| ExtractionMapping | ~100 bytes (YAML) | 3-10 per subtree | ~300-1000 bytes per subtree |
| SubtreeEntry (with extractions) | ~200-500 bytes | 5-20 per repo | ~1-10 KB total config |

**Estimate**: Typical subtree.yaml with extractions: 5-10 KB (negligible impact)

### Time Complexity

| Operation | Complexity | Notes |
|-----------|------------|-------|
| Load config | O(N) | N = subtrees, dominated by YAML parsing |
| Find subtree | O(N) | Linear search by name (case-insensitive) |
| Append mapping | O(N) | Load + append + save entire config |
| Match glob pattern | O(M * P) | M = files, P = pattern components |
| Execute mapping | O(M + C) | M = matched files, C = copy operations |

**Bottleneck**: File I/O (copying), not data model operations.

---

## Migration & Compatibility

### Backward Compatibility

**Existing configs remain valid**:
- SubtreeEntry without `extractions` field → `nil` (no error)
- Commands (init, add, update, remove) unaffected
- No schema version bump required

**Forward compatibility**:
- Old code ignores unknown `extractions` field (YAML parsing)
- New code handles missing field gracefully

### Migration Path

**From**: subtree.yaml without extraction mappings  
**To**: subtree.yaml with extraction mappings

**Process**: No migration needed (additive change)
1. User runs `subtree extract ... --persist` → adds mappings incrementally
2. Or manually edits YAML to add `extractions:` array

---

## Security Considerations

### Path Traversal Prevention

**Threat**: Malicious patterns or destinations escape repository

**Mitigation**:
- Destination paths validated (no `..`, must be relative)
- Glob matching scoped to subtree prefix only
- PathValidator reused for safety checks

### Arbitrary File Write

**Threat**: Extract overwrites critical files (e.g., .git/config)

**Mitigation**:
- Git-tracked files protected by default
- --force required for overwrite (explicit user intent)
- Destination validation prevents escaping repo boundaries

### Pattern Injection

**Threat**: Malicious glob patterns cause DoS (e.g., catastrophic backtracking)

**Mitigation**:
- No regex backtracking (using direct string/path matching)
- Pattern complexity limited by practical file system constraints
- Early termination on deep recursion

---

## Summary

### New Entities
1. **ExtractionMapping**: Saved extraction configuration (from, to, exclude)
2. **GlobPattern**: Internal parsed pattern representation (utility)

### Extended Entities
1. **SubtreeEntry**: Added optional `extractions: [ExtractionMapping]?` field

### Key Relationships
- SubtreeEntry (1) → (N) ExtractionMapping (one-to-many, optional)

### Validation Layers
1. Config-level: Schema and type validation
2. Command-level: Business logic validation
3. Runtime: Operational validation (git status, permissions)

**Next**: Create CLI contracts in contracts/ directory
