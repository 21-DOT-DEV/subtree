# Tasks: Init Command

**Input**: Design documents from `/specs/003-init-command/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Tests are REQUIRED per constitution (Principle II: Test-Driven Development)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Swift Package Manager CLI tool structure:
- **Source**: `Sources/SubtreeLib/` for library code
- **Executable**: `Sources/subtree/` for CLI wrapper
- **Tests**: `Tests/SubtreeLibTests/` for unit tests, `Tests/IntegrationTests/` for CLI tests

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: No new setup required - using existing bootstrap infrastructure (Phase 11 complete)

**Status**: ✅ Already complete from spec 001-cli-bootstrap

- Repository structure exists
- Test infrastructure ready (TestHarness, GitRepositoryFixture)
- CI pipeline configured (macOS-15 + Ubuntu 20.04)
- Swift Testing framework available

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core utilities that ALL user stories depend on for git operations and file management

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundation (TDD: Write First, Verify Fail)

- [x] T001 [P] Create unit test file for GitOperations in Tests/SubtreeLibTests/GitOperationsTests.swift
- [x] T002 [P] Create unit test file for ConfigFileManager in Tests/SubtreeLibTests/ConfigFileManagerTests.swift
- [x] T003 [P] Write test: findGitRoot() succeeds in valid repository (GitOperationsTests.swift)
- [x] T004 [P] Write test: findGitRoot() throws error outside repository (GitOperationsTests.swift)
- [x] T005 [P] Write test: findGitRoot() resolves symlinks correctly (GitOperationsTests.swift)
- [x] T006 [P] Write test: generateMinimalConfig() returns valid YAML with header (ConfigFileManagerTests.swift)
- [x] T007 [P] Write test: configPath() constructs correct path from git root (ConfigFileManagerTests.swift)
- [x] T008 [P] Write test: createAtomically() creates file with correct content (ConfigFileManagerTests.swift)
- [x] T009 [P] Write test: exists() returns true/false correctly (ConfigFileManagerTests.swift)
- [x] T010 Run swift test to verify all foundation tests FAIL (no implementation yet)

### Foundation Implementation

- [x] T011 Create GitOperations.swift utility in Sources/SubtreeLib/Utilities/GitOperations.swift
- [x] T012 Implement findGitRoot() function using git rev-parse --show-toplevel (GitOperations.swift)
- [x] T013 Implement isRepository() helper function (GitOperations.swift)
- [x] T014 Add error handling for GitError.notInRepository (GitOperations.swift)
- [x] T015 Create ConfigFileManager.swift utility in Sources/SubtreeLib/Utilities/ConfigFileManager.swift
- [x] T016 Define SubtreeConfig struct conforming to Codable (ConfigFileManager.swift)
- [x] T017 Implement generateMinimalConfig() using Yams encoder with header comment (ConfigFileManager.swift)
- [x] T018 Implement configPath(gitRoot:) function (ConfigFileManager.swift)
- [x] T019 Implement createAtomically(at:content:) with temp file + rename pattern (ConfigFileManager.swift)
- [x] T020 Implement exists(at:) file existence check (ConfigFileManager.swift)
- [x] T021 Run swift test to verify all foundation tests PASS

**Checkpoint**: Foundation ready - git detection and file creation utilities working and tested

---

## Phase 3: User Story 1 - First-Time Setup (Priority: P1) 🎯 MVP

**Goal**: Create minimal subtree.yaml at repository root in fresh git repositories

**Independent Test**: Run `subtree init` in fresh git repository, verify file created with correct content and success message

### Tests for User Story 1 (TDD: Write First, Verify Fail)

- [x] T022 [US1] Create integration test file in Tests/IntegrationTests/InitCommandIntegrationTests.swift
- [x] T023 [US1] Write test: init creates file at repository root from root directory (InitCommandIntegrationTests.swift)
- [x] T024 [US1] Write test: init creates file at repository root from subdirectory (InitCommandIntegrationTests.swift)
- [x] T025 [US1] Write test: init outputs success message with relative path (InitCommandIntegrationTests.swift)
- [x] T026 [US1] Write test: init exits with code 0 on success (InitCommandIntegrationTests.swift)
- [x] T027 [US1] Write test: created file has correct YAML structure with header comment (InitCommandIntegrationTests.swift)
- [x] T028 [US1] Run swift test --filter InitCommandIntegrationTests to verify tests FAIL

### Implementation for User Story 1

- [x] T029 [US1] Create InitCommand.swift in Sources/SubtreeLib/Commands/InitCommand.swift
- [x] T030 [US1] Define InitCommand struct conforming to ParsableCommand (InitCommand.swift)
- [x] T031 [US1] Add command configuration with name and abstract (InitCommand.swift)
- [x] T032 [US1] Implement run() function - detect git repository using GitOperations (InitCommand.swift)
- [x] T033 [US1] Implement run() function - generate config path using ConfigFileManager (InitCommand.swift)
- [x] T034 [US1] Implement run() function - generate minimal YAML content (InitCommand.swift)
- [x] T035 [US1] Implement run() function - create file atomically (InitCommand.swift)
- [x] T036 [US1] Implement run() function - calculate relative path for output (InitCommand.swift)
- [x] T037 [US1] Implement run() function - output success message with ✅ emoji (InitCommand.swift)
- [x] T038 [US1] Register InitCommand as subcommand in Sources/SubtreeLib/Commands/SubtreeCommand.swift
- [x] T039 [US1] Run swift test --filter InitCommandIntegrationTests to verify tests PASS

**Checkpoint**: User Story 1 complete - basic init command working in fresh repositories

---

## Phase 4: User Story 2 - Preventing Accidental Overwrites (Priority: P2)

**Goal**: Protect existing configurations from accidental overwrite with explicit --force opt-in

**Independent Test**: Create subtree.yaml, run `subtree init` (should fail), then run `subtree init --force` (should succeed)

### Tests for User Story 2 (TDD: Write First, Verify Fail)

- [x] T040 [US2] Write test: init fails when file exists without --force flag (InitCommandIntegrationTests.swift)
- [x] T041 [US2] Write test: init outputs error message with ❌ emoji when file exists (InitCommandIntegrationTests.swift)
- [x] T042 [US2] Write test: error message suggests using --force flag (InitCommandIntegrationTests.swift)
- [x] T043 [US2] Write test: init exits with code 1 when file exists (no --force) (InitCommandIntegrationTests.swift)
- [x] T044 [US2] Write test: init succeeds with --force flag when file exists (InitCommandIntegrationTests.swift)
- [x] T045 [US2] Write test: init overwrites existing file with --force (InitCommandIntegrationTests.swift)
- [x] T046 [US2] Run swift test --filter InitCommandIntegrationTests to verify new tests FAIL

### Implementation for User Story 2

- [x] T047 [US2] Add @Flag var force property to InitCommand struct (InitCommand.swift)
- [x] T048 [US2] Add file existence check before creation in run() (InitCommand.swift)
- [x] T049 [US2] Implement error path: output "❌ subtree.yaml already exists" (InitCommand.swift)
- [x] T050 [US2] Implement error path: output "Use --force to overwrite" hint (InitCommand.swift)
- [x] T051 [US2] Implement error path: exit with code 1 when file exists (InitCommand.swift)
- [x] T052 [US2] Allow file creation when --force flag is set (InitCommand.swift)
- [x] T053 [US2] Run swift test --filter InitCommandIntegrationTests to verify all tests PASS

**Checkpoint**: User Story 2 complete - file overwrite protection working with --force flag

---

## Phase 5: User Story 3 - Git Repository Validation (Priority: P3)

**Goal**: Provide clear error messages when command run outside git context

**Independent Test**: Run `subtree init` in non-git directory, verify appropriate error message and exit code

### Tests for User Story 3 (TDD: Write First, Verify Fail)

- [x] T054 [US3] Write test: init fails outside git repository (InitCommandIntegrationTests.swift)
- [x] T055 [US3] Write test: init outputs "❌ Must be run inside a git repository" (InitCommandIntegrationTests.swift)
- [x] T056 [US3] Write test: init exits with code 1 outside git repository (InitCommandIntegrationTests.swift)
- [x] T057 [US3] Write test: init works from subdirectory (validates git detection from any depth) (InitCommandIntegrationTests.swift)
- [x] T058 [US3] Write test: init works with symlinked repository path (InitCommandIntegrationTests.swift)
- [x] T059 [US3] Run swift test --filter InitCommandIntegrationTests to verify new tests FAIL

### Implementation for User Story 3

- [x] T060 [US3] Add error handling for GitError.notInRepository in run() (InitCommand.swift)
- [x] T061 [US3] Implement error path: output "❌ Must be run inside a git repository" (InitCommand.swift)
- [x] T062 [US3] Implement error path: exit with code 1 for git errors (InitCommand.swift)
- [x] T063 [US3] Verify symlink resolution works via git command (no code change needed) (InitCommand.swift)
- [x] T064 [US3] Run swift test --filter InitCommandIntegrationTests to verify all tests PASS

**Checkpoint**: User Story 3 complete - all error scenarios handled with clear messages

---

## Phase 6: Edge Cases & Error Handling

**Purpose**: Handle additional error scenarios and edge cases identified in spec

### Tests for Edge Cases (TDD: Write First, Verify Fail)

- [x] T065 [P] Write test: init handles permission denied error gracefully (InitCommandIntegrationTests.swift)
- [x] T066 [P] Write test: init handles I/O errors during file creation (InitCommandIntegrationTests.swift)
- [x] T067 [P] Write test: concurrent init processes don't corrupt file (InitCommandIntegrationTests.swift)
- [x] T068 [P] Write test: init works in detached HEAD state (InitCommandIntegrationTests.swift)
- [x] T069 Run swift test --filter InitCommandIntegrationTests to verify edge case tests FAIL

### Edge Case Implementation

- [x] T070 Add error handling for permission denied I/O errors in ConfigFileManager.createAtomically() (ConfigFileManager.swift)
- [x] T071 Add error path in run(): output "❌ Permission denied: cannot create subtree.yaml" (InitCommand.swift)
- [x] T072 Add error handling for generic I/O failures in createAtomically() (ConfigFileManager.swift)
- [x] T073 Add error path in run(): output "❌ Failed to create subtree.yaml: {error}" (InitCommand.swift)
- [x] T074 Verify atomic file operations prevent concurrent corruption (UUID-based temp files) (ConfigFileManager.swift)
- [x] T075 Add temp file cleanup on error in createAtomically() (ConfigFileManager.swift)
- [x] T076 Run swift test --filter InitCommandIntegrationTests to verify edge case tests PASS

**Checkpoint**: All edge cases handled - init command is production-ready

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and documentation updates

- [x] T077 [P] Run complete test suite: swift test (verify all 30+ tests pass)
- [x] T078 [P] Run manual tests from quickstart.md validation section
- [x] T079 [P] Verify CI passes on macOS-15 (local or GitHub Actions)
- [x] T080 [P] Verify CI passes on Ubuntu 20.04 (local act or GitHub Actions)
- [x] T081 [P] Update .windsurf/rules/bootstrap.md with init command patterns
- [x] T082 [P] Update AGENTS.md if phase/status changed
- [x] T083 Build release binary and test emoji display in different terminals
- [x] T084 Run performance benchmark: verify <1 second initialization (quickstart.md)
- [x] T085 Final code review: check Swift conventions and error handling completeness

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: ✅ Already complete from bootstrap
- **Foundational (Phase 2)**: Can start immediately - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User Story 1 (P1) must complete before User Story 2 (P2) - builds on basic init
  - User Story 2 (P2) adds to User Story 1 - requires init command to exist
  - User Story 3 (P3) enhances error handling - requires init command framework
- **Edge Cases (Phase 6)**: Depends on all user stories complete
- **Polish (Phase 7)**: Depends on all implementation complete

### User Story Dependencies

- **User Story 1 (P1)**: Depends on Foundational (Phase 2) - no other story dependencies
- **User Story 2 (P2)**: Depends on User Story 1 complete - adds --force flag to existing command
- **User Story 3 (P3)**: Depends on User Story 1 complete - enhances error handling in existing command

**Note**: Unlike typical independent user stories, these are sequential because they all enhance the same `InitCommand`. Each builds on the previous implementation.

### Within Each Phase

- **Foundation**: Tests first (T001-T010), implementation second (T011-T021)
- **User Story 1**: Tests first (T022-T028), implementation second (T029-T039)
- **User Story 2**: Tests first (T040-T046), implementation second (T047-T053)
- **User Story 3**: Tests first (T054-T059), implementation second (T060-T064)
- **Edge Cases**: Tests first (T065-T069), implementation second (T070-T076)

### Parallel Opportunities

**Foundation Phase**:
- T001-T002: Test file creation can be parallel
- T003-T009: All test writing can be parallel (different test functions)
- T011-T015: GitOperations and ConfigFileManager file creation can be parallel
- T016-T020: All function implementations within each file can be done together

**Within User Stories**:
- Test writing tasks can be parallel (different test functions)
- Polish phase tasks (T077-T082) can all be parallel

**Between Phases**:
- Must be sequential due to TDD (tests → implementation → verify) and story dependencies

---

## Parallel Example: Foundation Phase

```bash
# Launch all foundation test writing together:
Task T003: "Write test: findGitRoot() succeeds in valid repository"
Task T004: "Write test: findGitRoot() throws error outside repository"  
Task T005: "Write test: findGitRoot() resolves symlinks correctly"
Task T006: "Write test: generateMinimalConfig() returns valid YAML"
Task T007: "Write test: configPath() constructs correct path"
Task T008: "Write test: createAtomically() creates file correctly"
Task T009: "Write test: exists() returns true/false correctly"

# Then implement utilities (can be parallel per file):
Task T011-T014: GitOperations.swift implementation
Task T015-T020: ConfigFileManager.swift implementation (parallel to GitOperations)
```

---

## Implementation Strategy

### MVP Approach (All Three User Stories Required)

Given the sequential nature of this feature (all stories enhance the same command):

1. **Complete Phase 1**: ✅ Already done (bootstrap)
2. **Complete Phase 2**: Foundational utilities (git detection, file creation)
3. **Complete Phase 3**: User Story 1 (basic init command)
4. **Complete Phase 4**: User Story 2 (add --force protection)
5. **Complete Phase 5**: User Story 3 (git validation errors)
6. **Complete Phase 6**: Edge cases
7. **Complete Phase 7**: Polish and validate
8. **STOP and VALIDATE**: Run complete quickstart.md validation checklist

**Rationale**: Unlike typical independent user stories, P1/P2/P3 all build the same command incrementally. All three are needed for a production-safe init command per industry best practices.

### Delivery Strategy

**Single Delivery**: Complete feature (all phases) → Test completely → Deploy

**Why not incremental**: 
- P1 without P2 risks data loss (no overwrite protection)
- P3 error handling is essential for good UX
- All three are small additions to same command (basic init + --force flag + error handling)
- Total implementation ~85 tasks, well-scoped for single delivery

---

## Test Metrics

**Expected Test Coverage**:
- Foundation: 7 unit tests (GitOperations + ConfigFileManager)
- User Story 1: 6 integration tests
- User Story 2: 7 integration tests
- User Story 3: 6 integration tests
- Edge Cases: 5 integration tests

**Total**: ~31 new tests (combines with 25 existing bootstrap tests = 56 total)

**Performance Target**: All tests complete in <10 seconds

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- TDD strictly enforced: Write tests → Verify FAIL → Implement → Verify PASS
- Each checkpoint validates independent functionality
- Commit after completing each user story phase
- Verify tests fail before implementing to prove they validate the requirement
- Emoji output (❌/✅) is part of requirements, not optional styling
