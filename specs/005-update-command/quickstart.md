# Quickstart: Update Command

**Feature**: 005-update-command | **Date**: 2025-10-28  
**Purpose**: Quick validation and testing guide for developers

## Prerequisites

Before implementing or testing this feature:

```bash
# 1. Verify you're on the feature branch
git branch --show-current  # Should show: 005-update-command

# 2. Build the project
swift build

# 3. Run existing tests (should all pass)
swift test

# 4. Verify test infrastructure
ls -la Tests/IntegrationTests/GitRepositoryFixture.swift  # Should exist
ls -la Tests/IntegrationTests/TestHarness.swift  # Should exist
```

**Expected**: All 150 existing tests pass before starting implementation.

---

## Development Workflow (TDD)

### Phase 1: Write Failing Tests

Following TDD discipline from Constitution Principle II:

```bash
# 1. Create test file
touch Tests/IntegrationTests/UpdateCommandIntegrationTests.swift

# 2. Write tests for User Story 1 (P1: Selective Update)
# See spec.md acceptance scenarios 1-3

# 3. Run tests - VERIFY THEY FAIL
swift test --filter UpdateCommandIntegrationTests

# Expected: Tests fail with "not yet implemented" or similar
```

**Critical**: Tests MUST fail before implementation. If they pass, the tests aren't validating the requirement.

---

### Phase 2: Implement to Pass Tests

```bash
# 1. Create UpdateCommand.swift
touch Sources/SubtreeLib/Commands/UpdateCommand.swift

# 2. Implement minimal code to pass first test
# (Focus on one acceptance scenario at a time)

# 3. Run tests - VERIFY THEY PASS
swift test --filter UpdateCommandIntegrationTests

# 4. Repeat for each acceptance scenario
```

---

### Phase 3: Refactor While Green

```bash
# With all tests passing, refactor for:
# - Code reuse (leverage Add Command's atomic pattern)
# - Error handling clarity
# - Performance optimizations

# After each refactor:
swift test  # Must stay green
```

---

## Quick Manual Testing

### Test 1: Single Subtree Update

```bash
# Setup
cd /tmp
git init test-repo
cd test-repo
git commit --allow-empty -m "Initial"

# Initialize subtree config
subtree init

# Add a subtree
subtree add --remote https://github.com/apple/swift-argument-parser.git \
            --name argparse \
            --prefix Vendor/argparse \
            --ref main

# Wait or manually update upstream...
# Then update
subtree update argparse

# Verify
git log -1 --stat  # Should show Vendor/argparse/ + subtree.yaml
cat subtree.yaml   # Should show updated commit hash
```

**Expected**: Single commit with both subtree content and config update.

---

### Test 2: Report Mode (No Changes)

```bash
# Using repo from Test 1

# Check for updates
subtree update argparse --report

# Verify no changes
git status  # Should be clean
git log -1 --format=%H  # Should match pre-report hash

# Check exit code
echo $?  # 0 if up-to-date, 5 if updates available
```

**Expected**: Zero repository modifications, correct exit code.

---

### Test 3: Batch Update

```bash
# Add multiple subtrees
subtree add --remote https://github.com/jpsim/Yams.git \
            --name yams \
            --prefix Vendor/yams \
            --ref main

subtree add --remote https://github.com/apple/swift-system.git \
            --name swift-system \
            --prefix Vendor/system \
            --ref main

# Update all
subtree update --all

# Verify
git log -3 --oneline  # Should show 3 separate commits (one per subtree)
```

**Expected**: One atomic commit per updated subtree.

---

## Validation Checklist

After implementation, verify against spec requirements:

### Functional Requirements (FR-001 to FR-018)

```bash
# FR-001: Single update
subtree update <name>  # ✅ Works

# FR-002: Batch update
subtree update --all  # ✅ Works

# FR-003: Squash default
git log -1 --stat  # ✅ Single squashed commit

# FR-004: Uses configured ref
# ✅ Fetches from ref in subtree.yaml

# FR-005: Updates config
cat subtree.yaml  # ✅ Shows new commit hash

# FR-006: Report mode
subtree update --report  # ✅ Read-only check

# FR-007: Report format
subtree update --report  # ✅ Shows "X commits behind (Y days old)"

# FR-008: Report exit codes
subtree update --report && echo "up-to-date" || echo "exit: $?"
# ✅ Exit 0 or 5

# FR-009: Up-to-date handling
subtree update <name>  # ✅ "Already up to date" message

# FR-010: Current branch only
git branch  # ✅ Still on same branch

# FR-011: Config validation
rm subtree.yaml && subtree update <name>
# ✅ Error: "Configuration file not found"

# FR-012: Name validation
subtree update nonexistent
# ✅ Error: "Subtree 'nonexistent' not found"

# FR-013: Clean tree check
echo "test" >> README.md && subtree update <name>
# ✅ Error: "Working tree has uncommitted changes"

# FR-014: Network errors
subtree update <name> --remote https://invalid.url
# ✅ Clear error message

# FR-015: Git failures
# ✅ Surfaces git stderr

# FR-016: Batch continues on error
# ✅ Processes all subtrees, exit 1 if any fail

# FR-017: Tag-aware messages
git log -1  # ✅ Check format matches spec

# FR-018: Report performance
time subtree update --all --report  # ✅ <5 seconds
```

---

### Success Criteria (SC-001 to SC-007)

```bash
# SC-001: Report speed
time subtree update --all --report
# ✅ <5 seconds for 20 subtrees

# SC-002: Report clarity
subtree update --report
# ✅ Output clearly shows update availability

# SC-003: Config tracking
cat subtree.yaml && git log -1 --stat
# ✅ Commit hashes match

# SC-004: Exit code 5
subtree update --report || echo $?
# ✅ Exit 5 when updates available

# SC-005: First-attempt success
subtree update <name>
# ✅ Works without debugging

# SC-006: Batch summary
subtree update --all
# ✅ Shows "X updated, Y skipped, Z failed"

# SC-007: Actionable errors
# ✅ All error messages tell user what to do
```

---

## Performance Validation

### Report Mode Benchmark

```bash
# Create repo with 20 subtrees
for i in {1..20}; do
  subtree add --remote https://example.com/repo$i.git \
              --name lib$i \
              --prefix Vendor/lib$i
done

# Benchmark report mode
time subtree update --all --report
# Target: <5 seconds
```

---

### Update Mode Benchmark

```bash
# Single subtree update
time subtree update lib1
# Target: <10 seconds for typical update
```

---

## Regression Testing

Before merging, ensure existing functionality still works:

```bash
# Run ALL tests (not just new ones)
swift test

# Test init command
subtree init  # Should still work

# Test add command
subtree add --remote <url> --name <name> --prefix <path>
# Should still create atomic commit

# Verify CI
git push origin 005-update-command
# CI should run and pass on macOS + Ubuntu
```

---

## Common Issues & Solutions

### Issue: Tests fail with "command not found"

**Solution**: Build first, then test
```bash
swift build
swift test
```

---

### Issue: GitRepositoryFixture creates conflicts

**Solution**: Use unique directory names
```bash
let fixture = try await GitRepositoryFixture(name: "update-test-\(UUID())")
```

---

### Issue: Integration tests timeout

**Solution**: Check network connectivity, or mock git operations
```bash
# Increase timeout in test
try await test.run(timeout: .seconds(60))
```

---

### Issue: Atomic commit not working

**Solution**: Verify amend pattern from Add Command
```swift
// 1. Git subtree creates commit
try await gitSubtreePull(...)

// 2. Update config
try configManager.updateEntry(...)

// 3. Amend to include config
try await git.commitAmend(...)
```

---

## CI Validation

### Local CI Test (macOS)

```bash
# Simulate CI locally
swift build --configuration release
swift test --parallel

# Check coverage
swift test --enable-code-coverage
xcrun llvm-cov report .build/debug/SubtreePackageTests.xctest/Contents/MacOS/SubtreePackageTests
```

---

### Local CI Test (Ubuntu via Docker)

```bash
# Use act to test GitHub Actions locally
act workflow_dispatch -W .github/workflows/ci-local.yml

# Or use Docker directly
docker run --rm -v $(pwd):/workspace -w /workspace swift:6.1 \
  bash -c "swift test"
```

---

## Definition of Done

Before marking this feature complete, verify:

- [ ] All 5 user stories have passing tests
- [ ] All 18 functional requirements validated
- [ ] All 7 success criteria met
- [ ] CI passes on macOS-15 and Ubuntu 20.04
- [ ] Code reviewed against Add Command patterns
- [ ] `.windsurf/rules/` updated with new command
- [ ] Manual testing completed (all scenarios in this guide)
- [ ] No regressions (all 150+ existing tests pass)

---

## Next Steps After Implementation

```bash
# 1. Update agent rules
# See .windsurf/rules/bootstrap.md for instructions

# 2. Run /speckit.tasks to generate task breakdown
# (if not already done)

# 3. Commit implementation
git add -A
git commit -m "feat: implement Update Command (005)"

# 4. Push and verify CI
git push origin 005-update-command

# 5. Create PR after CI passes
```

---

## Reference Commands

Quick copy-paste commands for development:

```bash
# Build
swift build

# Test everything
swift test

# Test only update command
swift test --filter UpdateCommandIntegrationTests

# Test with output
swift test --filter UpdateCommandIntegrationTests 2>&1 | tee test-output.log

# Run CLI directly
.build/debug/subtree update --help
.build/debug/subtree update <name>
.build/debug/subtree update --all --report

# Check exit codes
.build/debug/subtree update <name>; echo "Exit: $?"

# Clean build
swift package clean
swift build

# CI simulation
act workflow_dispatch -W .github/workflows/ci-local.yml
```

---

**Ready to implement!** Follow TDD discipline and reference this guide for quick validation.
