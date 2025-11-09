# Implementation Tasks: Extract Command

**Feature**: `008-extract-command` | **Date**: 2025-10-31  
**Status**: Ready for Implementation | **Total Tasks**: 185

## Overview

This document provides a detailed, dependency-ordered task list for implementing the Extract Command feature. Tasks are organized by user story (P1-P5) to enable independent implementation and testing.

**User Stories**:
- **P1**: Ad-hoc File Extraction (core functionality)
- **P2**: Persistent Extraction Mappings (save to config)
- **P3**: Bulk Extraction Execution (--all flag)
- **P4**: Git-Aware Overwrite Protection (safety)
- **P5**: Glob Pattern Validation and Error Handling (quality of life)

---

## Phase 1: Setup

**Goal**: Prepare development environment and verify baseline

### Tasks

- [X] T001 Verify on feature branch 008-extract-command
- [X] T002 Verify all baseline tests pass (310 tests from existing commands)
- [X] T003 Verify CI pipeline passing on both macOS and Ubuntu
- [X] T004 Review spec.md, plan.md, data-model.md, contracts/, quickstart.md

---

## Phase 2: Foundational Components

**Goal**: Implement shared utilities and models needed by all user stories

**Rationale**: These components are used across multiple user stories. Completing them first maximizes parallel work on user stories.

### Configuration Model (ExtractionMapping)

- [X] T005 [P] Create ExtractionMapping.swift in Sources/SubtreeLib/Configuration/
- [X] T006 [P] Write test for ExtractionMapping init in Tests/SubtreeLibTests/ConfigurationTests/ExtractionMappingTests.swift
- [X] T007 [P] Write test for ExtractionMapping Codable conformance (encode/decode)
- [X] T008 [P] Write test for ExtractionMapping Equatable conformance
- [X] T009 [P] Write test for ExtractionMapping with optional exclude field
- [X] T010 [P] Write test for ExtractionMapping YAML serialization
- [X] T011 [P] Write test for ExtractionMapping YAML deserialization
- [X] T012 Implement ExtractionMapping struct with from, to, exclude fields
- [X] T013 Verify all ExtractionMapping tests pass

### SubtreeEntry Extension

- [X] T014 [P] Write test for SubtreeEntry with extractions array in Tests/SubtreeLibTests/ConfigurationTests/SubtreeEntryTests.swift
- [X] T015 [P] Write test for SubtreeEntry backward compatibility (missing extractions → nil)
- [X] T016 [P] Write test for SubtreeEntry with empty extractions array
- [X] T017 [P] Write test for SubtreeEntry with multiple extraction mappings
- [X] T018 Extend SubtreeEntry with optional extractions field in Sources/SubtreeLib/Configuration/SubtreeEntry.swift
- [X] T019 Verify all SubtreeEntry tests pass (including new extraction tests)

### GlobMatcher Utility

- [X] T020 [P] Create GlobMatcher.swift in Sources/SubtreeLib/Utilities/
- [X] T021 [P] Create GlobMatcherTests.swift in Tests/SubtreeLibTests/Utilities/
- [X] T022 [P] Write tests for single-level wildcard matching (*.txt)
- [X] T023 [P] Write tests for globstar matching (**/*.md, docs/**/*.txt)
- [X] T024 [P] Write tests for character class matching ([abc], *.{h,c})
- [X] T025 [P] Write tests for single char wildcard (?)
- [X] T026 [P] Write tests for literal path matching
- [X] T027 [P] Write tests for directory separator handling
- [X] T028 [P] Write tests for edge cases (empty path, root path, deep nesting)
- [X] T029 [P] Write tests for invalid patterns (unclosed brackets, invalid syntax)
- [X] T030 [P] Write tests for symlink handling (follow symlinks, copy target)
- [X] T031 Implement GlobMatcher pattern parsing
- [X] T032 Implement single-level wildcard matching
- [X] T033 Implement globstar recursive matching
- [X] T034 Implement character class matching
- [X] T035 Implement single char wildcard matching
- [X] T036 Implement pattern validation and error handling
- [X] T037 Verify all GlobMatcher tests pass (30+ test cases)

### GitOperations Extension

- [X] T038 [P] Write test for isFileTracked with tracked file in Tests/SubtreeLibTests/Utilities/GitOperationsTests.swift
- [X] T039 [P] Write test for isFileTracked with untracked file
- [X] T040 [P] Write test for isFileTracked with non-existent file
- [X] T041 [P] Write test for isFileTracked with file in subdirectory
- [X] T042 [P] Write test for isFileTracked error handling (not in git repo)
- [X] T043 Implement GitOperations.isFileTracked() method in Sources/SubtreeLib/Utilities/GitOperations.swift
- [X] T044 Verify all GitOperations tests pass (including new isFileTracked tests)

### ConfigFileManager Extension

- [X] T045 [P] Write test for appendExtraction to subtree in Tests/SubtreeLibTests/Utilities/ConfigFileManagerTests.swift
- [X] T046 [P] Write test for appendExtraction creates extractions array if missing
- [X] T047 [P] Write test for appendExtraction to existing extractions array
- [X] T048 [P] Write test for appendExtraction case-insensitive subtree lookup
- [X] T049 [P] Write test for appendExtraction error when subtree not found
- [X] T050 [P] Write test for appendExtraction atomicity (temp file pattern)
- [X] T051 Implement ConfigFileManager.appendExtraction() method in Sources/SubtreeLib/Utilities/ConfigFileManager.swift
- [X] T052 Verify all ConfigFileManager tests pass (including new appendExtraction tests)

### Foundational Checkpoint

- [X] T053 Verify all foundational tests pass (ExtractionMapping, SubtreeEntry, GlobMatcher, GitOperations, ConfigFileManager)
- [X] T054 Run swift test --filter "ExtractionMapping|SubtreeEntry|GlobMatcher|GitOperations|ConfigFileManager"

---

## Phase 3: User Story 1 (P1) - Ad-hoc File Extraction

**Goal**: Enable users to extract files using glob patterns with a single command

**Independent Test Criteria**: Add subtree, run extract with pattern, verify files copied with correct structure

### Integration Tests

- [X] T055 [P] [US1] Create ExtractIntegrationTests.swift in Tests/IntegrationTests/
- [X] T056 [P] [US1] Write test for extract copies markdown files with glob pattern
- [X] T057 [P] [US1] Write test for extract preserves directory structure relative to match
- [X] T058 [P] [US1] Write test for extract copies all files under directory (**/*.*)
- [X] T059 [P] [US1] Write test for extract with exclude patterns filters files
- [X] T060 [P] [US1] Write test for extract creates destination directory if missing

### Command Implementation

- [X] T061 [US1] Create ExtractCommand.swift in Sources/SubtreeLib/Commands/
- [X] T062 [US1] Define ExtractCommand structure with ArgumentParser
- [X] T063 [US1] Add --name flag for subtree selection
- [X] T064 [US1] Add source pattern positional argument
- [X] T065 [US1] Add destination positional argument
- [X] T066 [US1] Add --exclude repeatable flag for exclusion patterns
- [X] T067 [US1] Implement mode selection logic (ad-hoc vs saved mappings)
- [X] T068 [US1] Implement subtree validation (exists in config, prefix exists)
- [X] T069 [US1] Implement destination path validation (relative, no .., within repo)
- [X] T070 [US1] Implement glob pattern matching using GlobMatcher
- [X] T071 [US1] Implement exclusion pattern filtering
- [X] T072 [US1] Implement file copying with FileManager
- [X] T073 [US1] Implement directory structure preservation
- [X] T074 [US1] Implement destination directory creation
- [X] T075 [US1] Register ExtractCommand as subcommand in SubtreeCommand.swift
- [X] T076 [US1] Verify extract --help displays command documentation

### Unit Tests

- [X] T077 [P] [US1] Create ExtractCommandTests.swift in Tests/SubtreeLibTests/Commands/
- [X] T078 [P] [US1] Write test for mode selection (ad-hoc when positional args present)
- [X] T079 [P] [US1] Write test for subtree validation (missing subtree errors)
- [X] T080 [P] [US1] Write test for path validation (rejects .., absolute paths)
- [X] T081 [P] [US1] Write test for directory structure preservation logic
- [X] T082 [P] [US1] Write test for exclusion filtering logic

### US1 Checkpoint

- [X] T083 [US1] Verify all US1 integration tests pass (5/5 tests passing)
- [X] T084 [US1] Verify all US1 unit tests pass (8/8 tests passing)
- [X] T085 [US1] Manual test: subtree extract --name secp256k1 "**/*.md" docs/ (PASSED - 8 files extracted)
- [X] T086 [US1] Manual test with exclude: subtree extract --name secp256k1 "src/**/*.{c,h}" Sources/ --exclude "**/tests/**" --exclude "**/bench*/**" (PASSED - 91 files, tests excluded)

---

## Phase 4: User Story 2 (P2) - Persistent Extraction Mappings

**Goal**: Save extraction mappings to config with --persist flag

**Independent Test Criteria**: Run extraction with --persist, verify mapping saved, re-run without args uses saved mapping

### Integration Tests

- [X] T087 [P] [US2] Write test for extraction with --persist saves mapping to config
- [X] T088 [P] [US2] Write test for saved mapping includes exclude patterns
- [X] T089 [P] [US2] Write test for extraction without --persist doesn't save mapping
- [X] T090 [P] [US2] Write test for multiple saved mappings in config

### Command Implementation

- [X] T091 [US2] Add --persist flag to ExtractCommand
- [X] T092 [US2] Implement config save logic using ConfigFileManager.appendExtraction()
- [X] T093 [US2] Implement mapping construction from CLI flags (from, to, exclude)
- [X] T094 [US2] Ensure config update is atomic (reuses ConfigFileManager)
- [X] T095 [US2] Add success message when mapping saved

### Unit Tests

- [X] T096 [P] [US2] Write test for --persist flag parsing
- [X] T097 [P] [US2] Write test for mapping construction with exclude patterns
- [X] T098 [P] [US2] Write test for config save invocation

### US2 Checkpoint

- [X] T099 [US2] Verify all US2 integration tests pass (9/9 integration tests passing)
- [X] T100 [US2] Verify all US2 unit tests pass (11/11 unit tests passing)
- [X] T101 [US2] Manual test: subtree extract --name secp256k1 "**/*.md" project-docs/ --persist (PASSED - 8 files extracted, mapping saved)
- [X] T102 [US2] Verify mapping saved in subtree.yaml (PASSED - extractions array contains mapping)

---

## Phase 5: User Story 3 (P3) - Bulk Extraction Execution

**Goal**: Execute all saved mappings with --name or --all flags

**Independent Test Criteria**: Create saved mappings, run extract without positional args, verify all mappings execute

### Integration Tests

- [X] T103 [P] [US3] Write test for extract --name executes all saved mappings for subtree
- [X] T104 [P] [US3] Write test for extract --all executes mappings for all subtrees
- [X] T105 [P] [US3] Write test for extract --name with no saved mappings succeeds with message
- [X] T106 [P] [US3] Write test for mappings execute in array order
- [X] T107 [P] [US3] Write test for bulk execution continues on mapping failure
- [X] T108 [P] [US3] Write test for bulk execution reports all failures at end
- [X] T109 [P] [US3] Write test for bulk execution exits with highest severity code

### Command Implementation

- [X] T110 [US3] Add --all flag to ExtractCommand
- [X] T111 [US3] Implement mode selection for bulk execution (--all or --name without args)
- [X] T112 [US3] Implement saved mapping loading from config
- [X] T113 [US3] Implement mapping execution loop with failure collection
- [X] T114 [US3] Implement exit code priority logic (3 > 2 > 1)
- [X] T115 [US3] Implement failure summary reporting
- [X] T116 [US3] Add informational message when no saved mappings found

### Unit Tests

- [X] T117 [P] [US3] Write test for --all flag parsing
- [X] T118 [P] [US3] Write test for bulk mode selection logic
- [X] T119 [P] [US3] Write test for saved mapping loading
- [X] T120 [P] [US3] Write test for failure collection logic
- [X] T121 [P] [US3] Write test for exit code priority calculation

### US3 Checkpoint

- [X] T122 [US3] Verify all US3 integration tests pass (16/16 integration tests passing)
- [X] T123 [US3] Verify all US3 unit tests pass (16/16 unit tests passing)
- [X] T124 [US3] Manual test: subtree extract --name secp256k1 (PASSED - 3 mappings executed: 8 MD + 87 headers + 5 examples)
- [X] T125 [US3] Manual test: subtree extract --all (PASSED - 3 subtrees processed, 3 mappings succeeded, 1 skipped)

---

## Phase 6: User Story 4 (P4) - Git-Aware Overwrite Protection

**Goal**: Protect git-tracked files from accidental overwrite

**Independent Test Criteria**: Extract to git-tracked destination, verify blocked without --force, succeeds with --force

### Integration Tests

- [X] T126 [P] [US4] Write test for extraction blocked when destination is git-tracked
- [X] T127 [P] [US4] Write test for extraction succeeds when destination is untracked
- [X] T128 [P] [US4] Write test for extraction with --force overwrites git-tracked files
- [X] T129 [P] [US4] Write test for mixed tracked/untracked destinations
- [X] T130 [P] [US4] Write test for error message lists all protected files

### Command Implementation

- [X] T131 [US4] Add --force flag to ExtractCommand
- [X] T132 [US4] Implement git tracking check using GitOperations.isFileTracked()
- [X] T133 [US4] Implement overwrite protection logic (block tracked files)
- [X] T134 [US4] Implement --force override logic
- [X] T135 [US4] Implement protected file collection and error message
- [X] T136 [US4] Set exit code 2 for overwrite protection errors

### Unit Tests

- [X] T137 [P] [US4] Write test for --force flag parsing
- [X] T138 [P] [US4] Write test for overwrite protection decision logic
- [X] T139 [P] [US4] Write test for protected file error message formatting

### US4 Checkpoint

- [X] T140 [US4] Verify all US4 integration tests pass (21/21 integration tests passing)
- [X] T141 [US4] Verify all US4 unit tests pass (19/19 unit tests passing)
- [X] T142 [US4] Manual test: extract to tracked file (PASSED - exit 2, file protected, clear error message)
- [X] T143 [US4] Manual test: same extraction with --force (PASSED - exit 0, file overwritten successfully)

---

## Phase 7: User Story 5 (P5) - Glob Pattern Validation and Error Handling

**Goal**: Provide clear error messages for invalid inputs

**Independent Test Criteria**: Run extractions with invalid inputs, verify appropriate errors and exit codes

### Integration Tests

- [X] T144 [P] [US5] Write test for zero-match pattern error
- [X] T145 [P] [US5] Write test for all-excluded pattern error (pattern matches but all excluded)
- [X] T146 [P] [US5] Write test for non-existent subtree error
- [X] T147 [P] [US5] Write test for invalid destination path error (contains ..)
- [X] T148 [P] [US5] Write test for subtree prefix not found error
- [X] T149 [P] [US5] Write test for destination directory auto-creation

### Command Implementation

- [X] T150 [US5] Implement zero-match pattern validation (mode-dependent: error in ad-hoc, warning in bulk)
- [X] T151 [US5] Implement all-excluded pattern validation (treated as zero-match)
- [X] T152 [US5] Implement subtree existence validation (already existed)
- [X] T153 [US5] Implement prefix existence validation (already existed)
- [X] T154 [US5] Implement destination path safety validation (already existed)
- [X] T155 [US5] Add actionable error messages for each validation failure
- [X] T156 [US5] Set appropriate exit codes (1 for validation errors)

### Unit Tests

- [X] T157 [P] [US5] Write test for zero-match detection logic
- [X] T158 [P] [US5] Write test for all-excluded detection logic
- [X] T159 [P] [US5] Write test for error message formatting

### US5 Checkpoint

- [X] T160 [US5] Verify all US5 integration tests pass (6/6 passing)
- [X] T161 [US5] Verify all US5 unit tests pass (3/3 passing)
- [X] T162 [US5] Manual test: extract with non-existent pattern (PASSED - exit 1, clear error with suggestions)
- [X] T163 [US5] Manual test: extract with non-existent subtree (PASSED - exit 1, subtree not found error)

---

## Phase 8: Polish & Integration

**Goal**: Final refinements, documentation, and end-to-end validation

### Polish Tasks

- [X] T164 [P] Add comprehensive help text to ExtractCommand (modes, examples, patterns, exit codes)
- [X] T165 [P] Add usage examples to command documentation (8 examples in help text)
- [X] T166 [P] Verify all error messages have emoji prefixes (✅ all messages use ❌/✅/ℹ️/📊/📝/⚠️)
- [X] T167 [P] Verify all success messages are concise and informative (✅ verified)
- [ ] T168 [P] Add performance logging for extraction operations (SKIPPED - not required for MVP)
- [X] T169 Update README.md with extract command examples (status, usage, features documented)
- [X] T170 Update agents.md with extract command feature (all 5 user stories documented)

### Edge Case Testing

- [X] T171 [P] Write test for destination inside subtree prefix (documents behavior - extraction allowed)
- [X] T172 [P] Write test for glob matching outside subtree prefix (verifies scoping works correctly)
- [X] T173 [P] Write test for filename collisions (verifies directory structure preservation prevents collisions)
- [ ] T174 [P] Write test for filesystem permission errors (SKIPPED - OS-level, platform-dependent, unreliable to test)
- [X] T175 [P] Write test for destination is file not directory error (verifies error handling when path blocked)

### Full Integration Testing

- [X] T176 Run full test suite: swift test (415 tests, +4 edge case tests)
- [X] T177 Verify test count increased (baseline 310 → 415 tests, +105 new tests for Extract)
- [X] T178 Test on macOS platform (all tests passing on macOS)
- [ ] T179 Test on Ubuntu via CI (act workflow_dispatch -W .github/workflows/ci-local.yml)
- [X] T180 Verify all 5 user stories work end-to-end (27 integration tests covering all stories)
- [X] T181 Verify backward compatibility (all existing commands tests passing)

### Documentation Updates

- [ ] T182 Update .windsurf/rules/ with extract command per Constitution Principle V (DEFERRED - files are protected)
- [ ] T183 Document ExtractionMapping in config schema section (COVERED - documented in README/agents.md)
- [ ] T184 Add GlobMatcher to utilities section in rules (COVERED - documented in code and tests)
- [ ] T185 Create PR description with spec reference and user story completion (DEFERRED - can be created when ready for PR)

---

## Dependencies & Execution Order

### Critical Path

```
Phase 1 (Setup)
  ↓
Phase 2 (Foundational: ExtractionMapping → SubtreeEntry → GlobMatcher → GitOperations → ConfigFileManager)
  ↓
Phase 3 (US1: Ad-hoc Extraction) ← MVP Scope
  ↓
Phase 4 (US2: Persistence)
  ↓
Phase 5 (US3: Bulk Execution) [depends on US2]
  ↓
Phase 6 (US4: Overwrite Protection)
  ↓
Phase 7 (US5: Error Handling)
  ↓
Phase 8 (Polish)
```

### User Story Independence

- **US1** (P1): Depends only on foundational components
- **US2** (P2): Depends on US1
- **US3** (P3): Depends on US2 (needs saved mappings)
- **US4** (P4): Independent of US2/US3 (can be done after US1)
- **US5** (P5): Independent of US2/US3 (can be done after US1)

**Parallel Opportunities**: US4 and US5 can be implemented in parallel with US2/US3 after US1 completes.

---

## Implementation Strategy

### MVP Scope (Minimum Viable Product)

**Scope**: User Story 1 (P1) only
- Ad-hoc file extraction with glob patterns
- Exclude pattern support
- Directory structure preservation
- Basic validation

**Tasks**: T001-T086 (86 tasks)

**Value**: Delivers core functionality - users can extract files with a single command

**Validation**: Manual test shows extraction works correctly

### Incremental Delivery

**Iteration 1** (MVP): US1 → PR → Merge  
**Iteration 2** (Persistence): US2 → PR → Merge  
**Iteration 3** (Bulk + Safety): US3 + US4 → PR → Merge (parallel stories)  
**Iteration 4** (Quality): US5 → PR → Merge  
**Iteration 5** (Polish): Phase 8 → Final PR → Merge

---

## Task Summary

**Total Tasks**: 185

**By Phase**:
- Phase 1 (Setup): 4 tasks
- Phase 2 (Foundational): 50 tasks (models + utilities + tests)
- Phase 3 (US1): 32 tasks (integration + implementation + unit tests)
- Phase 4 (US2): 16 tasks
- Phase 5 (US3): 23 tasks
- Phase 6 (US4): 18 tasks
- Phase 7 (US5): 20 tasks
- Phase 8 (Polish): 22 tasks

**By Type**:
- Test tasks: ~120 (65%)
- Implementation tasks: ~50 (27%)
- Documentation/Polish: ~15 (8%)

**Parallel Tasks**: 85 tasks marked [P] can run in parallel (different files, no dependencies)

---

## Validation Checkpoints

After each phase, verify:

```bash
# Phase 2
swift test --filter "ExtractionMapping|SubtreeEntry|GlobMatcher|GitOperations|ConfigFileManager"

# Phase 3 (US1)
swift test --filter ExtractIntegrationTests
swift test --filter ExtractCommandTests

# Phase 4 (US2)
swift test --filter ExtractIntegrationTests
# Run manual persistence test

# Phase 5 (US3)
swift test --filter ExtractIntegrationTests
# Run manual bulk execution test

# Phase 6 (US4)
swift test --filter ExtractIntegrationTests
# Run manual overwrite protection test

# Phase 7 (US5)
swift test --filter ExtractIntegrationTests
# Run manual error validation test

# Phase 8
swift test  # Full suite
```

**Final Validation**: All ~450 test cases pass (310 baseline + ~140 new from 120 test tasks)

