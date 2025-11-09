# Quickstart: Remove Command Validation

**Feature**: Remove Command | **Phase**: 1 (Design) | **Date**: 2025-10-28

## Overview

Quick commands to validate the Remove Command implementation against the specification. Use these during development to verify behavior and after implementation to confirm all requirements are met.

---

## Prerequisites

```bash
# Ensure you're on the feature branch
git branch --show-current
# Should print: 006-remove-command

# Build the project
swift build

# Verify tests compile
swift test --list-tests
```

---

## Quick Validation Scenarios

### 1. Clean Removal (Happy Path)

**Setup**:
```bash
# Create test repository
cd /tmp
mkdir test-remove && cd test-remove
git init
git config user.name "Test User"
git config user.email "test@example.com"

# Initialize subtree config
swift run subtree init

# Add a test subtree (requires network)
swift run subtree add --remote https://github.com/apple/swift-argument-parser.git --name test-lib

# Verify subtree exists
ls -la test-lib/
cat subtree.yaml
```

**Test Removal**:
```bash
# Remove the subtree
swift run subtree remove test-lib

# Verify exit code
echo $?  # Should print: 0

# Verify directory gone
ls test-lib/ 2>&1  # Should error: "No such file or directory"

# Verify config updated
grep -q "test-lib" subtree.yaml
echo $?  # Should print: 1 (not found in config)

# Verify single commit
git log -1 --oneline
# Should show: "Remove subtree test-lib (was at <hash>)"

# Verify commit contains both changes
git show HEAD --name-status
# Should show:
#   D   test-lib/...  (deleted files)
#   M   subtree.yaml  (modified config)
```

**Cleanup**:
```bash
cd /tmp && rm -rf test-remove
```

---

### 2. Idempotent Removal

**Setup**:
```bash
# Create test repository with subtree (same as above)
cd /tmp
mkdir test-idempotent && cd test-idempotent
git init
git config user.name "Test User"
git config user.email "test@example.com"
swift run subtree init
swift run subtree add --remote https://github.com/apple/swift-argument-parser.git --name test-lib
```

**Test Idempotent Behavior**:
```bash
# Manually delete the directory
rm -rf test-lib/

# Verify directory gone
ls test-lib/ 2>&1  # Should error

# Remove via command (should still succeed)
swift run subtree remove test-lib

# Verify exit code
echo $?  # Should print: 0

# Verify output message
swift run subtree remove test-lib 2>&1 | grep "already removed"
# Should show: "✅ Removed subtree 'test-lib' (directory already removed, config cleaned up)"

# Verify config updated
grep -q "test-lib" subtree.yaml
echo $?  # Should print: 1
```

**Cleanup**:
```bash
cd /tmp && rm -rf test-idempotent
```

---

### 3. Error: Config Missing

**Setup**:
```bash
cd /tmp
mkdir test-no-config && cd test-no-config
git init
git config user.name "Test User"
git config user.email "test@example.com"
# No subtree init - config missing
```

**Test Error**:
```bash
# Try to remove (should fail)
swift run subtree remove mylib 2>&1

# Verify exit code
echo $?  # Should print: 3

# Verify error message
swift run subtree remove mylib 2>&1 | grep "not found"
# Should show: "❌ Configuration file not found. Run 'subtree init' first"
```

**Cleanup**:
```bash
cd /tmp && rm -rf test-no-config
```

---

### 4. Error: Name Not Found

**Setup**:
```bash
cd /tmp
mkdir test-not-found && cd test-not-found
git init
git config user.name "Test User"
git config user.email "test@example.com"
swift run subtree init
```

**Test Error**:
```bash
# Try to remove non-existent subtree
swift run subtree remove nonexistent 2>&1

# Verify exit code
echo $?  # Should print: 2

# Verify error message
swift run subtree remove nonexistent 2>&1 | grep "not found"
# Should show: "❌ Subtree 'nonexistent' not found in configuration"
```

**Cleanup**:
```bash
cd /tmp && rm -rf test-not-found
```

---

### 5. Error: Dirty Working Tree

**Setup**:
```bash
cd /tmp
mkdir test-dirty && cd test-dirty
git init
git config user.name "Test User"
git config user.email "test@example.com"
swift run subtree init
swift run subtree add --remote https://github.com/apple/swift-argument-parser.git --name test-lib

# Create uncommitted change
echo "test" > README.md
git add README.md
# Don't commit - leave staged
```

**Test Error**:
```bash
# Try to remove with dirty tree
swift run subtree remove test-lib 2>&1

# Verify exit code
echo $?  # Should print: 1

# Verify error message
swift run subtree remove test-lib 2>&1 | grep "uncommitted"
# Should show: "❌ Working tree has uncommitted changes. Commit or stash before removing"
```

**Cleanup**:
```bash
cd /tmp && rm -rf test-dirty
```

---

### 6. Error: Malformed Config

**Setup**:
```bash
cd /tmp
mkdir test-malformed && cd test-malformed
git init
git config user.name "Test User"
git config user.email "test@example.com"
swift run subtree init

# Corrupt the config file
echo "invalid: yaml: syntax: {{{" >> subtree.yaml
```

**Test Error**:
```bash
# Try to remove (should fail with parse error)
swift run subtree remove anyname 2>&1

# Verify exit code
echo $?  # Should print: 3

# Verify error message contains "malformed"
swift run subtree remove anyname 2>&1 | grep "malformed"
# Should show: "❌ Configuration file is malformed: <parse error details>"
```

**Cleanup**:
```bash
cd /tmp && rm -rf test-malformed
```

---

## Test Suite Validation

### Run All Tests

```bash
# Run full test suite
swift test

# Verify all tests pass
echo $?  # Should print: 0
```

### Run Specific Test Suites

```bash
# Unit tests only
swift test --filter SubtreeLibTests

# Integration tests only  
swift test --filter IntegrationTests

# Remove command tests specifically
swift test --filter RemoveCommandTests
swift test --filter RemoveIntegrationTests
```

### Test Coverage Check

```bash
# Run tests with coverage (if available)
swift test --enable-code-coverage

# Expected coverage for Remove Command:
# - RemoveCommand.swift: >90% line coverage
# - Error paths: 100% coverage
# - Success paths: 100% coverage
```

---

## CI Validation

### Local CI Simulation (with act)

```bash
# Run local CI workflow
act workflow_dispatch -W .github/workflows/ci-local.yml

# Should show:
# - Build success
# - All tests passing
# - Exit code 0
```

### GitHub Actions Check

```bash
# Push branch to trigger CI
git push origin 006-remove-command

# Check CI status
open https://github.com/<your-org>/subtree/actions

# Verify:
# - macOS-15 build passes
# - Ubuntu 20.04 build passes
# - All tests pass on both platforms
```

---

## Manual Verification Checklist

### Functional Requirements

- [ ] **FR-001**: Command accepts subtree name as positional argument
- [ ] **FR-002**: No `--all` flag support (should error if attempted)
- [ ] **FR-003**: Validates inside git repository
- [ ] **FR-004**: Validates config file exists
- [ ] **FR-005**: Validates config is parseable YAML
- [ ] **FR-006**: Validates subtree name exists in config
- [ ] **FR-007**: Validates working tree is clean
- [ ] **FR-008**: All validations before modifications
- [ ] **FR-009**: Removes directory using `git rm -r`
- [ ] **FR-010**: Removes config entry from subtree.yaml
- [ ] **FR-011**: Config update uses atomic file operations
- [ ] **FR-012**: Succeeds when directory missing (idempotent)
- [ ] **FR-013**: Shows idempotent message when directory gone
- [ ] **FR-014**: Exit code 0 on success (both variants)
- [ ] **FR-015**: Creates single atomic commit
- [ ] **FR-016**: Commit message format correct
- [ ] **FR-017**: Commit body includes all metadata
- [ ] **FR-018**: Short hash is 8 characters
- [ ] **FR-019**: Commit failure recovery instructions shown
- [ ] **FR-020**: Emoji-prefixed messages
- [ ] **FR-021**: Exit code 3 when config missing
- [ ] **FR-022**: Exit code 3 when config malformed
- [ ] **FR-023**: Exit code 2 when name not found
- [ ] **FR-024**: Exit code 1 when dirty working tree
- [ ] **FR-025**: Exit code 1 when not in git repo
- [ ] **FR-026**: Exit code 1 when commit fails
- [ ] **FR-027**: Error messages are actionable
- [ ] **FR-028**: Success message shows name and hash
- [ ] **FR-029**: Normal success message format correct
- [ ] **FR-030**: Idempotent success message format correct

### Success Criteria

- [ ] **SC-001**: Removal completes <5 seconds for <10,000 files
- [ ] **SC-002**: 100% of operations produce single commit
- [ ] **SC-003**: Single command removes without manual editing
- [ ] **SC-004**: Idempotent (second run shows "not found")
- [ ] **SC-005**: Idempotent removal <1 second
- [ ] **SC-006**: Validation failures before modifications
- [ ] **SC-007**: Error messages reduce support questions
- [ ] **SC-008**: Works on macOS 13+ and Ubuntu 20.04 LTS
- [ ] **SC-009**: Commit message preserves recovery info
- [ ] **SC-010**: 90% success without documentation

---

## Performance Benchmarking

### Small Subtree (<100 files)

```bash
# Time normal removal
time swift run subtree remove small-lib
# Target: <1 second

# Time idempotent removal
rm -rf small-lib/
time swift run subtree remove small-lib
# Target: <500ms
```

### Medium Subtree (~1,000 files)

```bash
time swift run subtree remove medium-lib
# Target: <2 seconds
```

### Large Subtree (~10,000 files)

```bash
time swift run subtree remove large-lib
# Target: <5 seconds
```

---

## Debugging Commands

### Inspect Commit Details

```bash
# Show last commit
git show HEAD

# Show commit message only
git log -1 --pretty=format:"%s%n%b"

# Show files changed
git show HEAD --name-status

# Show commit tree
git log --oneline --graph -5
```

### Inspect Configuration

```bash
# Show current config
cat subtree.yaml

# Pretty-print YAML
cat subtree.yaml | yq .

# Check specific entry
cat subtree.yaml | yq '.subtrees[] | select(.name == "test-lib")'
```

### Inspect Git State

```bash
# Check if in git repo
git rev-parse --git-dir

# Check working tree status
git status --porcelain

# Check staged changes
git diff --cached --name-status
```

---

## Common Issues & Solutions

### Issue: Tests Fail with "Command Not Found"

**Solution**: Rebuild the project
```bash
swift build
```

### Issue: Integration Tests Fail with Network Errors

**Solution**: Use local test fixtures instead of remote URLs, or check network connectivity

### Issue: Permission Denied on git rm

**Solution**: Check file permissions in test repository
```bash
chmod -R u+w test-lib/
```

### Issue: Config Parse Errors in Tests

**Solution**: Verify test fixture YAML syntax
```bash
cat subtree.yaml | yq .
```

---

## Next Steps After Validation

1. ✅ All quickstart scenarios pass
2. ✅ All tests pass (`swift test`)
3. ✅ CI passes on both platforms
4. ✅ Manual checklist complete
5. ✅ Performance targets met

**Ready for**: Code review, merge to main, agent rules update (architecture.md)
