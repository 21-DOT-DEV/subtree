# Research: CLI Bootstrap & Test Foundation

**Feature**: 001-cli-bootstrap  
**Date**: 2025-10-26  
**Purpose**: Research technical decisions and best practices for bootstrap implementation

## Research Questions

### Q1: Swift 6.1 with Swift Testing - Best Practices

**Decision**: Use Swift Testing framework (native to Swift 6.1) for all test types

**Rationale**:
- Swift Testing is Swift 6's native testing framework with modern macro-based syntax
- Better diagnostics and error messages than XCTest
- Async/await native support
- Parameterized testing built-in
- Compatible with Swift Package Manager out of the box
- Better performance for large test suites

**Alternatives Considered**:
- XCTest: Older API, less ergonomic, but more widely documented
- Rejected because Swift 6.1 target allows us to use modern tooling

**Implementation Notes**:
- Import `Testing` module in test files
- Use `@Test` macro instead of XCTestCase classes
- Use `@Suite` for test organization
- Use `#expect()` instead of XCTAssert macros

### Q2: Library + Executable Architecture with swift-argument-parser

**Decision**: Use ArgumentParser's `ParsableCommand` protocol in SubtreeLib, call from thin main.swift

**Rationale**:
- swift-argument-parser 1.6.1 supports this pattern officially
- Library contains all ArgumentParser command definitions
- Executable just calls `SubtreeCommand.main()`
- Enables unit testing of command parsing logic
- Standard pattern in Swift CLI ecosystem

**Alternatives Considered**:
- Put ArgumentParser in executable only: Not testable
- Duplicate command definitions: DRY violation
- Use custom argument parsing: Reinventing the wheel

**Implementation Pattern**:
```swift
// Sources/SubtreeLib/Commands/SubtreeCommand.swift
public struct SubtreeCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "subtree",
        subcommands: [InitCommand.self, AddCommand.self, ...]
    )
    
    public init() {}
}

// Sources/subtree/main.swift
import SubtreeLib
SubtreeCommand.main()
```

### Q3: Integration Test Harness with swift-system and swift-subprocess

**Decision**: Use swift-system for file operations, swift-subprocess for git/CLI execution

**Rationale**:
- swift-system 1.5.0 provides `FilePath` and file system APIs
- swift-subprocess 0.1.0+ provides modern async process execution
- Both are Apple-maintained, production-ready
- swift-subprocess has better error handling than Foundation's Process
- Async/await support matches Swift 6.1 concurrency model

**Alternatives Considered**:
- FileManager + Process: Older Foundation APIs, less type-safe
- Shell scripts: Not cross-platform, harder to debug
- Only Foundation: Missing modern Swift conveniences

**Implementation Pattern**:
```swift
import SystemPackage
import Subprocess

struct GitRepositoryFixture {
    let tempPath: FilePath
    
    func setUp() async throws {
        // Use FilePath for temp directory
        // Use Subprocess.run() for git init, git add, git commit
    }
}
```

### Q4: GitHub Actions CI with nektos/act Support

**Decision**: Use standard GitHub Actions syntax, test locally with act

**Rationale**:
- GitHub Actions is industry standard for Swift projects
- `nektos/act` allows local workflow testing without pushing
- Swift toolchain official actions available
- Easy matrix builds for macOS + Ubuntu
- Free for public repositories

**Alternatives Considered**:
- GitLab CI: Less Swift ecosystem support
- Circle CI: More complex config, cost considerations
- Travis CI: Declining ecosystem support

**Key Configuration Elements**:
- Use `swift-actions/setup-swift@v2` for Swift toolchain
- Matrix: `os: [macos-latest, ubuntu-20.04]`
- Swift version: 6.1
- Steps: checkout, setup, build, test
- Cache SPM dependencies for speed

**act Compatibility**:
- Avoid GitHub-specific features
- Use standard shell commands
- Test with: `act -j test` locally

### Q5: Stub Command Implementation Pattern

**Decision**: Print informative message to stdout, exit with code 0

**Rationale**:
- User gets immediate feedback that command exists but isn't implemented
- Exit code 0 prevents script failures during bootstrap phase
- Message pattern: "Command '<name>' not yet implemented"
- Consistent with help text behavior (also exit 0)
- Allows CI to pass during bootstrap phase

**Alternatives Considered**:
- Silent (no output): Poor UX, user confused
- Exit code 1: Would fail scripts unnecessarily
- Show help instead: Misleading, implies command has options

**Implementation Pattern**:
```swift
struct AddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a new subtree to the repository"
    )
    
    func run() throws {
        print("Command 'add' not yet implemented")
    }
}
```

### Q6: YAML Configuration with Yams

**Decision**: Use Yams 6.1.0 for YAML parsing (foundation for future config handling)

**Rationale**:
- Yams is the standard Swift YAML library
- Pure Swift implementation
- Good performance
- SwiftPM compatible
- Will be needed for subtree.yaml config in future specs

**Alternatives Considered**:
- JSON only: Less human-friendly for config files
- Custom parser: Unnecessary complexity
- Property lists: Not cross-platform

**Note**: Bootstrap doesn't use YAML yet, but dependency established now

### Q7: Exit Code Conventions

**Decision**: Define exit code constants in SubtreeLib/Utilities/ExitCode.swift

**Rationale**:
- Centralized exit code definitions
- Self-documenting code
- Easy to test
- Standard Unix conventions (0 = success, 1 = general error, 2 = misuse)

**Exit Code Schema**:
```swift
public enum ExitCode: Int32 {
    case success = 0
    case generalError = 1
    case misuse = 2
    case configError = 3
    case gitError = 4
}
```

**Note**: Bootstrap uses only `success` (0); others for future specs

## Summary

All technical decisions resolved with industry best practices:

1. ✅ Swift Testing for modern test ergonomics
2. ✅ Library + Executable for maximum testability
3. ✅ swift-system + swift-subprocess for robust file/process handling
4. ✅ GitHub Actions with act support for CI/local testing
5. ✅ Informative stub messages with exit code 0
6. ✅ Yams for future YAML config support
7. ✅ Centralized exit code definitions

No unresolved questions. Ready for Phase 1 design.
