# Data Model: Subtree Configuration Schema & Validation

**Feature**: 002-config-schema-validation | **Date**: 2025-10-26 | **Phase**: 1 (Design)

## Purpose

Document the data structures, validation rules, and relationships for subtree.yaml configuration parsing and validation.

## Entity Overview

```
SubtreeConfiguration (root)
└── subtrees: [SubtreeEntry]
    └── extracts: [ExtractPattern] (optional)

ValidationError (validation results)
```

---

## Entity: SubtreeConfiguration

**Purpose**: Represents the complete subtree.yaml file structure

**Responsibilities**:
- Contains collection of subtree entries
- Represents top-level configuration document

### Fields

| Field | Type | Required | Constraints | FR Reference |
|-------|------|----------|-------------|--------------|
| `subtrees` | Array<SubtreeEntry> | Yes | May be empty | FR-001, FR-031 |

### Validation Rules

- **FR-001**: MUST have top-level `subtrees` array
- **FR-031**: Empty `subtrees` array is valid (represents project with no subtrees)
- **FR-030**: All SubtreeEntry names MUST be unique within array

### Relationships

- **Contains many**: SubtreeEntry (0..n relationship)

### Example YAML

```yaml
subtrees:
  - name: secp256k1
    remote: https://github.com/bitcoin-core/secp256k1
    prefix: Vendors/secp256k1
    commit: bf4f0bc877e4d6771e48611cc9e66ab9db576bac
    tag: v0.7.0
    squash: true
  - name: another-lib
    remote: https://github.com/org/repo
    prefix: Vendors/another
    commit: abc123def456
    branch: main
```

---

## Entity: SubtreeEntry

**Purpose**: Represents a single subtree dependency definition

**Responsibilities**:
- Defines subtree source (remote repository)
- Specifies subtree location (prefix path)
- Tracks subtree version (commit, optionally tag/branch)
- Optionally defines file extraction rules

### Fields

| Field | Type | Required | Constraints | FR Reference |
|-------|------|----------|-------------|--------------|
| `name` | String | Yes | Non-empty, unique | FR-005, FR-030 |
| `remote` | String | Yes | Valid git URL format | FR-006 |
| `prefix` | String | Yes | Relative path, no `..` | FR-007 |
| `commit` | String | Yes | 40 hex characters (SHA-1) | FR-008 |
| `tag` | String | No | Non-empty | FR-009 |
| `branch` | String | No | Non-empty | FR-009 |
| `squash` | Boolean | No | true/false | FR-010 |
| `extracts` | Array<ExtractPattern> | No | Non-empty if present | FR-011 |

### Validation Rules

**Type Validation**:
- **FR-005**: `name` MUST be non-empty string
- **FR-006**: `remote` MUST match git URL format (https://, git@, file://)
  - Format validation only, no reachability check
- **FR-007**: `prefix` MUST be relative path (no leading `/`, no `..` components)
- **FR-008**: `commit` MUST match SHA-1 hash format (40 hexadecimal characters)
  - Format validation only, no existence check
- **FR-009**: `tag` and `branch`, when present, MUST be non-empty strings
- **FR-010**: `squash`, when present, MUST be boolean value
- **FR-011**: `extracts`, when present, MUST be non-empty array

**Logical Constraints**:
- **FR-012**: MUST NOT specify both `tag` and `branch` (mutual exclusivity)
- **FR-013**: MUST accept `commit` only (without tag or branch)
- **FR-014**: MUST accept `tag` and `commit` together
- **FR-015**: MUST accept `branch` and `commit` together
- **FR-016**: MUST reject unknown fields with clear error

**Uniqueness**:
- **FR-030**: `name` MUST be unique across all SubtreeEntry instances in configuration

### Relationships

- **Belongs to**: SubtreeConfiguration
- **Contains many**: ExtractPattern (0..n relationship)

### State Transitions

N/A - SubtreeEntry is a value type with no state machine

### Example YAML

```yaml
# Minimal (commit only)
name: minimal
remote: https://github.com/org/repo
prefix: Vendors/minimal
commit: abc123def456

# With tag
name: tagged
remote: https://github.com/org/repo
prefix: Vendors/tagged
commit: abc123def456
tag: v1.0.0
squash: true

# With branch
name: branched
remote: git@github.com:org/repo.git
prefix: Vendors/branched
commit: abc123def456
branch: develop

# With extracts
name: extracted
remote: https://github.com/org/repo
prefix: Vendors/extracted
commit: abc123def456
extracts:
  - from: include/*.h
    to: Sources/lib/include/
  - from: src/**/*.{h,c}
    to: Sources/lib/src/
    exclude:
      - src/**/test*
```

---

## Entity: ExtractPattern

**Purpose**: Represents a file extraction rule for selective file copying from subtree

**Responsibilities**:
- Defines source glob pattern for files to extract
- Specifies destination path for extracted files
- Optionally excludes files matching exclusion patterns

### Fields

| Field | Type | Required | Constraints | FR Reference |
|-------|------|----------|-------------|--------------|
| `from` | String | Yes | Valid glob pattern | FR-018, FR-019 |
| `to` | String | Yes | Relative path, no `..` | FR-018, FR-029 |
| `exclude` | Array<String> | No | Valid glob patterns | FR-019 |

### Validation Rules

- **FR-018**: MUST have both `from` and `to` fields
- **FR-019**: `from` MUST be valid glob pattern supporting:
  - `**` (globstar/recursive)
  - `*` (wildcard)
  - `?` (single character)
  - `[...]` (character classes)
  - `{...}` (brace expansion)
- **FR-019**: `exclude` patterns, when present, MUST be valid glob patterns
- **FR-029**: `to` MUST be relative path (no leading `/`, no `..` components)
- **FR-017**: MUST reject unknown fields with clear error

### Relationships

- **Belongs to**: SubtreeEntry

### State Transitions

N/A - ExtractPattern is a value type with no state machine

### Example YAML

```yaml
# Simple pattern
from: include/*.h
to: Sources/lib/include/

# Recursive with brace expansion
from: src/**/*.{h,c}
to: Sources/lib/src/

# With exclusions
from: src/**/*
to: Sources/lib/
exclude:
  - src/**/bench*/**
  - src/**/test*/**
  - src/precompute_*.c
```

---

## Entity: ValidationError

**Purpose**: Represents a validation failure with context for user-friendly error reporting

**Responsibilities**:
- Identifies which subtree entry failed validation
- Specifies which field failed validation
- Provides descriptive error message
- Offers actionable guidance for fixing the error

### Fields

| Field | Type | Required | Description | FR Reference |
|-------|------|----------|-------------|--------------|
| `entry` | String | Yes | Subtree name or index | FR-020 |
| `field` | String | Yes | Field name that failed | FR-021 |
| `message` | String | Yes | Descriptive error message | FR-022 |
| `suggestion` | String | No | How to fix the error | FR-023 |

### Validation Rules

N/A - ValidationError is output only, not validated

### Error Collection

- **FR-024**: Validator MUST collect and report all validation errors, not just first one

### Relationships

- **Produced by**: ConfigurationValidator and component validators
- **Consumed by**: User-facing error reporting

### Examples

```swift
// Missing required field
ValidationError(
    entry: "secp256k1",
    field: "commit",
    message: "Required field 'commit' is missing",
    suggestion: "Add a commit field with a 40-character SHA-1 hash"
)

// Invalid commit format
ValidationError(
    entry: "my-lib",
    field: "commit",
    message: "Invalid commit hash format: expected 40 hex characters, got 38",
    suggestion: "Verify the commit hash is a complete SHA-1 hash (40 characters)"
)

// Mutual exclusivity violation
ValidationError(
    entry: "another-lib",
    field: "tag/branch",
    message: "Cannot specify both 'tag' and 'branch' for the same subtree",
    suggestion: "Remove either 'tag' or 'branch' field"
)

// Duplicate name
ValidationError(
    entry: "secp256k1",
    field: "name",
    message: "Duplicate subtree name 'secp256k1' at index 2",
    suggestion: "Ensure each subtree has a unique name"
)

// Path safety violation
ValidationError(
    entry: "unsafe-lib",
    field: "prefix",
    message: "Path contains unsafe component '..'",
    suggestion: "Use relative paths only, without '..' or leading '/'"
)
```

---

## Validation Flow

```
1. Parse YAML → SubtreeConfiguration
   ├─ Success → Proceed to validation
   └─ Failure → Return ValidationError (YAML syntax error via YAMLErrorTranslator)

2. Validate SubtreeConfiguration (ConfigurationValidator)
   ├─ SchemaValidator: Check top-level structure
   ├─ For each SubtreeEntry:
   │   ├─ TypeValidator: Check field types and presence
   │   ├─ FormatValidator: Check URL format, commit format, path safety
   │   ├─ LogicValidator: Check mutual exclusivity, uniqueness
   │   └─ For each ExtractPattern:
   │       ├─ TypeValidator: Check required fields
   │       ├─ FormatValidator: Check path safety
   │       └─ GlobPatternValidator: Check pattern syntax
   └─ Collect all ValidationError instances

3. Return Results
   ├─ Empty array → Configuration valid
   └─ Non-empty array → Configuration invalid, report all errors
```

---

## Implementation Mapping

### Swift Types (Tentative)

```swift
// Models
struct SubtreeConfiguration: Codable {
    let subtrees: [SubtreeEntry]
}

struct SubtreeEntry: Codable {
    let name: String
    let remote: String
    let prefix: String
    let commit: String
    let tag: String?
    let branch: String?
    let squash: Bool?
    let extracts: [ExtractPattern]?
}

struct ExtractPattern: Codable {
    let from: String
    let to: String
    let exclude: [String]?
}

// Validation
struct ValidationError {
    let entry: String
    let field: String
    let message: String
    let suggestion: String?
}

protocol Validator {
    func validate(_ config: SubtreeConfiguration) -> [ValidationError]
    func validate(_ entry: SubtreeEntry, index: Int) -> [ValidationError]
    func validate(_ pattern: ExtractPattern, entry: String) -> [ValidationError]
}
```

---

## Data Model Complete

All entities, fields, relationships, and validation rules documented. Ready for contract generation and quickstart guide.

**Next Steps**:
1. Generate contracts/ (Phase 1)
2. Generate quickstart.md (Phase 1)
3. Update agent context (Phase 1)
