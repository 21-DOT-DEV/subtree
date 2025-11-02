# Quickstart: CLI Bootstrap & Test Foundation

**Feature**: 001-cli-bootstrap  
**Date**: 2025-10-26  
**Purpose**: Guide for building, testing, and using the bootstrap CLI

## Prerequisites

- macOS 13+ (Ventura) or Ubuntu 20.04 LTS (Focal)
- Swift 6.1 toolchain installed
- Git installed
- (Optional) [nektos/act](https://github.com/nektos/act) for local CI testing

## Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd subtree
git checkout 001-cli-bootstrap
```

### 2. Verify Swift Version

```bash
swift --version
# Should show Swift version 6.1.x
```

## Building

### Build the CLI

```bash
swift build
```

This creates:
- Library: `.build/debug/SubtreeLib`
- Executable: `.build/debug/subtree`

### Build for Release

```bash
swift build -c release
```

Executable: `.build/release/subtree`

## Running

### Run from Build Directory

```bash
.build/debug/subtree --help
```

### Install Locally (Optional)

```bash
swift build -c release
cp .build/release/subtree /usr/local/bin/
```

Then run:
```bash
subtree --help
```

## Testing

### Run All Tests

```bash
swift test
```

This runs:
- Unit tests in `Tests/SubtreeLibTests/`
- Integration tests in `Tests/IntegrationTests/`

### Run Specific Test Suite

```bash
# Unit tests only
swift test --filter SubtreeLibTests

# Integration tests only
swift test --filter IntegrationTests
```

### Run Specific Test

```bash
swift test --filter CommandTests
```

### Verify Test Performance

```bash
# Unit tests should complete in <10 seconds
time swift test --filter SubtreeLibTests

# Integration tests should complete in <30 seconds
time swift test --filter IntegrationTests
```

## Using the Bootstrap CLI

### Show Help

```bash
subtree --help
subtree -h
```

**Expected Output**: List of available commands

### Show Version

```bash
subtree --version
```

**Expected Output**: Version information

### Show Command Help

```bash
subtree init --help
subtree add --help
subtree update --help
subtree remove --help
subtree extract --help
subtree validate --help
```

**Expected Output**: Command-specific help text

### Run Stub Commands

```bash
subtree init
```

**Expected Output**: `Command 'init' not yet implemented`

**Exit Code**: `0`

All commands (add, update, remove, extract, validate) behave the same way in the bootstrap phase.

## CI Pipeline

### Run CI Locally (with act)

```bash
# Install act (macOS)
brew install act

# Run CI workflow
act -j test
```

This simulates the GitHub Actions workflow locally.

### GitHub Actions

CI runs automatically on:
- Push to any branch
- Pull request creation/update

**Platform Matrix**:
- macOS latest (Swift 6.1)
- Ubuntu 20.04 LTS (Swift 6.1)

**Steps**:
1. Checkout code
2. Setup Swift 6.1
3. Build project
4. Run unit tests
5. Run integration tests

**Expected Duration**: <10 minutes

## Verification Checklist

After implementation, verify:

- [ ] `swift build` succeeds on macOS
- [ ] `swift build` succeeds on Ubuntu 20.04
- [ ] `swift test` passes all tests (<40s total)
- [ ] `subtree --help` shows all 6 commands
- [ ] `subtree <command> --help` works for all commands
- [ ] All stub commands print "not implemented" message
- [ ] All stub commands exit with code 0
- [ ] CI passes on both platforms
- [ ] `act -j test` runs successfully locally

## Troubleshooting

### Swift Version Mismatch

**Problem**: Build fails with "Swift version not supported"

**Solution**: Install Swift 6.1 toolchain from [swift.org](https://swift.org/download/)

### Test Failures on Ubuntu

**Problem**: Integration tests fail with git errors

**Solution**: Ensure git is installed: `sudo apt-get install git`

### CI Timeout

**Problem**: GitHub Actions exceeds 10 minute limit

**Solution**: Check for:
- Network issues downloading Swift toolchain
- Excessive test output
- Tests hanging (add timeout annotations)

### act Not Finding Swift

**Problem**: `act -j test` can't find Swift 6.1

**Solution**: Use Docker image with Swift pre-installed or install Swift in act workflow

## Next Steps

After bootstrap implementation:

1. **Update `.windsurf/rules`** per Constitution Principle V
2. **Run `/speckit.tasks`** to generate task list
3. **Run `/speckit.implement`** to execute TDD implementation
4. **Create subsequent feature specs** building on this foundation

## Performance Benchmarks

Expected timings for reference:

| Operation | Target | Typical |
|-----------|--------|---------|
| Build (clean) | N/A | 30-60s |
| Build (incremental) | N/A | 5-10s |
| Unit tests | <10s | 2-5s |
| Integration tests | <30s | 10-20s |
| Full CI (per platform) | <10m | 3-5m |
| Help display | <5s | <1s |

## Related Documentation

- [spec.md](./spec.md) - Feature specification
- [plan.md](./plan.md) - Implementation plan
- [contracts/cli-commands.md](./contracts/cli-commands.md) - CLI command contracts
- [research.md](./research.md) - Technical research decisions

## Phase Validation Checkpoints

### Phase 1: Setup Validation

Verify project structure matches Package.swift:

```bash
# Check Package.swift declares all dependencies
grep "swift-argument-parser" Package.swift
grep "Yams" Package.swift
grep "swift-subprocess" Package.swift
grep "swift-system" Package.swift
grep "swift-testing" Package.swift

# Check Package.swift declares all targets
grep "SubtreeLib" Package.swift
grep '"subtree"' Package.swift
grep "SubtreeLibTests" Package.swift
grep "IntegrationTests" Package.swift

# Verify directory structure exists
ls -la Sources/SubtreeLib/Commands/
ls -la Sources/SubtreeLib/Utilities/
ls -la Sources/subtree/
ls -la Tests/SubtreeLibTests/
ls -la Tests/IntegrationTests/

# Verify required files exist
[ -f Package.swift ] && echo "✓ Package.swift"
[ -f README.md ] && echo "✓ README.md"
[ -f .gitignore ] && echo "✓ .gitignore"
[ -f .windsurf/rules/bootstrap.md ] && echo "✓ .windsurf/rules/bootstrap.md"
[ -f agents.md ] && echo "✓ agents.md"
```

**Expected Result**: All checks pass, structure matches Package.swift

### Phase 2-3: Foundation & Test Infrastructure

Verify buildable and test infrastructure ready:

```bash
# Build succeeds
swift build

# Executable works
.build/debug/subtree --help

# Test infrastructure compiles
swift build --build-tests
```

**Expected Result**: All commands succeed, help text displays

## Implementation Learnings

### Phase 2-3: Foundation Build (2025-10-26)

**Foundation Success**:
- Minimal code (ExitCode, SubtreeCommand, main.swift) sufficient for buildable package
- swift-argument-parser provides automatic help generation
- No subcommands needed for basic help to work

**Test Infrastructure**:
- Using swift-subprocess correctly with `Subprocess.run()` and `.path()` executable
- Refactored from initial Foundation Process (API misunderstanding)
- Added `#if canImport(System)` for System/SystemPackage compatibility
- TestHarness uses async/await with `.string(limit: 65536)` for output capture

**Swift Testing**:
- Swift Testing built into Swift 6.1 toolchain
- Package dependency causes deprecation warnings
- Should remove swift-testing from Package.swift (use built-in)

**Build Commands**:
```bash
swift build                    # Builds executable
.build/debug/subtree --help   # Runs CLI
swift build --build-tests      # Builds test targets
swift test                     # Runs tests (once written)
```

