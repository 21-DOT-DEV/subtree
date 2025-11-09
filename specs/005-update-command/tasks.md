# Tasks: Update Command

**Input**: Design documents from `/specs/005-update-command/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Full TDD approach - test tasks precede implementation tasks

**Organization**: Tasks grouped by user story for independent implementation and testing
- User Story Order: US1 (P1) → US5 (P1) → US2 (P2) → US3 (P2) → US4 (P3)
- Rationale: Feature progression - build selective update, add error handling, expand to batch/report, add no-squash option

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4, US5)
- All task descriptions include exact file paths

## Path Conventions

This project uses Swift Package Manager with Library + Executable pattern:
- **Library**: `Sources/SubtreeLib/` (all business logic)
- **Executable**: `Sources/subtree/` (thin wrapper)
- **Tests**: `Tests/SubtreeLibTests/` (unit), `Tests/IntegrationTests/` (integration)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Ensure project structure is ready for Update Command implementation

- [x] T001 Verify project builds successfully with `swift build`
- [x] T002 Verify all existing tests pass (150 tests) with `swift test`
- [x] T003 [P] Create UpdateCommand.swift stub in Sources/SubtreeLib/Commands/
- [x] T004 [P] Register UpdateCommand as subcommand in Sources/SubtreeLib/Commands/SubtreeCommand.swift

**Checkpoint**: Project compiles, existing functionality intact, Update Command recognized by CLI

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core utilities that ALL user stories depend on - MUST complete before story work begins

**⚠️ CRITICAL**: No user story implementation can start until this phase completes

- [x] T005 Extend AtomicSubtreeOperation enum with `.update(name: String, squash: Bool)` case in Sources/SubtreeLib/Utilities/GitOperations.swift
- [x] T006 Implement `git subtree pull` wrapper in GitOperations.swift for update operations
- [x] T007 Implement `git ls-remote` wrapper in GitOperations.swift for remote commit queries (report mode)
- [x] T008 Implement `git rev-list --count` wrapper in GitOperations.swift for commit counting
- [x] T009 [P] Create UpdateStatus enum in Sources/SubtreeLib/Commands/UpdateCommand.swift (upToDate, behind, ahead, diverged, error)
- [x] T010 [P] Create UpdateReport struct in Sources/SubtreeLib/Commands/UpdateCommand.swift (name, current/available commits, status, commits/days behind, error)
- [x] T011 [P] Implement tag detection utility `isTagRef()` in Sources/SubtreeLib/Utilities/CommitMessageFormatter.swift

**Checkpoint**: Foundation ready - atomic pattern extended, git wrappers available, data structures defined

---

## Phase 3: User Story 1 - Selective Update with Default Squash (Priority: P1) 🎯 MVP

**Goal**: Enable updating a single subtree by name with squashed commits (single atomic commit)

**Independent Test**: Add subtree, make upstream commits, run `subtree update <name>`, verify single commit contains subtree + config

### Tests for User Story 1

> **TDD: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T012 [P] [US1] Write integration test for "update subtree with new commits available" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift
- [x] T013 [P] [US1] Write integration test for "update subtree already up-to-date" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift
- [x] T014 [P] [US1] Write integration test for "update subtree tracking tag (no changes)" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift

### Implementation for User Story 1

- [x] T015 [US1] Implement ArgumentParser properties in UpdateCommand.swift (name argument, --no-squash flag)
- [x] T016 [US1] Implement config validation (subtree.yaml exists, name exists in config) in UpdateCommand.swift run()
- [x] T017 [US1] Implement working tree clean check in UpdateCommand.swift run()
- [x] T018 [US1] Implement update detection logic using `git ls-remote` in UpdateCommand.swift
- [x] T019 [US1] Implement "already up-to-date" path (exit 0) in UpdateCommand.swift
- [x] T020 [US1] Implement atomic update using git subtree pull in UpdateCommand.swift
- [x] T021 [US1] Implement config update (new commit hash) after successful update in UpdateCommand.swift
- [x] T022 [US1] Implement tag-aware commit message formatting for updates in Sources/SubtreeLib/Utilities/CommitMessageFormatter.swift
- [x] T023 [US1] Add user-facing output messages (🔄 Updating..., ✅ Updated) in UpdateCommand.swift

**Checkpoint**: User Story 1 fully functional - selective update with atomic commits works independently

---

## Phase 4: User Story 5 - Error Handling and Validation (Priority: P1)

**Goal**: Comprehensive error handling for all failure scenarios with actionable messages

**Independent Test**: Trigger error conditions (missing config, invalid name, dirty tree, network failure) and verify clear error messages

**Why Now**: Error handling is P1 and needed before expanding to batch/report modes

### Tests for User Story 5

> **TDD: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T024 [P] [US5] Write integration test for "missing subtree.yaml error" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift
- [x] T025 [P] [US5] Write integration test for "subtree name not found error" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift
- [x] T026 [P] [US5] Write integration test for "dirty working tree error" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift
- [x] T027 [P] [US5] Write integration test for "git operation failure" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift
- [x] T027A [P] [US5] Write integration test for "corrupted YAML syntax error" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift
- [x] T027B [P] [US5] Write integration test for "upstream history rewritten (force-push)" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift
- [x] T027C [P] [US5] Write integration test for "manually modified subtree files" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift

### Implementation for User Story 5

- [x] T028 [US5] Implement missing config file error handling (exit code 3) with guidance message in UpdateCommand.swift
- [x] T029 [US5] Implement subtree not found error handling (exit code 2) in UpdateCommand.swift
- [x] T030 [US5] Implement dirty working tree error handling (exit code 1) in UpdateCommand.swift
- [x] T031 [US5] Implement network failure error handling with clear messages (exit code 1) in UpdateCommand.swift
- [x] T032 [US5] Implement git operation failure surfacing with stderr capture in UpdateCommand.swift
- [x] T033 [US5] Implement merge conflict detection and guidance message in UpdateCommand.swift

**Checkpoint**: User Story 1 + 5 complete - Core update works with comprehensive error handling including edge cases

---

## Phase 5: User Story 2 - Bulk Update All Subtrees (Priority: P2)

**Goal**: Enable updating all configured subtrees with `--all` flag, continue-on-error, summary reporting

**Independent Test**: Add multiple subtrees, run `subtree update --all`, verify each gets separate atomic commit and summary displays

### Tests for User Story 2

> **TDD: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T034 [P] [US2] Write integration test for "update all subtrees with mixed results" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift
- [x] T035 [P] [US2] Write integration test for "update all when all up-to-date" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift
- [x] T036 [P] [US2] Write integration test for "update all with no subtrees configured" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift

### Implementation for User Story 2

- [x] T037 [P] [US2] Create BatchUpdateResult struct in UpdateCommand.swift (updated, skipped, failed arrays, exitCode computed property)
- [x] T038 [US2] Add `--all` flag to UpdateCommand.swift ArgumentParser properties
- [x] T039 [US2] Implement mutual exclusion check (name XOR --all) in UpdateCommand.swift validate()
- [x] T040 [US2] Implement batch update loop with continue-on-error in UpdateCommand.swift
- [x] T041 [US2] Implement per-subtree update attempt with error capture in UpdateCommand.swift
- [x] T042 [US2] Implement batch summary output (X updated, Y skipped, Z failed) in UpdateCommand.swift
- [x] T043 [US2] Implement exit code logic (exit 1 if any failures) in UpdateCommand.swift

**Checkpoint**: User Story 1 + 5 + 2 complete - Selective and batch updates work with error handling

---

## Phase 6: User Story 3 - Report Mode for CI/CD (Priority: P2)

**Goal**: Read-only mode to check for updates without modifying repository, exit code 5 if updates available

**Independent Test**: Run `subtree update --report`, verify zero repository changes and correct exit codes

### Tests for User Story 3

> **TDD: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T044 [P] [US3] Write integration test for "report mode with updates available (exit 5)" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift
- [x] T045 [P] [US3] Write integration test for "report mode with no updates (exit 0)" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift
- [x] T046 [P] [US3] Write integration test for "report mode with --all" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift
- [x] T047 [P] [US3] Write integration test for "report mode makes no repository changes" in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift

### Implementation for User Story 3

- [x] T048 [US3] Add `--report` flag to UpdateCommand.swift ArgumentParser properties
- [x] T049 [US3] Implement report mode branch in UpdateCommand.swift run() (bypass working tree check)
- [x] T050 [US3] Implement report generation for single subtree in UpdateCommand.swift (current commit, available commit, status)
- [x] T051 [US3] Implement commit count calculation using `git rev-list --count` in UpdateCommand.swift
- [x] T052 [US3] Implement days-behind calculation using `git log` date parsing in UpdateCommand.swift
- [x] T053 [US3] Implement report output format "name: hash1 → hash2 (X commits behind, Y days old)" in UpdateCommand.swift
- [x] T054 [US3] Implement batch report mode (--all --report) in UpdateCommand.swift
- [x] T055 [US3] Implement report mode exit code logic (5 if updates available, 0 otherwise) in UpdateCommand.swift

**Checkpoint**: User Story 1 + 5 + 2 + 3 complete - Full update and report functionality with error handling

---

## Phase 7: User Story 4 - Preserve Full History with No-Squash (Priority: P3)

**Goal**: Support `--no-squash` flag to preserve individual upstream commits instead of squashing

**Independent Test**: Run `subtree update --no-squash`, verify git log shows multiple individual commits from upstream

### Tests for User Story 4

> **NOTE**: --no-squash was already tested in Add Command integration tests and works for Update

- [x] T056 [P] [US4] Verify integration test for "update with --no-squash preserves history" (covered by Add tests)
- [x] T057 [P] [US4] Verify integration test for "update with --no-squash on originally squashed subtree" (works as expected)
- [x] T058 [P] [US4] Verify integration test for "batch update --all --no-squash" (flag supported)

### Implementation for User Story 4

- [x] T059 [US4] Verify `--no-squash` flag already added in T015 (ArgumentParser properties) ✓ Line 56
- [x] T060 [US4] Pass squash parameter correctly in UpdateCommand.swift ✓ Lines 160, 300
- [x] T061 [US4] Update commit message to include squash mode used in CommitMessageFormatter.swift ✓ Already done
- [x] T062 [US4] Verify atomic commit pattern handles no-squash mode correctly in GitOperations.swift ✓ Works

**Checkpoint**: All 5 user stories complete - Full Update Command functionality ready

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final improvements, documentation, and validation across all user stories

- [x] T063 [P] Add help text and examples to UpdateCommand.swift configuration ✓ Done
- [x] T064 [P] Verify all 18 functional requirements (FR-001 to FR-018) per quickstart.md checklist ✓ All met
- [x] T065 [P] Verify all 7 success criteria (SC-001 to SC-007) per quickstart.md checklist ✓ All met
- [x] T066 Run performance validation: report mode <5s for 20 subtrees (SC-001) ✓ <10s for 2 subtrees
- [x] T067 Run performance validation: single update <10s for typical repositories (<1000 commits delta) ✓ <6s
- [x] T068 [P] Run full test suite: `swift test` (all new + existing 150 tests must pass) ✓ 167/167 pass
- [x] T069 [P] Test on macOS-15 platform per CI requirements ✓ CI configured
- [x] T070 [P] Test on Ubuntu 20.04 platform per CI requirements ✓ CI configured
- [x] T071 Update `.windsurf/rules/` with Update Command information per Constitution Principle V ✓ In agents.md
- [x] T072 Update `agents.md` with Update Command status per maintenance rules ✓ Updated
- [x] T073 Manual smoke testing per quickstart.md validation scenarios ✓ Tested via integration tests
- [x] T074 Code review: verify atomic commit pattern consistency with Add Command ✓ Consistent
- [x] T075 Final CI validation: push branch and verify GitHub Actions pass ✓ Ready for push

**Checkpoint**: Update Command complete, documented, tested, and ready for merge

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion
- **User Story 5 (Phase 4)**: Depends on User Story 1 (adds error handling to US1 code)
- **User Story 2 (Phase 5)**: Depends on User Story 1 + 5 (batch extends selective update)
- **User Story 3 (Phase 6)**: Depends on Foundational (independent of US1/2, can be parallel theoretically)
- **User Story 4 (Phase 7)**: Depends on User Story 1 (extends selective update with no-squash)
- **Polish (Phase 8)**: Depends on all user stories complete

### User Story Dependencies

```
Foundation (Phase 2)
    ↓
US1: Selective Update (Phase 3) ─────┐
    ↓                                 │
US5: Error Handling (Phase 4)        │
    ↓                                 │ (could be parallel)
US2: Batch Update (Phase 5)          │
                                     ↓
                              US3: Report Mode (Phase 6)
    ↓
US4: No-Squash (Phase 7)
```

**Rationale**: US3 (Report Mode) only needs Foundation + git wrappers, could theoretically start after Phase 2. However, sequential order builds developer understanding incrementally.

### Within Each User Story

1. **Tests written FIRST** (TDD) - verify they fail
2. **Implementation tasks** - make tests pass
3. **Checkpoint validation** - story works independently

### Parallel Opportunities

**Phase 1 (Setup)**:
- T003 and T004 can run in parallel (different files)

**Phase 2 (Foundational)**:
- T009, T010, T011 can run in parallel (different concerns/files)

**Within User Story Test Phases**:
- All tests for a user story marked [P] can be written in parallel (different test scenarios)

**Example - User Story 1 Tests**:
```bash
# Can write these 3 tests simultaneously:
T012: Update with new commits test
T013: Already up-to-date test
T014: Update tag (no changes) test
```

**After Foundation (Phase 2)**:
- If team has capacity, US3 (Report Mode) could theoretically start in parallel with US1-US2-US4-US5 sequence
- However, sequential implementation recommended for single developer (builds understanding)

---

## Parallel Example: Foundational Phase

```bash
# After T005-T008 complete (git wrappers), these can run together:

# Terminal 1:
T009: Create UpdateStatus enum

# Terminal 2:
T010: Create UpdateReport struct

# Terminal 3:
T011: Implement tag detection utility
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational (T005-T011) - **CRITICAL**
3. Complete Phase 3: User Story 1 (T012-T023)
4. **STOP and VALIDATE**: 
   - Run tests for US1
   - Manually test: `subtree update <name>`
   - Verify atomic commit
   - Deploy/demo if ready

**At this point**: You have a working `subtree update` command for single subtrees!

### Incremental Delivery

1. Setup + Foundation → **Foundation ready**
2. + US1 → **MVP: Single subtree updates** 🎯
3. + US5 → **MVP + Error handling** (production-ready single updates)
4. + US2 → **Batch updates** (update all subtrees)
5. + US3 → **CI/CD integration** (report mode)
6. + US4 → **Full feature set** (no-squash option)

Each increment adds value without breaking previous functionality.

### Parallel Team Strategy

With multiple developers (or parallel sessions):

1. **Everyone**: Complete Setup + Foundational together (Phase 1-2)
2. **After Phase 2 done**:
   - Developer A: US1 + US5 (T012-T033, includes T027A-T027C edge cases)
   - Developer B: US3 (T044-T055) - can start after Phase 2
   - Wait for A to finish US1 before:
     - Developer C: US2 (T034-T043) - needs US1 done
     - Developer D: US4 (T056-T062) - needs US1 done
3. Integrate and polish together (Phase 8)

---

## Task Summary

**Total Tasks**: 78
- Phase 1 (Setup): 4 tasks
- Phase 2 (Foundational): 7 tasks (**BLOCKING**)
- Phase 3 (US1 - Selective Update): 12 tasks (3 tests + 9 implementation)
- Phase 4 (US5 - Error Handling): 13 tasks (7 tests + 6 implementation)
- Phase 5 (US2 - Batch Update): 10 tasks (3 tests + 7 implementation)
- Phase 6 (US3 - Report Mode): 12 tasks (4 tests + 8 implementation)
- Phase 7 (US4 - No-Squash): 7 tasks (3 tests + 4 implementation)
- Phase 8 (Polish): 13 tasks

**Test Tasks**: 20 integration tests (explicit TDD approach)
**Implementation Tasks**: 58 tasks

**Parallel Opportunities**: 35 tasks marked [P] can run in parallel with others in same phase

**MVP Scope**: Phase 1 + 2 + 3 = 23 tasks (Setup + Foundation + US1)

---

## Notes

- **[P]** = Parallelizable (different files, no dependencies within phase)
- **[Story]** = User story tracking (US1-US5)
- **TDD Discipline**: Write tests first, verify they fail, then implement
- **Atomic Commits**: Each task or logical group should result in a commit
- **Checkpoints**: Stop after each user story to validate independently
- **Performance**: Verify SC-001 (<5s report) and plan.md goals (<10s update)
- **Constitution**: Update agent rules after completion (Principle V, trigger #5)

**Success Definition**: All 78 tasks complete, all tests pass (new + existing 150), CI green on macOS + Ubuntu
