# Tasks: Extract Clean Mode

**Input**: Design documents from `/specs/010-extract-clean/`  
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/cli-contract.md  
**Branch**: `010-extract-clean`

**Organization**: Tasks grouped by user story for independent implementation and testing.  
**Testing**: TDD approach - tests written first, verified to fail before implementation.  
**MVP Scope**: P1+P2 (ad-hoc clean with checksum + force override)

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story label (US1, US2, etc.) - only for user story phases

## Path Conventions

Based on plan.md structure:
- **Library**: `Sources/SubtreeLib/`
- **Commands**: `Sources/SubtreeLib/Commands/`
- **Utilities**: `Sources/SubtreeLib/Utilities/`
- **Unit Tests**: `Tests/SubtreeLibTests/`
- **Integration Tests**: `Tests/IntegrationTests/`

---

## Phase 1: Setup

**Purpose**: Create new files and test infrastructure for clean mode

- [x] T001 Create test file `Tests/SubtreeLibTests/Utilities/GitOperationsHashTests.swift` with test suite structure
- [x] T002 [P] Create test file `Tests/SubtreeLibTests/Utilities/DirectoryPrunerTests.swift` with test suite structure
- [x] T003 [P] Create test file `Tests/SubtreeLibTests/Commands/ExtractCleanTests.swift` with test suite structure
- [x] T004 [P] Create test file `Tests/IntegrationTests/ExtractCleanIntegrationTests.swift` with test suite structure

**Checkpoint**: Test files created with empty suite structures, ready for TDD

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core utilities that MUST be complete before clean mode can work

**⚠️ CRITICAL**: User story implementation depends on these utilities

### Tests First

- [x] T005 [P] Write test for `GitOperations.hashObject(file:)` returns SHA hash in `Tests/SubtreeLibTests/Utilities/GitOperationsHashTests.swift`
- [x] T006 [P] Write test for `GitOperations.hashObject(file:)` throws error for nonexistent file
- [x] T007 [P] Write test for `DirectoryPruner.add(parentOf:)` collects parent directories in `Tests/SubtreeLibTests/Utilities/DirectoryPrunerTests.swift`
- [x] T008 [P] Write test for `DirectoryPruner.pruneEmpty()` removes empty directories bottom-up
- [x] T009 [P] Write test for `DirectoryPruner` respects boundary (never prunes destination root)
- [x] T010 [P] Write test for `DirectoryPruner` leaves non-empty directories intact

### Implementation

- [x] T011 Implement `GitOperations.hashObject(file:)` using `git hash-object -t blob` in `Sources/SubtreeLib/Utilities/GitOperations.swift`
- [x] T012 Create `DirectoryPruner` struct with `boundary`, `add(parentOf:)`, `pruneEmpty()` in `Sources/SubtreeLib/Utilities/DirectoryPruner.swift`
- [x] T013 Verify all foundational tests pass with `swift test --filter "GitOperationsHash|DirectoryPruner"`

**Checkpoint**: Foundation ready - `hashObject()` and `DirectoryPruner` working. User story implementation can begin.

---

## Phase 3: User Story 1 - Ad-hoc Clean with Checksum Validation (Priority: P1) 🎯 MVP

**Goal**: Remove previously extracted files using `--clean` flag with checksum validation to prevent accidental deletion of modified files.

**Independent Test**: Extract files, run clean with same pattern, verify files removed only when checksums match.

### Tests First (US1)

> **Write these tests FIRST, verify they FAIL before implementation**

- [x] T014 [P] [US1] Write integration test: `--clean` flag removes files when checksums match in `Tests/IntegrationTests/ExtractCleanIntegrationTests.swift`
- [x] T015 [P] [US1] Write integration test: `--clean` fails fast on checksum mismatch with error message
- [x] T016 [P] [US1] Write integration test: `--clean` skips files with missing source and shows warning
- [x] T017 [P] [US1] Write integration test: `--clean` prunes empty directories after file removal
- [x] T018 [P] [US1] Write integration test: `--clean` treats zero matched files as success (exit 0)
- [x] T019 [P] [US1] Write integration test: `--clean --persist` rejected with error (invalid combination)
- [x] T020 [P] [US1] Write unit test for clean mode validation logic in `Tests/SubtreeLibTests/Commands/ExtractCleanTests.swift`

### Implementation (US1)

- [x] T021 [US1] Add `--clean` flag to `ExtractCommand` in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T022 [US1] Add validation rejecting `--clean` combined with `--persist`
- [x] T023 [US1] Implement `runCleanMode()` method structure with mode branching (ad-hoc vs bulk)
- [x] T024 [US1] Implement `runAdHocClean()` for ad-hoc clean with pattern arguments
- [x] T025 [US1] Implement `findFilesToClean()` to match destination files against source patterns
- [x] T026 [US1] Implement `validateChecksum()` using `GitOperations.hashObject()` for source/dest comparison
- [x] T027 [US1] Implement fail-fast behavior on first checksum mismatch (exit 1)
- [x] T028 [US1] Implement skip-with-warning for files where source is missing
- [x] T029 [US1] Implement file deletion with `FileManager.removeItem()` following symlinks
- [x] T030 [US1] Integrate `DirectoryPruner` for post-deletion empty directory cleanup
- [x] T031 [US1] Implement success/error output formatting per cli-contract.md
- [x] T032 [US1] Verify all US1 tests pass with `swift test --filter ExtractClean`

**Checkpoint**: User Story 1 complete. Ad-hoc clean mode works with checksum validation. Can be tested independently.

---

## Phase 4: User Story 2 - Force Clean Override (Priority: P2) 🎯 MVP

**Goal**: Enable `--force` flag to clean files regardless of checksum validation.

**Independent Test**: Modify extracted file, run clean with --force, verify modified file is removed.

### Tests First (US2)

> **Write these tests FIRST, verify they FAIL before implementation**

- [x] T033 [P] [US2] Write integration test: `--clean --force` removes modified files (checksum mismatch) in `Tests/IntegrationTests/ExtractCleanIntegrationTests.swift`
- [x] T034 [P] [US2] Write integration test: `--clean --force` removes files where source is missing
- [x] T035 [P] [US2] Write integration test: `--clean --force` bypasses subtree prefix validation (allows clean after subtree removed)
- [x] T036 [P] [US2] Write integration test: `--clean --force` removes all matching files regardless of validation

### Implementation (US2)

- [x] T037 [US2] Modify checksum validation to skip when `force` flag is true
- [x] T038 [US2] Modify prefix validation to skip when `force` flag is true (FR-021)
- [x] T039 [US2] Modify missing source handling to delete when `force` is true
- [x] T040 [US2] Verify all US2 tests pass with `swift test --filter ExtractClean`

**Checkpoint**: User Stories 1+2 complete. MVP delivered - ad-hoc clean with checksum validation and force override.

---

## Phase 5: User Story 3 - Bulk Clean from Persisted Mappings (Priority: P3)

**Goal**: Clean all files for persisted extraction mappings with `--clean --name` or `--clean --all`.

**Independent Test**: Create saved mappings, run clean with --name, verify all mappings processed.

### Tests First (US3)

- [x] T041 [P] [US3] Write integration test: `--clean --name` cleans all persisted mappings for subtree
- [x] T042 [P] [US3] Write integration test: `--clean --all` cleans all mappings for all subtrees
- [x] T043 [P] [US3] Write integration test: bulk clean continues on error, reports all failures
- [x] T044 [P] [US3] Write integration test: `--clean --name` with no mappings succeeds with message
- [x] T045 [P] [US3] Write integration test: bulk clean exit code is highest severity encountered

### Implementation (US3)

- [x] T046 [US3] Implement `runBulkClean()` for cleaning persisted mappings
- [x] T047 [US3] Implement single-subtree bulk clean (`--clean --name`)
- [x] T048 [US3] Implement all-subtrees bulk clean (`--clean --all`)
- [x] T049 [US3] Implement continue-on-error with failure collection (consistent with bulk extract)
- [x] T050 [US3] Implement failure summary reporting at end of bulk clean
- [x] T051 [US3] Implement exit code priority (3 > 2 > 1) for bulk clean
- [x] T052 [US3] Verify all US3 tests pass

**Checkpoint**: User Story 3 complete. Bulk clean mode fully functional.

---

## Phase 6: User Story 4 - Multi-Pattern Clean (Priority: P4)

**Goal**: Support multiple `--from` patterns in single clean command.

**Independent Test**: Extract with multiple patterns, clean with same patterns, verify all files removed.

### Tests First (US4)

- [x] T053 [P] [US4] Write integration test: multiple `--from` patterns clean files from multiple sources
- [x] T054 [P] [US4] Write integration test: `--exclude` patterns filter which files are cleaned
- [x] T055 [P] [US4] Write integration test: persisted mappings with pattern arrays clean correctly

### Implementation (US4)

- [x] T056 [US4] Modify `findFilesToClean()` to handle multiple `--from` patterns with deduplication
- [x] T057 [US4] Verify exclude patterns apply to clean mode (should already work from extraction code reuse)
- [x] T058 [US4] Verify all US4 tests pass

**Checkpoint**: User Story 4 complete. Multi-pattern clean has feature parity with extraction.

---

## Phase 7: User Story 5 - Clean Error Handling (Priority: P5)

**Goal**: Clear error messages for all clean failure scenarios.

**Independent Test**: Run clean with invalid inputs, verify appropriate error messages and exit codes.

### Tests First (US5)

- [x] T059 [P] [US5] Write integration test: non-existent subtree name returns error with exit 1
- [x] T060 [P] [US5] Write integration test: permission error during delete returns error with exit 3
- [x] T061 [P] [US5] Write integration test: all error messages include actionable suggestions

### Implementation (US5)

- [x] T062 [US5] Review and enhance error messages per cli-contract.md format
- [x] T063 [US5] Ensure all exit codes match FR-024 through FR-027
- [x] T064 [US5] Verify all US5 tests pass

**Checkpoint**: User Story 5 complete. All error scenarios handled with clear messaging.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, and validation

- [x] T065 [P] Update command help text in `ExtractCommand.swift` to include `--clean` documentation
- [x] T066 [P] Update README.md with clean mode examples
- [x] T067 Run full test suite: `swift test`
- [x] T068 Run quickstart.md validation scenarios manually
- [x] T069 Verify performance: clean operation <3 seconds for 10-50 files (SC-001)

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup) ──────────────────┐
                                  ▼
Phase 2 (Foundational) ───────────┤ BLOCKS ALL USER STORIES
                                  │
                                  ▼
                           Phase 3 (US1)
                              P1 MVP
                                  │
                                  ▼
                           Phase 4 (US2)
                              P2 MVP
                                  │
                                  ▼
                           MVP COMPLETE
                                  │
         ┌────────────────────────┼────────────────────────┐
         ▼                        ▼                        ▼
    Phase 5 (US3)          Phase 6 (US4)           Phase 7 (US5)
         │                        │                        │
         └────────────────────────┼────────────────────────┘
                                  ▼
                           Phase 8 (Polish)
```

### User Story Dependencies

| Story | Depends On | Can Start After |
|-------|------------|-----------------|
| US1 (P1) | Phase 2 | Foundational complete |
| US2 (P2) | US1 | US1 implementation (reuses clean logic) |
| US3 (P3) | US1 | US1 complete (bulk uses ad-hoc logic) |
| US4 (P4) | US1 | US1 complete (multi-pattern extends single-pattern) |
| US5 (P5) | US1-US4 | All stories complete (error handling polish) |

### Parallel Opportunities

**Phase 1 (all parallel)**:
- T001, T002, T003, T004 create independent test files

**Phase 2 (tests parallel, then impl)**:
- T005-T010 all test tasks parallel
- T011-T012 can be parallel (different files)

**Phase 3 US1 (tests parallel)**:
- T014-T020 all test tasks parallel
- T021-T031 sequential (same file modifications)

**Phase 4 US2 (tests parallel)**:
- T033-T036 all test tasks parallel

---

## Implementation Strategy

### MVP First (Recommended)

1. **Complete Phase 1**: Setup (T001-T004)
2. **Complete Phase 2**: Foundational (T005-T013) - CRITICAL
3. **Complete Phase 3**: User Story 1 (T014-T032)
4. **Complete Phase 4**: User Story 2 (T033-T040)
5. **STOP and VALIDATE**: Run `swift test --filter ExtractClean`
6. **MVP Complete**: Ad-hoc clean with checksum + force override

### Post-MVP Incremental

7. **Phase 5**: User Story 3 (bulk clean)
8. **Phase 6**: User Story 4 (multi-pattern)
9. **Phase 7**: User Story 5 (error polish)
10. **Phase 8**: Polish & documentation

---

## Summary

| Phase | Story | Tasks | Test Tasks | Impl Tasks |
|-------|-------|-------|------------|------------|
| 1 | Setup | 4 | 0 | 4 |
| 2 | Foundational | 9 | 6 | 3 |
| 3 | US1 (P1) | 19 | 7 | 12 |
| 4 | US2 (P2) | 8 | 4 | 4 |
| 5 | US3 (P3) | 12 | 5 | 7 |
| 6 | US4 (P4) | 6 | 3 | 3 |
| 7 | US5 (P5) | 6 | 3 | 3 |
| 8 | Polish | 5 | 0 | 5 |
| **Total** | | **69** | **28** | **41** |

**MVP Tasks (P1+P2)**: 40 tasks (Phases 1-4)

---

## Notes

- TDD approach: All test tasks marked with "Write test" must be completed and verified to FAIL before implementation
- Each user story has a checkpoint for independent validation
- MVP (Phase 1-4) delivers core clean functionality with safety features
- Remaining phases (5-8) add bulk mode, multi-pattern, and polish
