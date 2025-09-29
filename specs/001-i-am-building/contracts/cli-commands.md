# CLI Contracts: Subtree

## Root Command
- Usage: `subtree [OPTIONS] <COMMAND>`
- Options:
  - `-h, --help` — show help and exit 0
  - `--version` — print version and exit 0
- Output: human-readable to STDOUT; errors/diagnostics to STDERR
- Exit codes: 0 success; 1 general error; 2 invalid usage/config; 3 git failure; 4 config file not found

## `init`
- Purpose: Create a starter `subtree.yaml` and/or import existing git subtree configuration
- Usage: `subtree init [--force] [--import] [--interactive]`
- Behavior:
  - If `subtree.yaml` exists and `--force` not provided → exit 2 with error
  - Default (no flags): create or overwrite `subtree.yaml` with a minimal valid template; when safe, may import detected settings without prompts
  - With `--import`: non-interactive scan to detect current `git subtree` usage and write a minimal `subtree.yaml`
  - With `--interactive`: guided setup (TTY only) to discover/import subtrees and configure entries interactively
  - `--import` and `--interactive` are mutually exclusive; providing both → exit 2
- Exit codes: 0 success; 1 general error; 2 invalid usage/config

## `add`
- Purpose: Add one or more subtrees defined in config
- Usage: `subtree add [--name <name>] [--all] [--no-squash] [--prefix <path>] [--remote <url>] [--ref <branch-or-commit>]`
- Behavior:
  - Reads `subtree.yaml` from repo root; missing file → exit 4
  - If `--name` supplied, operate on that entry; if `--all`, operate on all entries
  - Runs `git subtree add` with effective remote/branch/prefix values. By default these come from config; when provided, `--prefix`, `--remote`, and `--ref` override for this invocation.
  - `--ref` may be a branch or a commit; branches are resolved to a commit before add. After success, the resolved commit is recorded to `commit`.
  - In v1, `--prefix`/`--remote` overrides do not rewrite subtree.yaml fields; the CLI warns if overrides differ from configuration. Use config edits to persist such changes.
  - Invalid combination: when `--all` is used, overrides (`--prefix`, `--remote`, `--ref`) are not allowed → exit 2.
  - `--no-squash` toggles squash=false
  - Idempotency: If the subtree is already present at `prefix` and matches the configured lineage (remote + ref ancestry), the command is a no‑op and exits 0 with a message. If `prefix` exists but does not match, exit 2 with guidance to use `subtree update` or `subtree remove` then re‑add.
- Exit codes: 0 success; 3 git failure; 2 invalid usage/config; 4 config missing

## `update`
- Purpose: Fetch and synchronize git subtrees to the newest target commit based on each subtree’s update policy (branch tip by default). Acts like Dependabot for git subtrees.
- Usage: `subtree update [--name <name>] [--commit] [--single-commit] [--branch <name>] [--on-current] [--mode {branch|tag|release}] [--constraint <semver-range>] [--include-prereleases] [--dry-run] [--force]`
- Behavior:
  - Report vs apply:
    - Default (no `--commit`): fetch remotes, compute newest targets (per subtree policy), and report pending updates without changing files (exit 5 if updates available, else 0).
    - With `--commit`: apply updates using `git subtree pull` (or equivalent), updating each subtree to the resolved commit and updating `commit` in `subtree.yaml`.
  - Target resolution:
    - Default mode: branch tip (configured `branch`).
    - Tag/Release modes: when configured (or overridden), select newest tag/release satisfying `constraint`; `includePrereleases` optional.
    - Per-invocation overrides: `--mode`, `--constraint`, `--include-prereleases` (do not rewrite config).
  - Commit policy:
    - Default: one commit per updated subtree (per‑subtree granularity).
    - `--single-commit`: squash all updates into a single combined commit.
  - Branch strategy:
    - Default: create/update a topic branch: `update/<name>/<stamp>` for single subtree or `update/all/<stamp>` for multiple.
    - `--branch <name>`: commit on or create a specific branch; `--on-current`: commit on current branch.
  - Safety & dry-run:
    - Block if subtree prefix has modified/tracked changes unless `--force`; allow overwriting untracked by default; respect `.gitignore`.
    - `--dry-run`: print planned updates and exit without changes.
  - Network: always fetch the remote for each selected subtree; unreachable remote → exit 3.
- Exit codes: 0 (no updates in report mode OR applied successfully with `--commit`); 5 (updates available in report mode); 1 (partial/failed apply with `--commit`); 3 (git failure); 2 (invalid usage); 4 (config missing)

## `remove`
- Purpose: Remove a configured subtree
- Usage: `subtree remove --name <name>`
- Behavior: removes files at prefix, updates git history appropriately (exact strategy to be documented),
  requires explicit `--name`
- Exit codes: 0 success; 3 git failure; 2 invalid usage/config; 4 config missing

## `extract`
- Purpose: Extract files/dirs from a subtree into target locations and record mappings in `subtree.yaml`
- Usage (ad-hoc):
  - `subtree extract --name <name> --from <path-or-glob> --to <target> [--from <p2> --to <t2> ...] [--dry-run] [--no-overwrite] [--force] [--stage]`
- Usage (declared):
  - `subtree extract --name <name> --all [--match <glob>] [--dry-run] [--no-overwrite] [--force] [--stage]`
  - `subtree extract --all [--match <glob>] [--dry-run] [--no-overwrite] [--force] [--stage]`
- Behavior:
  - `from` is relative to the subtree’s `prefix`; supports files, directories, and globs (including `**`).
  - `to` is relative to the repository root.
  - If `from` expands to multiple items (dir/glob), `to` MUST be a directory; relative structure is preserved.
  - Symlinks are dereferenced by default (copy file contents) for portability.
  - Ad-hoc mode records each mapping under the subtree’s `copies` and de-duplicates exact `(from,to)` pairs (idempotent).
  - Declared mode applies mappings already defined in `subtree.yaml`; `--match <glob>` filters entries by `from`.
  - Mutually exclusive: Declared mode (`--all`/`--match`) cannot be combined with ad-hoc `--from/--to` pairs.
  - Overwrite policy: untracked targets may be overwritten by default; modified/tracked targets are blocked unless `--force`.
  - `--no-overwrite` forces failure if a target exists; `--dry-run` prints planned actions without writing; no staging by default unless `--stage`.
- Exit codes: 0 success; 2 invalid usage/config (mismatches, empty globs, mutual exclusivity violations); 4 config missing; 1 general error; 3 git failure (if git interaction is required).
## `validate`
- Purpose: Validate a subtree and its copied files are in a clean state
- Usage:
  - `subtree validate [--name <name>] [--from <glob>] [--with-remote] [--repair] [--prune] [--dry-run] [--jobs <N>] [--force] [--stage]`
- Behavior:
  - Default: offline verification against the subtree's `commit` hash (if present). With `--with-remote`, also check divergence vs remote HEAD (fetch required).
  - Without `--repair`: report differences between subtree prefix and commit hash, and between each declared `from` and its `to` target; make no changes.
  - With `--repair`: reset subtree prefix to `commit` hash and re-copy declared mappings to make targets identical; do not prune extra files by default (use `--prune` to remove extras); leave changes unstaged unless `--stage`.
  - Filtering: `--name` limits scope to one subtree; `--from <glob>` filters declared mappings by source path.
  - Comparison: uses Git plumbing only — compute content hashes via `git hash-object` for sources and targets and compare object IDs for identity.
  - Safety: by default, modified/tracked targets block changes unless `--force`; untracked targets may be overwritten; respect `.gitignore`.
- Exit codes: 0 clean (or repaired successfully); 5 differences detected (no `--repair`); 1 partial/failed repair; 3 git failure; 2 invalid usage; 4 config missing.

## Examples
```bash
subtree --help
# Initialize configuration (non-interactive): creates minimal subtree.yaml (may import when safe)
subtree init

# Guided init (TTY): discover/import subtrees and configure interactively
subtree init --interactive

# Non-interactive import pass
subtree init --import

# Then add using values from subtree.yaml (e.g., prefix Vendor/libfoo, ref main)
subtree add --name example-lib

# Add with explicit overrides (mimics `git subtree add` flags)
subtree add --name libfoo \
  --remote https://github.com/example/libfoo.git \
  --prefix Vendor/libfoo \
  --ref main \
  --no-squash

# Update all configured subtrees (default scope)
subtree update

# Apply updates, creating one commit per updated subtree on a topic branch
subtree update --commit

# Update a single subtree on a named topic branch
subtree update --name example-lib --commit --branch update/example-lib/20250923

# Update by newest tag satisfying a SemVer range
subtree update --mode tag --constraint "^1.2" --commit

# Squash all updates into a single commit on the current branch
subtree update --commit --single-commit --on-current
subtree remove --name example-lib
subtree extract --name example-lib --from docs/README.md --to Docs/ExampleLib.md
subtree extract --name example-lib --from templates/** --to Templates/ExampleLib/
subtree extract --name example-lib --all --match "**/*.md"
subtree extract --all --dry-run
subtree validate
subtree validate --name example-lib --from "**/*.md"
subtree validate --repair --prune
subtree validate --with-remote
```
