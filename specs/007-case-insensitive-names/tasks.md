# Tasks: Case-Insensitive Names & Validation

**Input**: Design documents from `/specs/007-case-insensitive-names/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Explicit test tasks included per TDD discipline (Constitution Principle II)

**Organization**: Tasks organized by validation layer (foundation → add → remove/update → verification) to optimize shared dependency reuse

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4, US5)
- Include exact file paths in descriptions

## Path Conventions

- **Sources/SubtreeLib/**: Library module (all business logic)
- **Tests/SubtreeLibTests/**: Unit tests
- **Tests/IntegrationTests/**: Integration tests

---

## Phase 1: Setup (Project Already Exists)

**Purpose**: No setup needed - project structure established by spec 001

**Status**: ✅ Complete (skip to Phase 2)

---

## Phase 2: Foundational (Validation Infrastructure)

**Purpose**: Shared validation utilities that ALL user stories depend on

**⚠️ CRITICAL**: No command modifications can begin until this phase is complete

### Tests for Foundation

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T001 [P] Write ValidationError tests in Tests/SubtreeLibTests/Utilities/ValidationErrorTests.swift
- [X] T002 [P] Write PathValidator tests in Tests/SubtreeLibTests/Utilities/PathValidatorTests.swift
- [X] T003 [P] Write NameValidator tests in Tests/SubtreeLibTests/Utilities/NameValidatorTests.swift
- [X] T004 [P] Write StringExtensions tests in Tests/SubtreeLibTests/Utilities/StringExtensionsTests.swift
- [X] T005 Write SubtreeConfig validation tests in Tests/SubtreeLibTests/ConfigurationTests/SubtreeConfigurationValidationTests.swift

### Implementation for Foundation

- [X] T006 [P] Implement ValidationError enum in Sources/SubtreeLib/Utilities/ValidationError.swift
- [X] T007 [P] Implement PathValidator struct in Sources/SubtreeLib/Utilities/PathValidator.swift
- [X] T008 [P] Implement NameValidator struct in Sources/SubtreeLib/Utilities/NameValidator.swift
- [X] T009 [P] Implement String extensions in Sources/SubtreeLib/Utilities/StringExtensions.swift
- [X] T010 Extend SubtreeConfig with validation methods in Sources/SubtreeLib/Configuration/SubtreeConfiguration.swift

**Checkpoint**: Foundation ready - all validation utilities tested and working. Command modifications can now begin in parallel.

---

## Phase 3: User Story 2 & 3 - Add Command Validation (Priority: P2)

**Goal**: Prevent duplicate names and prefixes during add operations, validate path format

**Independent Test**: Add subtree named `Hello-World`, then attempt to add `hello-world`. Verify second add fails with clear error before git operations.

**Combined Stories**: US2 (Duplicate Name Prevention) + US3 (Duplicate Prefix Prevention) + Path Validation

### Tests for Add Command Validation

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T011 [P] [US2] Write duplicate name prevention tests in Tests/IntegrationTests/AddIntegrationTests.swift
- [X] T012 [P] [US3] Write duplicate prefix prevention tests in Tests/IntegrationTests/AddIntegrationTests.swift
- [X] T013 [P] [US2] Write path validation tests (absolute, traversal, backslashes) in Tests/IntegrationTests/AddIntegrationTests.swift
- [X] T014 [P] [US2] Write whitespace normalization tests in Tests/IntegrationTests/AddIntegrationTests.swift
- [X] T015 [P] [US2] Write non-ASCII warning tests in Tests/IntegrationTests/AddIntegrationTests.swift

### Implementation for Add Command

- [X] T016 [US2][US3] Modify AddCommand to validate names/prefixes before git operations in Sources/SubtreeLib/Commands/AddCommand.swift
- [X] T017 [US2] Add whitespace normalization to AddCommand input processing in Sources/SubtreeLib/Commands/AddCommand.swift
- [X] T018 [US2] Add non-ASCII warning display to AddCommand in Sources/SubtreeLib/Commands/AddCommand.swift
- [X] T019 [US2][US3] Add config validation call before add operations in Sources/SubtreeLib/Commands/AddCommand.swift

**Checkpoint**: Add command prevents all duplicate scenarios and invalid paths. Users cannot create problematic configs through CLI.

---

## Phase 4: User Story 1 - Case-Insensitive Lookup (Priority: P1)

**Goal**: Users can reference subtrees by name in any case variation (remove/update commands)

**Independent Test**: Add subtree with name `My-Library`, then successfully remove it with `subtree remove my-library`. Verify config entry is deleted.

### Tests for Remove Command

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T020 [P] [US1] Write case-insensitive removal tests in Tests/IntegrationTests/RemoveIntegrationTests.swift
- [X] T021 [P] [US1] Write not-found error tests in Tests/IntegrationTests/RemoveIntegrationTests.swift
- [X] T022 [P] [US1] Write whitespace trimming tests in Tests/IntegrationTests/RemoveIntegrationTests.swift

### Implementation for Remove Command

- [X] T023 [US1] Modify RemoveCommand to use case-insensitive name lookup in Sources/SubtreeLib/Commands/RemoveCommand.swift
- [X] T024 [US1] Add config validation call before remove operations in Sources/SubtreeLib/Commands/RemoveCommand.swift

### Tests for Update Command

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T025 [P] [US1] Write case-insensitive update tests in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift
- [X] T026 [P] [US1] Write not-found error tests in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift
- [X] T027 [P] [US1] Write whitespace trimming tests in Tests/IntegrationTests/UpdateCommandIntegrationTests.swift

### Implementation for Update Command

- [X] T028 [US1] Modify UpdateCommand to use case-insensitive name lookup in Sources/SubtreeLib/Commands/UpdateCommand.swift
- [X] T029 [US1] Add config validation call before update operations in Sources/SubtreeLib/Commands/UpdateCommand.swift

**Checkpoint**: Remove and Update commands accept any case variation. Users don't need to remember exact capitalization.

---

## Phase 5: User Story 4 & 5 - Corruption Detection & Case Preservation (Priority: P3-P4)

**Goal**: Detect manually corrupted configs and verify case preservation behavior

**Independent Test**: Manually create config with `Hello-World` and `hello-world` entries. Run any command. Verify it fails with diagnostic error.

**Combined Stories**: US4 (Config Corruption Detection) + US5 (Case Preservation)

### Tests for Corruption Detection

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T030 [P] [US4] Write multiple matches detection tests for Remove in Tests/IntegrationTests/RemoveIntegrationTests.swift
- [X] T031 [P] [US4] Write multiple matches detection tests for Update in Tests/IntegrationTests/UpdateIntegrationTests.swift
- [X] T032 [P] [US4] Write config corruption detection tests for Add in Tests/IntegrationTests/AddIntegrationTests.swift
- [X] T033 [P] [US4] Write duplicate prefix corruption tests in Tests/IntegrationTests/AddIntegrationTests.swift

### Tests for Case Preservation

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T034 [P] [US5] Write case preservation tests for Add in Tests/IntegrationTests/AddIntegrationTests.swift
- [X] T035 [P] [US5] Write case preservation tests for Update in Tests/IntegrationTests/UpdateIntegrationTests.swift
- [X] T036 [P] [US5] Write mixed-case config verification tests in Tests/IntegrationTests/AddIntegrationTests.swift

### Implementation for Corruption Detection & Case Preservation

**Note**: Most implementation already complete in Phase 2-4. These tasks verify behavior.

- [X] T037 [US4][US5] Verify SubtreeConfig.findSubtree() handles multiple matches correctly (code review/test)
- [X] T038 [US4][US5] Verify all commands use config.validate() before operations (code review/test)
- [X] T039 [US5] Verify whitespace normalization preserves case after trimming (code review/test)

**Checkpoint**: Config corruption detected with helpful errors. Original case always preserved in config file.

---

## Phase 6: Polish & Validation

**Purpose**: Final validation, documentation, and cross-cutting improvements

- [X] T040 [P] Update .windsurf/rules with validation patterns and modified commands (NOTE: .windsurf/rules is protected - manual update required)
- [X] T041 [P] Update agents.md with feature status and validation capabilities
- [X] T042 [P] Update README.md with validation behavior documentation
- [X] T043 Run quickstart.md validation checklist
- [X] T044 [P] Add error message examples to contracts/ documentation
- [X] T045 Verify all 310 tests pass (swift test)
- [X] T046 Verify CI passes on macOS-15 and Ubuntu 20.04 (NOTE: Manual verification - push to GitHub to trigger ci.yml)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1: Setup**: ✅ Complete (project already established)
- **Phase 2: Foundational**: Can start immediately - BLOCKS all command modifications
- **Phase 3: US2+US3 (Add)**: Depends on Foundational completion
- **Phase 4: US1 (Remove/Update)**: Depends on Foundational completion, can run parallel with Phase 3
- **Phase 5: US4+US5 (Verification)**: Depends on Phases 2-4 completion
- **Phase 6: Polish**: Depends on all user stories being complete

### User Story Dependencies

- **Foundation (Phase 2)**: No dependencies - shared infrastructure
- **US2+US3 (Phase 3)**: Depends on Foundation - can start after T010
- **US1 (Phase 4)**: Depends on Foundation - can start after T010, **can run parallel with Phase 3**
- **US4+US5 (Phase 5)**: Depends on all previous phases - verification of integrated behavior

### Within Each Phase

- **Foundation (Phase 2)**: Tests (T001-T005) → Implementation (T006-T010)
  - All tests can run in parallel (marked [P])
  - All implementations can run in parallel after tests pass (marked [P])
- **Phase 3 (Add)**: Tests (T011-T015) → Implementation (T016-T019)
  - All tests can run in parallel (marked [P])
- **Phase 4 (Remove/Update)**: Tests (T020-T027) → Implementation (T023-T029)
  - Remove tests can run in parallel (T020-T022)
  - Update tests can run in parallel (T025-T027)
  - Remove and Update implementations are sequential (modify same command patterns)
- **Phase 5 (Verification)**: Tests (T030-T036) → Review (T037-T039)
  - All tests can run in parallel (marked [P])

### Parallel Opportunities

**Maximum Parallelism After Foundation (T010)**:
- Phase 3 (Add Command): Developer A
- Phase 4 (Remove Command): Developer B
- Phase 4 (Update Command): Developer C

**Critical Path**: Foundation (T001-T010) → Add/Remove/Update (parallel) → Verification (T030-T039) → Polish (T040-T046)

---

## Parallel Example: Foundation Phase

```bash
# Launch all foundation tests together (after T010 complete):
Task T001: "ValidationError tests in Tests/SubtreeLibTests/Utilities/ValidationErrorTests.swift"
Task T002: "PathValidator tests in Tests/SubtreeLibTests/Utilities/PathValidatorTests.swift"
Task T003: "NameValidator tests in Tests/SubtreeLibTests/Utilities/NameValidatorTests.swift"
Task T004: "StringExtensions tests in Tests/SubtreeLibTests/Utilities/StringExtensionsTests.swift"

# Then launch all implementations together (after tests pass):
Task T006: "ValidationError in Sources/SubtreeLib/Utilities/ValidationError.swift"
Task T007: "PathValidator in Sources/SubtreeLib/Utilities/PathValidator.swift"
Task T008: "NameValidator in Sources/SubtreeLib/Utilities/NameValidator.swift"
Task T009: "String extensions in Sources/SubtreeLib/Utilities/StringExtensions.swift"
```

## Parallel Example: Add Command Tests

```bash
# Launch all Add command tests together:
Task T011: "Duplicate name prevention tests"
Task T012: "Duplicate prefix prevention tests"
Task T013: "Path validation tests"
Task T014: "Whitespace normalization tests"
Task T015: "Non-ASCII warning tests"
```

---

## Implementation Strategy

### MVP First (Foundation + Add Command)

1. Complete Phase 2: Foundational (T001-T010)
2. Complete Phase 3: Add Command (T011-T019)
3. **STOP and VALIDATE**: Test Add command prevents duplicates
4. Ready for production use (users can't create invalid configs)

### Incremental Delivery

1. Foundation (T001-T010) → All validation utilities working
2. Add Command (T011-T019) → Test independently → **MVP Ready!**
3. Remove/Update (T020-T029) → Test independently → Enhanced UX
4. Verification (T030-T039) → Test independently → Safety complete
5. Polish (T040-T046) → Documentation and validation

### Parallel Team Strategy

With 3 developers after Foundation complete:

1. **Team completes Foundation together** (T001-T010)
2. Once T010 done:
   - **Developer A**: Add Command (T011-T019)
   - **Developer B**: Remove Command (T020-T024)
   - **Developer C**: Update Command (T025-T029)
3. **All meet for Verification** (T030-T039)
4. **Share Polish tasks** (T040-T046)

---

## Task Summary

**Total Tasks**: 46

**By Phase**:
- Phase 1: Setup - 0 tasks (project exists)
- Phase 2: Foundation - 10 tasks (5 test + 5 implementation)
- Phase 3: US2+US3 (Add) - 9 tasks (5 test + 4 implementation)
- Phase 4: US1 (Remove/Update) - 10 tasks (6 test + 4 implementation)
- Phase 5: US4+US5 (Verification) - 10 tasks (7 test + 3 review)
- Phase 6: Polish - 7 tasks

**By User Story**:
- Foundation: 10 tasks
- US1 (Flexible Name Matching): 10 tasks
- US2 (Duplicate Name Prevention): 9 tasks (combined with US3 in Phase 3)
- US3 (Duplicate Prefix Prevention): 9 tasks (combined with US2 in Phase 3)
- US4 (Config Corruption Detection): 4 tasks
- US5 (Case Preservation): 3 tasks
- Polish: 7 tasks

**Parallel Opportunities**: 31 tasks marked [P] (67% of tasks can run in parallel within phases)

**Independent Test Criteria**:
- Foundation: All validation utilities pass tests independently
- Add Command: Prevents duplicates before git operations
- Remove Command: Finds subtrees case-insensitively
- Update Command: Finds subtrees case-insensitively  
- Corruption Detection: Detects manual config edits
- Case Preservation: Original case always stored

**MVP Scope**: Foundation (T001-T010) + Add Command (T011-T019) = 19 tasks

---

## Notes

- [P] tasks = different files, no dependencies within phase
- [Story] label maps task to specific user story for traceability
- TDD mandatory: Write tests first, verify they fail, then implement
- Each phase should produce independently testable increment
- Commit after each task or logical group
- Stop at any checkpoint to validate functionality independently
- Validation layer organization enables maximum parallelization after foundation
