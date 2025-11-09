# Feature Specification: CLI Bootstrap & Test Foundation

**Feature Branch**: `001-cli-bootstrap`  
**Created**: 2025-10-26  
**Status**: Draft  
**Input**: User description: "Create the initial bootstrap for a command-line tool named 'subtree.' The goal is to enable fast, test-driven development of future features. Provide a CLI skeleton that exposes top-level commands (init, add, update, remove, extract, validate) with discoverable help and clear error/exit behavior, even if implementations are stubs. Establish a minimal but complete test baseline: unit tests that verify command presence/help/exit codes and an integration test harness that can run end-to-end flows in a temporary repository (e.g., non-interactive init creating a minimal config file). Include a generic CI workflow that runs both unit and integration tests on a representative platform matrix, failing the build on regressions. Add a concise .windsurf/rules file instructing agents to keep rules up to date after structural, dependency, CI, or major feature changes."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Command Discovery & Help (Priority: P1)

As a developer starting to use subtree, I need to discover available commands and understand their purpose through built-in help, so I can quickly learn the tool without external documentation.

**Why this priority**: Command discoverability is the foundation of CLI usability. Without it, users cannot progress to any other functionality.

**Independent Test**: Can be fully tested by running the CLI with no arguments, `--help`, and `<command> --help`, and verifying help text appears with exit code 0.

**Acceptance Scenarios**:

1. **Given** the CLI is installed, **When** I run `subtree` with no arguments, **Then** I see a list of available commands and general usage information
2. **Given** the CLI is installed, **When** I run `subtree --help`, **Then** I see comprehensive help text with command descriptions
3. **Given** the CLI is installed, **When** I run `subtree <command> --help` for each command (init, add, update, remove, extract, validate), **Then** I see command-specific help text
4. **Given** I request help, **When** help text is displayed, **Then** the process exits with code 0

---

### User Story 2 - Command Presence & Exit Codes (Priority: P2)

As a developer or CI system, I need all documented commands to exist and return predictable exit codes, so I can write reliable scripts and automation.

**Why this priority**: Consistent exit codes enable scripting and automation. This is essential infrastructure before implementing real functionality.

**Independent Test**: Can be fully tested by invoking each command and checking the exit code matches expectations (0 for success/help, non-zero for errors).

**Acceptance Scenarios**:

1. **Given** the CLI is installed, **When** I run `subtree init`, **Then** the command executes without crashing and returns exit code 0
2. **Given** the CLI is installed, **When** I run each stub command (add, update, remove, extract, validate), **Then** each returns exit code 0 and displays "not implemented" message
3. **Given** the CLI is installed, **When** I run `subtree invalid-command`, **Then** the process shows an error message and exits with non-zero code
4. **Given** I run a command, **When** the command completes, **Then** the exit code is deterministic and documented

---

### User Story 3 - Integration Test Foundation (Priority: P3)

As a future feature developer, I need an integration test harness that can execute CLI commands in isolated temporary git repositories, so I can verify end-to-end behavior without polluting my workspace.

**Why this priority**: Integration tests prevent regressions in real-world usage. The foundation must exist before implementing features.

**Independent Test**: Can be fully tested by running the integration test suite and verifying it creates/cleans up temp repositories and validates git state.

**Acceptance Scenarios**:

1. **Given** the test harness is available, **When** an integration test runs, **Then** it creates a temporary directory with a git repository
2. **Given** a temporary repository is created, **When** the integration test executes CLI commands, **Then** commands run in the isolated environment
3. **Given** an integration test completes, **When** the test finishes (pass or fail), **Then** the temporary directory is cleaned up
4. **Given** the integration test runs CLI commands, **When** commands modify git state, **Then** the test can verify the git repository state before and after

---

### User Story 4 - CI Pipeline & Quality Gates (Priority: P4)

As a project maintainer, I need automated CI that runs unit and integration tests across multiple platforms and fails on regressions, so code quality is enforced before merge.

**Why this priority**: Automated quality gates prevent regressions and ensure cross-platform compatibility. Essential for sustainable development.

**Independent Test**: Can be fully tested by triggering CI with known-passing and known-failing test cases and verifying CI status matches expectations.

**Acceptance Scenarios**:

1. **Given** code is pushed to the repository, **When** CI runs, **Then** all unit tests execute on macOS latest and Ubuntu LTS with Swift latest stable
2. **Given** code is pushed to the repository, **When** CI runs, **Then** all integration tests execute on the platform matrix
3. **Given** all tests pass, **When** CI completes, **Then** the build status is success
4. **Given** any test fails, **When** CI completes, **Then** the build status is failure and merge is blocked
5. **Given** CI is configured, **When** viewing the workflow, **Then** the platform matrix is clearly documented

---

### User Story 5 - Agent Rules Foundation (Priority: P5)

As an AI agent working on this codebase, I need a `.windsurf/rules` file that documents when and how to update project expectations, so I maintain accurate context as the project evolves.

**Why this priority**: Living documentation prevents drift between code reality and agent understanding. Enables effective agent assistance.

**Independent Test**: Can be fully tested by verifying the `.windsurf/rules` file exists, contains required sections, and documents update triggers.

**Acceptance Scenarios**:

1. **Given** the bootstrap is complete, **When** I check the repository, **Then** `.windsurf/rules` file exists
2. **Given** `.windsurf/rules` exists, **When** I read it, **Then** it documents the project structure, dependencies, and conventions
3. **Given** `.windsurf/rules` exists, **When** I read it, **Then** it lists the five mandatory update triggers (dependencies, structure, architecture, CI, major features)
4. **Given** `.windsurf/rules` exists, **When** I read it, **Then** it provides clear instructions for when agents must update the file

---

### Edge Cases

**Out of Scope for Bootstrap**: The following edge cases are deferred to future feature specs when real command implementations exist:

- Invalid flags (handled automatically by swift-argument-parser with usage display)
- Empty or malformed arguments (handled automatically by swift-argument-parser)
- Integration test permission failures (test infrastructure concern, not CLI behavior)
- CI timeout handling (CI platform configuration, covered by FR-023 10-minute limit)
- Missing git in test environment (CI setup responsibility, not CLI behavior)

**Bootstrap Focus**: Happy path validation only - help text displays correctly, stubs execute without crashing, tests pass.

## Requirements *(mandatory)*

### Functional Requirements

**CLI Structure & Commands**:
- **FR-001**: CLI MUST expose six top-level commands: init, add, update, remove, extract, validate
- **FR-002**: CLI MUST support `--help` flag at root level and for each command
- **FR-003**: CLI MUST display help text when run with no arguments
- **FR-004**: CLI MUST show "not implemented" message to stdout for stub commands (format: "Command '<name>' not yet implemented")
- **FR-005**: CLI MUST return exit code 0 for successful operations and help requests
- **FR-006**: CLI MUST return non-zero exit code for invalid commands or errors

**Unit Testing**:
- **FR-007**: Unit tests MUST verify each command exists and is invokable
- **FR-008**: Unit tests MUST verify help text is displayed for `--help` flag
- **FR-009**: Unit tests MUST verify exit codes for all command scenarios
- **FR-010**: Unit tests MUST be runnable via standard test command
- **FR-011**: Unit tests MUST complete in under 10 seconds total

**Integration Testing**:
- **FR-012**: Integration test harness MUST create temporary directories for each test
- **FR-013**: Integration test harness MUST initialize git repositories in temporary directories with initial commit (commit message: "Initial commit", empty tree or single .gitkeep file)
- **FR-014**: Integration test harness MUST clean up temporary directories after test completion
- **FR-015**: Integration test harness MUST verify git repository state before and after operations
- **FR-016**: Integration tests MUST be isolated (no shared state between tests)
- **FR-017**: Integration tests MUST complete in under 30 seconds total

**CI Pipeline**:
- **FR-018**: CI MUST run unit tests on macOS latest with Swift 6.1
- **FR-019**: CI MUST run unit tests on Ubuntu 20.04 LTS with Swift 6.1
- **FR-020**: CI MUST run integration tests on macOS latest with Swift 6.1
- **FR-021**: CI MUST run integration tests on Ubuntu 20.04 LTS with Swift 6.1
- **FR-022**: CI MUST fail the build if any test fails
- **FR-023**: CI MUST complete in under 10 minutes total

**Note**: Linting and formatting are deferred to future feature specs per bootstrap scope. Bootstrap focuses on establishing test infrastructure only.

**Agent Rules**:
- **FR-025**: `.windsurf/rules` file MUST exist at repository root
- **FR-026**: `.windsurf/rules` MUST document current project structure
- **FR-027**: `.windsurf/rules` MUST document dependencies and their purpose
- **FR-028**: `.windsurf/rules` MUST list the five mandatory update triggers
- **FR-029**: `.windsurf/rules` MUST provide update procedure instructions
- **FR-030**: `.windsurf/rules` MUST remain concise (under 200 lines)

### Key Entities

- **Command**: Represents a CLI command (init, add, update, remove, extract, validate) with name, help text, and execution behavior
- **Test Suite**: Collection of unit or integration tests with setup, execution, and teardown lifecycle
- **Temporary Repository**: Isolated git repository in temporary directory for integration testing, with initial commit and clean state verification
- **CI Workflow**: Automated pipeline configuration defining platform matrix, test execution order, and failure conditions
- **Rules File**: Living documentation file tracking project structure, conventions, and agent update triggers

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developer can discover all six commands by running `subtree --help` in under 5 seconds
- **SC-002**: Unit test suite covers 100% of commands and completes in under 10 seconds
- **SC-003**: Integration test harness successfully creates, uses, and cleans up temporary git repositories in 100% of test runs
- **SC-004**: CI pipeline runs on both macOS and Ubuntu, completing full test suite in under 10 minutes
- **SC-005**: CI correctly fails build when any test fails (verified by intentionally breaking a test)
- **SC-006**: `.windsurf/rules` file exists and contains all required sections (structure, dependencies, triggers, procedure)
- **SC-007**: Future feature developers can add new integration tests using the harness without modifying harness code - validated by creating a new test file that imports TestHarness, writes a test using existing harness methods, and verifies swift build succeeds with zero changes to TestHarness.swift or GitRepositoryFixture.swift
- **SC-008**: All stub commands execute without crashing and return exit code 0
