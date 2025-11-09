# Research: Subtree Configuration Schema & Validation

**Feature**: 002-config-schema-validation | **Date**: 2025-10-26 | **Phase**: 0 (Research)

## Purpose

Document technical decisions, research findings, and rationale for implementation choices in the subtree.yaml schema and validation feature.

## Research Questions

### 1. Validation Architecture Pattern

**Question**: How should validation logic be structured to handle 31 functional requirements across multiple categories?

**Decision**: Separate validator types organized by concern

**Rationale**:
- **Modularity**: Each validator (Schema, Type, Format, Logic) handles a specific category of validation rules
- **Testability**: Each validator can be independently unit tested without coordinating with other validators
- **Single Responsibility**: Each validator class has one reason to change (its validation category)
- **Maintainability**: New validation rules can be added to the appropriate validator without affecting others
- **Clarity**: Validation logic maps naturally to the spec's FR organization

**Alternatives Considered**:
- **Single monolithic validator**: Rejected because a single class handling 31 rules becomes large (500+ lines), harder to test individual rules, and violates single responsibility principle
- **Rule-based validation engine**: Rejected because it adds abstraction overhead for a relatively small number of rules (31), increases complexity without proportional benefit, and makes debugging harder

**Implementation Approach**:
```swift
// Facade pattern coordinates validators
struct ConfigurationValidator {
    private let schemaValidator = SchemaValidator()
    private let typeValidator = TypeValidator()
    private let formatValidator = FormatValidator()
    private let logicValidator = LogicValidator()
    
    func validate(_ config: SubtreeConfiguration) -> [ValidationError] {
        // Collect errors from all validators
        // Return comprehensive error list
    }
}
```

---

### 2. YAML Error Handling Strategy

**Question**: How should YAML parsing errors from Yams library be handled to meet FR-026 (graceful errors with clear messages)?

**Decision**: Catch Yams errors and translate to user-friendly messages

**Rationale**:
- **User Experience**: Technical parser errors like "Scanner error at line 5, column 3" are not actionable for end users
- **FR-026 Compliance**: Spec requires "graceful" handling with "clear error messages"
- **Error Context**: Translation layer can add context about what the user should fix (e.g., "Check for missing quotes" or "Verify indentation")
- **Abstraction**: Isolates Yams implementation details from rest of codebase

**Alternatives Considered**:
- **Pass through with context**: Rejected because Yams errors remain technical and cryptic even with added file context
- **Pre-validate YAML syntax**: Rejected because it duplicates parser logic, misses edge cases, and adds complexity without eliminating the need for error translation

**Implementation Approach**:
```swift
struct YAMLErrorTranslator {
    func translateParsingError(_ error: Error, file: String) -> ValidationError {
        // Map Yams error types to user-friendly messages
        // Add file context and actionable guidance
        // Examples:
        // - Scanner error → "Invalid YAML syntax: unclosed string"
        // - Parser error → "Invalid YAML structure: incorrect indentation"
    }
}
```

**Error Translation Examples**:
| Yams Error | User-Friendly Message |
|------------|----------------------|
| Scanner.Error.unexpectedEnd | "Invalid YAML syntax at line X: Unexpected end of file. Check for unclosed strings or missing indentation." |
| Parser.Error.invalidYAML | "Invalid YAML structure: Incorrect indentation at line X. YAML requires consistent spacing." |
| Constructor.Error.dataTypeError | "Invalid data type at line X: Expected Y but got Z." |

---

### 3. Glob Pattern Validation Implementation

**Question**: How should glob pattern syntax be validated to support standard features (`**`, `*`, `?`, `[...]`, `{...}`) per FR-019?

**Decision**: Pattern parser approach for syntactic correctness

**Rationale**:
- **Accurate Validation**: Parser can detect specific syntax errors (unclosed braces, invalid escapes) and provide meaningful error messages
- **Format-Only**: Validates syntax without file system access, per spec clarification
- **Error Quality**: Can pinpoint exact character position of syntax errors
- **Spec Compliance**: Meets FR-019 requirement to validate pattern syntax

**Alternatives Considered**:
- **Regex validation**: Rejected because regex can only pattern-match basic structure; it misses subtle syntax errors like `{a,b` (unclosed brace) and provides poor error messages
- **Allowlist approach**: Rejected because it fails to catch typos and doesn't meet FR-019 requirement to validate syntax

**Implementation Approach**:
```swift
struct GlobPatternValidator {
    func validate(_ pattern: String) -> ValidationError? {
        // Validate standard glob features:
        // - ** (globstar/recursive)
        // - * (wildcard)
        // - ? (single character)
        // - [...] (character classes)
        // - {...} (brace expansion)
        
        // Check for:
        // - Matching braces in {a,b,c}
        // - Valid escape sequences
        // - Proper character class syntax [a-z]
        // - No invalid characters
        
        // Return specific error with character position if invalid
    }
}
```

**Validation Rules**:
- Braces: `{` must have matching `}`, commas separate alternatives
- Character classes: `[` must have matching `]`, ranges like `a-z` are valid
- Escapes: Backslash escapes special characters (`\*`, `\?`)
- Invalid: Unclosed braces/brackets, invalid escape sequences

**Examples**:
| Pattern | Valid? | Reason |
|---------|--------|--------|
| `src/**/*.{h,c}` | ✅ | All features valid |
| `{a,b,c}` | ✅ | Valid brace expansion |
| `{a,b` | ❌ | Unclosed brace |
| `[a-z]` | ✅ | Valid character class |
| `[a-` | ❌ | Unclosed character class |

---

### 4. Path Safety Validation

**Question**: What constitutes "safe" paths for `prefix` and `extracts.to` fields per FR-007 and FR-029?

**Decision**: Relative paths only, no `..` components, no absolute paths (leading `/`)

**Rationale**:
- **Security**: Prevents accidental or malicious writes outside repository
- **Portability**: Relative paths work across different systems and repository locations
- **Predictability**: All subtree operations contained within repository boundary
- **Spec Clarification**: Both `prefix` and `extracts.to` should use same safety rules

**Validation Rules**:
```swift
func isPathSafe(_ path: String) -> Bool {
    // Reject absolute paths
    if path.hasPrefix("/") { return false }
    
    // Reject parent directory navigation
    if path.contains("..") { return false }
    
    // Reject empty paths
    if path.isEmpty { return false }
    
    // Accept relative paths
    return true
}
```

**Examples**:
| Path | Safe? | Reason |
|------|-------|--------|
| `Vendors/secp256k1` | ✅ | Relative path |
| `Sources/lib/include/` | ✅ | Relative with subdirs |
| `/usr/local/lib` | ❌ | Absolute path |
| `../outside/repo` | ❌ | Parent directory navigation |
| `vendor/../exploit` | ❌ | Contains `..` |

---

## Technology Decisions

### YAML Parsing: Yams 6.1.0

**Choice**: Yams library (already project dependency)

**Rationale**:
- Already in use for project (no new dependency)
- Well-maintained Swift YAML parser
- Supports YAML 1.2 specification (FR-025)
- Comprehensive error reporting for translation layer

**No alternatives evaluated**: Yams already established in project dependencies

---

### Testing: Swift Testing (Built into Swift 6.1)

**Choice**: Swift Testing framework

**Rationale**:
- Already established in bootstrap spec (001-cli-bootstrap)
- Native to Swift 6.1 (no external dependency)
- Macro-based testing (`@Test`, `#expect`)
- First-class async/await support

**No alternatives evaluated**: Testing framework established by bootstrap spec per constitution

---

## Implementation Notes

### Test Coverage Strategy

**Unit Tests** (31 tests minimum, one per FR):
- Each FR gets at least one unit test
- Tests organized by validator type (Schema, Type, Format, Logic)
- Model tests verify data structure parsing
- Parser tests verify YAML error translation

**Integration Tests**:
- End-to-end validation workflows
- Valid config scenarios (P1 user stories)
- Invalid config scenarios (P1 user stories - error messages)
- Extract pattern scenarios (P2 user stories)

**Test Organization**:
```
SubtreeLibTests/ConfigurationTests/
├── Models/ (3 tests - one per model)
├── Validation/ (4+ tests - validators)
├── Parsing/ (2+ tests - parser + translator)
└── Patterns/ (1+ test - glob validator)

IntegrationTests/
└── ConfigValidationIntegrationTests.swift (multiple scenarios)
```

---

### Performance Considerations

**Validation Time**: Target <1 second for typical configs (<100 subtrees)

**Strategy**:
- Validation is format-only (no I/O, no network)
- Sequential validation (no need for parallelization at this scale)
- Early exit on schema errors (don't validate types if schema invalid)
- Error accumulation (collect all errors, don't fail fast)

**Justification**: Format-only validation is CPU-bound and should complete in milliseconds. The 1-second target provides ample margin for configs with 100 subtrees, each with multiple extract patterns.

---

## Research Complete

All technical unknowns resolved. Ready for Phase 1 (data model, contracts, quickstart).

**Next Steps**:
1. Generate data-model.md (Phase 1)
2. Generate contracts/ (Phase 1)
3. Generate quickstart.md (Phase 1)
4. Update agent context (Phase 1)
