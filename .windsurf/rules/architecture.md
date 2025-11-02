---
trigger: always_on
---

# Subtree CLI - Architecture & Testing Patterns

Last Updated: 2025-10-26 | Phase: 10 (Complete) | Context: Proven patterns from MVP + CI implementation

## Architecture Pattern: Library + Executable

**Pattern**: Swift community standard for CLI tools

### Structure

```
Sources/
├── SubtreeLib/          # Library module (all business logic)
│   ├── Commands/        # Command implementations
│   └── Utilities/       # Helper utilities
└── subtree/             # Executable module (thin wrapper)
    └── EntryPoint.swift # Calls SubtreeCommand.main()
```

### Responsibilities

**SubtreeLib (Library)**:
- Contains ALL business logic
- Fully unit-testable with `@testable import`
- Can be used programmatically by other Swift code
- Exports `SubtreeCommand` as public API

**subtree (Executable)**:
- Thin wrapper (5 lines)
- Single responsibility: Call `SubtreeCommand.main()`
- No business logic
- Enables standalone CLI usage

### Benefits

✅ **Testability**: Unit tests import SubtreeLib directly  
✅ **Reusability**: Library can be embedded in other tools  
✅ **Separation**: CLI concerns separate from business logic  
✅ **Standard**: Matches swift-argument-parser best practices

## Command Pattern: ArgumentParser

**Framework**: swift-argument-parser 1.6.1

### Key Conventions

- **Public struct**: Conforming to `ParsableCommand`
- **Static configuration**: Defines command metadata
- **Subcommands array**: Lists available subcommands
- **Public init**: Required for library usage
- **Version string**: Displayed with `--version`

### Automatic Features

ArgumentParser provides for free:
- `--help` / `-h` flag
- `--version` flag  
- Subcommand help (`subtree <command> --help`)
- Error handling with usage display
- Bash completion support

## Testing Pattern: Two-Layer Approach

### Unit Tests (SubtreeLibTests/)

**Purpose**: Test business logic directly

**Characteristics**:
- Uses `@testable import` for internal access
- Tests configuration, logic, utilities
- Fast (no process execution)
- Built-in Swift Testing framework (Swift 6.1)

### Integration Tests (IntegrationTests/)

**Purpose**: Test CLI end-to-end

**Characteristics**:
- Uses TestHarness to execute actual binary
- Captures stdout/stderr/exit code
- Tests real CLI behavior
- Async execution with swift-subprocess

## TestHarness Pattern

**Location**: `Tests/IntegrationTests/TestHarness.swift`

### Purpose

Execute CLI commands in tests and capture results.

### Core API

```swift
struct TestHarness {
    func run(arguments: [String]) async throws -> CommandResult
}

struct CommandResult {
    let stdout: String
    let stderr: String
    let exitCode: Int
}
```

### Git Support

**GitRepositoryFixture**: Creates temporary git repositories for testing
- UUID-based unique paths (parallel-safe)
- Async initialization with initial commit
- Helper methods: `getCurrentCommit()`, `getCommitCount()`, `fileExists()`
- Complete cleanup with `tearDown()`

**TestHarness Git Helpers**: `runGit()`, `verifyCommitExists()`, `getGitConfig()`, `isGitRepository()`

## Swift Testing Framework

**Version**: Built into Swift 6.1 toolchain (no package dependency)

### Key Features

- **@Suite**: Groups related tests
- **@Test**: Marks individual test functions
- **#expect**: Assertion macro (replaces XCTest assertions)
- **async/await**: First-class async test support
- **Parallel execution**: Tests run concurrently by default

## Conventions

### Swift Naming

- **Files**: PascalCase (SubtreeCommand.swift, ExitCode.swift)
- **Types**: PascalCase (SubtreeCommand, TestHarness)
- **Functions**: camelCase (run, verifyCommitExists)
- **Constants**: camelCase (executablePath, exitCode)

### Testing Discipline

- **TDD**: Write tests first, verify failure, implement, verify pass
- **Test naming**: Descriptive strings in @Test("description")
- **Async tests**: Use async/await, not callbacks
- **Test isolation**: Each test is independent, use fixtures for setup
- **Assertions**: Use #expect(), not traditional assert()

### Code Organization

- **Library first**: All logic in SubtreeLib
- **Public API**: Only expose what's needed externally
- **Documentation**: Use Swift doc comments (///)
- **Error handling**: Use Swift errors, not exit() in library code

---

## MVP Validation Checkpoint

Verify architecture matches implementation:

```bash
# 1. Library + Executable Pattern
ls -la Sources/SubtreeLib/Commands/
wc -l Sources/subtree/main.swift  # Should be ~5 lines

# 2. Test Structure
grep "@testable import SubtreeLib" Tests/SubtreeLibTests/*.swift
grep "let harness: TestHarness" Tests/IntegrationTests/*.swift

# 3. Swift Testing (no package dependency)
! grep "swift-testing" Package.swift || echo "ERROR"

# 4. All tests pass
swift test  # Should show 25/25 tests passed
```

**Expected**: All checks pass, architecture is consistent

---

## Update Triggers

Update this file when:

1. **Architecture patterns change** (new layers, different structure)
2. **Testing patterns evolve** (new test utilities, different approaches)
3. **Framework updates** (ArgumentParser API changes, Testing updates)
4. **New command patterns** (subcommands, shared utilities)

---

**Lines**: ~195 (under 200-line limit)