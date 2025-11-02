# Contract: Validation Error Format

**Feature**: 002-config-schema-validation | **Version**: 1.0.0 | **Status**: Draft

## Purpose

This contract defines the structure and content of validation error messages. Any code that reports validation errors MUST conform to this format to ensure consistent, actionable error reporting.

## Error Message Structure

### Required Components

Every validation error MUST include:

1. **Entry Identification** - Which subtree entry failed (name or index)
2. **Field Identification** - Which field caused the error
3. **Descriptive Message** - What went wrong
4. **Actionable Guidance** - How to fix it (when applicable)

**FR Coverage**: FR-020, FR-021, FR-022, FR-023

---

## ValidationError Data Structure

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `entry` | String | Yes | Subtree name or "index N" |
| `field` | String | Yes | Field name that failed validation |
| `message` | String | Yes | Clear description of the error |
| `suggestion` | String | No | How to fix the error |

### Swift Representation (Reference)

```swift
struct ValidationError {
    let entry: String        // "secp256k1" or "index 0"
    let field: String        // "commit" or "extracts[0].from"
    let message: String      // "Invalid commit hash format..."
    let suggestion: String?  // "Verify the commit hash is..."
}
```

---

## Error Categories

### Schema Errors

**Category**: Top-level structure violations

**Format**:
- Entry: `"configuration"`
- Field: Top-level key name
- Message: Describe structural issue
- Suggestion: How to fix structure

**Examples**:

```
Entry: "configuration"
Field: "subtrees"
Message: "Missing required top-level field 'subtrees'"
Suggestion: "Add a 'subtrees' key at the top level with an array value"
```

```
Entry: "configuration"
Field: "unknown_field"
Message: "Unknown top-level field 'unknown_field'"
Suggestion: "Remove 'unknown_field' or check for typos. Valid fields: subtrees"
```

**FR Coverage**: FR-001, FR-016, FR-027, FR-028

---

### Type Errors

**Category**: Field type mismatches

**Format**:
- Entry: Subtree name or index
- Field: Field name
- Message: "Expected {type}, got {actual}"
- Suggestion: Correct type and example

**Examples**:

```
Entry: "secp256k1"
Field: "squash"
Message: "Expected boolean, got string \"true\""
Suggestion: "Use unquoted boolean: squash: true (not \"true\")"
```

```
Entry: "my-lib"
Field: "extracts"
Message: "Expected array, got object"
Suggestion: "Extracts must be an array. Use: extracts: [{from: ..., to: ...}]"
```

**FR Coverage**: FR-010, FR-011

---

### Format Errors

**Category**: Field format violations (URLs, paths, commit hashes, glob patterns)

**Format**:
- Entry: Subtree name or index
- Field: Field name
- Message: "Invalid {format}: {specific issue}"
- Suggestion: Correct format and example

**Examples**:

```
Entry: "secp256k1"
Field: "commit"
Message: "Invalid commit hash format: expected 40 hex characters, got 38"
Suggestion: "Verify the commit hash is a complete SHA-1 hash (40 characters). Example: bf4f0bc877e4d6771e48611cc9e66ab9db576bac"
```

```
Entry: "my-lib"
Field: "remote"
Message: "Invalid git URL format: unsupported protocol 'ftp'"
Suggestion: "Use https://, git@, or file:// protocols. Example: https://github.com/org/repo"
```

```
Entry: "unsafe-lib"
Field: "prefix"
Message: "Path contains unsafe component '..'"
Suggestion: "Use relative paths only, without '..' or leading '/'. Example: Vendors/lib"
```

```
Entry: "glob-lib"
Field: "extracts[0].from"
Message: "Invalid glob pattern: unclosed brace at position 5"
Suggestion: "Check brace syntax. Example: {a,b,c} requires matching braces"
```

**FR Coverage**: FR-006, FR-007, FR-008, FR-019, FR-029

---

### Logic Errors

**Category**: Cross-field constraint violations

**Format**:
- Entry: Subtree name or index
- Field: Involved field names (e.g., "tag/branch")
- Message: Describe constraint violation
- Suggestion: How to resolve conflict

**Examples**:

```
Entry: "my-lib"
Field: "tag/branch"
Message: "Cannot specify both 'tag' and 'branch' for the same subtree"
Suggestion: "Remove either 'tag' or 'branch' field. Use tag for releases, branch for development tracking"
```

```
Entry: "duplicate-lib"
Field: "name"
Message: "Duplicate subtree name 'my-lib' at index 2"
Suggestion: "Ensure each subtree has a unique name. Consider: my-lib-2, my-lib-dev, etc."
```

**FR Coverage**: FR-012, FR-030

---

### Missing Field Errors

**Category**: Required fields not present

**Format**:
- Entry: Subtree name or index
- Field: Missing field name
- Message: "Required field '{field}' is missing"
- Suggestion: Add field with example

**Examples**:

```
Entry: "incomplete-lib"
Field: "commit"
Message: "Required field 'commit' is missing"
Suggestion: "Add a commit field with a 40-character SHA-1 hash. Example: commit: bf4f0bc877e4d6771e48611cc9e66ab9db576bac"
```

```
Entry: "index 0"
Field: "name"
Message: "Required field 'name' is missing"
Suggestion: "Add a name field to identify this subtree. Example: name: my-lib"
```

```
Entry: "extract-lib"
Field: "extracts[1].to"
Message: "Required field 'to' is missing in extract pattern"
Suggestion: "Add a 'to' field specifying the destination path. Example: to: Sources/lib/"
```

**FR Coverage**: FR-002, FR-018

---

### YAML Parsing Errors

**Category**: YAML syntax errors

**Format**:
- Entry: "configuration"
- Field: "yaml"
- Message: User-friendly translation of parser error
- Suggestion: Fix for common YAML mistakes

**Examples**:

```
Entry: "configuration"
Field: "yaml"
Message: "Invalid YAML syntax at line 5: unclosed string"
Suggestion: "Check for missing closing quote. YAML strings with special characters need quotes"
```

```
Entry: "configuration"
Field: "yaml"
Message: "Invalid YAML structure at line 8: incorrect indentation"
Suggestion: "YAML requires consistent spacing (2 or 4 spaces). Tabs are not allowed"
```

```
Entry: "configuration"
Field: "yaml"
Message: "Unexpected end of file"
Suggestion: "Check for unclosed brackets, braces, or quotes"
```

**FR Coverage**: FR-026

---

## Error Collection and Reporting

### Multiple Errors

**Requirement**: Validator MUST collect ALL validation errors, not just the first one

**FR Coverage**: FR-024

**Format**: Array of ValidationError instances

```swift
[
    ValidationError(
        entry: "lib1",
        field: "commit",
        message: "Invalid commit hash format: expected 40 hex characters, got 38",
        suggestion: "Verify the commit hash is a complete SHA-1 hash"
    ),
    ValidationError(
        entry: "lib2",
        field: "tag/branch",
        message: "Cannot specify both 'tag' and 'branch' for the same subtree",
        suggestion: "Remove either 'tag' or 'branch' field"
    ),
    ValidationError(
        entry: "lib3",
        field: "name",
        message: "Duplicate subtree name 'lib1' at index 2",
        suggestion: "Ensure each subtree has a unique name"
    )
]
```

### Output Format

**Console Output** (for CLI):

```
Configuration validation failed with 3 errors:

1. Subtree 'lib1', field 'commit':
   Invalid commit hash format: expected 40 hex characters, got 38
   → Verify the commit hash is a complete SHA-1 hash

2. Subtree 'lib2', field 'tag/branch':
   Cannot specify both 'tag' and 'branch' for the same subtree
   → Remove either 'tag' or 'branch' field

3. Subtree 'lib3', field 'name':
   Duplicate subtree name 'lib1' at index 2
   → Ensure each subtree has a unique name
```

**Programmatic Access** (for library use):

```swift
let errors: [ValidationError] = validator.validate(config)
if !errors.isEmpty {
    // Handle errors programmatically
    for error in errors {
        print("[\(error.entry)] \(error.field): \(error.message)")
        if let suggestion = error.suggestion {
            print("  Suggestion: \(suggestion)")
        }
    }
}
```

---

## Message Quality Guidelines

### Clarity Requirements

1. **Be Specific**: "Invalid commit hash format: expected 40 hex characters, got 38"
   - NOT: "Invalid commit"

2. **Identify Location**: "Subtree 'secp256k1', field 'prefix'"
   - NOT: "Path error"

3. **Explain the Rule**: "Cannot specify both 'tag' and 'branch'"
   - NOT: "Conflict detected"

4. **Provide Examples**: "Example: commit: bf4f0bc877e4d6771e48611cc9e66ab9db576bac"
   - NOT: "Check format"

5. **Use Actionable Language**: "Remove either 'tag' or 'branch' field"
   - NOT: "Fix this"

### Tone

- **Professional**: Avoid condescending language
- **Helpful**: Focus on fixing, not blaming
- **Concise**: Get to the point quickly
- **Consistent**: Use same terminology throughout

---

## Testing Requirements

### Error Message Tests

Every error category MUST have tests verifying:

1. **Correct entry identification** - Error points to right subtree
2. **Correct field identification** - Error points to right field
3. **Message clarity** - Error message is descriptive
4. **Suggestion presence** - Actionable guidance provided (when applicable)
5. **Error collection** - Multiple errors reported together

### Example Test Cases

```swift
@Test("Missing required field error format")
func testMissingFieldError() {
    let config = """
    subtrees:
      - name: incomplete
        remote: https://github.com/org/repo
        prefix: Vendors/incomplete
    """
    
    let errors = validator.validate(parseYAML(config))
    
    #expect(errors.count == 1)
    #expect(errors[0].entry == "incomplete")
    #expect(errors[0].field == "commit")
    #expect(errors[0].message.contains("Required field 'commit' is missing"))
    #expect(errors[0].suggestion != nil)
}

@Test("Multiple errors collected")
func testMultipleErrors() {
    let config = """
    subtrees:
      - name: bad1
        remote: https://github.com/org/repo
        prefix: ../unsafe
        commit: short
      - name: bad1
        remote: https://github.com/org/repo2
        prefix: Vendors/dup
        commit: 1234567890abcdef1234567890abcdef12345678
    """
    
    let errors = validator.validate(parseYAML(config))
    
    // Should collect ALL errors: unsafe path, short commit, duplicate name
    #expect(errors.count >= 3)
}
```

---

## Backward Compatibility

**Version 1.0.0** - Initial error format

Future versions MAY:
- Add new error categories
- Add new fields to ValidationError (must be optional)
- Improve message clarity

Future versions MUST NOT:
- Remove required fields
- Change field meanings
- Break programmatic parsing of errors

---

## Contract Versioning

- **Version**: 1.0.0 (Initial)
- **Last Updated**: 2025-10-26
- **Breaking Changes**: None (initial version)

---

## References

- Spec: [spec.md](../spec.md)
- Data Model: [data-model.md](../data-model.md)
- YAML Schema: [yaml-schema.md](./yaml-schema.md)
- Error Reporting Requirements: FR-020 through FR-024 in spec.md
