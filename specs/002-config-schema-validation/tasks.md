# Tasks: Subtree Configuration Schema & Validation

**Input**: Design documents from `/specs/002-config-schema-validation/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included - TDD approach with explicit test tasks before implementation per constitution

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Using existing Swift project structure from bootstrap (001-cli-bootstrap):
- **Library**: `Sources/SubtreeLib/` (all business logic)
- **Tests**: `Tests/SubtreeLibTests/` (unit tests), `Tests/IntegrationTests/` (integration tests)
- **New for this feature**: `Sources/SubtreeLib/Configuration/` module

---

## Phase 1: Setup (Directory Structure)

**Purpose**: Extend project with Configuration module structure

- [x] T001 Create Configuration/ directory structure in Sources/SubtreeLib/Configuration/
- [x] T002 [P] Create Models/ subdirectory in Sources/SubtreeLib/Configuration/Models/
- [x] T003 [P] Create Validation/ subdirectory in Sources/SubtreeLib/Configuration/Validation/
- [x] T004 [P] Create Parsing/ subdirectory in Sources/SubtreeLib/Configuration/Parsing/
- [x] T005 [P] Create Patterns/ subdirectory in Sources/SubtreeLib/Configuration/Patterns/
- [x] T006 Create ConfigurationTests/ directory in Tests/SubtreeLibTests/ConfigurationTests/

---

## Phase 2: Foundational (Models, Parser, Error Types)

**Purpose**: Core data structures and parsing that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundational Components

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T007 [P] Write SubtreeConfiguration parsing tests in Tests/SubtreeLibTests/ConfigurationTests/Models/SubtreeConfigurationTests.swift
- [x] T008 [P] Write SubtreeEntry parsing tests in Tests/SubtreeLibTests/ConfigurationTests/Models/SubtreeEntryTests.swift
- [x] T009 [P] Write ExtractPattern parsing tests in Tests/SubtreeLibTests/ConfigurationTests/Models/ExtractPatternTests.swift
- [x] T010 [P] Write ConfigurationParser tests in Tests/SubtreeLibTests/ConfigurationTests/Parsing/ConfigurationParserTests.swift
- [x] T011 [P] Write YAMLErrorTranslator tests in Tests/SubtreeLibTests/ConfigurationTests/Parsing/YAMLErrorTranslatorTests.swift
- [x] T012 [P] Write ValidationError tests in Tests/SubtreeLibTests/ConfigurationTests/Validation/ValidationErrorTests.swift

**Checkpoint**: ✅ Verified all 6 tests fail initially (TDD)

### Implementation for Foundational Components

- [x] T013 [P] Implement SubtreeConfiguration model in Sources/SubtreeLib/Configuration/Models/SubtreeConfiguration.swift
- [x] T014 [P] Implement SubtreeEntry model in Sources/SubtreeLib/Configuration/Models/SubtreeEntry.swift
- [x] T015 [P] Implement ExtractPattern model in Sources/SubtreeLib/Configuration/Models/ExtractPattern.swift
- [x] T016 Implement ConfigurationParser in Sources/SubtreeLib/Configuration/Parsing/ConfigurationParser.swift (depends on T013-T015)
- [x] T017 [P] Implement YAMLErrorTranslator in Sources/SubtreeLib/Configuration/Parsing/YAMLErrorTranslator.swift
- [x] T018 [P] Implement ValidationError type in Sources/SubtreeLib/Configuration/Validation/ValidationError.swift

**Checkpoint**: ✅ Foundation complete - Models and parsers implemented, ready for user story phases

---

## Phase 3: User Story 1 - Valid Configuration Loading (Priority: P1) 🎯 MVP

**Goal**: Parse and load valid subtree.yaml files with required and optional fields

**Independent Test**: Create valid subtree.yaml with minimal fields, verify successful parsing without errors

**Acceptance Criteria from Spec**:
- FR-001: Parse top-level `subtrees` array
- FR-002: Parse required fields (name, remote, prefix, commit)
- FR-003: Parse optional fields (tag, branch, squash, extracts)
- FR-031: Accept empty `subtrees: []` as valid

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T019 [P] [US1] Write SchemaValidator tests for FR-001, FR-031 in Tests/SubtreeLibTests/ConfigurationTests/Validation/SchemaValidatorTests.swift
- [x] T020 [P] [US1] Write integration test for valid minimal config in Tests/IntegrationTests/ConfigValidationIntegrationTests.swift
- [x] T021 [P] [US1] Write integration test for valid config with optional fields in Tests/IntegrationTests/ConfigValidationIntegrationTests.swift
- [x] T022 [P] [US1] Write integration test for valid config with multiple subtrees in Tests/IntegrationTests/ConfigValidationIntegrationTests.swift
- [x] T023 [P] [US1] Write integration test for empty subtrees array in Tests/IntegrationTests/ConfigValidationIntegrationTests.swift

**Checkpoint**: ✅ Verified all US1 tests written (TDD)

### Implementation for User Story 1

- [x] T024 [US1] Implement SchemaValidator in Sources/SubtreeLib/Configuration/Validation/SchemaValidator.swift
- [x] T025 [US1] Implement ConfigurationValidator facade in Sources/SubtreeLib/Configuration/Validation/ConfigurationValidator.swift
- [x] T026 [US1] Integrate SchemaValidator into ConfigurationValidator facade
- [x] T027 [US1] Update ConfigurationParser to use ConfigurationValidator for valid configs

**Checkpoint**: ✅ User Story 1 complete - valid configs parse and validate successfully (MVP ready)

---

## Phase 4: User Story 2 - Configuration Validation with Clear Error Messages (Priority: P1)

**Goal**: Validate all fields and constraints, providing clear actionable error messages for invalid configs

**Independent Test**: Create intentionally invalid configs, verify meaningful error messages are produced

**Acceptance Criteria from Spec**:
- FR-005 through FR-019: Type and format validation
- FR-020 through FR-024: Error reporting quality
- FR-030: Duplicate name validation

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

#### Type Validator Tests

- [x] T028 [P] [US2] Write TypeValidator test for FR-005 (name non-empty) in Tests/SubtreeLibTests/ConfigurationTests/Validation/TypeValidatorTests.swift
- [x] T029 [P] [US2] Write TypeValidator test for FR-009 (tag/branch non-empty) in Tests/SubtreeLibTests/ConfigurationTests/Validation/TypeValidatorTests.swift
- [x] T030 [P] [US2] Write TypeValidator test for FR-010 (squash boolean) in Tests/SubtreeLibTests/ConfigurationTests/Validation/TypeValidatorTests.swift
- [x] T031 [P] [US2] Write TypeValidator test for FR-011 (extracts non-empty array) in Tests/SubtreeLibTests/ConfigurationTests/Validation/TypeValidatorTests.swift

#### Format Validator Tests

- [x] T032 [P] [US2] Write FormatValidator test for FR-006 (remote URL format) in Tests/SubtreeLibTests/ConfigurationTests/Validation/FormatValidatorTests.swift
- [x] T033 [P] [US2] Write FormatValidator test for FR-007 (prefix path safety) in Tests/SubtreeLibTests/ConfigurationTests/Validation/FormatValidatorTests.swift
- [x] T034 [P] [US2] Write FormatValidator test for FR-008 (commit hash format) in Tests/SubtreeLibTests/ConfigurationTests/Validation/FormatValidatorTests.swift

#### Logic Validator Tests

- [x] T035 [P] [US2] Write LogicValidator test for FR-012 (tag/branch mutual exclusivity) in Tests/SubtreeLibTests/ConfigurationTests/Validation/LogicValidatorTests.swift
- [x] T036 [P] [US2] Write LogicValidator test for FR-013 (commit only) in Tests/SubtreeLibTests/ConfigurationTests/Validation/LogicValidatorTests.swift
- [x] T037 [P] [US2] Write LogicValidator test for FR-014 (tag + commit) in Tests/SubtreeLibTests/ConfigurationTests/Validation/LogicValidatorTests.swift
- [x] T038 [P] [US2] Write LogicValidator test for FR-015 (branch + commit) in Tests/SubtreeLibTests/ConfigurationTests/Validation/LogicValidatorTests.swift
- [x] T039 [P] [US2] Write LogicValidator test for FR-016 (unknown fields at entry level) in Tests/SubtreeLibTests/ConfigurationTests/Validation/LogicValidatorTests.swift
- [x] T040 [P] [US2] Write LogicValidator test for FR-030 (duplicate names) in Tests/SubtreeLibTests/ConfigurationTests/Validation/LogicValidatorTests.swift

#### Integration Tests for Error Messages

- [x] T041 [P] [US2] Write integration test for missing required field error in Tests/IntegrationTests/ConfigValidationIntegrationTests.swift
- [x] T042 [P] [US2] Write integration test for invalid commit format error in Tests/IntegrationTests/ConfigValidationIntegrationTests.swift
- [x] T043 [P] [US2] Write integration test for tag/branch conflict error in Tests/IntegrationTests/ConfigValidationIntegrationTests.swift
- [x] T044 [P] [US2] Write integration test for invalid remote URL error in Tests/IntegrationTests/ConfigValidationIntegrationTests.swift
- [x] T045 [P] [US2] Write integration test for duplicate name error in Tests/IntegrationTests/ConfigValidationIntegrationTests.swift
- [x] T046 [P] [US2] Write integration test for unsafe path error in Tests/IntegrationTests/ConfigValidationIntegrationTests.swift
- [x] T047 [P] [US2] Write integration test for multiple errors collected (FR-024) in Tests/IntegrationTests/ConfigValidationIntegrationTests.swift

**Checkpoint**: ✅ All US2 tests written (TDD) - 20 tests covering all validation scenarios

### Implementation for User Story 2

- [x] T048 [P] [US2] Implement TypeValidator in Sources/SubtreeLib/Configuration/Validation/TypeValidator.swift
- [x] T049 [P] [US2] Implement FormatValidator in Sources/SubtreeLib/Configuration/Validation/FormatValidator.swift
- [x] T050 [P] [US2] Implement LogicValidator in Sources/SubtreeLib/Configuration/Validation/LogicValidator.swift
- [x] T051 [US2] Integrate TypeValidator, FormatValidator, LogicValidator into ConfigurationValidator facade
- [x] T052 [US2] Verify error message quality matches contracts/validation-error-format.md
- [x] T053 [US2] Update YAMLErrorTranslator for YAML syntax error messages per FR-026, FR-028

**Checkpoint**: ✅ User Stories 1 AND 2 complete - valid configs load, invalid configs produce clear, actionable error messages

---

## Phase 5: User Stories 3+4 - Extract Pattern Validation + Documentation (Priority: P2)

**Goal**: Validate glob patterns in extract rules and provide comprehensive schema documentation

**Independent Test**: Create configs with extract patterns, verify glob syntax validation works

**Acceptance Criteria from Spec**:
- US3: FR-017, FR-018, FR-019, FR-029 (extract pattern validation)
- US4: Schema documentation with examples

### Tests for User Stories 3+4

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T054 [P] [US3] Write GlobPatternValidator test for valid patterns in Tests/SubtreeLibTests/ConfigurationTests/Patterns/GlobPatternValidatorTests.swift
- [x] T055 [P] [US3] Write GlobPatternValidator test for `**` (globstar) in Tests/SubtreeLibTests/ConfigurationTests/Patterns/GlobPatternValidatorTests.swift
- [x] T056 [P] [US3] Write GlobPatternValidator test for `{...}` (brace expansion) in Tests/SubtreeLibTests/ConfigurationTests/Patterns/GlobPatternValidatorTests.swift
- [x] T057 [P] [US3] Write GlobPatternValidator test for `[...]` (character classes) in Tests/SubtreeLibTests/ConfigurationTests/Patterns/GlobPatternValidatorTests.swift
- [x] T058 [P] [US3] Write GlobPatternValidator test for unclosed brace error in Tests/SubtreeLibTests/ConfigurationTests/Patterns/GlobPatternValidatorTests.swift
- [x] T059 [P] [US3] Write GlobPatternValidator test for unclosed bracket error in Tests/SubtreeLibTests/ConfigurationTests/Patterns/GlobPatternValidatorTests.swift
- [x] T060 [P] [US3] Write FormatValidator test for FR-029 (extracts.to path safety) in Tests/SubtreeLibTests/ConfigurationTests/Validation/FormatValidatorTests.swift
- [x] T061 [P] [US3] Write LogicValidator test for FR-017 (unknown fields in extracts) in Tests/SubtreeLibTests/ConfigurationTests/Validation/LogicValidatorTests.swift
- [x] T062 [P] [US3] Write LogicValidator test for FR-018 (extracts missing from/to) in Tests/SubtreeLibTests/ConfigurationTests/Validation/LogicValidatorTests.swift
- [x] T063 [P] [US3] Write integration test for valid extract patterns in Tests/IntegrationTests/ConfigValidationIntegrationTests.swift
- [x] T064 [P] [US3] Write integration test for invalid glob pattern error in Tests/IntegrationTests/ConfigValidationIntegrationTests.swift

**Checkpoint**: ✅ All US3+US4 tests written (TDD)

### Implementation for User Stories 3+4

- [x] T065 [US3] Implement GlobPatternValidator in Sources/SubtreeLib/Configuration/Patterns/GlobPatternValidator.swift
- [x] T066 [US3] Add extract pattern validation to FormatValidator (FR-019, FR-029)
- [x] T067 [US3] Add extract pattern validation to LogicValidator (FR-017, FR-018)
- [x] T068 [US3] Integrate GlobPatternValidator into FormatValidator
- [x] T069 [P] [US4] Verify contracts/yaml-schema.md has all required examples per FR coverage
- [x] T070 [P] [US4] Verify contracts/validation-error-format.md has examples for all error categories

**Checkpoint**: ✅ All user stories complete - full validation working with glob patterns and comprehensive documentation

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final improvements and documentation updates

- [x] T071 [P] Run full test suite - verify all 31 FRs have passing tests
- [x] T072 [P] Performance test with 100-subtree config - verify <1 second per SC-002
- [x] T073 [P] Verify SC-001: Valid configs parse on first attempt
- [x] T074 [P] Verify SC-004: YAML errors are user-friendly (not technical)
- [x] T075 [P] Verify SC-005: All constraint violations caught before git operations
- [x] T076 [P] Verify SC-006: Schema documentation has all field combination examples
- [x] T077 Run quickstart.md validation checkpoints
- [x] T078 Update .windsurf/rules/bootstrap.md with Configuration/ module per constitution Principle V
- [x] T079 [P] Code review validation against data-model.md and contracts/
- [x] T080 [P] Final integration test sweep - all user scenarios from spec

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational - Can start after Phase 2
- **User Story 2 (Phase 4)**: Depends on Foundational - Can start after Phase 2 (parallel with US1)
- **User Stories 3+4 (Phase 5)**: Depends on Foundational - Can start after Phase 2 (parallel with US1, US2)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Independent - Only depends on Foundational phase
- **User Story 2 (P1)**: Independent - Only depends on Foundational phase (uses same validators, different tests)
- **User Stories 3+4 (P2)**: Independent - Only depends on Foundational phase (adds glob validation on top)

### Within Each User Story

- Tests MUST be written first (T007-T012, T019-T023, T028-T047, T054-T064)
- Tests MUST fail before implementation begins
- Models complete before validators (handled in Foundational phase)
- Validators complete before integration
- Story tests pass before moving to next priority

### Parallel Opportunities

**Phase 1 (Setup)**: All tasks T001-T006 can run in parallel

**Phase 2 (Foundational)**:
- Tests: T007, T008, T009, T010, T011, T012 can run in parallel
- Implementation: T013, T014, T015 can run in parallel; T017, T018 can run in parallel with T016

**Phase 3 (US1)**:
- Tests: T019, T020, T021, T022, T023 can run in parallel

**Phase 4 (US2)**:
- Tests: All T028-T047 can run in parallel
- Implementation: T048, T049, T050 can run in parallel

**Phase 5 (US3+US4)**:
- Tests: All T054-T064 can run in parallel
- Implementation: T069, T070 can run in parallel with T065-T068

**Phase 6 (Polish)**: T071-T076, T079-T080 can run in parallel

**Cross-Phase Parallelism**: After Foundational completes, US1, US2, and US3+US4 can all proceed in parallel

---

## Parallel Example: User Story 2 (Error Validation)

```bash
# Launch all tests for User Story 2 together:
# TypeValidator tests (T028-T031)
# FormatValidator tests (T032-T034)
# LogicValidator tests (T035-T040)
# Integration tests (T041-T047)

# Then launch all validator implementations together:
# T048: TypeValidator
# T049: FormatValidator  
# T050: LogicValidator
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (valid config loading)
4. **STOP and VALIDATE**: Test US1 independently per quickstart.md
5. Deliverable: Parser that loads valid subtree.yaml files

### Incremental Delivery (P1 Stories)

1. Foundation ready (Phase 1+2)
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo (Full validation!)
4. Each story adds value without breaking previous stories

### Full Feature (Add P2 Stories)

1. Foundation + US1 + US2 complete
2. Add User Stories 3+4 → Test independently → Deploy/Demo
3. Complete feature with extract pattern validation and documentation

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done (Phase 2 complete):
   - Developer A: User Story 1 (Phase 3)
   - Developer B: User Story 2 (Phase 4)
   - Developer C: User Stories 3+4 (Phase 5)
3. Stories complete and integrate independently
4. Team converges on Polish phase

---

## Task Count Summary

- **Phase 1 (Setup)**: 6 tasks
- **Phase 2 (Foundational)**: 12 tasks (6 tests + 6 implementation)
- **Phase 3 (US1)**: 9 tasks (5 tests + 4 implementation)
- **Phase 4 (US2)**: 26 tasks (20 tests + 6 implementation)
- **Phase 5 (US3+US4)**: 17 tasks (11 tests + 6 implementation)
- **Phase 6 (Polish)**: 10 tasks

**Total**: 80 tasks

**Test Coverage**: 42 test tasks covering all 31 FRs plus integration scenarios

---

## Notes

- [P] tasks = different files, no dependencies - can run in parallel
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- TDD discipline: Write tests → verify fail → implement → verify pass
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Constitution Principle V: Update .windsurf/rules/bootstrap.md after implementation (T078)
