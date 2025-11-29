# Tasks: Multi-Pattern Extraction

**Input**: Design documents from `/specs/009-multi-pattern-extraction/`  
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/, research.md, quickstart.md

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4, US5)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Prepare test infrastructure for multi-pattern feature

- [x] T001 Create test file `Tests/SubtreeLibTests/ExtractionMappingTests.swift` with test suite skeleton
- [x] T002 [P] Create test file `Tests/IntegrationTests/ExtractMultiPatternTests.swift` with test suite skeleton

**Checkpoint**: Test files exist and compile (empty suites)

---

## Phase 2: Foundational (Data Model)

**Purpose**: Modify ExtractionMapping to support array format — blocks all user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests for Data Model

- [x] T003 [P] Unit test: Decode single string format `from: "pattern"` in `Tests/SubtreeLibTests/ExtractionMappingTests.swift`
- [x] T004 [P] Unit test: Decode array format `from: ["p1", "p2"]` in `Tests/SubtreeLibTests/ExtractionMappingTests.swift`
- [x] T005 [P] Unit test: Encode single pattern as string in `Tests/SubtreeLibTests/ExtractionMappingTests.swift`
- [x] T006 [P] Unit test: Encode multiple patterns as array in `Tests/SubtreeLibTests/ExtractionMappingTests.swift`
- [x] T007 [P] Unit test: Reject empty array `from: []` in `Tests/SubtreeLibTests/ExtractionMappingTests.swift`
- [x] T007b [P] Unit test: Verify Yams coercion of non-string elements in `Tests/SubtreeLibTests/ExtractionMappingTests.swift`
- [x] T008 [P] Unit test: Single-pattern initializer works in `Tests/SubtreeLibTests/ExtractionMappingTests.swift`

### Implementation for Data Model

- [x] T009 Change `from` field from `String` to `[String]` in `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`
- [x] T010 Add custom `init(from decoder:)` with try-array/fallback-string logic in `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`
- [x] T011 Add custom `encode(to:)` with single=string/multiple=array logic in `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`
- [x] T012 Add `init(fromPatterns:to:exclude:)` initializer in `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`
- [x] T013 Update existing `init(from:to:exclude:)` to wrap single string in array in `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`
- [x] T014 Add validation to reject empty arrays in decoding in `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`
- [x] T015 Verify all unit tests pass with `swift test --filter SubtreeLibTests` (277/277 passed)

**Checkpoint**: ExtractionMapping accepts both formats, all unit tests pass

---

## Phase 3: P1 User Stories (CLI + YAML) 🎯 MVP

**Goal**: Core multi-pattern functionality — users can specify multiple `--from` flags

**User Stories**: US1 (Multiple CLI Patterns), US2 (Backward Compatible YAML)

**Independent Test**: Run `subtree extract --name foo --from 'p1' --from 'p2' --to 'dest/'` and verify union extraction

### Tests for P1

- [x] T016 [P] [US1] Integration test: Multiple --from flags extract union of files in `Tests/IntegrationTests/ExtractMultiPatternTests.swift`
- [x] T017 [P] [US1] Integration test: Duplicate files extracted once (no duplicates) in `Tests/IntegrationTests/ExtractMultiPatternTests.swift`
- [x] T018 [P] [US1] Integration test: Different directory depths preserve relative paths in `Tests/IntegrationTests/ExtractMultiPatternTests.swift`
- [x] T019 [P] [US2] Integration test: Legacy string format still works in `Tests/IntegrationTests/ExtractMultiPatternTests.swift`
- [x] T020 [P] [US2] Integration test: Array format in config works in `Tests/IntegrationTests/ExtractMultiPatternTests.swift`
- [x] T021 [P] [US2] Integration test: Mixed formats in same config work in `Tests/IntegrationTests/ExtractMultiPatternTests.swift`

### Implementation for P1

- [x] T022 [US1] Change positional args to `@Option var from: [String]` and `@Option var to: String?` in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T023 [US1] Update extraction logic to iterate over `from` array in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T024 [US1] Add Set-based deduplication for matched files in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T025 [US1] Update file matching to process each pattern and merge results in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T026 [US2] Update bulk extraction to handle array `from` field in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T027 Verify single --from still works (backward compat) with `swift test`

**Checkpoint**: ✅ Multi-pattern CLI works, legacy configs work — MVP complete (430/430 tests pass)

---

## Phase 4: P2 User Stories (Persist + Excludes)

**Goal**: Persistence saves arrays, excludes work globally

**User Stories**: US3 (Persist Multiple Patterns), US4 (Global Excludes)

**Independent Test**: Run `--persist` with multiple patterns and verify YAML array format

### Tests for P2

- [x] T028 [P] [US3] Integration test: --persist stores patterns as array in `Tests/IntegrationTests/ExtractMultiPatternTests.swift`
- [x] T029 [P] [US3] Integration test: Bulk extract with persisted array works in `Tests/IntegrationTests/ExtractMultiPatternTests.swift`
- [x] T030 [P] [US3] Integration test: Duplicate exact mapping skipped with warning in `Tests/IntegrationTests/ExtractMultiPatternTests.swift`
- [x] T031 [P] [US4] Integration test: Exclude applies to all patterns in `Tests/IntegrationTests/ExtractMultiPatternTests.swift`
- [x] T032 [P] [US4] Integration test: Exclude filters from only matching pattern in `Tests/IntegrationTests/ExtractMultiPatternTests.swift`
- [x] T033 [P] [US4] Integration test: Exclude behavior verified with multiple patterns in `Tests/IntegrationTests/ExtractMultiPatternTests.swift`

### Implementation for P2

- [x] T034 [US3] `appendExtraction` already handles array format (uses ExtractionMapping which encodes correctly)
- [x] T035 [US3] ExtractionMapping.encode already outputs array when >1 pattern (implemented in Phase 2)
- [x] T036 [US4] Excludes already apply to union of all patterns (verified by tests T031-T033)

**Checkpoint**: ✅ Persist saves arrays, excludes filter all patterns (436/436 tests pass)

---

## Phase 5: P3 User Stories (Warnings)

**Goal**: UX polish — warn on zero-match patterns

**User Stories**: US5 (Zero-Match Warning)

**Independent Test**: Run with one valid + one invalid pattern, verify warning shown

### Tests for P3

- [x] T037 [P] [US5] Integration test: Zero-match pattern shows warning in `Tests/IntegrationTests/ExtractMultiPatternTests.swift`
- [x] T038 [P] [US5] Integration test: All patterns zero-match exits with error in `Tests/IntegrationTests/ExtractMultiPatternTests.swift`
- [x] T039 [P] [US5] Integration test: Exit code 0 when some patterns match in `Tests/IntegrationTests/ExtractMultiPatternTests.swift`

### Implementation for P3

- [x] T040 [US5] Add per-pattern match tracking in extraction loop in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T041 [US5] Display warning for each zero-match pattern in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T042 [US5] Return error exit code when all patterns match nothing (already existed, verified working)
- [x] T043 [US5] Per-pattern file counts tracked via `patternMatchCounts` array (warnings show 0-match patterns)

**Checkpoint**: ✅ Zero-match warnings displayed, appropriate exit codes (439/439 tests pass)

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, final validation

- [x] T044 [P] Update command help text for multiple --from in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T045 [P] Add doc comments for new initializers in `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`
- [x] T046 Run full test suite: `swift test` (439/439 pass)
- [x] T047 Quickstart.md validation steps documented (manual validation available)
- [x] T048 Update README.md with multi-pattern examples (extract section, API reference, config format)

**Checkpoint**: ✅ Phase 6 complete — 009-multi-pattern-extraction DONE (439/439 tests pass)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — can start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user stories
- **Phase 3 (P1)**: Depends on Phase 2 — Core MVP
- **Phase 4 (P2)**: Depends on Phase 3 — Persist and Excludes
- **Phase 5 (P3)**: Depends on Phase 3 (not Phase 4) — Warnings
- **Phase 6 (Polish)**: Depends on Phases 3-5

### User Story Dependencies

- **US1 + US2**: Can proceed together (both P1)
- **US3 + US4**: Can proceed together after P1 (both P2)
- **US5**: Can proceed after P1 (independent of P2)

### Parallel Opportunities

**Within Phase 2**:
```
T003, T004, T005, T006, T007, T007b, T008 (all unit tests) — parallel
```

**Within Phase 3**:
```
T016, T017, T018, T019, T020, T021 (all integration tests) — parallel
```

**Within Phase 4**:
```
T028, T029, T030, T031, T032, T033 (all integration tests) — parallel
```

---

## Implementation Strategy

### MVP First (P1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (data model)
3. Complete Phase 3: P1 User Stories (CLI + YAML)
4. **STOP and VALIDATE**: Run quickstart.md steps 1-4
5. Deploy/demo if ready — users can use multi-pattern extraction

### Incremental Delivery

1. **P1 Complete** → Users can extract with multiple patterns ✓
2. **P2 Complete** → Users can persist multi-pattern mappings ✓
3. **P3 Complete** → Users get warnings for typos ✓
4. **Polish Complete** → Documentation and help updated ✓

---

## Notes

- All tests must FAIL before implementation (TDD)
- Commit after each phase completion
- Run `swift test` before moving to next phase
- Phase 2 is critical — data model change affects everything downstream
