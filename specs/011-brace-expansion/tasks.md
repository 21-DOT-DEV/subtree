# Tasks: Brace Expansion with Embedded Path Separators

**Input**: Design documents from `/specs/011-brace-expansion/`  
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

**Tests**: TDD approach — tests written first, verified to fail, then implementation

**Organization**: Tasks grouped by user story for independent implementation and testing

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Exact file paths included in descriptions

## Path Conventions

```
Sources/SubtreeLib/Utilities/BraceExpander.swift     # NEW: Main implementation
Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift  # NEW: Unit tests
Sources/SubtreeLib/Commands/ExtractCommand.swift     # MODIFY: Integration
Tests/IntegrationTests/ExtractIntegrationTests.swift # MODIFY: Integration tests
```

---

## Phase 1: Setup

**Purpose**: Create file structure and error type

- [x] T001 Create `BraceExpanderTests.swift` test file skeleton in `Tests/SubtreeLibTests/Utilities/`
- [x] T002 Create `BraceExpander.swift` source file with `BraceExpanderError` enum in `Sources/SubtreeLib/Utilities/`
- [x] T003 Verify project builds with empty implementations: `swift build`

---

## Phase 2: Foundational

**Purpose**: Core parsing infrastructure that ALL user stories depend on

**⚠️ CRITICAL**: User story implementation cannot begin until brace group detection works

### Tests (TDD)

- [x] T004 [P] Write test for finding brace groups in pattern in `Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift`
- [x] T005 Verify T004 tests FAIL (no implementation yet): `swift test --filter BraceExpanderTests`

### Implementation

- [x] T006 Implement `findBraceGroups()` private method to locate `{...}` with commas in `Sources/SubtreeLib/Utilities/BraceExpander.swift`
- [x] T007 Verify T004 tests PASS: `swift test --filter BraceExpanderTests`

**Checkpoint**: Brace group parsing works — user story implementation can begin

---

## Phase 3: User Story 1 - Basic Brace Expansion (Priority: P1) 🎯 MVP

**Goal**: Expand `{a,b}` and `{a,b/c}` patterns into multiple strings

**Independent Test**: `BraceExpander.expand("{a,b}")` returns `["a", "b"]`

### Tests (TDD)

- [x] T008 [P] [US1] Write tests for basic expansion (`{a,b}` → `["a", "b"]`) in `Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift`
- [x] T009 [P] [US1] Write tests for embedded path separators (`{a,b/c}` → `["a", "b/c"]`) in `Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift`
- [x] T010 [P] [US1] Write tests for patterns with prefix/suffix (`*.{h,c}` → `["*.h", "*.c"]`) in `Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift`
- [x] T011 [US1] Verify T008-T010 tests FAIL: `swift test --filter BraceExpanderTests`

### Implementation

- [x] T012 [US1] Implement `expand(_ pattern: String) throws -> [String]` for single brace group in `Sources/SubtreeLib/Utilities/BraceExpander.swift`
- [x] T013 [US1] Verify T008-T010 tests PASS: `swift test --filter BraceExpanderTests`

**Checkpoint**: Basic brace expansion works — `{a,b}` and `{a,b/c}` expand correctly

---

## Phase 4: User Story 2 - Multiple Brace Groups (Priority: P2)

**Goal**: Expand `{a,b}{1,2}` with cartesian product → `["a1", "a2", "b1", "b2"]`

**Independent Test**: `BraceExpander.expand("{a,b}{1,2}")` returns 4 patterns

### Tests (TDD)

- [x] T014 [P] [US2] Write tests for two brace groups cartesian product in `Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift`
- [x] T015 [P] [US2] Write tests for three brace groups (8 patterns) in `Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift`
- [x] T016 [US2] Verify T014-T015 tests FAIL: `swift test --filter BraceExpanderTests`

### Implementation

- [x] T017 [US2] Extend `expand()` to handle multiple brace groups with iterative cartesian product in `Sources/SubtreeLib/Utilities/BraceExpander.swift`
- [x] T018 [US2] Add warning to stderr when expansion exceeds 100 patterns in `Sources/SubtreeLib/Utilities/BraceExpander.swift`
- [x] T019 [US2] Verify T014-T015 tests PASS: `swift test --filter BraceExpanderTests`

**Checkpoint**: Multiple brace groups expand as cartesian product

---

## Phase 5: User Story 3 - Pass-Through for Invalid Patterns (Priority: P3)

**Goal**: Treat malformed braces as literal text (bash behavior)

**Independent Test**: `BraceExpander.expand("{a}")` returns `["{a}"]` (no expansion)

### Tests (TDD)

- [x] T020 [P] [US3] Write tests for no-comma pass-through (`{a}` → `["{a}"]`) in `Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift`
- [x] T021 [P] [US3] Write tests for empty braces pass-through (`{}` → `["{}"]`) in `Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift`
- [x] T022 [P] [US3] Write tests for unclosed braces pass-through (`{a,b` → `["{a,b"]`) in `Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift`
- [x] T023 [P] [US3] Write tests for no-braces pass-through (`plain.txt` → `["plain.txt"]`) in `Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift`
- [x] T024 [US3] Verify T020-T023 tests FAIL: `swift test --filter BraceExpanderTests`

### Implementation

- [x] T025 [US3] Update `findBraceGroups()` to skip invalid patterns in `Sources/SubtreeLib/Utilities/BraceExpander.swift`
- [x] T026 [US3] Verify T020-T023 tests PASS: `swift test --filter BraceExpanderTests`

**Checkpoint**: Invalid patterns pass through unchanged

---

## Phase 6: User Story 4 - Error on Empty Alternatives (Priority: P3)

**Goal**: Throw error for `{a,}`, `{,b}`, `{a,,b}` patterns

**Independent Test**: `BraceExpander.expand("{a,}")` throws `BraceExpanderError.emptyAlternative`

### Tests (TDD)

- [x] T027 [P] [US4] Write tests for trailing empty alternative error (`{a,}`) in `Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift`
- [x] T028 [P] [US4] Write tests for leading empty alternative error (`{,b}`) in `Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift`
- [x] T029 [P] [US4] Write tests for middle empty alternative error (`{a,,b}`) in `Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift`
- [x] T030 [US4] Verify T027-T029 tests FAIL: `swift test --filter BraceExpanderTests`

### Implementation

- [x] T031 [US4] Add empty alternative detection in brace parsing in `Sources/SubtreeLib/Utilities/BraceExpander.swift`
- [x] T032 [US4] Throw `BraceExpanderError.emptyAlternative(pattern)` with full pattern in `Sources/SubtreeLib/Utilities/BraceExpander.swift`
- [x] T033 [US4] Verify T027-T029 tests PASS: `swift test --filter BraceExpanderTests`

**Checkpoint**: Empty alternatives are rejected with clear error

---

## Phase 7: Integration

**Purpose**: Wire BraceExpander into ExtractCommand

### Tests (TDD)

- [x] T034 [P] Write integration test for extract with embedded path separator pattern in `Tests/IntegrationTests/ExtractIntegrationTests.swift`
- [x] T035 [P] Write integration test for extract with multiple brace groups in `Tests/IntegrationTests/ExtractIntegrationTests.swift`
- [x] T036 [P] Write integration test for extract error on empty alternative in `Tests/IntegrationTests/ExtractIntegrationTests.swift`
- [x] T037 Verify T034-T036 tests FAIL: `swift test --filter ExtractIntegrationTests`

### Implementation

- [x] T038 Add pattern expansion helper function in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T039 Expand `--from` patterns before file matching in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T040 Expand `--exclude` patterns before file matching in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T041 Handle `BraceExpanderError` with user-friendly error message in `Sources/SubtreeLib/Commands/ExtractCommand.swift`
- [x] T042 Verify T034-T036 tests PASS: `swift test --filter ExtractIntegrationTests`

**Checkpoint**: Brace expansion works end-to-end in extract command

---

## Phase 8: Polish & Validation

**Purpose**: Final verification and backward compatibility

- [x] T043 [P] Run full test suite and verify all 477+ existing tests pass: `swift test`
- [x] T044 Run quickstart.md validation commands
- [x] T045 Update README.md with brace expansion examples in glob pattern documentation
- [x] T046 [P] Add performance test verifying expansion completes in <10ms for pattern with 3 brace groups in `Tests/SubtreeLibTests/Utilities/BraceExpanderTests.swift`
- [x] T047 Final code review for KISS/DRY compliance

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup) → Phase 2 (Foundational) → User Stories (3-6) → Integration (7) → Polish (8)
```

### User Story Dependencies

| Story | Depends On | Can Start After |
|-------|------------|-----------------|
| US1 (Basic) | Phase 2 | T007 complete |
| US2 (Multiple Groups) | US1 | T013 complete |
| US3 (Pass-Through) | Phase 2 | T007 complete (parallel with US1) |
| US4 (Empty Error) | Phase 2 | T007 complete (parallel with US1) |

### Within Each User Story (TDD Cycle)

1. Write tests → 2. Verify FAIL → 3. Implement → 4. Verify PASS

### Parallel Opportunities

**Phase 1**: T001-T002 can run in parallel  
**Phase 3 Tests**: T008-T010 can run in parallel  
**Phase 5 Tests**: T020-T023 can run in parallel  
**Phase 6 Tests**: T027-T029 can run in parallel  
**Phase 7 Tests**: T034-T036 can run in parallel  
**Phase 8**: T043-T044 can run in parallel

---

## Parallel Example: User Story 1

```bash
# Write all US1 tests in parallel:
T008: Test basic expansion {a,b}
T009: Test embedded separators {a,b/c}
T010: Test prefix/suffix *.{h,c}

# Then verify fail, implement, verify pass (sequential)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (brace group detection)
3. Complete Phase 3: User Story 1 (basic expansion)
4. **STOP and VALIDATE**: Test `BraceExpander.expand("{a,b/c}")` works
5. Can demo/integrate at this point

### Incremental Delivery

1. Setup + Foundational → Framework ready
2. US1 → Basic expansion works (MVP!)
3. US2 → Cartesian product works
4. US3 + US4 → Edge cases handled
5. Integration → End-to-end works
6. Polish → Production ready

### Suggested MVP Scope

**Minimum viable**: Phases 1-3 (Setup + Foundational + US1)  
**Delivers**: Basic `{a,b/c}` expansion working in unit tests  
**Estimate**: ~15 tasks

---

## Summary

| Metric | Count |
|--------|-------|
| **Total Tasks** | 47 |
| **Phase 1 (Setup)** | 3 |
| **Phase 2 (Foundational)** | 4 |
| **Phase 3 (US1 - Basic)** | 6 |
| **Phase 4 (US2 - Multiple)** | 6 |
| **Phase 5 (US3 - Pass-Through)** | 7 |
| **Phase 6 (US4 - Errors)** | 7 |
| **Phase 7 (Integration)** | 9 |
| **Phase 8 (Polish)** | 5 |
| **Parallel Opportunities** | 18 tasks marked [P] |

---

## Notes

- All tests follow TDD: write → fail → implement → pass
- [P] tasks can run in parallel (different files, no dependencies)
- Commit after each TDD cycle (test pass)
- Stop at any checkpoint to validate independently
- Existing 477 tests MUST continue passing (backward compatibility)
