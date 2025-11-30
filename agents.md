# AI Agent Guide: Subtree CLI

**Last Updated**: 2025-11-29 | **Phase**: 010-extract-clean (Complete) | **Status**: Production-ready with Extract Clean Mode

## What This Project Is

A Swift 6.1 command-line tool for managing git subtrees with declarative YAML configuration. Think "git submodule" but with subtrees, plus automatic config tracking and file extraction.

**Current Reality**: Init + Add + Remove + Update + Extract (with clean mode) commands complete - Production-ready with 477 passing tests.

## Current State (5 Commands Complete)

### ✅ What Exists
- Swift Package Manager structure (Package.swift)
- Foundation utilities (GitOperations, ConfigFileManager, URLParser, NameSanitizer, CommitMessageFormatter)
- **Init command** (PRODUCTION-READY - creates subtree.yaml with full error handling)
- **Add command** (PRODUCTION-READY - adds subtrees with atomic commits, smart defaults, full validation)
- **Update command** (PRODUCTION-READY - updates subtrees with case-insensitive lookup, atomic commits)
- **Remove command** (PRODUCTION-READY - removes subtrees with case-insensitive lookup, atomic commits)
- **Extract command** (PRODUCTION-READY - extract files with glob patterns, persistent mappings, bulk execution, clean mode)
- **1 stub command** (validate - prints "not yet implemented")
- **Full CLI** (`subtree --help`, all command help screens work perfectly)
- **Test suite** (477/477 tests pass: comprehensive integration + unit tests)
- **Git test fixtures** (GitRepositoryFixture with UUID-based temp directories, async)
- **Git verification helpers** (TestHarness for CLI execution, git state validation)
- **Test infrastructure** (TestHarness with swift-subprocess, async/await, black-box testing)
- **CI workflows** (ci.yml with macOS-15 + Ubuntu 20.04, ci-local.yml for local act - ALL PASSING)
- **Platform-specific CI** (native Xcode for macOS, setup-swift for Ubuntu)
- **CI badge** (README workflow status)
- **Complete agent rules** (.windsurf/rules/ with 4 files: bootstrap, architecture, ci-cd, compliance)
- Documentation (specs/, constitution, README, this file)

### ✅ Init Command Features (Complete)
- Creates subtree.yaml at repository root from any subdirectory
- Works with symlinked repository paths
- Overwrite protection with explicit --force flag
- Git repository validation with clear error messages
- Permission and I/O error handling
- Concurrent execution safety (atomic operations)
- Detached HEAD support
- Performance: <200ms (well under 1s requirement)

### ✅ Add Command Features (Complete - 5 User Stories)
**US1 - MVP (Smart Defaults)**:
- Minimal flags: only `--remote` required
- Auto-derives name from URL, sanitizes for filesystem safety
- Defaults prefix to name, ref to "main"
- Single atomic commit (subtree + config in one commit)
- Custom commit message with structured format

**US2 - Override Defaults**:
- `--name` flag to override derived name
- `--prefix` flag to specify custom location
- `--ref` flag to specify branch/tag
- Prefix defaults from name when only name provided

**US3 - No-Squash Mode**:
- `--no-squash` flag preserves full upstream history
- Config tracks squash setting
- Git log shows individual commits from upstream

**US4 - Duplicate Prevention**:
- Validates no duplicate names before git operations
- Validates no duplicate prefixes before git operations
- Clear error messages with emoji prefixes
- Zero side effects on duplicate detection

**US5 - Error Handling**:
- Invalid URL format detection
- Missing config file guidance (suggests `init`)
- Not in git repository validation
- Git operation failure surfacing
- Comprehensive error messages with actionable guidance

### ✅ Case-Insensitive Validation Features (Complete)
- **Case-insensitive name lookup**: Works across all commands (add, remove, update, extract)
- **Corruption detection**: Validates configs for duplicate names/prefixes before operations
- **Whitespace normalization**: Trims input while preserving original case in config
- **Original case preservation**: Config always stores user-provided casing
- **Smart error messages**: Emoji prefixes, actionable guidance, correct exit codes

### ✅ Extract Command Features (Complete - 5 User Stories)
**US1 - Ad-Hoc Extraction**:
- Flexible glob patterns (*, **, ?, [abc], {a,b})
- Multiple `--from` patterns (union extraction with deduplication)
- Exclude patterns with --exclude flag
- Full relative path preservation (industry standard)
- Pattern-based file matching using GlobMatcher

**US2 - Persistent Mappings**:
- --persist flag saves extraction mappings to subtree.yaml
- Duplicate detection prevents redundant mappings
- Atomic config updates
- Reusable extraction workflows

**US3 - Bulk Execution**:
- Execute all mappings for one subtree (--name)
- Execute all mappings for all subtrees (--all)
- Continue-on-error with failure collection
- Detailed progress output with file counts
- Exit code priority (highest severity wins)

**US4 - Overwrite Protection**:
- Git-tracked file detection before extraction
- --force flag to override protection
- Smart error messages (show all ≤20 files, truncate >20)
- Per-mapping protection in bulk mode
- Atomic failure (no partial extractions)

**US5 - Validation & Error Handling**:
- Mode-dependent zero-match handling (error in ad-hoc, warning in bulk)
- Per-pattern match tracking with warnings for zero-match patterns
- Clear error messages with actionable suggestions
- Emoji prefixes for all output (❌/✅/ℹ️/📊/📝/⚠️)
- Appropriate exit codes (0=success, 1=user error, 2=system error, 3=config error)

### ✅ Extract Clean Mode Features (Complete - 5 User Stories)
**US1 - Ad-hoc Clean with Checksum Validation**:
- `--clean` flag removes previously extracted files
- Checksum validation via `git hash-object` prevents accidental deletion
- Empty directory pruning up to destination root
- Fail-fast on first checksum mismatch

**US2 - Force Clean Override**:
- `--force` bypasses checksum validation
- Removes files even when source is missing
- Bypasses subtree prefix validation

**US3 - Bulk Clean from Persisted Mappings**:
- `--clean --name` cleans all mappings for one subtree
- `--clean --all` cleans all mappings for all subtrees
- Continue-on-error with failure summary
- Exit code priority (highest severity wins)

**US4 - Multi-Pattern Clean**:
- Multiple `--from` patterns supported
- `--exclude` patterns filter removals
- Feature parity with extraction

**US5 - Error Handling**:
- Clear error messages with actionable suggestions
- Appropriate exit codes (0=success, 1=validation, 2=user error, 3=I/O)

### ⏳ What's Next
- Implement lint/validate command
- Additional enhancements and polish

## Architecture Overview

**Pattern**: Library + Executable (Swift best practice)
- `SubtreeLib` - All business logic, fully testable
- `subtree` - Thin executable wrapper, calls SubtreeLib.main()

**Rationale**: Maximum testability, enables future programmatic use.

**Platforms**: macOS 13+, Ubuntu 20.04 LTS

## Development Philosophy

This project follows **strict constitutional governance**. Every feature:

1. **Spec-First**: Starts with `spec.md` defining requirements and failing tests
2. **TDD**: Tests written before implementation, verified to fail first
3. **Small Specs**: Independent, testable increments of value
4. **CI Gates**: Automated quality enforcement (no exceptions)
5. **Living Rules**: Agent context updated after structural changes

**Constitution**: See `.specify/memory/constitution.md` for complete governance

## Where to Find Details

### For Understanding the Project
- **README.md**: Human-readable project overview, current phase status
- **specs/010-extract-clean/spec.md**: Extract Clean Mode requirements (latest feature)
- **specs/008-extract-command/plan.md**: Technical approach and architecture decisions
- **.specify/memory/constitution.md**: Governance principles (NON-NEGOTIABLE)

### For Implementation Guidance
- **specs/010-extract-clean/tasks.md**: Step-by-step task list (69 tasks complete)
- **specs/008-extract-command/contracts/**: Command contracts and test standards
- **specs/008-extract-command/data-model.md**: Configuration models (ExtractionMapping)
- **.windsurf/rules/**: Windsurf-specific patterns (architecture, ci-cd, compliance)

### For Validation
- **specs/008-extract-command/checklists/requirements.md**: Spec quality validation
- **Test suite**: 477 tests covering all commands and features

## Tech Stack

**Language**: Swift 6.1  
**Package Manager**: Swift Package Manager  
**Testing**: Swift Testing (Swift 6 native, macro-based)  
**CI**: GitHub Actions (macOS + Ubuntu 20.04 LTS)  
**Dependencies**:
- swift-argument-parser 1.6.1 (CLI framework)
- Yams 6.1.0 (YAML parsing)
- swift-subprocess 0.1.0+ (process execution)
- swift-system 1.5.0 (file operations, pinned for Ubuntu compatibility)
- swift-testing 0.6.0+ (test framework)

## Key Constraints

- **No linting yet**: Deferred to future feature specs (bootstrap scope limited)
- **Swift 6.1 required**: Uses modern Swift features (concurrency, macros)
- **Ubuntu 20.04 LTS**: swift-system pinned to 1.5.0 for compatibility
- **TDD mandatory**: Constitution requires tests before implementation
- **200-line limit**: Agent rules files must stay concise per constitution

## How to Help

### If You're Implementing Code
1. Read current phase status in README.md
2. Check `.specify/memory/roadmap/` for next planned feature
3. Follow TDD: write tests → verify fail → implement → verify pass
4. Consult .windsurf/rules/bootstrap.md for conventions
5. Update README.md and agents.md (this file) after phase completes

### If You're Analyzing/Planning
1. Check .specify/memory/constitution.md for governance
2. Review current feature's spec.md for requirements
3. Examine plan.md for technical decisions
4. Verify constitutional compliance before suggesting changes

### If You're Debugging
1. Check current feature's quickstart.md for validation commands
2. Run `swift test` to verify all tests pass
3. Verify Package.swift matches documented structure
4. Ensure all directories exist: `ls -la Sources/ Tests/`

## What Makes This Project Different

**Spec-Driven**: Requirements drive implementation, not vice versa  
**Test-First**: Tests prove requirements, implementation passes tests  
**Constitutional**: Governance in code, principles are enforced  
**Agent-Friendly**: Documentation designed for human AND AI collaboration  
**Feedback Loops**: Structure → validate → document → iterate

## Maintenance Notes

**This file updates after every phase** to reflect current reality:
- **Bootstrap (001)**: CLI foundation, init command ✅
- **Add Command (004)**: All 5 user stories complete ✅
- **Remove Command (005)**: Case-insensitive removal ✅
- **Update Command (006)**: Case-insensitive updates ✅
- **Case-Insensitive Names (007)**: Validation across all commands ✅
- **Extract Command (008)**: All 5 user stories complete ✅
- **Multi-Pattern Extraction (009)**: All 5 user stories complete ✅
- **Extract Clean Mode (010)**: All 5 user stories complete ✅
  - Phase 1-2: Setup + Foundational (GitOperations.hashObject, DirectoryPruner) ✅
  - Phase 3-4: Ad-hoc clean + Force override (MVP) ✅
  - Phase 5-6: Bulk clean + Multi-pattern clean ✅
  - Phase 7-8: Error handling + Polish ✅

**Keep synchronized with**:
- README.md (status, build instructions, usage examples)
- .windsurf/rules/ (architecture, ci-cd, compliance patterns)
- .specify/memory/roadmap/ (phase progress)

---

**For Humans**: See README.md  
**For Windsurf**: See .windsurf/rules/ (architecture, ci-cd, compliance)  
**For Governance**: See .specify/memory/constitution.md  
**For Requirements**: See specs/010-extract-clean/spec.md (latest feature)
