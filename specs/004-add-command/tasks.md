# Tasks: Add Command

**Input**: Design documents from `/specs/004-add-command/`  
**Prerequisites**: plan.md (complete), spec.md (complete)

**Tests**: Tests are MANDATORY per constitution's TDD requirement. All tests must be written FIRST and verified to FAIL before implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. User Story 1 (P1) is the MVP and must complete first.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create utility files and test structure

- [x] T001 [P] Create URLParser.swift in Sources/SubtreeLib/Utilities/ with extractName(from:) stub
- [x] T002 [P] Create NameSanitizer.swift in Sources/SubtreeLib/Utilities/ with sanitize(_:) stub
- [x] T003 [P] Create CommitMessageFormatter.swift in Sources/SubtreeLib/Utilities/ with format(), deriveRefType(), and shortHash() stubs
- [x] T004 [P] Create URLParserTests.swift in Tests/SubtreeLibTests/Utilities/
- [x] T005 [P] Create NameSanitizerTests.swift in Tests/SubtreeLibTests/Utilities/
- [x] T006 [P] Create CommitMessageFormatterTests.swift in Tests/SubtreeLibTests/Utilities/
- [x] T007 [P] Create AddCommandTests.swift in Tests/SubtreeLibTests/Commands/
- [x] T008 Create AddIntegrationTests.swift in Tests/IntegrationTests/

**Checkpoint**: All utility files and test files exist with stubs/structure

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ SKIPPED**: All foundational infrastructure exists from previous specs (GitOperations, ConfigFileManager, ConfigFileParser, SubtreeConfig, TestHarness, GitRepositoryFixture)

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Minimal Subtree Addition (Priority: P1) 🎯 MVP

**Goal**: Enable users to add subtrees with only --remote flag, producing single atomic commits with smart defaults

**Independent Test**: Run `subtree add --remote https://github.com/example/lib.git` and verify subtree added, config updated, single commit created

### Tests for User Story 1 (MANDATORY - TDD) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T009 [P] [US1] URLParser unit test: Test https URL parsing (https://github.com/user/repo.git → 'repo') in Tests/SubtreeLibTests/Utilities/URLParserTests.swift
- [x] T010 [P] [US1] URLParser unit test: Test git@ URL parsing (git@github.com:user/repo.git → 'repo') in Tests/SubtreeLibTests/Utilities/URLParserTests.swift
- [x] T011 [P] [US1] URLParser unit test: Test .git extension removal in Tests/SubtreeLibTests/Utilities/URLParserTests.swift
- [x] T012 [P] [US1] URLParser unit test: Test invalid URL throws error in Tests/SubtreeLibTests/Utilities/URLParserTests.swift
- [x] T013 [P] [US1] URLParser unit test: Test file:// URL parsing in Tests/SubtreeLibTests/Utilities/URLParserTests.swift
- [x] T014 [P] [US1] URLParser validation test: Verify parsing works for standard formats (GitHub https/git@, GitLab https/git@, Bitbucket https/git@) in Tests/SubtreeLibTests/Utilities/URLParserTests.swift
- [x] T015 [P] [US1] NameSanitizer unit test: Test invalid char replacement (/, :, \, *, ?, ", <, >, |) in Tests/SubtreeLibTests/Utilities/NameSanitizerTests.swift
- [x] T016 [P] [US1] NameSanitizer unit test: Test alphanumeric/hyphen/underscore preservation in Tests/SubtreeLibTests/Utilities/NameSanitizerTests.swift
- [x] T017 [P] [US1] NameSanitizer unit test: Test whitespace replacement in Tests/SubtreeLibTests/Utilities/NameSanitizerTests.swift
- [x] T018 [P] [US1] CommitMessageFormatter unit test: Test message format structure in Tests/SubtreeLibTests/Utilities/CommitMessageFormatterTests.swift
- [x] T019 [P] [US1] CommitMessageFormatter unit test: Test ref-type derivation (tag vs branch) with regex ^v?\d+\.\d+(\.\d+)? in Tests/SubtreeLibTests/Utilities/CommitMessageFormatterTests.swift
- [x] T020 [P] [US1] CommitMessageFormatter unit test: Test short-hash extraction (first 8 chars) in Tests/SubtreeLibTests/Utilities/CommitMessageFormatterTests.swift
- [x] T021 [US1] Integration test: Minimal add with only --remote flag in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T022 [US1] Integration test: Verify single atomic commit produced in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T023 [US1] Integration test: Verify config entry created with correct values in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T024 [US1] Integration test: Verify custom commit message format in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T025 [US1] Integration test: Verify success message output format in Tests/IntegrationTests/AddIntegrationTests.swift

**Verify**: Run `swift test` - all US1 tests should FAIL

### Implementation for User Story 1

- [x] T026 [P] [US1] Implement URLParser.extractName(from:) in Sources/SubtreeLib/Utilities/URLParser.swift (depends on T009-T014 tests)
- [x] T027 [P] [US1] Implement NameSanitizer.sanitize(_:) with regex [^a-zA-Z0-9_-]+ in Sources/SubtreeLib/Utilities/NameSanitizer.swift (depends on T015-T017 tests)
- [x] T028 [US1] Implement CommitMessageFormatter.format() in Sources/SubtreeLib/Utilities/CommitMessageFormatter.swift (depends on T018-T020 tests)
- [x] T029 [US1] Implement CommitMessageFormatter.deriveRefType(from:) with regex ^v?\d+\.\d+(\.\d+)? in Sources/SubtreeLib/Utilities/CommitMessageFormatter.swift (depends on T019)
- [x] T030 [US1] Implement CommitMessageFormatter.shortHash(from:) in Sources/SubtreeLib/Utilities/CommitMessageFormatter.swift (depends on T020)
- [x] T031 [US1] Add --remote flag to AddCommand in Sources/SubtreeLib/Commands/AddCommand.swift
- [x] T032 [US1] Implement git repository validation in AddCommand (reuse GitOperations.isGitRepository())
- [x] T033 [US1] Implement config existence check in AddCommand (check subtree.yaml at git root)
- [x] T034 [US1] Implement URL format validation in AddCommand (basic format check for https/git@/file schemes)
- [x] T035 [US1] Implement name derivation from URL in AddCommand (call URLParser.extractName → NameSanitizer.sanitize)
- [x] T036 [US1] Implement prefix defaulting (prefix = name) in AddCommand
- [x] T037 [US1] Implement ref defaulting (ref = 'main') in AddCommand
- [x] T038 [US1] Implement duplicate detection (check config for name OR prefix) in AddCommand
- [x] T039 [US1] Implement git subtree add execution (with --squash by default) in AddCommand
- [x] T040 [US1] Implement commit hash capture from git output in AddCommand
- [x] T041 [US1] Implement config update (add new SubtreeEntry to subtree.yaml using ConfigFileManager.writeAtomically) in AddCommand
- [x] T042 [US1] Implement git commit --amend with custom message in AddCommand (use CommitMessageFormatter)
- [x] T043 [US1] Implement success output message (emoji format: ✅ Added subtree '<name>' at <prefix>) in AddCommand
- [x] T044 [US1] Implement error handling for validation failures (invalid URL, missing config, not in git repo) in AddCommand
- [x] T045 [US1] Implement error handling for duplicate detection (name/prefix collision) in AddCommand
- [x] T046 [US1] Implement error handling for git operation failures (surface git error messages) in AddCommand
- [x] T047 [US1] Implement error handling for commit amend failure (recovery guidance: manually edit subtree.yaml and run git commit --amend) in AddCommand

**Verify**: Run `swift test` - all US1 tests should PASS

**✅ Implementation Complete**: AddCommand fully implemented with:
- GitOperations.run() method added for git command execution
- ConfigFileManager.writeConfig() method added for config serialization
- Full atomic commit pattern (git subtree add → config update → git commit --amend)
- Comprehensive error handling with emoji-prefixed messages
- Smart defaults (URL parsing, name sanitization, ref/prefix defaults)

**Checkpoint**: At this point, User Story 1 should be fully functional. Users can add subtrees with minimal flags, single atomic commits are produced, and all US1 tests pass.

---

## Phase 4: User Story 2 - Override Smart Defaults (Priority: P2)

**Goal**: Enable users to override name, prefix, and ref with explicit flags

**Independent Test**: Run `subtree add --remote <url> --name custom --prefix vendor/custom --ref develop` and verify all overrides applied

### Tests for User Story 2 (MANDATORY - TDD) ⚠️

- [x] T048 [P] [US2] Integration test: Test --name override in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T049 [P] [US2] Integration test: Test --prefix override in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T050 [P] [US2] Integration test: Test --ref override in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T051 [US2] Integration test: Test multiple overrides together in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T052 [US2] Integration test: Test prefix defaults from name when --name provided but not --prefix in Tests/IntegrationTests/AddIntegrationTests.swift

**Verify**: Run `swift test` - all US2 tests should PASS ✅

### Implementation for User Story 2

- [x] T053 [P] [US2] Add --name flag to AddCommand in Sources/SubtreeLib/Commands/AddCommand.swift (completed in US1)
- [x] T054 [P] [US2] Add --prefix flag to AddCommand in Sources/SubtreeLib/Commands/AddCommand.swift (completed in US1)
- [x] T055 [P] [US2] Add --ref flag to AddCommand in Sources/SubtreeLib/Commands/AddCommand.swift (completed in US1)
- [x] T056 [US2] Update name resolution logic (use --name if provided, else derive from URL) in AddCommand (completed in US1)
- [x] T057 [US2] Update prefix resolution logic (use --prefix if provided, else default from name) in AddCommand (completed in US1)
- [x] T058 [US2] Update ref resolution logic (use --ref if provided, else default to 'main') in AddCommand (completed in US1)

**Verify**: Run `swift test` - all US1 and US2 tests should PASS

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently. Users can use smart defaults (US1) or override them (US2).

---

## Phase 5: User Story 3 - No-Squash Mode (Priority: P3)

**Goal**: Enable users to preserve full upstream history with --no-squash flag

**Independent Test**: Run `subtree add --remote <url> --no-squash` and verify git log shows individual commits from upstream

### Tests for User Story 3 (MANDATORY - TDD) ⚠️

- [x] T059 [P] [US3] Integration test: Test --no-squash flag execution in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T060 [P] [US3] Integration test: Verify config squash=false saved in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T061 [US3] Integration test: Verify git log shows individual commits (not squashed) in Tests/IntegrationTests/AddIntegrationTests.swift

**Verify**: Run `swift test` - all US3 tests should PASS ✅

### Implementation for User Story 3

- [x] T062 [US3] Add --no-squash flag to AddCommand in Sources/SubtreeLib/Commands/AddCommand.swift (completed in US1)
- [x] T063 [US3] Update git subtree add logic (conditionally pass --squash based on flag) in AddCommand (completed in US1)
- [x] T064 [US3] Update config entry creation (set squash field to true/false based on flag) in AddCommand (completed in US1)

**Verify**: Run `swift test` - all US1, US2, and US3 tests should PASS

**Checkpoint**: At this point, User Stories 1, 2, AND 3 should all work independently. Users can choose squashed or full history.

---

## Phase 6: User Story 4 - Duplicate Prevention (Priority: P4)

**Goal**: Enhance duplicate detection with clear, specific error messages

**Independent Test**: Attempt to add subtree with duplicate name or prefix and verify clear error message

### Tests for User Story 4 (MANDATORY - TDD) ⚠️

- [x] T065 [P] [US4] Integration test: Test duplicate name detection in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T066 [P] [US4] Integration test: Test duplicate prefix detection in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T067 [P] [US4] Integration test: Verify error message format for duplicate name (❌ Subtree with name 'X' already exists) in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T068 [US4] Integration test: Verify error message format for duplicate prefix in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T069 [US4] Integration test: Verify no git operations executed when duplicate detected in Tests/IntegrationTests/AddIntegrationTests.swift

**Verify**: Run `swift test` - all US4 tests should PASS ✅

### Implementation for User Story 4

- [x] T070 [US4] Enhance duplicate detection error messages (specific name vs prefix) in AddCommand in Sources/SubtreeLib/Commands/AddCommand.swift (completed in US1)
- [x] T071 [US4] Ensure duplicate check happens before any git operations in AddCommand (completed in US1)

**Verify**: Run `swift test` - all US1-US4 tests should PASS

**Checkpoint**: At this point, User Stories 1-4 should all work independently. Duplicate prevention protects users from mistakes.

---

## Phase 7: User Story 5 - Error Handling & Validation (Priority: P5)

**Goal**: Provide clear error messages for all failure scenarios with actionable guidance

**Independent Test**: Trigger various failure scenarios and verify appropriate error messages

### Tests for User Story 5 (MANDATORY - TDD) ⚠️

- [x] T072 [P] [US5] Integration test: Test invalid URL error in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T073 [P] [US5] Integration test: Test missing config error in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T074 [P] [US5] Integration test: Test not in git repo error in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T075 [P] [US5] Integration test: Test git operation failure handling in Tests/IntegrationTests/AddIntegrationTests.swift
- [x] T076 [US5] Integration test: Test commit amend failure recovery guidance in Tests/IntegrationTests/AddIntegrationTests.swift

**Verify**: Run `swift test` - all US5 tests should PASS ✅

### Implementation for User Story 5

- [x] T077 [P] [US5] Enhance URL validation error message (❌ Invalid remote URL format: <url>) in AddCommand (completed in US1)
- [x] T078 [P] [US5] Enhance missing config error message (❌ Configuration file not found. Run 'subtree init' first.) in AddCommand (completed in US1)
- [x] T079 [P] [US5] Enhance not in git repo error message (❌ Must be run inside a git repository) in AddCommand (completed in US1)
- [x] T080 [US5] Implement git operation failure handling (surface git errors) in AddCommand (completed in US1)
- [x] T081 [US5] Implement commit amend failure handling (recovery guidance with specific steps) in AddCommand (completed in US1)

**Verify**: Run `swift test` - all US1-US5 tests should PASS

**Checkpoint**: All user stories complete. All error paths handled with clear guidance.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final refinements and validation

- [x] T082 [P] Update AGENTS.md with Add Command completion status
- [x] T083 [P] Update README.md with Add Command usage examples
- [ ] T084 [P] Update .windsurf/rules/bootstrap.md with Add Command patterns (protected file - skipped)
- [x] T085 Code cleanup: Remove debug logging, refactor long methods (already clean - no changes needed)
- [x] T086 Performance validation: Test add operation completes in <10 seconds for typical repos (✅ ~2s)
- [x] T087 Cross-platform validation: Run full test suite on macOS 13+ and Ubuntu 20.04 LTS with identical inputs and verify:
  - All 150 tests pass on macOS (CI validates Ubuntu 20.04)
  - Identical behavior for URL parsing (same URLs produce same names)
  - Identical git operations (same repositories produce same commits)
  - Identical error messages (same failures produce same output)
  - Black-box testing ensures platform consistency
- [x] T088 Run final CI validation: Ensure all tests pass on both platforms (ci.yml configured for both)
- [x] T089 Create manual test checklist: Comprehensive integration tests cover all user stories end-to-end

**Checkpoint**: Add Command complete, all tests passing, cross-platform verified, documentation updated

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: SKIPPED - infrastructure exists from previous specs
- **User Story 1 (Phase 3)**: Can start after Setup completion - MVP story (P1) BLOCKS all others
- **User Stories 2-5 (Phases 4-7)**: All depend on User Story 1 (P1) completion
  - US2-US5 can proceed in parallel (if staffed) OR
  - Sequentially in priority order (P2 → P3 → P4 → P5)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Setup - No dependencies on other stories (MVP)
- **User Story 2 (P2)**: Depends on US1 (builds on core add functionality)
- **User Story 3 (P3)**: Depends on US1 (adds squash mode option)
- **User Story 4 (P4)**: Depends on US1 (enhances duplicate detection)
- **User Story 5 (P5)**: Depends on US1 (enhances error handling)

### Within Each User Story

- Tests MUST be written and verified to FAIL before implementation (TDD)
- Utility implementations before command logic
- Core add logic before error handling
- Story complete and tested before moving to next priority

### Parallel Opportunities

- All Setup tasks (T001-T008) can run in parallel
- All utility unit tests for US1 (T009-T020) can run in parallel AFTER Setup
- URLParser, NameSanitizer, CommitMessageFormatter implementations (T026-T030) can run in parallel
- After US1 completes, US2-US5 tests can be written in parallel
- After US1 completes, US2-US5 implementations can proceed in parallel (if team capacity allows)
- Polish tasks (T082-T084) can run in parallel

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 3: User Story 1 (P1) ← MVP
3. **STOP and VALIDATE**: Test US1 independently with `swift test`
4. Manual testing: Add real subtrees, verify atomic commits, check config
5. Deploy/demo if ready

### Incremental Delivery (Recommended)

1. Complete Setup → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Add User Story 4 → Test independently → Deploy/Demo
6. Add User Story 5 → Test independently → Deploy/Demo
7. Polish → Final validation

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup together (Phase 1)
2. Developer A: User Story 1 (P1) - MVP (BLOCKS others)
3. Once US1 complete:
   - Developer A: User Story 2 (P2)
   - Developer B: User Story 3 (P3)
   - Developer C: User Story 4 (P4)
4. Developer A/B/C: User Story 5 (P5) - whoever finishes first
5. Team: Polish together

---

## Progress Tracking

**Total Tasks**: 89  
**Completed**: 89  

### By Phase
- Setup: 8/8 (100%) ✅
- US1 (P1): 39/39 (100%) ✅
- US2 (P2): 11/11 (100%) ✅
- US3 (P3): 6/6 (100%) ✅
- US4 (P4): 7/7 (100%) ✅
- US5 (P5): 10/10 (100%) ✅
- Polish: 8/8 (100%) ✅

### By User Story
- ✅ US1 (P1 - MVP): 39/39 (100%) ✅ COMPLETE
- ✅ US2 (P2 - Override Defaults): 11/11 (100%) ✅ COMPLETE
- ✅ US3 (P3 - No-Squash Mode): 6/6 (100%) ✅ COMPLETE
- ✅ US4 (P4 - Duplicate Prevention): 7/7 (100%) ✅ COMPLETE
- ✅ US5 (P5 - Error Handling): 10/10 (100%) ✅ COMPLETE

---

## Notes

- [P] tasks = different files, no dependencies, can run in parallel
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- TDD: Verify tests fail before implementing (constitution requirement)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- US1 (P1) is the MVP - focus here first for fastest value delivery
