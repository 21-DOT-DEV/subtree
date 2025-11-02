# Implementation Tasks: Remove Command

**Feature**: Remove Command | **Branch**: `006-remove-command` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Overview

This task list implements the Remove Command feature following TDD principles. Tasks are organized by user story to enable independent implementation and testing. Each phase represents a complete, independently testable increment.

**Total Estimated Tasks**: 53 tasks
**Approach**: MVP-first (US1 alone could ship), then robustness (US2), built on solid foundation (US3 validation)

---

## Phase 1: Setup & Configuration (4 tasks)

**Goal**: Prepare development environment and test infrastructure for Remove Command implementation.

### Tasks

- [X] T001 [P] Create RemoveCommand.swift stub in Sources/SubtreeLib/Commands/RemoveCommand.swift
- [X] T002 [P] Register RemoveCommand as subcommand in Sources/SubtreeLib/Commands/SubtreeCommand.swift
- [X] T003 [P] Create RemoveCommandTests.swift test file in Tests/SubtreeLibTests/Commands/RemoveCommandTests.swift
- [X] T004 [P] Create RemoveIntegrationTests.swift test file in Tests/IntegrationTests/RemoveIntegrationTests.swift

**Verification**: Run `swift build` and `swift test --list-tests` to confirm files compile and tests are discovered.

---

## Phase 2: Foundational - Validation & Error Handling (16 tasks)

**Goal**: Implement comprehensive validation and error handling that US1 and US2 depend on. This phase corresponds to User Story 3 (Error Handling & Validation - Priority P1).

**Independent Test**: Trigger each error condition and verify correct exit code and error message without any repository modifications.

### Validation Infrastructure Tests (TDD)

- [X] T005 [P] Write test for git repository validation in Tests/SubtreeLibTests/Commands/RemoveCommandTests.swift
- [X] T006 [P] Write test for config file existence check in Tests/SubtreeLibTests/Commands/RemoveCommandTests.swift
- [X] T007 [P] Write test for config file parsing validation in Tests/SubtreeLibTests/Commands/RemoveCommandTests.swift
- [X] T008 [P] Write test for subtree name existence check in Tests/SubtreeLibTests/Commands/RemoveCommandTests.swift
- [X] T009 [P] Write test for clean working tree validation in Tests/SubtreeLibTests/Commands/RemoveCommandTests.swift

### Validation Implementation

- [X] T010 Implement git repository validation in Sources/SubtreeLib/Commands/RemoveCommand.swift (uses GitOperations.findRepositoryRoot())
- [X] T011 Implement config file existence check in Sources/SubtreeLib/Commands/RemoveCommand.swift (FR-004)
- [X] T012 Implement config file parsing with error handling in Sources/SubtreeLib/Commands/RemoveCommand.swift (FR-005, catches Yams errors)
- [X] T013 Implement subtree name lookup in config in Sources/SubtreeLib/Commands/RemoveCommand.swift (FR-006)
- [X] T014 Implement clean working tree validation in Sources/SubtreeLib/Commands/RemoveCommand.swift (FR-007, uses GitOperations.isCleanWorkingTree())

### Error Message Tests (TDD)

- [X] T015 [P] Write integration test for "config not found" error with exit code 3 in Tests/IntegrationTests/RemoveIntegrationTests.swift
- [X] T016 [P] Write integration test for "config malformed" error with exit code 3 in Tests/IntegrationTests/RemoveIntegrationTests.swift
- [X] T017 [P] Write integration test for "subtree not found" error with exit code 2 in Tests/IntegrationTests/RemoveIntegrationTests.swift
- [X] T018 [P] Write integration test for "dirty working tree" error with exit code 1 in Tests/IntegrationTests/RemoveIntegrationTests.swift
- [X] T019 [P] Write integration test for "not in git repo" error with exit code 1 in Tests/IntegrationTests/RemoveIntegrationTests.swift

### Error Message Implementation

- [X] T020 Implement error message formatting for all validation failures in Sources/SubtreeLib/Commands/RemoveCommand.swift (FR-018, FR-023, FR-027)

**Phase 2 Verification**: All validation tests pass. Running remove command with invalid inputs produces correct errors and exit codes. No repository modifications occur on validation failures.

---

## Phase 3: US1 - Clean Subtree Removal (19 tasks)

**Goal**: Implement core removal functionality - remove subtree directory, update config, create atomic commit.

**User Story**: US1 - Clean Subtree Removal (Priority: P1)
- Remove directory from working tree
- Update subtree.yaml to remove entry
- Create single atomic commit with both changes
- Display success message with commit hash

**Independent Test**: Add a subtree, remove it, verify directory gone, config updated, single commit created with both changes.

### Directory Removal Tests (TDD)

- [X] T021 [P] [US1] Write test for directory existence check in Tests/SubtreeLibTests/Commands/RemoveCommandTests.swift
- [X] T022 [P] [US1] Write test for git rm execution in Tests/SubtreeLibTests/Commands/RemoveCommandTests.swift
- [X] T023 [P] [US1] Write integration test for successful directory removal in Tests/IntegrationTests/RemoveIntegrationTests.swift

### Directory Removal Implementation

- [X] T024 [US1] Implement directory existence check in Sources/SubtreeLib/Commands/RemoveCommand.swift (FR-009, uses FileManager)
- [X] T025 [US1] Implement git rm operation in Sources/SubtreeLib/Utilities/GitOperations.swift (add remove(prefix:) method, wraps git rm -r)
- [X] T026 [US1] Integrate git rm call in RemoveCommand when directory exists in Sources/SubtreeLib/Commands/RemoveCommand.swift

### Config Update Tests (TDD)

- [X] T027 [P] [US1] Write test for config entry removal in Tests/SubtreeLibTests/Commands/RemoveCommandTests.swift
- [X] T028 [P] [US1] Write test for config file atomic write in Tests/SubtreeLibTests/Commands/RemoveCommandTests.swift

### Config Update Implementation

- [X] T029 [US1] Implement removeEntry(name:) method in Sources/SubtreeLib/Configuration/ConfigFileManager.swift (FR-010)
- [X] T030 [US1] Integrate config removal in RemoveCommand in Sources/SubtreeLib/Commands/RemoveCommand.swift

### Atomic Commit Tests (TDD)

- [X] T031 [P] [US1] Write test for commit message formatting in Tests/SubtreeLibTests/Commands/RemoveCommandTests.swift (FR-016, FR-017, FR-018)
- [X] T032 [P] [US1] Write integration test for single atomic commit in Tests/IntegrationTests/RemoveIntegrationTests.swift (verify git log shows 1 commit)
- [X] T033 [P] [US1] Write integration test for commit contains both changes in Tests/IntegrationTests/RemoveIntegrationTests.swift (verify git show HEAD includes directory + config)

### Atomic Commit Implementation

- [X] T034 [US1] Implement commit message formatting in Sources/SubtreeLib/Commands/RemoveCommand.swift (title + body with metadata)
- [X] T035 [US1] Extend AtomicSubtreeOperation to support regular commit mode in Sources/SubtreeLib/Utilities/AtomicSubtreeOperation.swift (add .remove case, create commit vs amend)
- [X] T036 [US1] Integrate atomic commit creation in RemoveCommand in Sources/SubtreeLib/Commands/RemoveCommand.swift (FR-015, FR-019)

### Commit Failure Recovery Test (TDD)

- [X] T037 [P] [US1] Write integration test for commit failure recovery in Tests/IntegrationTests/RemoveIntegrationTests.swift (FR-019, FR-026: verify staged changes remain, recovery instructions shown, exit code 1)

### Success Message Tests (TDD)

- [X] T038 [P] [US1] Write integration test for success message format in Tests/IntegrationTests/RemoveIntegrationTests.swift (FR-029)

### Success Message Implementation

- [X] T039 [US1] Implement success message output for normal removal in Sources/SubtreeLib/Commands/RemoveCommand.swift (✅ emoji, name, short hash)

**Phase 3 Verification**: Can add a subtree and remove it successfully. Directory deleted, config updated, exactly one commit created. Success message shows correct format with commit hash.

---

## Phase 4: US2 - Idempotent Removal (12 tasks)

**Goal**: Enable idempotent behavior - succeed even if directory already deleted, clean up orphaned config entries.

**User Story**: US2 - Idempotent Removal (Priority: P2)
- Skip git rm when directory missing
- Still remove config entry
- Create commit with config change only
- Display idempotent success message

**Independent Test**: Manually delete subtree directory, run remove command, verify config cleaned up, success with idempotent message.

### Idempotent Logic Tests (TDD)

- [X] T040 [P] [US2] Write test for directory-missing path in Tests/SubtreeLibTests/Commands/RemoveCommandTests.swift (FR-012, FR-013)
- [X] T041 [P] [US2] Write integration test for removal when directory already gone in Tests/IntegrationTests/RemoveIntegrationTests.swift
- [X] T042 [P] [US2] Write integration test for idempotent success message in Tests/IntegrationTests/RemoveIntegrationTests.swift (FR-030)
- [X] T043 [P] [US2] Write integration test for double-removal error in Tests/IntegrationTests/RemoveIntegrationTests.swift (second run shows "not found")

### Idempotent Implementation

- [X] T044 [US2] Add conditional logic for directory existence in Sources/SubtreeLib/Commands/RemoveCommand.swift (skip git rm if missing)
- [X] T045 [US2] Ensure config removal works when directory missing in Sources/SubtreeLib/Commands/RemoveCommand.swift (FR-011)
- [X] T046 [US2] Implement commit creation for config-only changes in Sources/SubtreeLib/Commands/RemoveCommand.swift (directory already gone)
- [X] T047 [US2] Implement idempotent success message variant in Sources/SubtreeLib/Commands/RemoveCommand.swift (FR-030, indicates directory already removed)

### Idempotent Edge Case Tests (TDD)

- [X] T048 [P] [US2] Write test for exit code 0 on idempotent success in Tests/SubtreeLibTests/Commands/RemoveCommandTests.swift (FR-014)
- [X] T049 [P] [US2] Write test for second removal attempt failure in Tests/IntegrationTests/RemoveIntegrationTests.swift (config entry gone, exit code 2)

### Idempotent Edge Cases Implementation

- [X] T050 [US2] Verify exit code 0 for both removal variants in Sources/SubtreeLib/Commands/RemoveCommand.swift (normal and idempotent)
- [X] T051 [US2] Ensure second removal fails gracefully with "not found" in Sources/SubtreeLib/Commands/RemoveCommand.swift (config already cleaned)

**Phase 4 Verification**: Can manually delete subtree directory and remove command still succeeds. Config cleaned up, idempotent message shown. Second removal fails with clear error.

---

## Phase 5: Polish & Validation (2 tasks)

**Goal**: Final cleanup, comprehensive validation, documentation updates.

### Final Validation

- [X] T052 Run full quickstart validation scenarios from specs/006-remove-command/quickstart.md
- [X] T053 Update .windsurf/rules/architecture.md with Remove command patterns per Constitution Principle V

**Phase 5 Verification**: All 53 tasks complete, all tests passing, CI green on both platforms, agent rules updated.

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
    ↓
Phase 2 (Foundational - US3 Validation) ← MUST complete before US1/US2
    ↓
Phase 3 (US1 - Clean Removal) ← Independent, can deploy alone
    ↓
Phase 4 (US2 - Idempotent Removal) ← Depends on US1 (enhances core removal)
    ↓
Phase 5 (Polish)
```

### Critical Path

**Blocking Tasks** (must complete in order):
1. T001-T004: Setup files
2. T010-T014: Core validation logic (blocks all user stories)
3. T024-T026: Directory removal (blocks US1 completion)
4. T029-T030: Config update (blocks US1 completion)
5. T034-T036: Atomic commit (blocks US1 completion)
6. T044-T047: Idempotent logic (blocks US2 completion)

**Parallel Opportunities**:
- All test writing tasks marked [P] can run in parallel
- T001-T004 can all run in parallel (different files)
- T005-T009 can run in parallel (independent test methods)
- T015-T019 can run in parallel (independent integration tests)
- T021-T023, T027-T028, T031-T033, T037-T038 can run in parallel (independent tests)
- T040-T043, T048-T049 can run in parallel (independent tests)

---

## Implementation Strategy

### MVP Scope (Minimum Viable Product)

**Phase 2 + Phase 3 = MVP**
- Core validation (prevents data loss)
- Clean removal (directory + config + atomic commit)
- Error handling (clear messages, correct exit codes)

**Estimated Tasks for MVP**: 39 tasks (T001-T039)
**Value**: Users can safely remove subtrees with automatic config cleanup

### Incremental Delivery

1. **Iteration 1** (MVP): Phases 1-3 (T001-T039)
   - Ship: Basic remove command with validation
   - Test: Clean removal scenarios
   
2. **Iteration 2** (Robustness): Phase 4 (T040-T051)
   - Ship: Idempotent behavior
   - Test: Recovery scenarios

3. **Iteration 3** (Polish): Phase 5 (T052-T053)
   - Ship: Documentation updates
   - Test: Full validation suite

### Testing Strategy

**Unit Tests** (Tests/SubtreeLibTests/Commands/RemoveCommandTests.swift):
- Validation logic (T005-T009)
- Directory existence check (T021)
- Git rm execution (T022)
- Config entry removal (T027)
- Config atomic write (T028)
- Commit message formatting (T031)
- Idempotent logic (T040, T048)
- Total: ~15-20 unit tests

**Integration Tests** (Tests/IntegrationTests/RemoveIntegrationTests.swift):
- Error scenarios (T015-T019): 5 tests
- Clean removal (T023, T032-T033, T037-T038): 5 tests
- Idempotent removal (T041-T043, T049): 4 tests
- Total: ~13-15 integration tests

**Total Test Count**: ~29-36 tests

---

## Success Criteria Mapping

| Success Criteria | Verified By Tasks |
|------------------|-------------------|
| SC-001: Removal <5 seconds for <10,000 files | T052 (quickstart performance tests) |
| SC-002: 100% single atomic commits | T032-T033, T037 (integration tests verify commit count + recovery) |
| SC-003: Single command without manual editing | T039 (end-to-end integration test) |
| SC-004: Idempotent (second run shows error) | T043, T049, T051 (double-removal tests) |
| SC-005: Idempotent removal <1 second | T052 (quickstart performance tests) |
| SC-006: Validation before modifications | T005-T020 (all validation tests) |
| SC-007: Clear error messages | T015-T019 (integration tests check messages) |
| SC-008: Works on macOS + Ubuntu | T052 (CI validation on both platforms) |
| SC-009: Commit messages preserve recovery info | T031, T034 (commit message format tests) |
| SC-010: 90% success without docs | T052 (manual usability validation) |

---

## Functional Requirements Coverage

All 30 functional requirements (FR-001 through FR-030) are covered by tasks:

**Command Interface** (FR-001, FR-002): T001-T002 (command structure)
**Validation** (FR-003-FR-008): T005-T014, T020 (validation logic)
**Removal Operation** (FR-009-FR-011): T024-T030 (directory + config removal)
**Idempotent Behavior** (FR-012-FR-014): T040-T051 (idempotent logic)
**Atomic Commit** (FR-015-FR-019): T031-T037 (commit creation + failure recovery)
**Error Handling** (FR-020-FR-027): T015-T020 (error messages + exit codes)
**Output** (FR-028-FR-030): T038-T039, T047 (success messages)

---

## Notes

**TDD Discipline**: Each phase follows write-test-first pattern. Tests are grouped before implementation tasks.

**Parallel Execution**: All test writing tasks marked [P] can be done concurrently. Implementation tasks are sequential within each phase but phases can be developed by different contributors.

**Independent Testing**: Each phase has clear verification criteria. US1 and US2 can be tested independently (US1 doesn't require US2 to pass tests).

**Constitution Compliance**: 
- Principle I: Spec-first ✅ (tasks derived from spec.md)
- Principle II: TDD ✅ (tests before implementation, explicit test tasks)
- Principle III: Small specs ✅ (single feature, independently testable)
- Principle IV: CI gates ✅ (T052 validates CI passes)
- Principle V: Agent maintenance ✅ (T053 updates agent rules)

---

**Ready for Implementation**: All tasks defined with clear file paths and dependencies. Follow task order for optimal workflow.
