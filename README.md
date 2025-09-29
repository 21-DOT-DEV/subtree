# 🌳 Subtree CLI

Simplify git subtree management through declarative configuration with safe file extraction and validation capabilities.

[![CI Status](https://github.com/21-DOT-DEV/subtree/actions/workflows/ci.yml/badge.svg)](https://github.com/21-DOT-DEV/subtree/actions/workflows/ci.yml)
[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Objectives

- **Declarative Configuration** - Manage subtrees through a simple `subtree.yaml` file instead of remembering complex git commands
- **Atomic Operations** - All subtree changes include configuration updates in single commits for perfect consistency
- **Safe File Management** - Extract files from subtrees with smart overwrite protection and validation
- **Developer Experience** - Intuitive CLI with clear error messages, dry-run modes, and helpful guidance

> [!NOTE]  
> Subtree CLI wraps `git subtree` with enhanced safety and convenience - your existing git history remains unchanged.

## Table of Contents

- [Objectives](#objectives)
- [Installation](#installation)
- [Usage Examples](#usage-examples)
- [API Reference](#api-reference)
- [Platform Compatibility](#platform-compatibility)
- [Contributing](#contributing)
- [License](#license)

## Installation

### Requirements

> [!IMPORTANT]  
> You must be inside a Git repository to use Subtree CLI. The tool will not initialize repositories for you.

- **Swift 6.0+** toolchain
- **macOS 13+** or **Linux (glibc 2.27+)** 
- **Git** installed and available on PATH


### Swift Package Manager

Add the following to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/21-DOT-DEV/subtree.git", from: "1.0.0")
]
```

### GitHub Releases

Download pre-built binaries from [GitHub Releases](https://github.com/21-DOT-DEV/subtree/releases):

1. Download the appropriate binary for your platform:
   - `subtree_1.0.0_macOS_arm64` (Apple Silicon)
   - `subtree_1.0.0_macOS_x86_64` (Intel Mac)
   - `subtree_1.0.0_linux_x86_64` (Linux)
   - `subtree_1.0.0_linux_arm64` (Linux ARM)

2. Make executable and add to PATH:
   ```bash
   chmod +x subtree_1.0.0_macOS_arm64
   mv subtree_1.0.0_macOS_arm64 /usr/local/bin/subtree
   ```

### Swift Artifact Bundle

Use the artifact bundle for Swift Package Manager integration:

```swift
dependencies: [
    .binaryTarget(
        name: "subtree",
        url: "https://github.com/21-DOT-DEV/subtree/releases/download/1.0.0/subtree.artifactbundle.zip",
        checksum: "..."
    )
]
```

### Build from Source

```bash
git clone https://github.com/21-DOT-DEV/subtree.git
cd subtree
swift build -c release
./.build/release/subtree --help
```

## Usage Examples

### 🚀 Quick Start

Create your first `subtree.yaml` configuration:

```bash
# Create minimal config in your git repository
subtree init

# 🎯 Interactive setup with step-by-step guidance (TTY only)
subtree init --interactive
```

> [!TIP]  
> Start with `--interactive` mode to get familiar with the configuration format!

### 📦 Add Subtrees

Add configured subtrees to your repository:

```bash
# Add a single subtree by name
subtree add --name example-lib

# Add with explicit overrides
subtree add --name libfoo \
  --remote https://github.com/example/libfoo.git \
  --prefix Vendor/libfoo \
  --ref main \
  --no-squash

# Add all configured subtrees
subtree add --all
```

### 🔄 Update Subtrees

Manage subtree updates with various strategies:

```bash
# Report pending updates (no changes, exit 5 if updates available)
subtree update

# Apply updates (one commit per subtree on topic branch)
subtree update --commit

# Single commit with all updates on current branch
subtree update --commit --single-commit --on-current

# Dry run to preview changes
subtree update --dry-run
```

### 🗑️ Remove Subtrees

```bash
# Remove a configured subtree
subtree remove --name example-lib
```

### 📂 Extract Files

Copy files from subtrees to your repository:

> [!WARNING]  
> Extract operations respect Git's tracking status - tracked files are protected unless you use `--force`.

```bash
# Ad-hoc file extraction
subtree extract --name example-lib --from docs/README.md --to Docs/ExampleLib.md

# Extract with glob patterns
subtree extract --name example-lib --from templates/** --to Templates/ExampleLib/

# Apply declared mappings from config
subtree extract --name example-lib --all

# Extract all subtrees matching pattern
subtree extract --all --match "**/*.md"
```

### ✅ Validate Subtree State

Verify subtree integrity and synchronization:

```bash
# Offline validation against commit hash
subtree validate

# Validate specific subtree with pattern
subtree validate --name example-lib --from "**/*.md"

# Repair discrepancies
subtree validate --repair

# Include remote divergence check
subtree validate --with-remote
```

## API Reference

### Commands

- **`init`** - Initialize `subtree.yaml` configuration
  - `--import` - Scan for existing git subtrees
  - `--interactive` - Guided setup (TTY only)
  - `--force` - Overwrite existing configuration

- **`add`** - Add configured subtrees 
  - `--name <name>` - Add specific subtree
  - `--all` - Add all configured subtrees
  - Override flags: `--remote`, `--prefix`, `--ref`, `--no-squash`

- **`update`** - Update subtrees with various strategies
  - `--name <name>` - Update specific subtree  
  - `--all` - Update all subtrees
  - `--commit` - Apply updates (default: report only)
  - `--mode <branch|tag|release>` - Update strategy
  - `--branch <name>` - Custom topic branch name
  - `--single-commit` - Squash all updates into one commit
  - `--on-current` - Apply updates to current branch
  - `--dry-run` - Preview changes without applying
  - `--force` - Override safety checks

- **`remove`** - Remove configured subtrees
  - `--name <name>` - Remove specific subtree

- **`extract`** - Copy files from subtrees
  - `--name <name>` - Extract from specific subtree
  - `--from <path>` - Source path/glob pattern
  - `--to <path>` - Destination path
  - `--all` - Apply declared copy mappings
  - `--match <pattern>` - Filter by glob pattern
  - `--dry-run` - Preview without copying
  - `--no-overwrite` - Skip existing files
  - `--force` - Overwrite protected files

- **`validate`** - Verify subtree integrity
  - `--name <name>` - Validate specific subtree
  - `--from <pattern>` - Validate specific files
  - `--repair` - Fix discrepancies
  - `--with-remote` - Include remote comparison

### Exit Codes

- **0** - Success
- **1** - General error
- **2** - Invalid usage or configuration  
- **3** - Git operation failure or not in Git repository
- **4** - Configuration file not found
- **5** - Updates available (report mode only)

### Configuration Format

`subtree.yaml` schema:

```yaml
subtrees:
  - name: example-lib                    # Unique identifier
    remote: https://github.com/example/lib.git
    prefix: Sources/ThirdParty/ExampleLib
    branch: main
    squash: true                         # Default: true
    commit: 0123456789abcdef...           # Latest known commit
    copies:                              # File extraction mappings  
      - from: docs/README.md
        to: Docs/ExampleLib.md
      - from: templates/**
        to: Templates/ExampleLib/
```

## Platform Compatibility

| Platform | Architecture | Minimum Version | Status |
|----------|-------------|-----------------|---------|
| macOS | arm64, x86_64 | 13.0+ | ✅ Supported |
| Linux | x86_64, arm64 | glibc 2.27+ | ✅ Supported |
| Windows | x86_64, arm64 | Windows 10+ | Future |

**Dependencies:**
- Swift 6.0+ toolchain
- Git (any recent version)
- ArgumentParser 1.6.1
- Yams 6.1.0  
- swift-subprocess 0.1.0+
- SemanticVersion 0.5.1

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Quick Start for Contributors

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Run tests: `swift test`
4. Make your changes following our coding standards
5. Add tests for new functionality
6. Submit a pull request

### Development Setup

```bash
git clone https://github.com/21-DOT-DEV/subtree.git
cd subtree
swift build
swift test
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
