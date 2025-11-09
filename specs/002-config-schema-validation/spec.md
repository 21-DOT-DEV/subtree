# Feature Specification: Subtree Configuration Schema & Validation

**Feature Branch**: `002-config-schema-validation`  
**Created**: 2025-10-26  
**Status**: Draft  
**Input**: User description: "Create subtree.yaml schema & validation (documents fields, types, and validators; includes unit tests for parsing/validation)."

## Clarifications

### Session 2025-10-26

- Q: How should the system handle duplicate subtree names within the same configuration file? → A: Require unique names (reject duplicates) to keep CLI commands unambiguous. Users can still have the same repository at multiple prefixes with different names (e.g., secp256k1-main and secp256k1-experimental).
- Q: Should validation check format only or also verify existence (commit exists in repo, remote is reachable, paths exist)? → A: Format-only validation at config parse time. This keeps validation fast, deterministic, and doesn't require network access or git operations. Commands can validate existence when they actually need to use the values.
- Q: What level of glob pattern validation should be performed on extract patterns? → A: Validate standard glob features including `**`, `*`, `?`, `[...]`, `{...}` brace expansion. This covers real-world use cases (e.g., `src/**/*.{h,c}`) while catching malformed patterns (unclosed braces, invalid escapes).
- Q: Should path safety validation (no `..`, no absolute paths) apply to both `prefix` and `extracts.to`? → A: Validate both `prefix` and `extracts.to` using the same safety rules (relative paths only, no `..`, no absolute paths). This prevents accidental writes outside the repository for both subtree placement and file extraction.
- Q: Should an empty subtrees array be considered valid? → A: Accept empty array as valid. This allows users to initialize a project with an empty config file and add subtrees incrementally.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Valid Configuration Loading (Priority: P1)

As a developer, I need to define my subtree dependencies in a subtree.yaml file and have the tool parse and validate it, so that I can manage my subtrees declaratively without manually running git commands.

**Why this priority**: This is the foundational capability that enables all other features - without parsing and validating the config file, none of the subtree commands (add, update, remove) can function.

**Independent Test**: Can be fully tested by creating a valid subtree.yaml file and verifying the parser reads it without errors. Delivers immediate value by enabling declarative subtree management.

**Acceptance Scenarios**:

1. **Given** a subtree.yaml file with required fields (name, remote, prefix, commit), **When** the parser loads the file, **Then** it successfully parses all subtree entries with no errors
2. **Given** a subtree.yaml with optional fields (tag, branch, squash, extracts), **When** the parser loads the file, **Then** it correctly parses all optional fields and makes them accessible
3. **Given** a subtree.yaml with multiple subtree entries, **When** the parser loads the file, **Then** all entries are parsed and accessible as a collection

---

### User Story 2 - Configuration Validation with Clear Error Messages (Priority: P1)

As a developer, I need clear, actionable error messages when my subtree.yaml file has invalid entries, so that I can quickly fix configuration mistakes without guessing what went wrong.

**Why this priority**: Without validation, users will encounter cryptic errors during command execution. Early validation with clear messages prevents frustration and saves debugging time.

**Independent Test**: Can be fully tested by creating intentionally invalid configs and verifying meaningful error messages are produced. Delivers value by catching errors before any git operations occur.

**Acceptance Scenarios**:

1. **Given** a subtree.yaml missing a required field (name, remote, prefix, or commit), **When** validation runs, **Then** it reports which specific field is missing and on which subtree entry
2. **Given** a subtree.yaml with an unknown field, **When** validation runs, **Then** it rejects the config and identifies the unknown field name
3. **Given** a subtree.yaml with invalid commit hash format, **When** validation runs, **Then** it reports the commit hash is malformed and specifies the expected format
4. **Given** a subtree.yaml with both tag and branch specified, **When** validation runs, **Then** it reports the mutual exclusivity violation and suggests using only one ref type
5. **Given** a subtree.yaml with invalid remote URL, **When** validation runs, **Then** it reports the URL is invalid and specifies accepted formats

---

### User Story 3 - Extract Pattern Validation (Priority: P2)

As a developer, I need to define file extraction patterns in my subtree config and have them validated, so that I can selectively copy files from the subtree to my project structure without manual errors.

**Why this priority**: Supports advanced use cases where only parts of a subtree are needed. Not critical for basic add/update/remove workflows but important for real-world selective integration scenarios.

**Independent Test**: Can be fully tested by defining extract patterns and verifying they are parsed and validated correctly. Delivers value by enabling selective file copying use cases.

**Acceptance Scenarios**:

1. **Given** a subtree with extracts defined (from, to), **When** validation runs, **Then** it accepts the valid extract patterns
2. **Given** a subtree with extracts but missing the "to" field, **When** validation runs, **Then** it reports the missing required field within extracts
3. **Given** a subtree with extracts using glob patterns, **When** validation runs, **Then** it validates the glob pattern syntax
4. **Given** a subtree with extracts including exclude patterns, **When** validation runs, **Then** it parses and validates the exclude array

---

### User Story 4 - Schema Documentation (Priority: P2)

As a developer new to the tool, I need comprehensive documentation of all supported fields, types, and constraints in the subtree.yaml schema, so that I can create valid configurations without trial and error.

**Why this priority**: Good documentation reduces support burden and improves user experience. While the validator provides error messages, proactive documentation helps users create correct configs on the first try.

**Independent Test**: Can be fully tested by reviewing the documentation and creating configs based solely on the docs. Delivers value by enabling self-service configuration authoring.

**Acceptance Scenarios**:

1. **Given** a developer reads the schema documentation, **When** they create a subtree.yaml, **Then** they can identify all required and optional fields
2. **Given** a developer reads the schema documentation, **When** they need to choose between tag, branch, or commit-only, **Then** the docs clearly explain the differences and mutual exclusivity
3. **Given** a developer reads the schema documentation, **When** they want to use extract patterns, **Then** the docs provide examples and explain glob syntax

---

### Edge Cases

- What happens when subtree.yaml is empty or contains only whitespace? → Validation error (FR-028)
- What happens when subtree.yaml contains an empty subtrees array (`subtrees: []`)? → Valid, represents project with no subtrees configured
- What happens when subtree.yaml has malformed YAML syntax (invalid indentation, unclosed quotes)? → Clear parsing error message (FR-026)
- What happens when a commit hash is valid format (40 hex chars) but doesn't exist in the repository? → Format validation passes; existence validation deferred to command execution
- What happens when a glob pattern in extracts is syntactically valid but matches no files? → Pattern validation passes; file matching occurs during extraction
- What happens when prefix path contains `..` or absolute path components? → Validation fails with path safety error (FR-007)
- What happens when remote URL is valid format but unreachable? → Format validation passes; reachability checked during command execution
- What happens when extracts.to points outside the repository root? → Validation fails with path safety error (FR-029)
- What happens when multiple subtrees have the same name? → Validation fails with duplicate name error (FR-030)
- What happens when squash field is present but set to a non-boolean value? → Validation fails with type error (FR-010)

## Requirements *(mandatory)*

### Functional Requirements

#### Schema Definition

- **FR-001**: System MUST define a schema for subtree.yaml with a top-level `subtrees` array (may be empty)
- **FR-002**: Each subtree entry MUST support required fields: `name` (string), `remote` (string), `prefix` (string), `commit` (string)
- **FR-003**: Each subtree entry MUST support optional fields: `tag` (string), `branch` (string), `squash` (boolean), `extracts` (array)
- **FR-004**: Extract entries MUST support fields: `from` (string, required), `to` (string, required), `exclude` (array of strings, optional)

#### Type Validation

- **FR-005**: System MUST validate that `name` is a non-empty string
- **FR-006**: System MUST validate that `remote` matches valid git URL format (https://, git@, or file://) without verifying reachability
- **FR-007**: System MUST validate that `prefix` is a relative path (no leading `/`, no `..` components)
- **FR-008**: System MUST validate that `commit` matches SHA-1 hash format (40 hexadecimal characters) without verifying existence in repository
- **FR-009**: System MUST validate that `tag` and `branch`, when present, are non-empty strings
- **FR-010**: System MUST validate that `squash`, when present, is a boolean value
- **FR-011**: System MUST validate that `extracts`, when present, is a non-empty array

#### Logical Constraints

- **FR-012**: System MUST reject configurations where both `tag` and `branch` are specified for the same subtree entry
- **FR-013**: System MUST accept configurations where only `commit` is specified (without tag or branch)
- **FR-014**: System MUST accept configurations where `tag` and `commit` are both specified
- **FR-015**: System MUST accept configurations where `branch` and `commit` are both specified
- **FR-016**: System MUST reject unknown fields at the subtree entry level with a clear error message
- **FR-017**: System MUST reject unknown fields within extracts entries with a clear error message
- **FR-018**: System MUST validate that each extract entry has both `from` and `to` fields
- **FR-019**: System MUST validate glob pattern syntax in `from` and `exclude` fields supporting standard features: `**` (globstar), `*` (wildcard), `?` (single char), `[...]` (character classes), `{...}` (brace expansion)
- **FR-029**: System MUST validate that `extracts.to` paths are relative (no leading `/`, no `..` components)
- **FR-030**: System MUST reject configurations where multiple subtree entries have the same `name`

#### Error Reporting

- **FR-020**: System MUST report the specific subtree entry (by name or index) where validation fails
- **FR-021**: System MUST report the specific field name that failed validation
- **FR-022**: System MUST provide a descriptive error message explaining why validation failed
- **FR-023**: System MUST provide guidance on how to fix validation errors (e.g., "expected 40 hex characters, got 38")
- **FR-024**: System MUST collect and report all validation errors, not just the first one encountered

#### Parsing

- **FR-025**: System MUST parse subtree.yaml using YAML 1.2 specification
- **FR-026**: System MUST handle YAML syntax errors gracefully with clear error messages
- **FR-027**: System MUST handle missing subtree.yaml file with a clear error message
- **FR-028**: System MUST handle empty or whitespace-only subtree.yaml files as validation errors
- **FR-031**: System MUST accept subtree.yaml files with an empty `subtrees` array as valid

### Key Entities

- **SubtreeConfiguration**: Represents the entire subtree.yaml file structure with a collection of subtree entries
  - Attributes: subtrees (array of SubtreeEntry)
  
- **SubtreeEntry**: Represents a single subtree dependency definition
  - Required attributes: name, remote, prefix, commit
  - Optional attributes: tag, branch, squash, extracts
  
- **ExtractPattern**: Represents a file extraction rule within a subtree
  - Required attributes: from (source glob pattern), to (destination path)
  - Optional attributes: exclude (array of exclusion patterns)

- **ValidationError**: Represents a validation failure with context
  - Attributes: entry (name or index), field (field name), message (error description), suggestion (how to fix)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can create a valid subtree.yaml file and have it successfully parsed on first attempt when following schema documentation
- **SC-002**: When a subtree.yaml file has validation errors, users receive clear error messages that identify the exact field and entry with the problem within 1 second of running validation
- **SC-003**: All 31 functional requirements have corresponding unit tests that verify the requirement is met
- **SC-004**: Parser handles malformed YAML gracefully and provides actionable error messages instead of crashing or showing cryptic parser errors
- **SC-005**: Validation catches all constraint violations (type mismatches, mutual exclusivity, unknown fields, format errors) before any git operations occur
- **SC-006**: Schema documentation includes examples for all supported field combinations (basic config, with tag, with branch, with extracts, etc.)
