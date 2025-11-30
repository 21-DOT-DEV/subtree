# Phase 5 — Future Features (Backlog)

**Status:** FUTURE  
**Last Updated:** 2025-11-29

## Goal

Post-1.0 enhancements for advanced workflows, improved onboarding, and enterprise-grade reliability.

## Key Features

### 1. Config-First Add Workflow

- **Purpose & user value**: Add subtrees by reading pre-configured entries from `subtree.yaml`, enabling declarative workflow where users edit config first
- **Success metrics**:
  - Users can define subtrees in config and apply them without repeating CLI flags
- **Dependencies**: Add Command (CLI-First)
- **Notes**: Enables `subtree add --name <name>` to apply pre-configured entry

### 2. Batch Add (--all flag)

- **Purpose & user value**: Add all configured subtrees in one command for initial repository setup
- **Success metrics**:
  - Users can populate all subtrees without manual iteration
  - `git clone && subtree add --all` workflow supported
- **Dependencies**: Config-First Add Workflow
- **Notes**: Requires detection logic to skip already-added subtrees

### 3. Interactive Init Mode

- **Purpose & user value**: Guided configuration setup with prompts and validation (TTY-only)
- **Success metrics**:
  - Users complete interactive init without documentation in <3 minutes
- **Dependencies**: Init Command
- **Notes**: Step-by-step subtree configuration with validation

### 4. Config Migration Tools

- **Purpose & user value**: Import existing git subtrees into `subtree.yaml` by scanning repository history
- **Success metrics**:
  - 90% of existing subtrees detected and imported correctly
- **Dependencies**: Lint Command
- **Notes**: Enables adoption by projects already using git subtrees manually

### 5. Advanced Extract Remapping

- **Purpose & user value**: Complex path transformations and multi-source merging for extract operations
- **Success metrics**:
  - Users can remap nested paths without manual post-processing
- **Dependencies**: Extract Command
- **Notes**: Supports advanced monorepo scenarios with nested subtree structures

### 6. Extract Flatten Mode (`--flatten` flag)

- **Purpose & user value**: Strip pattern prefix from extracted paths (e.g., `src/**/*.c` extracts `src/foo.c` to `dest/foo.c` instead of `dest/src/foo.c`)
- **Success metrics**:
  - Users can flatten path structure when needed without manual post-processing
- **Dependencies**: Extract Command
- **Notes**: Default behavior (009-multi-pattern-extraction) preserves full relative paths per industry best practices. `--flatten` restores pre-009 behavior for users who prefer prefix stripping. Handles filename conflicts with clear errors.

### 7. Extract Dry-Run Mode (`--dry-run` flag)

- **Purpose & user value**: Preview extraction or clean results without modifying filesystem
- **Success metrics**:
  - Users can verify extraction plan (files matched, conflicts detected) without copying files
  - Users can preview clean operation (files to delete, checksum status) without removing files
- **Dependencies**: Extract Command, Extract Clean Mode
- **Notes**: Shows file list with status indicators, conflict warnings, summary statistics. For clean mode, shows checksum validation results and would-be-deleted files

### 8. Extract Auto-Stage Mode (`--stage` flag)

- **Purpose & user value**: Automatically stage extracted files for git commit
- **Success metrics**:
  - Users can extract and stage files in single command
- **Dependencies**: Extract Command
- **Notes**: Optional flag; runs `git add` on extracted files after successful copy

### 9. Update Dry-Run Mode

- **Purpose & user value**: Simulate update operations without committing changes
- **Success metrics**:
  - Users can validate update behavior including conflict detection
- **Dependencies**: Update Command
- **Notes**: Complements report mode; performs full validation

### 10. Network Retry with Exponential Backoff

- **Purpose & user value**: Automatic retry logic for transient network failures during git operations
- **Success metrics**:
  - 95% of transient network errors recover without manual intervention
- **Dependencies**: Update Command
- **Notes**: Configurable retry count, distinguishes transient from permanent failures

### 11. Brace Expansion: Backslash Escaping

- **Purpose & user value**: Allow users to escape literal braces in patterns using `\{` and `\}` (bash-style escaping)
- **Success metrics**:
  - Users can match files with literal `{` or `}` characters in names
  - `path/\{literal\}.txt` matches file named `{literal}.txt`
- **Dependencies**: Brace Expansion (011)
- **Notes**: MVP workaround is character class syntax `[{]` and `[}]`. Backslash escaping provides more intuitive syntax.

### 12. Brace Expansion: Nested Braces

- **Purpose & user value**: Support nested brace patterns like `{a,{b,c}}` expanding to `a`, `b`, `c`
- **Success metrics**:
  - Nested braces expand recursively matching bash behavior
- **Dependencies**: Brace Expansion (011)
- **Notes**: Adds complexity; evaluate user demand before implementing

### 13. Brace Expansion: Numeric Ranges

- **Purpose & user value**: Support numeric range patterns like `{1..10}` expanding to `1`, `2`, ..., `10`
- **Success metrics**:
  - Numeric ranges expand to sequential numbers
  - Supports zero-padding `{01..10}` → `01`, `02`, ..., `10`
- **Dependencies**: Brace Expansion (011)
- **Notes**: Bash feature; useful for numbered files but lower priority than core expansion

## Dependencies & Sequencing

- Features are independent and can be prioritized based on user demand
- Config-First → Batch Add is a dependency chain
- All features depend on Phase 4 completion (v1.0 release)

## Phase-Specific Metrics & Success Criteria

This phase is successful when:
- High-value features are selected based on user feedback
- Each delivered feature has comprehensive test coverage

## Risks & Assumptions

- **Assumptions**: User feedback available post-1.0 to guide prioritization
- **Risks & mitigations**: 
  - Feature creep → strict prioritization based on user value
  - Maintenance burden → keep implementations minimal

## Phase Notes

- 2025-11-29: Added Brace Expansion deferred features (backslash escaping, nested braces, numeric ranges)
- 2025-11-27: Initial backlog created from roadmap refactor
