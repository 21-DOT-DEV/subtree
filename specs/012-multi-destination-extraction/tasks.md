# Tasks: Multi-Destination Extraction (Fan-Out)

**Input**: Design documents from `/specs/012-multi-destination-extraction/`  
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/, research.md, quickstart.md

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4, US5)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Prepare test infrastructure for multi-destination feature

- [x] T001 Create test file `Tests/SubtreeLibTests/PathNormalizerTests.swift` with test suite skeleton
- [x] T002 [P] Add test cases for `to` array parsing in `Tests/SubtreeLibTests/ExtractionMappingTests.swift`
- [x] T003 [P] Create test file `Tests/IntegrationTests/ExtractMultiDestTests.swift` with test suite skeleton

**Checkpoint**: Test files exist and compile (empty suites)

---

## Phase 2: Foundational (Data Model + PathNormalizer)

**Purpose**: Modify ExtractionMapping for `to` array + create PathNormalizer — blocks all user stories

**Note**: Corresponds to plan.md "Phase 1: Data Model + CLI + Persist" (tasks.md Phase 1 is setup scaffolding only).

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests for PathNormalizer

- [x] T004 [P] Unit test: Normalize removes trailing slash in `Tests/SubtreeLibTests/PathNormalizerTests.swift`
- [x] T005 [P] Unit test: Normalize removes leading `./` in `Tests/SubtreeLibTests/PathNormalizerTests.swift`
- [x] T006 [P] Unit test: Normalize handles combined `./path/` in `Tests/SubtreeLibTests/PathNormalizerTests.swift`
- [x] T007 [P] Unit test: Deduplicate removes equivalent paths in `Tests/SubtreeLibTests/PathNormalizerTests.swift`
- [x] T008 [P] Unit test: Deduplicate preserves order and original form in `Tests/SubtreeLibTests/PathNormalizerTests.swift`

### Implementation for PathNormalizer

- [x] T009 Create `Sources/SubtreeLib/Utilities/PathNormalizer.swift` with `normalize(_:)` function
- [x] T010 Add `deduplicate(_:)` function in `Sources/SubtreeLib/Utilities/PathNormalizer.swift`
- [x] T011 Verify PathNormalizer tests pass with `swift test --filter PathNormalizerTests`

### Tests for ExtractionMapping `to` Array

- [x] T012 [P] Unit test: Decode single string format `to: "path/"` in `Tests/SubtreeLibTests/ExtractionMappingTests.swift`
- [x] T013 [P] Unit test: Decode array format `to: ["p1/", "p2/"]` in `Tests/SubtreeLibTests/ExtractionMappingTests.swift`
- [x] T014 [P] Unit test: Encode single destination as string in `Tests/SubtreeLibTests/ExtractionMappingTests.swift`
- [x] T015 [P] Unit test: Encode multiple destinations as array in `Tests/SubtreeLibTests/ExtractionMappingTests.swift`
- [x] T016 [P] Unit test: Reject empty array `to: []` in `Tests/SubtreeLibTests/ExtractionMappingTests.swift`
- [x] T017 [P] Unit test: Single-destination initializer works in `Tests/SubtreeLibTests/ExtractionMappingTests.swift`
- [x] T018 [P] Unit test: Multi-destination initializer works in `Tests/SubtreeLibTests/ExtractionMappingTests.swift`
- [x] T018b [P] Unit test: Verify Yams coercion of non-string elements in `to` in `Tests/SubtreeLibTests/ExtractionMappingTests.swift`

### Implementation for ExtractionMapping `to` Array

- [x] T019 Change `to` field from `String` to `[String]` in `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`
- [x] T020 Update `init(from decoder:)` with try-array/fallback-string logic for `to` in `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`
- [x] T021 Update `encode(to:)` with single=string/multiple=array logic for `to` in `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`
- [x] T022 Add `init(from:toDestinations:exclude:)` initializer in `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`
- [x] T023 Add `init(fromPatterns:toDestinations:exclude:)` initializer in `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`
- [x] T024 Update existing initializers to wrap single `to` in array in `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`
- [x] T025 Add validation to reject empty `to` arrays in decoding in `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`
- [x] T026 Verify all unit tests pass with `swift test --filter SubtreeLibTests`

**Checkpoint**: ExtractionMapping accepts both `to` formats, PathNormalizer works, all unit tests pass

---

## Phase 3: P1 User Stories (CLI + Persist) 🎯 MVP

**Goal**: Core multi-destination functionality — users can specify multiple `--to` flags

**User Stories**: US1 (Multiple CLI Destinations), US2 (Persist Multi-Destination)

**Independent Test**: Run `subtree extract --name foo --from '*.h' --to 'Lib/' --to 'Vendor/'` and verify fan-out extraction

### Tests for P1

- [x] T027 [P] [US1] Integration test: Multiple --to flags extract to all destinations in `Tests/IntegrationTests/ExtractMultiDestTests.swift`
- [x] T028 [P] [US1] Integration test: Same files appear in every destination in `Tests/IntegrationTests/ExtractMultiDestTests.swift`
- [x] T029 [P] [US1] Integration test: Directory structure preserved identically in `Tests/IntegrationTests/ExtractMultiDestTests.swift`
- [x] T030 [P] [US1] Integration test: Duplicate destinations deduplicated (./Lib = Lib/ = Lib) in `Tests/IntegrationTests/ExtractMultiDestTests.swift`
- [x] T031 [P] [US1] Integration test: Per-destination success output shown in `Tests/IntegrationTests/ExtractMultiDestTests.swift`
- [x] T031b [P] [US1] Integration test: Overlapping destinations (`Lib/` and `Lib/Sub/`) both receive files in `Tests/IntegrationTests/ExtractMultiDestTests.swift`
- [x] T032 [P] [US2] Integration test: Legacy string `to` format still works in `Tests/IntegrationTests/ExtractMultiDestTests.swift`
- [x] T033 [P] [US2] Integration test: --persist stores destinations as array in `Tests/IntegrationTests/ExtractMultiDestTests.swift`
- [x] T034 [P] [US2] Integration test: Bulk extract with persisted array destinations works in `Tests/IntegrationTests/ExtractMultiDestTests.swift`

### Implementation for P1

- [x] T035 [US1] Change `@Option var to: String?` to `@Option var to: [String]` in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T036 [US1] Add destination deduplication using PathNormalizer in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T037 [US1] Update ad-hoc extraction to iterate over destinations (fan-out loop) in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T038 [US1] Add per-destination success output (FR-017) in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T039 [US1] Add soft limit warning for >10 destinations (FR-011) in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T040 [US2] Update bulk extraction to handle array `to` field in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T041 [US2] Update `saveMappingToConfig` for array destination format in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T042 Verify single --to still works (backward compat) with `swift test`

**Checkpoint**: Multi-destination CLI works, persist saves arrays, legacy configs work — MVP complete

---

## Phase 4: P2/P3 User Stories (Clean + Fail-Fast + Bulk)

**Goal**: Behavioral integration — fail-fast validation, clean mode, bulk mode support

**User Stories**: US3 (Clean Mode), US4 (Fail-Fast), US5 (Bulk Mode)

**Independent Test**: Create conflict in one destination, verify extraction fails before any writes

### Tests for US3 (Clean Mode)

- [x] T043 [P] [US3] Integration test: --clean removes files from all destinations in `Tests/IntegrationTests/ExtractMultiDestTests.swift`
- [x] T044 [P] [US3] Integration test: Clean with persisted multi-dest mapping works in `Tests/IntegrationTests/ExtractMultiDestTests.swift`
- [x] T045 [P] [US3] Integration test: Clean fails-fast if checksum mismatch in any destination in `Tests/IntegrationTests/ExtractMultiDestTests.swift`
- [x] T046 [P] [US3] Integration test: Per-destination clean output shown in `Tests/IntegrationTests/ExtractMultiDestTests.swift`

### Tests for US4 (Fail-Fast)

- [x] T047 [P] [US4] Integration test: Overwrite protection validates ALL destinations upfront in `Tests/IntegrationTests/ExtractMultiDestTests.swift`
- [x] T048 [P] [US4] Integration test: No files copied if any destination has conflicts in `Tests/IntegrationTests/ExtractMultiDestTests.swift`
- [x] T049 [P] [US4] Integration test: Error lists conflicts across all destinations in `Tests/IntegrationTests/ExtractMultiDestTests.swift`
- [x] T050 [P] [US4] Integration test: --force bypasses protection for all destinations in `Tests/IntegrationTests/ExtractMultiDestTests.swift`

### Tests for US5 (Bulk Mode)

- [x] T051 [P] [US5] Integration test: --all processes multi-dest mappings correctly in `Tests/IntegrationTests/ExtractMultiDestTests.swift`
- [x] T052 [P] [US5] Integration test: --clean --all removes from all destinations in `Tests/IntegrationTests/ExtractMultiDestTests.swift`
- [x] T053 [P] [US5] Integration test: Continue-on-error per subtree (not per destination) in `Tests/IntegrationTests/ExtractMultiDestTests.swift`

### Implementation for US3 (Clean Mode)

- [x] T054 [US3] Update `runAdHocClean` to iterate over destinations in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T055 [US3] Add per-destination clean output in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T056 [US3] Ensure checksum validation applies to all destinations before any deletes in `Sources/SubtreeLib/Commands/ExtractCommand.swift`

### Implementation for US4 (Fail-Fast)

- [x] T057 [US4] Refactor `checkForTrackedFiles` to collect conflicts from ALL destinations in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T058 [US4] Update `handleOverwriteProtection` to list conflicts grouped by destination in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T059 [US4] Ensure fan-out loop only executes after all destinations validated in `Sources/SubtreeLib/Commands/ExtractCommand.swift`

### Implementation for US5 (Bulk Mode)

- [x] T060 [US5] Update `runBulkExtraction` to handle multi-dest mappings in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T061 [US5] Update `runBulkClean` to handle multi-dest mappings in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T062 [US5] Verify continue-on-error semantics at subtree level (not destination) in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T063 Verify all integration tests pass with `swift test --filter ExtractMultiDestTests`

**Checkpoint**: Fail-fast works, clean mode supports multi-dest, bulk mode handles arrays

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, final validation

- [x] T064 [P] Update command help text for multiple --to in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T065 [P] Add doc comments for new initializers in `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`
- [x] T066 [P] Add doc comments for PathNormalizer in `Sources/SubtreeLib/Utilities/PathNormalizer.swift`
- [x] T067 Run full test suite: `swift test` — 571 tests pass
- [x] T068 Run quickstart.md validation steps manually — N/A (no quickstart.md for this feature)
- [x] T069 Update README.md with multi-destination examples (extract section, config format)

**Checkpoint**: Documentation complete, all tests pass, feature ready for merge

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — can start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user stories
- **Phase 3 (P1)**: Depends on Phase 2 — Core MVP
- **Phase 4 (P2/P3)**: Depends on Phase 3 — Behavioral integration
- **Phase 5 (Polish)**: Depends on Phases 3-4

### User Story Dependencies

- **US1 + US2**: Can proceed together (both P1, Phase 3)
- **US3 + US4 + US5**: Can proceed together after P1 (all in Phase 4)
- **US4 (Fail-Fast)** should be implemented before US3 (Clean) for correct validation order

### Parallel Opportunities

**Within Phase 2**:
```
T004, T005, T006, T007, T008 (PathNormalizer tests) — parallel
T012, T013, T014, T015, T016, T017, T018 (ExtractionMapping tests) — parallel
```

**Within Phase 3**:
```
T027, T028, T029, T030, T031, T032, T033, T034 (P1 integration tests) — parallel
```

**Within Phase 4**:
```
T043-T046 (US3 tests), T047-T050 (US4 tests), T051-T053 (US5 tests) — parallel
```

---

## Implementation Strategy

### MVP First (P1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (data model + PathNormalizer)
3. Complete Phase 3: P1 User Stories (CLI + Persist)
4. **STOP and VALIDATE**: Run quickstart.md steps 1-4
5. Deploy/demo if ready — users can use multi-destination extraction

### Incremental Delivery

1. **P1 Complete** → Users can extract to multiple destinations
2. **P2/P3 Complete** → Users get fail-fast protection, clean mode, bulk support
3. **Polish Complete** → Documentation and help updated

---

## Task Summary

| Phase | Task Range | Count | Purpose |
|-------|------------|-------|---------|
| Setup | T001-T003 | 3 | Test scaffolding |
| Foundational | T004-T026 + T018b | 24 | Data model + PathNormalizer |
| P1 (US1+US2) | T027-T042 + T031b | 17 | CLI + Persist MVP |
| P2/P3 (US3+US4+US5) | T043-T063 | 21 | Clean + Fail-fast + Bulk |
| Polish | T064-T069 | 6 | Docs + validation |
| **Total** | | **71** | |

---

## Notes

- All tests must FAIL before implementation (TDD)
- Commit after each phase completion
- Run `swift test` before moving to next phase
- Phase 2 is critical — data model change affects everything downstream
- Fail-fast (US4) should be implemented before clean mode (US3) within Phase 4
