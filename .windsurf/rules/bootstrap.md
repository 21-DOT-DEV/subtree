---
trigger: always_on
---

# Subtree CLI - Bootstrap Rules

Last Updated: 2025-10-26 | Spec: 001-cli-bootstrap | Phase: 10 (Complete)

## Dependencies

**Purpose**: Swift 6.1 CLI tool for managing git subtrees with declarative configuration

- **swift-argument-parser 1.6.1**: CLI argument parsing
- **Yams 6.1.0**: YAML configuration parsing  
- **swift-subprocess 0.1.0+**: Process execution
- **swift-system 1.5.0**: File operations (Ubuntu 20.04 compatible)

## Structure

```
Sources/SubtreeLib/      # Library (all business logic)
├── Commands/            # ArgumentParser commands
└── Utilities/           # Helpers (ExitCode, etc.)
Sources/subtree/         # Executable (calls SubtreeLib.main())
Tests/SubtreeLibTests/   # Unit tests (@testable import)
Tests/IntegrationTests/  # Integration tests (run binary + git fixtures)
```

**Platforms**: macOS 13+, Ubuntu 20.04 LTS

## Architecture

**Library + Executable** (Swift standard pattern)
- SubtreeLib: All logic, fully testable
- subtree: Thin wrapper
- Rationale: Testability + future programmatic use

## CI/CD

**Status**: Complete (Phase 5: local act, Phase 9: GitHub Actions)
**Details**: See [ci-cd.md](./ci-cd.md) for workflows, platform matrix, and validation

## Features (Complete)

**CLI Skeleton**:
- 6 stub commands (init, add, update, remove, extract, validate)
- Help system (`subtree --help`)
- Exit codes (0=success, non-zero=error)

**Test Infrastructure**:
- TestHarness (CLI execution with swift-subprocess)
- GitRepositoryFixture (temporary git repos with UUID-based paths)
- 25 tests total (2 command + 7 exit code + 16 integration)

**CI Automation**:
- GitHub Actions (macOS-15 + Ubuntu 20.04)
- Local testing (nektos/act with ci-local.yml)
- Platform-specific Swift setup (DEVELOPER_DIR vs setup-swift)

---

## Update Triggers

Agent MUST update when changes occur to:
1. **Project dependencies** - Add/remove packages, version changes
2. **Directory structure** - New folders, renamed paths
3. **Architecture patterns** - New layers, different structure
4. **CI/CD pipeline** - Workflow changes, platform updates
5. **Major feature areas** - New commands, test utilities

**Procedure**: Read current file → identify changes → update surgically → keep <200 lines

---

## Rules Organization

**Pattern**: Multiple specialized files (not monolithic)

**Current Files**:
- `compliance-check.md`: Constitution checks (always-on)
- `bootstrap.md`: Bootstrap context (this file)
- `architecture.md`: Architecture & testing patterns
- `ci-cd.md`: CI/CD workflows & validation

**Rationale**: Modular (<200 lines each), focused, scalable

---

## agents.md Maintenance

**File**: `/agents.md` (universal AI onboarding per https://agents.md/)

**Purpose**: High-level context for ANY AI tool

**Update**: After EVERY phase (sync with README.md)

**Procedure**:
1. Update header (date, phase)
2. Update status (✅ exists, ⏳ doesn't)
3. Update next phase pointer

**See**: [agents.md](../agents.md) for current state

---

## Architecture & Testing Patterns

**Detailed Documentation**: See [architecture.md](./architecture.md)

**Quick Reference**:
- Library + Executable pattern (SubtreeLib + subtree)
- ArgumentParser for commands
- Two-layer testing (unit + integration)
- TestHarness for CLI execution
- Swift Testing (built into Swift 6.1)

---

**Lines**: ~120 (well under 200-line limit)


## Shell Configuration

**Zsh Autocorrect**: Prevent zsh from prompting to correct `subtree` or `swift` commands:

```bash
# Use nocorrect prefix for commands zsh might autocorrect
nocorrect swift test
nocorrect swift build
```

**Agent Guidance**: When generating `run_command` calls, prefer using `nocorrect` prefix for:
- `swift test`
- `swift build`
- `./.build/release/subtree`

This prevents interactive prompts that block automated execution.

---

**Lines**: ~145 (under 200-line limit)
