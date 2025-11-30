# Feature Specification: Brace Expansion with Embedded Path Separators

**Feature Branch**: `011-brace-expansion`  
**Created**: 2025-11-29  
**Status**: Complete (2025-11-30)  
**Input**: User description: "Add support for embedded separators patterns such as {a,b/c} in glob patterns"

## Overview

Extend the existing brace expansion syntax to support **embedded path separators** inside braces. The current GlobMatcher already supports `{a,b,c}` for simple alternatives (e.g., `*.{h,c}`), but patterns like `{A,B/C}` with `/` inside braces do not work correctly because the pattern is split by `/` before brace expansion occurs.

**Current limitation**: `Sources/{A,B/C}.swift` fails because the pattern is segmented as `["Sources", "{A,B/C}.swift"]` and the brace alternative `B/C` cannot match across path segments.

**Solution**: Pre-expand braces BEFORE the pattern reaches GlobMatcher, so `Sources/{A,B/C}.swift` becomes two separate patterns: `Sources/A.swift` and `Sources/B/C.swift`.

**Key Example**:
```bash
subtree extract --name swift-crypto \
  --from 'Sources/Crypto/Util/{PrettyBytes,SecureBytes,BoringSSL/RNG_boring}.swift'
```
Expands to 3 patterns:
- `Sources/Crypto/Util/PrettyBytes.swift`
- `Sources/Crypto/Util/SecureBytes.swift`
- `Sources/Crypto/Util/BoringSSL/RNG_boring.swift`

## Clarifications

### Session 2025-11-29

- Q: How much of brace expansion is already implemented? → A: GlobMatcher already supports basic `{a,b,c}` for file extensions (e.g., `*.{h,c}`), but embedded path separators `{a,b/c}` do NOT work because patterns are split by `/` before brace expansion
- Q: Should `--to` support brace expansion? → A: No — `--to` is a destination path, not a glob pattern; brace expansion only applies to `--from` and `--exclude` patterns
- Q: What's the implementation approach? → A: Pre-expand braces at CLI level via `BraceExpander` utility BEFORE passing patterns to GlobMatcher (bash semantics)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Basic Brace Expansion (Priority: P1)

A developer wants to extract multiple related files from different paths using a single compact pattern instead of specifying multiple `--from` flags.

**Why this priority**: Core value proposition — reduces verbosity and matches familiar bash syntax that developers already know.

**Independent Test**: Can be fully tested by providing a pattern with braces and verifying it expands to the expected multiple patterns before matching.

**Acceptance Scenarios**:

1. **Given** a subtree with files at `Sources/Foo.swift` and `Sources/Bar.swift`, **When** the user runs `extract --from 'Sources/{Foo,Bar}.swift'`, **Then** both files are matched and extracted.

2. **Given** a subtree with nested structure, **When** the user runs `extract --from 'Sources/{A,B/C}.swift'`, **Then** files at `Sources/A.swift` and `Sources/B/C.swift` are matched (embedded path separator supported).

3. **Given** a pattern without braces, **When** the user runs `extract --from 'Sources/*.swift'`, **Then** the pattern is passed through unchanged to glob matching (100% backward compatible).

---

### User Story 2 - Multiple Brace Groups (Priority: P2)

A developer wants to use multiple brace groups in a single pattern to generate a cartesian product of paths, matching bash behavior exactly.

**Why this priority**: Enables powerful pattern composition for complex directory structures without needing many separate patterns.

**Independent Test**: Can be tested by providing a pattern with two brace groups and verifying all combinations are generated.

**Acceptance Scenarios**:

1. **Given** a subtree with files in multiple directories, **When** the user runs `extract --from '{Sources,Tests}/{Foo,Bar}.swift'`, **Then** 4 patterns are generated: `Sources/Foo.swift`, `Sources/Bar.swift`, `Tests/Foo.swift`, `Tests/Bar.swift`.

2. **Given** a pattern with 3 brace groups, **When** the pattern is expanded, **Then** all combinations are generated (cartesian product of all groups).

---

### User Story 3 - Pass-Through for Invalid Patterns (Priority: P3)

A developer accidentally uses malformed brace syntax. The system should handle this gracefully following bash semantics.

**Why this priority**: Robustness and user-friendliness — malformed patterns shouldn't cause crashes or confusing errors when bash would treat them as literals.

**Independent Test**: Can be tested by providing various malformed patterns and verifying correct handling.

**Acceptance Scenarios**:

1. **Given** an unclosed brace pattern like `{a,b`, **When** expansion is attempted, **Then** the pattern is treated as literal text (no expansion, passed through unchanged).

2. **Given** a single-alternative pattern like `{a}`, **When** expansion is attempted, **Then** the pattern is treated as literal text (no comma = no expansion).

3. **Given** empty braces `{}`, **When** expansion is attempted, **Then** the pattern is treated as literal text.

---

### User Story 4 - Error on Empty Alternatives (Priority: P3)

A developer uses a pattern with empty alternatives like `{a,}` or `{,b}`. The system should reject this with a clear error to prevent accidental empty path components.

**Why this priority**: Safety — empty path components can cause unexpected behavior. This is a deliberate deviation from bash for safety.

**Independent Test**: Can be tested by providing patterns with empty alternatives and verifying error response.

**Acceptance Scenarios**:

1. **Given** a pattern with trailing empty alternative `{a,}`, **When** expansion is attempted, **Then** an error is returned with a clear message explaining empty alternatives are not supported.

2. **Given** a pattern with leading empty alternative `{,b}`, **When** expansion is attempted, **Then** an error is returned.

3. **Given** a pattern with middle empty alternative `{a,,b}`, **When** expansion is attempted, **Then** an error is returned.

---

### Edge Cases

- **Nested braces**: `{a,{b,c}}` — Not supported in MVP (treated as literal, no expansion). Deferred to backlog.
- **Literal braces in filenames**: Users needing literal `{` or `}` can use character class workaround `[{]` or `[}]`. Backslash escaping deferred to backlog.
- **Braces inside glob patterns**: `*.{swift,h}` should expand to `*.swift` and `*.h` (braces processed before glob matching).
- **Very long expansions**: Large cartesian products (e.g., 1000+ patterns) should be handled but may warrant a warning.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST expand brace patterns `{a,b,c}` into multiple patterns before glob matching
- **FR-002**: System MUST support embedded path separators inside braces (e.g., `{a,b/c}` expands to `a` and `b/c`)
- **FR-003**: System MUST support multiple brace groups in a single pattern with cartesian product expansion
- **FR-004**: System MUST apply brace expansion to `--from` and `--exclude` patterns
- **FR-005**: System MUST treat unclosed braces as literal text (no expansion)
- **FR-006**: System MUST treat single-alternative braces `{a}` as literal text (no expansion)
- **FR-007**: System MUST treat empty braces `{}` as literal text (no expansion)
- **FR-008**: System MUST return an error for patterns with empty alternatives (`{a,}`, `{,b}`, `{a,,b}`)
- **FR-009**: System MUST maintain 100% backward compatibility with existing patterns (no braces = no change)
- **FR-010**: System MUST expand braces before passing patterns to existing glob matching logic

### Non-Functional Requirements

- **NFR-001**: Brace expansion MUST complete in <10ms for typical patterns (≤10 alternatives, ≤3 brace groups)
- **NFR-002**: System SHOULD warn if expansion generates more than 100 patterns

### Out of Scope (Deferred to Backlog)

- Nested brace expansion `{a,{b,c}}`
- Backslash escaping for literal braces `\{`, `\}`
- Numeric ranges `{1..10}`

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can extract files from multiple nested paths (with different directory depths) using a single `--from` pattern
- **SC-002**: All existing extract operations work unchanged (100% backward compatibility)
- **SC-003**: Expansion of patterns with ≤3 brace groups completes in <10ms
- **SC-004**: Error messages for invalid patterns clearly explain the issue and suggest corrections
- **SC-005**: Patterns with embedded path separators like `Sources/{A,B/C}.swift` correctly match files at different directory depths
