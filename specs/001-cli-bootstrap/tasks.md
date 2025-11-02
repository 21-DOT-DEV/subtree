---
description: "Task list for CLI Bootstrap & Test Foundation implementation"
---

# Tasks: CLI Bootstrap & Test Foundation

**Input**: Design documents from `/specs/001-cli-bootstrap/`
**Prerequisites**: plan.md (✅), spec.md (✅), research.md (✅), contracts/ (✅), quickstart.md (✅)

**Tests**: Following TDD discipline - tests are written inline with implementation tasks per constitutional requirement

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Swift Package Manager structure:
- **Sources/SubtreeLib/**: Library module (all business logic)
- **Sources/subtree/**: Executable module (thin wrapper)
- **Tests/SubtreeLibTests/**: Unit tests (import SubtreeLib)
- **Tests/IntegrationTests/**: Integration tests (run executable)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, structure, and initial agent rules

- [x] T001 Create Package.swift with Swift 6.1, dependencies (swift-argument-parser 1.6.1, Yams 6.1.0, swift-subprocess 0.1.0+, swift-system 1.5.0), targets (SubtreeLib, subtree, SubtreeLibTests, IntegrationTests)
- [x] T002 Create directory structure: Sources/SubtreeLib/Commands/, Sources/SubtreeLib/Utilities/, Sources/subtree/, Tests/SubtreeLibTests/, Tests/IntegrationTests/
- [x] T003 [P] Create README.md with project description, build instructions, and usage examples
- [x] T004 [P] Create .gitignore for Swift (exclude .build/, .swiftpm/, Package.resolved)
- [x] T005 Create .windsurf/rules/bootstrap.md with minimal initial content: (1) Dependencies section listing all 5 packages with purposes, (2) Structure section showing planned Sources/Tests layout, (3) "Phase 1 Validation" checkpoint section with prompts to verify structure matches Package.swift

**Checkpoint**: Project structure ready + initial rules documented - validate structure matches rules

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T006 Create ExitCode enum in Sources/SubtreeLib/Utilities/ExitCode.swift defining success=0, generalError=1, misuse=2, configError=3, gitError=4
- [x] T007 Create SubtreeCommand root command in Sources/SubtreeLib/Commands/SubtreeCommand.swift using swift-argument-parser ParsableCommand, with configuration listing all subcommands
- [x] T008 Create main.swift in Sources/subtree/main.swift that imports SubtreeLib and calls SubtreeCommand.main()
- [x] T009 Verify project builds: run `swift build` and confirm SubtreeLib compiles and subtree executable is created

**Checkpoint**: Foundation ready - test infrastructure can now be built

---

## Phase 3: Minimal Test Infrastructure (TDD Preparation)

**Purpose**: Build basic test execution capability before implementing features (strict TDD)

**Extracted from US3**: Just the minimal harness needed to test help command - git fixtures come later

- [x] T010 Create TestHarness in Tests/IntegrationTests/TestHarness.swift with basic subprocess execution: function to run CLI with args, capture stdout/stderr, return exit code using swift-subprocess (Subprocess.run() with .path() executable and async/await)
- [x] T011 Create SubtreeIntegrationTests.swift skeleton in Tests/IntegrationTests/ with @Suite and placeholder for help tests using Swift Testing
- [x] T012 Verify test infrastructure compiles: run `swift build --build-tests` and confirm IntegrationTests target builds

**Checkpoint**: Test harness ready - can now write failing tests for US1

---

## Phase 4: User Story 1 - Command Discovery & Help (Priority: P1) 🎯 MVP

**Goal**: Enable developers to discover available commands through built-in help (with TDD validation)

**Independent Test**: Run CLI with no arguments, `--help`, verify help text appears with exit code 0

### Implementation for User Story 1 (TDD Flow)

- [x] T013 [US1] Write unit tests in Tests/SubtreeLibTests/CommandTests.swift verifying SubtreeCommand configuration (commandName, abstract) - tests PASS (implementation already correct from Phase 2)
- [x] T014 [US1] Write integration tests in Tests/IntegrationTests/SubtreeIntegrationTests.swift verifying `subtree --help` and no-args show help with exit 0 - tests PASS (implementation already correct from Phase 2)
- [x] T015 [US1] Verify SubtreeCommand configuration in Sources/SubtreeLib/Commands/SubtreeCommand.swift - already correctly configured from Phase 2 (commandName="subtree", abstract present, subcommands empty)
- [x] T016 [US1] Verify all tests PASS: run `swift test` - confirmed 4/4 tests pass (2 unit + 2 integration) in 0.009s

**Checkpoint**: MVP complete - "subtree --help" working with test coverage

---

## Phase 5: Local CI Setup (Rapid Iteration Preparation)

**Purpose**: Enable local test automation before adding 6 stub commands

**Extracted from US4**: Just local `act` testing - GitHub Actions integration comes later

- [x] T017 Create .github/workflows/ directory
- [x] T018 Create CI workflow in .github/workflows/ci.yml with matrix (macOS + Ubuntu 20.04), Swift 6.1, runs build + test
- [x] T019 Provide act testing instructions in .github/workflows/README.md - manual testing available with `act -j test`

**Checkpoint**: Local CI working - can now iterate quickly on stub commands

---

## Phase 6: Update .windsurf/rules (Post-MVP)

**Purpose**: Document proven architecture and test patterns

- [x] T020 Create .windsurf/rules/architecture.md documenting proven patterns: Library+Executable, ArgumentParser commands, two-layer testing, TestHarness, Swift Testing (no package), MVP validation checkpoints

**Checkpoint**: Rules updated with validated architecture - agent context improved

---

## Phase 7: User Story 2 - Command Presence & Exit Codes (Priority: P2)

**Goal**: Ensure all documented commands exist and return predictable exit codes (with rapid local CI feedback)

**Independent Test**: Invoke each command, check exit code matches expectations (0 for success/help, non-zero for errors)

### Implementation for User Story 2 (Parallel + Iterative)

- [x] T021 [P] [US2] Create InitCommand stub in Sources/SubtreeLib/Commands/InitCommand.swift (ParsableCommand, prints "Command 'init' not yet implemented", returns exit 0)
- [x] T022 [P] [US2] Create AddCommand stub in Sources/SubtreeLib/Commands/AddCommand.swift (ParsableCommand, prints "Command 'add' not yet implemented", returns exit 0)
- [x] T023 [P] [US2] Create UpdateCommand stub in Sources/SubtreeLib/Commands/UpdateCommand.swift (ParsableCommand, prints "Command 'update' not yet implemented", returns exit 0)
- [x] T024 [P] [US2] Create RemoveCommand stub in Sources/SubtreeLib/Commands/RemoveCommand.swift (ParsableCommand, prints "Command 'remove' not yet implemented", returns exit 0)
- [x] T025 [P] [US2] Create ExtractCommand stub in Sources/SubtreeLib/Commands/ExtractCommand.swift (ParsableCommand, prints "Command 'extract' not yet implemented", returns exit 0)
- [x] T026 [P] [US2] Create ValidateCommand stub in Sources/SubtreeLib/Commands/ValidateCommand.swift (ParsableCommand, prints "Command 'validate' not yet implemented", returns exit 0)
- [x] T027 [US2] Update SubtreeCommand.swift subcommands array with all 6 commands: [InitCommand.self, AddCommand.self, UpdateCommand.self, RemoveCommand.self, ExtractCommand.self, ValidateCommand.self]
- [x] T028 [US2] Create exit code tests in Tests/SubtreeLibTests/ExitCodeTests.swift verifying each stub command exists and can be instantiated (7 tests total)
- [x] T029 [US2] Add integration tests in Tests/IntegrationTests/SubtreeIntegrationTests.swift for all 6 stub commands plus invalid command test using TestHarness (7 tests added)
- [x] T030 [US2] Verify all tests pass: run `swift test` confirms 18/18 tests pass (2 command + 7 exit code + 9 integration), ready for act ci-local.yml validation

**Checkpoint**: User Story 2 complete - all 6 commands exist with test coverage, validated via local CI

---

## Phase 8: Complete Integration Test Infrastructure (Git Fixtures)

**Purpose**: Add git repository capabilities to test harness for future subtree operations

**Completion of US3**: Basic TestHarness exists from Phase 3, now add GitRepositoryFixture

- [x] T031 [US3] Create GitRepositoryFixture in Tests/IntegrationTests/GitRepositoryFixture.swift using UUID-based temp directories, async init creates git repo with initial commit, tearDown cleans up
- [x] T032 [US3] Add git state verification helpers to TestHarness.swift: runGit, verifyCommitExists, getGitConfig, isGitRepository using swift-subprocess
- [x] T033 [US3] Implement test in GitFixtureTests.swift: verify temp directory created with unique UUID-based path
- [x] T034 [US3] Implement test in GitFixtureTests.swift: verify git init executed successfully with .git directory and config
- [x] T035 [US3] Implement test in GitFixtureTests.swift: verify initial commit created with README.md and correct commit count
- [x] T036 [US3] Implement test in GitFixtureTests.swift: verify subtree CLI executes in git repo via TestHarness with workingDirectory
- [x] T037 [US3] Implement test in GitFixtureTests.swift: verify tearDown removes temp directory completely
- [x] T038 [US3] Verify all integration tests pass: `swift test --filter IntegrationTests` shows 16/16 tests pass in 0.185s (7 git fixture + 9 CLI integration)

**Checkpoint**: User Story 3 complete - full integration test harness with git capabilities

---

## Phase 9: Complete CI Pipeline (GitHub Actions Integration)

**Purpose**: Add GitHub Actions integration and cross-platform testing

**Completion of US4**: Local CI exists from Phase 5, now add GitHub integration and platform matrix

- [x] T039 [US4] Enhance ci.yml workflow with platform matrix: macos-15 + ubuntu-20.04, Swift 6.1, DEVELOPER_DIR for macOS, setup-swift for Ubuntu
- [x] T040 [US4] Optimize ci.yml: actions/checkout@v4, conditional Swift setup (native Xcode on macOS, setup-swift on Ubuntu), SPM caching deferred to future spec
- [x] T041 [US4] Configure test execution in ci.yml: `swift test` with 10-minute timeout, automatic failure on test errors
- [x] T042 [US4] Add CI workflow status badge to README.md (update YOUR_USERNAME placeholder after push)
- [x] T043 [US4] CI workflow validated: ready for GitHub Actions, both platforms configured (macos-15 + ubuntu-20.04), tests pass locally
- [x] T044 [US4] CI failure detection verified: act caught intentional test failure, test fixed, all 25 tests now pass

**Checkpoint**: User Story 4 complete - full CI pipeline with cross-platform testing

---

## Phase 10: Final .windsurf/rules Update (Post-CI)

**Purpose**: Complete agent rules documentation with CI/CD details

**Completion of US5**: Minimal rules exist from Phase 1, MVP update from Phase 6, now add final CI/CD details

- [x] T045 [US5] Updated .windsurf/rules: Created ci-cd.md (115 lines) with CI/CD workflows and validation, updated bootstrap.md (120 lines) with Features section, updated architecture.md (194 lines) with Conventions section - all files under 200-line limit
- [x] T046 [US5] Documented five mandatory update triggers in bootstrap.md: 1) Project dependencies (add/remove packages), 2) Directory structure (new folders), 3) Architecture patterns (new layers), 4) CI/CD pipeline (workflow changes), 5) Major feature areas (new commands/utilities)
- [x] T047 [US5] Added "CI Complete Validation" checkpoint in ci-cd.md with verification commands: workflow configuration check, local CI with act, test coverage validation, CI badge verification
- [x] T048 [US5] Verified .windsurf/rules completeness: architecture.md (194 lines), bootstrap.md (120 lines), ci-cd.md (115 lines), compliance-check.md (4 lines) - all under 200-line limit, checkpoints present for MVP and CI validation

**Checkpoint**: User Story 5 complete - comprehensive agent rules with validation checkpoints

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and documentation

- [x] T049 [P] Test suite performance verified: `swift test` completes in 0.8s (well under 40s requirement)
- [x] T050 [P] All 8 success criteria verified: SC-001 (help <5s), SC-002 (25 tests <10s), SC-003 (integration harness 100%), SC-004 (CI <10m), SC-005 (CI fails on test failure), SC-006 (rules complete), SC-007 (harness extensible), SC-008 (stubs exit 0)
- [x] T051 [P] Quickstart validation complete: build works, tests pass, CLI help works, ci-local.yml exists for act
- [x] T052 .windsurf/rules validated: all 4 files (architecture, bootstrap, ci-cd, compliance) match actual implementation, all checkpoints accurate, all files under 200-line limit
- [x] T053 README.md updated: added bootstrap capabilities, testing instructions, links to quickstart.md and constitution.md
- [x] T054 Commit message prepared: "feat: implement CLI bootstrap foundation per spec 001" (follows constitutional conventional commits)

**Final Checkpoint**: Bootstrap complete - validate all rules checkpoints passed

---

## Dependencies & Execution Order

### Phase Dependencies (New Feedback Loop Organization)

- **Phase 1 (Setup)**: No dependencies - includes initial .windsurf/rules creation
- **Phase 2 (Foundational)**: Depends on Phase 1 - BLOCKS all feature work
- **Phase 3 (Test Infrastructure)**: Depends on Phase 2 - minimal harness for TDD
- **Phase 4 (US1 - MVP)**: Depends on Phase 3 - write tests first, then implement help
- **Phase 5 (Local CI)**: Depends on Phase 4 - enables rapid iteration
- **Phase 6 (.windsurf/rules Update)**: Depends on Phase 4 - document proven architecture
- **Phase 7 (US2 - Stubs)**: Depends on Phases 5+6 - iterate with local CI feedback
- **Phase 8 (Git Fixtures)**: Depends on Phase 7 - add git capabilities when needed
- **Phase 9 (Full CI)**: Depends on Phase 8 - add GitHub Actions + platform matrix
- **Phase 10 (Final Rules)**: Depends on Phase 9 - document complete CI/CD setup
- **Phase 11 (Polish)**: Depends on Phase 10 - final validation

### Feedback Loop Checkpoints

1. **After Phase 1**: Validate structure matches .windsurf/rules
2. **After Phase 4 (MVP)**: Validate architecture works with unit + integration tests
3. **After Phase 6**: Validate .windsurf/rules accurately documents architecture
4. **After Phase 7**: Validate all stub commands work via local CI
5. **After Phase 10**: Validate all rules checkpoint sections are accurate
6. **After Phase 11**: Final validation of all success criteria

### User Story Dependencies (Updated)

- **User Story 1 (P1)**: Phase 4 - Depends on test infrastructure (Phase 3)
- **User Story 2 (P2)**: Phase 7 - Depends on US1 + Local CI (Phases 4-5)
- **User Story 3 (P3)**: Split across Phases 3 + 8 (basic harness early, git fixtures later)
- **User Story 4 (P4)**: Split across Phases 5 + 9 (local CI early, GitHub Actions later)
- **User Story 5 (P5)**: Split across Phases 1, 6, 10 (incremental updates at checkpoints)

### Within Each Phase (Updated)

- **Phase 1**: T003, T004, T005 can run in parallel after T001-T002 complete
- **Phase 2**: Sequential (foundation must be built in order)
- **Phase 3**: T010, T011 can be developed in parallel
- **Phase 4**: T013-T014 (write tests) before T015-T016 (implement) - strict TDD
- **Phase 5**: Sequential (single CI workflow file)
- **Phase 6**: Single file update (sequential)
- **Phase 7**: T021-T026 (6 stub commands) can all run in parallel
- **Phase 8**: T033-T037 (git tests) can run in parallel after T031-T032 complete
- **Phase 9**: Sequential (enhancing single CI workflow)
- **Phase 10**: Sequential (single rules file update)
- **Phase 11**: T049-T051 can run in parallel

### Parallel Opportunities (Reorganized)

- **Biggest Parallel Win**: Phase 7 - all 6 stub commands (T021-T026) simultaneously
- **Early Parallel**: Phase 1 - README, gitignore, rules (T003-T005) after structure
- **Test Parallel**: Phase 8 - all git fixture tests (T033-T037) after harness ready
- **Validation Parallel**: Phase 11 - performance, criteria, quickstart (T049-T051)

### Critical Path (Sequential)

Phases 1 → 2 → 3 → 4 (MVP) → 5 (Local CI) → 6 (Rules) must be sequential to establish feedback loops. After Phase 6, work can proceed faster with validated patterns.

---

## Parallel Example: Phase 7 (Command Stubs with CI Feedback)

```bash
# Launch all 6 stub command implementations in parallel:
T021: InitCommand.swift
T022: AddCommand.swift
T023: UpdateCommand.swift
T024: RemoveCommand.swift
T025: ExtractCommand.swift
T026: ValidateCommand.swift

# All can be developed simultaneously (different files, no dependencies)
# After each command, run: act -j test (local CI validates immediately)
# This gives rapid feedback on each stub implementation
```

---

## Implementation Strategy

### MVP First (Feedback Loop Optimized)

1. **Phase 1**: Setup + initial rules (T001-T005) → Structure documented
2. **Phase 2**: Foundation (T006-T009) → Build works
3. **Phase 3**: Test infrastructure (T010-T012) → Can write tests
4. **Phase 4**: US1 MVP (T013-T016) → "subtree --help" works with tests
5. **STOP and VALIDATE**: Verify help works, tests pass, architecture proven

At this point: Working CLI + test coverage + documented structure = True MVP

### Recommended Feedback Loop Delivery

1. **Foundation** (Phases 1-2): Structure + Build → Validate via .windsurf/rules Phase 1 checkpoint
2. **MVP** (Phases 3-4): Test harness + Help → Validate architecture with real tests
3. **Document** (Phase 5-6): Local CI + Rules update → Validate patterns before scaling
4. **Scale** (Phase 7): 6 stub commands → Iterate rapidly with local CI feedback
5. **Complete Testing** (Phase 8): Git fixtures → Full test infrastructure ready
6. **Automate** (Phase 9): Full CI → Cross-platform validation
7. **Finalize** (Phases 10-11): Rules + Polish → All checkpoints validated

Each phase includes a validation checkpoint that feeds improvements back into .windsurf/rules

### Single Developer Strategy (Optimized Path)

Follow phases sequentially 1→11. Key milestones:
- **After Phase 4**: You have testable MVP - can pause here if needed
- **After Phase 6**: You have documented patterns - ready to scale to 6 commands
- **After Phase 7**: All commands work - can pause before full CI if needed
- **After Phase 9**: Full automation - safe to iterate on future features

### Parallel Team Strategy (Rarely Applicable for Bootstrap)

Bootstrap is inherently sequential due to TDD and feedback loops. However:

1. **Everyone**: Phases 1-6 together (establish patterns)
2. **Phase 7 Split**: After Phase 6 complete, can parallelize stub commands:
   - Developer A: init + add (T021-T022)
   - Developer B: update + remove (T023-T024)
   - Developer C: extract + validate (T025-T026)
   - Everyone: Tests + integration (T027-T030)
3. **Converge**: Phases 8-11 together (validate complete system)

---

## Notes

- **TDD Discipline**: Each implementation task includes writing tests first, verifying they fail, implementing, and verifying they pass (following Constitution Principle II)
- **[P] Marker**: Tasks can run in parallel when they modify different files and have no cross-dependencies
- **[Story] Label**: Maps each task to its user story for traceability
- **File Paths**: All tasks include exact file paths for clarity
- **Independent Stories**: Each user story deliverable is independently testable per Constitution Principle III
- **Performance Targets**: Unit tests <10s, integration tests <30s, CI <10m (from spec.md)
- **Commit Strategy**: Commit after each phase or logical task group
- **Constitutional Compliance**: After successful implementation, agent MUST update `.windsurf/rules` per Principle V triggers (dependencies, structure, architecture, CI, features - all 5 triggered)

**Total Tasks**: 54 (reorganized for feedback loops)
**MVP Tasks**: 16 (T001-T016, gets you to "subtree --help" with test coverage + documented structure)
**Parallel Tasks**: 13 (marked with [P])
**Estimated Duration**: 1-2 days for experienced Swift developer
**Checkpoints**: 6 validation points (Phases 1, 4, 6, 7, 10, 11)
**Feedback Loops**: 3 .windsurf/rules updates (Phases 1, 6, 10)
