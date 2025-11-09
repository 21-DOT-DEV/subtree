# Contract: subtree.yaml Schema

**Feature**: 002-config-schema-validation | **Version**: 1.0.0 | **Status**: Draft

## Purpose

This contract defines the structure and validation rules for `subtree.yaml` configuration files. Any code that parses or validates subtree.yaml MUST conform to this schema.

## Schema Specification

### Top-Level Structure

```yaml
subtrees:  # REQUIRED, MAY be empty array
  - [SubtreeEntry]
  - [SubtreeEntry]
  # ...
```

**Validation**:
- MUST have `subtrees` key at top level
- `subtrees` MUST be an array
- Empty array `subtrees: []` is VALID
- Unknown top-level keys are INVALID (rejected with error)

**FR Coverage**: FR-001, FR-031

---

### SubtreeEntry Structure

```yaml
name: string              # REQUIRED
remote: string            # REQUIRED
prefix: string            # REQUIRED
commit: string            # REQUIRED
tag: string               # OPTIONAL
branch: string            # OPTIONAL
squash: boolean           # OPTIONAL
extracts:                 # OPTIONAL
  - [ExtractPattern]
  - [ExtractPattern]
  # ...
```

#### Required Fields

| Field | Type | Format | Example |
|-------|------|--------|---------|
| `name` | string | Non-empty, unique across all entries | `secp256k1` |
| `remote` | string | Git URL (https://, git@, file://) | `https://github.com/org/repo` |
| `prefix` | string | Relative path, no `..`, no leading `/` | `Vendors/secp256k1` |
| `commit` | string | 40 hexadecimal characters (SHA-1 hash) | `bf4f0bc877e4d6771e48611cc9e66ab9db576bac` |

**FR Coverage**: FR-002, FR-005, FR-006, FR-007, FR-008, FR-030

#### Optional Fields

| Field | Type | Format | Example |
|-------|------|--------|---------|
| `tag` | string | Non-empty | `v0.7.0` |
| `branch` | string | Non-empty | `main` |
| `squash` | boolean | `true` or `false` | `true` |
| `extracts` | array | Non-empty array of ExtractPattern | See below |

**FR Coverage**: FR-003, FR-009, FR-010, FR-011

#### Validation Rules

**Type Validation**:
- `name`: Non-empty string
- `remote`: Valid git URL format (format check only, no reachability test)
  - Accepted: `https://`, `git@`, `file://`
  - Rejected: `ftp://`, `http://` (non-SSL), malformed URLs
- `prefix`: Relative path validation
  - Rejected: Leading `/` (absolute path)
  - Rejected: Contains `..` component
  - Accepted: `dir/subdir`, `dir/`, `dir`
- `commit`: SHA-1 hash format (format check only, no existence test)
  - MUST be exactly 40 characters
  - MUST be hexadecimal [0-9a-f]
  - Case insensitive
- `tag`, `branch`: Non-empty strings when present
- `squash`: Boolean values only (`true`, `false`)
  - Rejected: String `"true"`, number `1`, etc.
- `extracts`: Non-empty array when present

**Logical Constraints**:
- MUST NOT specify both `tag` and `branch` (mutual exclusivity)
- MUST accept `commit` alone (without `tag` or `branch`)
- MUST accept `tag` + `commit` together
- MUST accept `branch` + `commit` together
- MUST reject unknown fields (strict schema enforcement)

**Uniqueness**:
- `name` field MUST be unique across all SubtreeEntry instances

**FR Coverage**: FR-012, FR-013, FR-014, FR-015, FR-016, FR-030

---

### ExtractPattern Structure

```yaml
from: string              # REQUIRED
to: string                # REQUIRED
exclude:                  # OPTIONAL
  - string
  - string
  # ...
```

#### Fields

| Field | Type | Format | Example |
|-------|------|--------|---------|
| `from` | string | Valid glob pattern | `src/**/*.{h,c}` |
| `to` | string | Relative path, no `..`, no leading `/` | `Sources/lib/src/` |
| `exclude` | array of strings | Valid glob patterns | `["src/**/test*"]` |

**FR Coverage**: FR-004, FR-018

#### Validation Rules

**Required Fields**:
- MUST have `from` field
- MUST have `to` field

**Glob Pattern Validation** (`from` and `exclude` elements):
- MUST support standard glob features:
  - `**` - Globstar (recursive directory match)
  - `*` - Wildcard (match any characters except `/`)
  - `?` - Single character match
  - `[...]` - Character class (e.g., `[a-z]`, `[0-9]`)
  - `{...}` - Brace expansion (e.g., `{h,c}`, `{test,spec}`)
- MUST validate syntax:
  - Matching braces: `{` paired with `}`
  - Matching brackets: `[` paired with `]`
  - Valid escape sequences: `\*`, `\?`, etc.
- Format validation only (no file system access)

**Path Safety** (`to` field):
- MUST be relative path (no leading `/`)
- MUST NOT contain `..` component
- Same rules as SubtreeEntry `prefix`

**Strict Schema**:
- MUST reject unknown fields

**FR Coverage**: FR-017, FR-019, FR-029

---

## Complete Examples

### Minimal Configuration

```yaml
subtrees:
  - name: minimal
    remote: https://github.com/org/repo
    prefix: Vendors/minimal
    commit: abc123def456789012345678901234567890abcd
```

### Configuration with Tag

```yaml
subtrees:
  - name: secp256k1
    remote: https://github.com/bitcoin-core/secp256k1
    prefix: Vendors/secp256k1
    commit: bf4f0bc877e4d6771e48611cc9e66ab9db576bac
    tag: v0.7.0
    squash: true
```

### Configuration with Branch

```yaml
subtrees:
  - name: feature-lib
    remote: git@github.com:org/repo.git
    prefix: Vendors/feature-lib
    commit: 1234567890abcdef1234567890abcdef12345678
    branch: develop
```

### Configuration with Extracts

```yaml
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
      - from: src/*.h
        to: Sources/libsecp256k1/src/
      - from: src/**/*.{h,c}
        to: Sources/libsecp256k1/src/
        exclude:
          - src/**/bench*/**
          - src/**/test*/**
          - src/ctime_tests.c
```

### Multiple Subtrees

```yaml
subtrees:
  - name: secp256k1
    remote: https://github.com/bitcoin-core/secp256k1
    prefix: Vendors/secp256k1
    commit: bf4f0bc877e4d6771e48611cc9e66ab9db576bac
    tag: v0.7.0
    
  - name: another-lib
    remote: https://github.com/org/another
    prefix: Vendors/another
    commit: 1234567890abcdef1234567890abcdef12345678
    branch: main
    squash: false
```

### Empty Configuration (Valid)

```yaml
subtrees: []
```

---

## Invalid Examples

### Missing Required Field

```yaml
subtrees:
  - name: bad
    remote: https://github.com/org/repo
    # Missing: prefix, commit
```

**Error**: "Required field 'prefix' is missing in subtree 'bad'"

### Invalid Commit Format

```yaml
subtrees:
  - name: bad
    remote: https://github.com/org/repo
    prefix: Vendors/bad
    commit: short123  # Only 8 characters
```

**Error**: "Invalid commit hash format in subtree 'bad': expected 40 hex characters, got 8"

### Both Tag and Branch

```yaml
subtrees:
  - name: bad
    remote: https://github.com/org/repo
    prefix: Vendors/bad
    commit: abc123def456789012345678901234567890abcd
    tag: v1.0.0
    branch: main  # Violation: can't have both
```

**Error**: "Cannot specify both 'tag' and 'branch' in subtree 'bad'"

### Unsafe Path

```yaml
subtrees:
  - name: bad
    remote: https://github.com/org/repo
    prefix: ../outside/repo  # Contains ..
    commit: abc123def456789012345678901234567890abcd
```

**Error**: "Path contains unsafe component '..' in subtree 'bad', field 'prefix'"

### Duplicate Names

```yaml
subtrees:
  - name: lib
    remote: https://github.com/org/repo1
    prefix: Vendors/lib1
    commit: abc123def456789012345678901234567890abcd
    
  - name: lib  # Duplicate
    remote: https://github.com/org/repo2
    prefix: Vendors/lib2
    commit: 1234567890abcdef1234567890abcdef12345678
```

**Error**: "Duplicate subtree name 'lib' at index 1"

### Unknown Field

```yaml
subtrees:
  - name: bad
    remote: https://github.com/org/repo
    prefix: Vendors/bad
    commit: abc123def456789012345678901234567890abcd
    typo_field: value  # Unknown field
```

**Error**: "Unknown field 'typo_field' in subtree 'bad'"

### Invalid Glob Pattern

```yaml
subtrees:
  - name: bad
    remote: https://github.com/org/repo
    prefix: Vendors/bad
    commit: abc123def456789012345678901234567890abcd
    extracts:
      - from: "src/{a,b"  # Unclosed brace
        to: Sources/lib/
```

**Error**: "Invalid glob pattern in subtree 'bad', extracts[0].from: unclosed brace"

---

## Backward Compatibility

**Version 1.0.0** - Initial schema definition

Future versions MUST maintain backward compatibility with 1.0.0 configs:
- New optional fields MAY be added
- Required fields MUST NOT be removed
- Validation rules MUST NOT become more strict for existing fields
- Schema version MAY be added as optional top-level field in future

---

## Testing Contract Compliance

### Required Test Cases

Every parser/validator implementation MUST pass these test cases:

**Valid Configs**:
1. Minimal (name, remote, prefix, commit only)
2. With optional tag
3. With optional branch
4. With optional squash
5. With extracts (single pattern)
6. With extracts (multiple patterns with exclusions)
7. Multiple subtrees
8. Empty subtrees array

**Invalid Configs** (MUST reject):
1. Missing required field (name, remote, prefix, commit)
2. Invalid commit format (not 40 hex chars)
3. Both tag and branch specified
4. Unknown field
5. Duplicate subtree names
6. Unsafe path (absolute or `..`)
7. Invalid glob pattern syntax
8. Empty string in required field
9. Wrong type (string instead of boolean)
10. Malformed YAML syntax

**FR Coverage**: SC-003 requires all 31 FRs have tests

---

## Contract Versioning

- **Version**: 1.0.0 (Initial)
- **Last Updated**: 2025-10-26
- **Breaking Changes**: None (initial version)

---

## References

- Spec: [spec.md](../spec.md)
- Data Model: [data-model.md](../data-model.md)
- Functional Requirements: FR-001 through FR-031 in spec.md
