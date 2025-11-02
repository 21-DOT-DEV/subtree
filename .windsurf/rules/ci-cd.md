---
trigger: always_on
---

# Subtree CLI - CI/CD & Validation

Last Updated: 2025-10-26 | Phase: 10 (Complete) | Context: Production CI pipeline

## CI/CD Pipeline

**Platform**: GitHub Actions with local testing via nektos/act

### Workflow: ci.yml

**Purpose**: Production CI for all pushes and pull requests

**Platform Matrix**:
- macOS-15 (Xcode 16.4 = Swift 6.1)
- Ubuntu 20.04 LTS (Swift 6.1)

**Swift Setup Strategy**:
- **macOS**: Native Xcode via `DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer`
  - No download/setup needed
  - Faster execution
  - Pre-installed on GitHub runners
- **Ubuntu**: `swift-actions/setup-swift@v2`
  - Downloads Swift 6.1
  - Required (no Swift on Ubuntu runners)

**Steps**:
1. Checkout code (`actions/checkout@v4`)
2. Setup Swift (Ubuntu only, conditional)
3. Verify Swift version
4. Build (`swift build`)
5. Run tests (`swift test` with 10-minute timeout)

**Triggers**:
- Push to `main` or `001-cli-bootstrap` branches
- Pull requests to `main`

### Workflow: ci-local.yml

**Purpose**: Local CI testing with nektos/act

**Platform**: Ubuntu only (Docker container)

**Container**: `swift:6.1` (Swift pre-installed)

**Usage**:
```bash
# Run local CI validation
act workflow_dispatch -W .github/workflows/ci-local.yml
```

**When to Use**:
- Before committing changes
- Testing workflow modifications
- Verifying test coverage

**Limitations**:
- Linux only (act can't run macOS containers)
- Uses Docker (requires Docker running)
- First run downloads ~1.5GB image

## CI Complete Validation Checkpoint

Run these checks to verify CI matches implementation:

### 1. Verify Workflow Configuration

```bash
# Check ci.yml has correct platform matrix
grep "macos-15" .github/workflows/ci.yml
grep "ubuntu-20.04" .github/workflows/ci.yml

# Verify DEVELOPER_DIR for macOS
grep "DEVELOPER_DIR" .github/workflows/ci.yml

# Check conditional setup-swift for Ubuntu
grep "if: matrix.os == 'ubuntu-20.04'" .github/workflows/ci.yml
```

### 2. Verify Local CI Works

```bash
# Test with act (should pass)
act workflow_dispatch -W .github/workflows/ci-local.yml

# All 25 tests should pass in container
```

### 3. Verify Test Coverage

```bash
# Check all test suites run
swift test 2>&1 | grep "Suite"

# Should show:
# - Command Tests (2 tests)
# - Exit Code Tests (7 tests)  
# - Subtree Integration Tests (9 tests)
# - Git Fixture Tests (7 tests)
# Total: 25 tests
```

### 4. Verify CI Badge

Check README.md contains CI badge linking to workflow.

**Expected**: All checks pass, CI pipeline matches documentation

---

**Lines**: ~100 (well under 200-line limit)

