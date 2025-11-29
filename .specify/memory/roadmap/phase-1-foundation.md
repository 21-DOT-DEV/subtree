# Phase 1 — Foundation

**Status:** COMPLETE  
**Last Updated:** 2025-11-27

## Goal

Establish project infrastructure and configuration management. Delivers CLI skeleton, config schema, and init command as the foundation for all subsequent features.

## Key Features

### 1. CLI Bootstrap

- **Purpose & user value**: Provides command-line interface skeleton with discoverable help system, enabling users to explore available commands and understand tool capabilities without external documentation
- **Success metrics**:
  - Command help accessible in <5 seconds via `subtree --help`
  - All stub commands execute without crashing (exit code 0)
  - CI pipeline runs tests on macOS + Ubuntu completing in <10 minutes
- **Dependencies**: None
- **Notes**: Includes test infrastructure (unit + integration test harness) and GitHub Actions CI

### 2. Configuration Schema & Validation

- **Purpose & user value**: Defines `subtree.yaml` structure and validation rules, enabling users to manage subtree dependencies declaratively with clear error messages when configuration is invalid
- **Success metrics**:
  - Valid configs parse successfully on first attempt when following docs
  - Invalid configs produce clear, actionable error messages within 1 second
  - 100% of format/constraint violations caught before git operations
- **Dependencies**: CLI Bootstrap
- **Notes**: Format-only validation (no network/git checks), supports glob patterns for extract mappings

### 3. Init Command

- **Purpose & user value**: Creates initial `subtree.yaml` configuration file at git repository root, providing starting point for declarative subtree management with overwrite protection
- **Success metrics**:
  - Initialization completes in <1 second
  - Users successfully initialize on first attempt without documentation
  - 100% of initialization attempts either succeed or fail with clear error
- **Dependencies**: Configuration Schema & Validation
- **Notes**: Works from any subdirectory, follows symlinks to find git root, atomic file operations for concurrent safety

## Dependencies & Sequencing

- **Local ordering**: CLI Bootstrap → Configuration Schema → Init Command
- **Rationale**: Each feature builds on the previous; CLI provides entry point, schema defines config format, init creates the config file

## Phase-Specific Metrics & Success Criteria

This phase is successful when:
- All three features are complete and tested on macOS 13+ and Ubuntu 20.04 LTS
- Test infrastructure supports both unit tests and integration tests
- CI pipeline validates all changes automatically

## Risks & Assumptions

- **Assumptions**: Swift 6.1 toolchain available on target platforms
- **Risks & mitigations**: None significant for foundation phase

## Phase Notes

- 2025-10-27: Phase 1 complete with all features delivered
