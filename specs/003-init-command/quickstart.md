# Quickstart: Init Command

**Feature**: 003-init-command | **Purpose**: Build, test, and validate the init command implementation

## Prerequisites

- Swift 6.1 installed
- Git repository cloned
- On branch `003-init-command`

## Build

```bash
# Build the project
swift build

# Verify build succeeded
ls .build/debug/subtree
```

**Expected**: Binary exists at `.build/debug/subtree`

---

## Run Tests

### All Tests

```bash
# Run complete test suite
swift test

# Expected output:
# Test Suite 'All tests' passed at ...
# Executed XX tests, with 0 failures
```

### Unit Tests Only

```bash
# Run only SubtreeLib unit tests
swift test --filter SubtreeLibTests

# Expected: All unit tests pass
```

### Integration Tests Only

```bash
# Run only integration tests
swift test --filter IntegrationTests

# Expected: All integration tests pass
```

### Specific Test Suite

```bash
# Run init command tests specifically
swift test --filter InitCommand

# Expected: All init-related tests pass
```

---

## Manual Testing

### Setup Test Repository

```bash
# Create temporary test repository
cd /tmp
mkdir test-subtree-init
cd test-subtree-init
git init
```

### Test Success Path

```bash
# Run init command (from repo root)
/path/to/subtree/.build/debug/subtree init

# Expected output:
# ✅ Created subtree.yaml

# Verify file created
cat subtree.yaml
# Expected content:
# # Managed by subtree CLI - https://github.com/21-DOT-DEV/subtree
# subtrees: []

# Check exit code
echo $?
# Expected: 0
```

### Test From Subdirectory

```bash
# Create subdirectory
mkdir -p src/components
cd src/components

# Run init
/path/to/subtree/.build/debug/subtree init

# Expected output:
# ✅ Created ../../subtree.yaml

# Verify file at root
ls ../../subtree.yaml
# Expected: File exists
```

### Test File Already Exists

```bash
# Run init again (file exists)
/path/to/subtree/.build/debug/subtree init

# Expected output (stderr):
# ❌ subtree.yaml already exists
# Use --force to overwrite

# Check exit code
echo $?
# Expected: 1
```

### Test Force Overwrite

```bash
# Run with --force flag
/path/to/subtree/.build/debug/subtree init --force

# Expected output:
# ✅ Created subtree.yaml

# Check exit code
echo $?
# Expected: 0
```

### Test Not in Git Repository

```bash
# Go outside git repository
cd /tmp
mkdir not-a-repo
cd not-a-repo

# Run init
/path/to/subtree/.build/debug/subtree init

# Expected output (stderr):
# ❌ Must be run inside a git repository

# Check exit code
echo $?
# Expected: 1
```

---

## Validation Commands

### Verify Git Detection

```bash
# In test repo
cd /tmp/test-subtree-init

# Check git command works
git rev-parse --show-toplevel
# Expected: /tmp/test-subtree-init

# Verify init uses this path
/path/to/subtree/.build/debug/subtree init --force
cat subtree.yaml
# Expected: File created at repository root
```

### Verify YAML Structure

```bash
# Parse YAML to verify structure
python3 -c "import yaml; print(yaml.safe_load(open('subtree.yaml')))"
# Expected: {'subtrees': []}

# Or use yq if available
yq eval subtree.yaml
# Expected: subtrees: []
```

### Verify Emoji Output

```bash
# Capture stderr for error cases
/path/to/subtree/.build/debug/subtree init 2>&1 | head -1
# Expected: ❌ subtree.yaml already exists

# Capture stdout for success
/path/to/subtree/.build/debug/subtree init --force 2>&1 | head -1
# Expected: ✅ Created subtree.yaml
```

### Verify Atomic Operations

```bash
# Attempt concurrent execution (requires bash)
/path/to/subtree/.build/debug/subtree init --force &
/path/to/subtree/.build/debug/subtree init --force &
wait

# Verify file is valid (not corrupted)
cat subtree.yaml
# Expected: Valid YAML with header and empty array

# Verify no temp files left behind
ls subtree.yaml.tmp.* 2>/dev/null
# Expected: No such file (cleanup succeeded)
```

### Verify Symlink Handling

```bash
# Create symlink to repo
cd /tmp
ln -s test-subtree-init test-subtree-symlink
cd test-subtree-symlink

# Run init
/path/to/subtree/.build/debug/subtree init --force

# Verify file created at canonical location
ls -la /tmp/test-subtree-init/subtree.yaml
# Expected: File exists at real location, not symlinked path
```

---

## CI Validation

### Local CI (using act)

```bash
# Run local CI workflow
cd /path/to/subtree
act workflow_dispatch -W .github/workflows/ci-local.yml

# Expected: All tests pass in container
```

### GitHub Actions

```bash
# Push branch to GitHub
git push origin 003-init-command

# Check CI status
# Navigate to: https://github.com/21-DOT-DEV/subtree/actions

# Expected: Green checkmark on macOS-15 and Ubuntu 20.04 jobs
```

---

## Verification Checklist

Run this checklist before marking implementation complete:

### Build & Test
- [ ] `swift build` succeeds with no warnings
- [ ] `swift test` passes all tests (0 failures)
- [ ] Unit tests cover all `GitOperations` functions
- [ ] Unit tests cover all `ConfigFileManager` functions
- [ ] Integration tests cover all CLI scenarios from spec

### Functionality
- [ ] Init creates file at repository root (tested from root)
- [ ] Init creates file at repository root (tested from subdirectory)
- [ ] Init fails when file exists (no --force)
- [ ] Init succeeds with --force flag
- [ ] Init fails outside git repository
- [ ] Success message shows correct relative path
- [ ] Error messages include emoji prefixes

### Edge Cases
- [ ] Symlink resolution works correctly
- [ ] Concurrent execution doesn't corrupt file
- [ ] Detached HEAD state handled
- [ ] Permission denied error is clear
- [ ] Temp files cleaned up on error

### Quality Gates
- [ ] CI passes on macOS-15
- [ ] CI passes on Ubuntu 20.04
- [ ] No linting errors
- [ ] Code follows Swift conventions
- [ ] Test coverage is comprehensive

### Documentation
- [ ] `.windsurf/rules` updated with init command patterns
- [ ] AGENTS.md updated if phase/status changed
- [ ] README.md updated with init command mention (if applicable)

---

## Troubleshooting

### Build Fails

**Problem**: `swift build` fails with errors

**Solution**:
```bash
# Clean build artifacts
rm -rf .build

# Try clean build
swift build

# Check Swift version
swift --version
# Expected: Swift version 6.1.x
```

### Tests Fail

**Problem**: Tests fail unexpectedly

**Solution**:
```bash
# Run specific failing test with verbose output
swift test --filter <TestName> --verbose

# Check test isolation (temp directories)
# GitRepositoryFixture should use UUID-based paths
```

### Git Detection Fails

**Problem**: Cannot find git repository

**Solution**:
```bash
# Verify git is in PATH
which git
# Expected: /usr/bin/git or similar

# Test git command manually
git rev-parse --show-toplevel
# Expected: Repository root path

# Check swift-subprocess execution
# Ensure PATH includes /usr/bin when running subprocess
```

### YAML Generation Fails

**Problem**: Generated YAML is invalid

**Solution**:
```bash
# Verify Yams dependency
swift package show-dependencies | grep Yams
# Expected: Yams 6.1.0

# Test YAML encoding in isolation
# Check ConfigFileManager unit tests
```

### Emoji Not Displaying

**Problem**: Emojis show as boxes or question marks

**Solution**:
- Verify terminal supports UTF-8
- Check locale: `echo $LANG` (should be *.UTF-8)
- Test in different terminal (iTerm2, Terminal.app)
- CI output may not show emojis perfectly (expected)

---

## Next Steps

After all verification passes:

1. **Commit changes**:
   ```bash
   git add .
   git commit -m "Implement init command (spec 003)"
   ```

2. **Push to GitHub**:
   ```bash
   git push origin 003-init-command
   ```

3. **Create PR**:
   - Verify CI passes on GitHub
   - Review changes
   - Merge when green

4. **Update agent rules**:
   - Run `.specify/scripts/bash/update-agent-context.sh windsurf`
   - Verify `.windsurf/rules/` updated
   - Commit rules update

5. **Mark spec complete**:
   - Update spec.md status from "Draft" to "Implemented"
   - Document any learnings in spec notes

---

## Performance Benchmarks

### Expected Performance

- **Build time**: <30 seconds (clean build)
- **Test time**: <10 seconds (all tests)
- **Init execution**: <200ms (typical repository)

### Measure Performance

```bash
# Time build
time swift build

# Time tests
time swift test

# Time init execution
time /path/to/subtree/.build/debug/subtree init --force
```

**Expected**: All operations complete well within success criteria (<1 second for init)

---

## Help Output

```bash
# Verify help works
/path/to/subtree/.build/debug/subtree init --help

# Expected output:
# OVERVIEW: Initialize a subtree configuration file
# 
# USAGE: subtree init [--force]
# 
# OPTIONS:
#   --force     Overwrite existing subtree.yaml
#   -h, --help  Show help information.
```

---

## Cleanup

```bash
# Remove test repository
rm -rf /tmp/test-subtree-init
rm -rf /tmp/test-subtree-symlink

# Remove any temp files
find /tmp -name "subtree.yaml.tmp.*" -delete
```
