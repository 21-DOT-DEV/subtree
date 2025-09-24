# Quickstart: Subtree CLI

## Prerequisites
- Git installed and available on PATH
- Swift toolchain (SPM) for building from source

## Build from Source
```bash
# from repository root
nocorrect swift build -c release
# run
./.build/release/subtree --help
```

## Initialize Configuration
```bash
# from your Git repository
subtree init
# creates repository-root subtree.yaml

# guided setup (TTY only): discover/import subtrees and configure interactively
subtree init --interactive

# import existing git subtree usage (non-interactive)
subtree init --import
```

## Add a Subtree
```bash
# add a single entry by name from subtree.yaml
subtree add --name example-lib

# add with explicit overrides (mimics git subtree add)
subtree add --name libfoo \
  --remote https://github.com/example/libfoo.git \
  --prefix Vendor/libfoo \
  --ref main \
  --no-squash

# or operate on all configured entries
subtree add --all
```

## Update Subtrees
```bash
# Report pending updates (no changes) — exit 5 if updates available
subtree update

# Apply updates (one commit per updated subtree on a topic branch)
subtree update --commit

# Update a single subtree on a named topic branch
subtree update --name example-lib --commit --branch update/example-lib/20250923

# Update by newest tag satisfying a SemVer range
subtree update --mode tag --constraint "^1.2" --commit

# Squash all updates into a single commit on the current branch
subtree update --commit --single-commit --on-current
```

## Remove a Subtree
```bash
subtree remove --name example-lib
```

## Extract Files from a Subtree
```bash
# Ad-hoc copy (records mapping under the subtree)
subtree extract --name example-lib --from docs/README.md --to Docs/ExampleLib.md
subtree extract --name example-lib --from templates/** --to Templates/ExampleLib/

# Apply declared copies from subtree.yaml
subtree extract --name example-lib --all
subtree extract --all --match "**/*.md"

# Safety and preview
subtree extract --dry-run
subtree extract --no-overwrite
subtree extract --force --stage
```

## Validate Subtree State
```bash
# Offline by default, against commit hash
subtree validate
subtree validate --name example-lib --from "**/*.md"

# Repair and optionally prune extras
subtree validate --repair
subtree validate --repair --prune

# Include remote divergence check
subtree validate --with-remote
```

## Behavior Notes
- Output goes to STDOUT; errors/diagnostics go to STDERR
- Explicit exit codes: 0 success; 1 general error; 2 invalid usage/config; 3 git failure; 4 config file not found
- Run from any subdirectory: the tool resolves the repository root
- Outside a Git repository: exit 3 with a clear error
