# Feature Specification: Subtree CLI — git subtree manager

**Feature Branch**: `001-i-am-building`  
**Created**: 2025-09-22  
**Status**: Draft  
**Input**: User description: "I am building a Swift + SPM CLI named Subtree to simplify managing `git subtree` operations in a repository. With no arguments, it prints a short description and a list of top‑level commands. Core commands are: `init`  (create a starter `subtree.yaml`  and/or import existing git subtree configuration), `add` , `update` , and `remove` . The tool reads configuration from `subtree.yaml`  at the repository root; if the file is missing or invalid, `init`  guides creation, otherwise the command exits non‑zero with a clear error to stderr. Normal output is human‑readable text to stdout; errors and diagnostics go to stderr. Help is available via `-h/--help`  for the CLI and each subcommand. Exit codes are explicit: 0 (success), 1 (general error), 2 (invalid usage or configuration), 3 (git command failure), 4 (config file not found). The package builds and runs with Swift Package Manager and ships a single executable named `subtree`."

---

## ⚡ Quick Guidelines
- ✅ Focus on WHAT users need and WHY
- ❌ Avoid HOW to implement (no deep tech details or internal code structure)
- 👥 Written for stakeholders; implementation choices are captured in plan/tasks

---

## User Scenarios & Testing (mandatory)

### Primary User Story
A developer managing multiple external components via `git subtree` wants a simple, consistent CLI to add, update, and remove subtrees using a declarative configuration (`subtree.yaml`) at the repository root.

### Acceptance Scenarios
1. Given a Git repository, when the user runs `subtree` with no arguments, then it prints a short description and a list of top‑level commands and exits with code 0.
2. Given an existing Git repository with no `subtree.yaml` at the repository root, when the user runs `subtree init`, then a starter `subtree.yaml` is created, and the command exits 0.
3. Given an invalid or unreadable `subtree.yaml`, when the user runs any command other than `init`, then the command writes a clear error to stderr and exits with code 2 (invalid usage/config).
4. Given `subtree.yaml` is missing, when the user runs any command other than `init`, then the command writes a clear error to stderr and exits with code 4 (config file not found).
5. Given the user requests help with `-h/--help` on the CLI or any subcommand, then usage text is printed to stdout and the command exits 0.
6. Given a configured subtree, when the user runs `subtree add`, then the subtree is added according to configuration and config changes are included in the same commit atomically; on git failure, the command exits 3 and prints diagnostics to stderr; otherwise exits 0 with human‑readable confirmation on stdout.
7. Given a configured subtree, when the user runs `subtree update`, then the subtree is updated according to configuration; on git failure, the command exits 3 and prints diagnostics to stderr; otherwise exits 0.
8. Given a configured subtree, when the user runs `subtree remove`, then the subtree is removed according to configuration; on git failure, the command exits 3 and prints diagnostics to stderr; otherwise exits 0.

9. Given a subtree `name` and a valid `from` and `to`, when the user runs `subtree extract --name <name> --from <path-or-glob> --to <target>`, then the tool copies matching files/directories from under the subtree’s `prefix` to the target (relative to repo root) and records the mapping under that subtree’s `copies`; if multiple matches (dir or glob), `to` MUST be a directory and relative structure is preserved; exit 0 on success.
10. Given repeated ad-hoc mappings, when the user runs `subtree extract --name <name> --from a --to x --from b --to y`, then both mappings are applied and recorded idempotently (de-duplicate exact pairs per subtree); exit 0.
11. Given declared mappings in `subtree.yaml`, when the user runs `subtree extract --name <name> --all`, then all mappings under that subtree’s `copies` are applied; `subtree extract --all` applies all mappings for all subtrees; optional `--match <glob>` filters by `from` path; exit 0.
12. Given Windows or POSIX filesystems, when copying symlinks by default, then the tool dereferences symlinks (copies file contents) to ensure portability; exit 0.
13. Given target files that are untracked, when copying without `--no-overwrite`, then untracked files may be overwritten by default; modified/tracked files are blocked unless `--force`; exit 2 if blocked with a clear error.
14. Given declared copies and a commit hash, when the user runs `subtree validate`, then the tool reports differences between the subtree prefix and the commit hash, and between each declared `from` source and its `to` target (bit-for-bit content comparison) without changing files; exit 0 if clean, 5 if differences detected.
15. Given `subtree validate --repair`, then the tool resets the subtree prefix to the commit hash and re-copies declared mappings so targets match sources; it does not prune extra files in target directories by default; leaves changes unstaged; exit 0 if all fixed, 1 if some fixes failed, 3 on git failure.
16. Given `subtree validate --with-remote`, then the tool additionally checks divergence from upstream by fetching the remote and comparing against remote HEAD; network is optional and off by default; exit codes as above.
17. Given a TTY and no existing `subtree.yaml`, when the user runs `subtree init --interactive`, then the tool guides discovery/import of subtrees and writes a valid `subtree.yaml`; exit 0.
19. Given a subtree already added at the configured `prefix` and matching the configured lineage (remote + ref ancestry), when the user runs `subtree add --name <name>` again, then no changes are made and the command exits 0 with an "already present" message. If `prefix` exists but the lineage does not match, the command exits 2 with guidance to use `subtree update` or `subtree remove` then re-add.
20. Given subtrees configured to track a branch tip by default, when the user runs `subtree update` without `--commit`, then the tool fetches remotes, computes newest targets, and reports pending updates without making changes; it exits 5 if updates are available, otherwise 0.
21. Given subtrees added via tags, when the user runs `subtree update --commit`, then the tool updates each subtree to the newest available tag and creates commits per subtree by default; commit is updated to the resolved commit.
22. Given `subtree update --commit --single-commit`, then the tool applies all updates and creates one combined commit; commit values are updated atomically with the subtree changes.
23. Given `subtree update --name <subtree> --commit --branch update/<name>/<yyyymmdd>`, then the tool applies that subtree’s update on a topic branch and records the new commit hash.
24. Given local modifications in a subtree prefix, when the user runs `subtree update --commit` without `--force`, then the command refuses to proceed and exits 2 with guidance; with `--force`, it proceeds.

### Edge Cases
- Running outside a Git repository → error to stderr, exit 3 (git failure).
- `subtree.yaml` present but invalid YAML/schema → stderr error, exit 2.
- Running from a subdirectory → tool locates repository root to find `subtree.yaml`.
- Windows path handling and line endings should not affect YAML parse or `git` invocations.
- Copy mismatched types (file→existing directory without explicit filename, or dir/glob→file) → exit 2 with a clear message.
- Copy globs that match nothing → exit 2 listing non-matching patterns.

---

## Requirements (mandatory)

### Functional Requirements
- **FR-001**: The CLI MUST provide top‑level commands: `init`, `add`, `update`, `remove`.
- **FR-002**: Running with no arguments MUST print a short description and list of top‑level commands to stdout and exit 0.
- **FR-003**: `-h/--help` MUST be available for the root CLI and each subcommand, printing usage to stdout and exiting 0.
- **FR-004**: Configuration MUST be read from `subtree.yaml` at the repository root.
- **FR-005**: If `subtree.yaml` is missing, `init` MUST guide creation and other commands MUST exit with code 4 and print a clear error to stderr.
- **FR-006**: If `subtree.yaml` is invalid, commands other than `init` MUST exit with code 2 and print a clear error to stderr.
- **FR-007**: Normal (non‑error) output MUST be human‑readable text to stdout; errors and diagnostics MUST go to stderr.
- **FR-008**: Exit codes MUST be: 0 (success), 1 (general error), 2 (invalid usage/config), 3 (git command failure), 4 (config file not found), 5 (differences/updates available in report-only modes such as `validate`/`update`).
- **FR-009**: The package MUST build and run with Swift Package Manager and ship a single executable named `subtree`. **CLARIFIED**: v1.0.0 targets macOS .v13+ and Linux (glibc); Windows support deferred to v1.1+.
- **FR-010**: `add`, `update`, and `remove` MUST perform the corresponding `git subtree` operations based on entries in `subtree.yaml`, surfacing git failures as exit code 3.
- **FR-011**: The tool MUST operate from any subdirectory of the repository by resolving the repository root.

// Extract command
- **FR-012**: The CLI MUST provide an `extract` command for ad-hoc mappings: `--name <subtree> --from <path-or-glob> --to <target>`; `from` is relative to the subtree’s `prefix`; `to` is relative to repo root; directories and globs (including `**`) are supported. If `from` expands to multiple items, `to` MUST be a directory and relative structure is preserved.
- **FR-013**: The `extract` command MUST allow repeated `--from/--to` pairs under a single `--name`, applying each mapping and recording them idempotently (de-duplicate exact pairs per subtree).
- **FR-014**: The CLI MUST support declared extract modes: `extract --name <subtree> --all` to apply all mappings for a subtree; `extract --all` to apply all mappings for all subtrees; optional `--match <glob>` filters declared mappings by `from`. Declared mode MUST be mutually exclusive with ad-hoc `--from/--to` pairs.
 - **FR-015**: Overwrite policy: untracked targets MAY be overwritten by default; modified/tracked targets MUST be blocked unless `--force` is provided; `--no-overwrite` MUST cause failure if the target exists; respect `.gitignore` (ignored files do not block). No changes are staged by default; provide `--stage` to stage changes; support `--dry-run` preview. **CLARIFIED**: Consistent safety policy across extract and validate commands.
 - **FR-016**: Symlinks MUST be dereferenced by default (copy file contents) for portability; optionally provide a `--preserve-symlinks` flag in a future version (not required in v1).

// Validate command
- **FR-017**: The CLI MUST provide a `validate` command. By default it verifies all subtrees and their declared `copies` for bit‑for‑bit identity: subtree prefix vs commit hash; each `from` vs its `to`. It MUST exit 0 if clean and 5 if differences are detected without `--repair`.
- **FR-018**: `validate --repair` MUST reset the subtree prefix to the commit hash and re‑copy declared mappings to make targets identical to sources; it MUST leave changes unstaged by default. It MUST NOT prune extra files in target directories by default; provide an opt‑in `--prune` to remove extras. **CLARIFIED**: Uses consistent safety policy - blocks overwriting tracked files unless `--force` provided.
 - **FR-019**: `validate` MUST be offline by default; `--with-remote` MAY be provided to also check divergence from upstream by fetching and comparing against remote HEAD. **CLARIFIED**: No global offline mode - each command handles network operations individually per its requirements.
 - **FR-020**: File comparison MUST use Git plumbing only (no external hashing libraries): compute content hashes via `git hash-object` for sources and targets and compare object IDs for identity.
 - **FR-021**: File comparison operations are performed sequentially to ensure predictable resource usage and avoid disk thrash.

// Commit tracking behavior
- **FR-022**: On successful `add` or `update`, the tool MUST record the commit used under the subtree entry as `commit` (git SHA). `validate` and `--repair` operate against this commit hash by default.
- **FR-022a**: The `add` command MUST include `subtree.yaml` configuration updates in the same commit as the subtree addition, ensuring atomic operations. Config changes and subtree content MUST be committed together.

// Add overrides
- **FR-023**: The `add` command MUST support optional override flags: `--prefix <path>`, `--remote <url>`, and `--ref <branch-or-commit>`. Defaults come from `subtree.yaml`; provided overrides apply to the current invocation only and MUST NOT rewrite configuration. If `--ref` is a branch, it MUST be resolved to a commit and recorded to `commit` on success.
- **FR-024**: Overrides MUST NOT be combined with `--all`; such combinations MUST fail with exit 2.

// Init flows
- **FR-025**: The `init` command MUST support `--interactive` (TTY only) to guide interactive subtree configuration. **CLARIFIED**: `--import` functionality removed from v1.0.0 for simplicity.
 
// Add idempotency
- **FR-027**: The `add` command MUST be idempotent when the subtree at `prefix` already matches the configured lineage (remote + ref ancestry): perform no changes and exit 0 with an informational message. If `prefix` exists but does not match the configured lineage, it MUST exit 2 with guidance to use `subtree update` or `subtree remove` then re-add.

// Init constraints
- **FR-028**: The `init` command MUST NEVER initialize git repositories or call `git init`. It operates only on existing git repositories and creates only the `subtree.yaml` configuration file.

// Update policies
- **FR-029**: Update target resolution: subtrees with `branch` field update to newer commits on that branch; subtrees added via tag update to newer tags only; subtrees with commit-only (no branch) are skipped during updates. **CLARIFIED**: SemVer constraint parsing is deferred to v2 - v1 ships with simple newest tag selection only.
- **FR-030**: Without `--commit`, `subtree update` MUST only report pending updates and MUST NOT modify the working tree. It MUST exit 5 if any updates are available, otherwise 0.
- **FR-031**: With `--commit`, updates MUST be applied. Default commit granularity is per-subtree (one commit per updated subtree). Provide `--single-commit` to squash into a single combined commit.
- **FR-032**: Branch strategy: by default, create/update a topic branch (`update/<name>/<yyyymmdd>` for single subtree or `update/all/<yyyymmdd>` for multiple). Provide `--branch <name>` to force a branch name (auto-create) and `--on-current` to commit on the current branch.
- **FR-033**: Commit coordination: when applying updates with `--commit`, the subtree changes and subtree.yaml `commit` field MUST be updated together atomically in the same commit(s).
- **FR-034**: Safety: block when subtree prefix has modified/tracked changes unless `--force`; allow overwriting untracked by default; respect `.gitignore`; support `--dry-run` to print the plan without changes.
- **FR-035**: Network: `update` MUST fetch remotes to compute newest targets; unreachable remotes MUST result in exit 3.
- **FR-036**: Overrides: `update` MAY accept per-invocation selection filter `--name <subtree>` to update specific subtrees only.
- **FR-037**: Exit codes: 0 (no updates in report mode OR applied successfully with `--commit`), 5 (updates available in report mode), 1 (partial/failed apply with `--commit`), 3 (git failure), 2 (invalid usage), 4 (config not found).

### Key Entities (include if feature involves data)
- **SubtreeConfig (from `subtree.yaml`)**: declarative mapping of one or more subtrees to managed remotes/paths/branches.
  - Schema structure: Array format `subtrees: [{name, remote, prefix, branch, squash, commit, copies}]`
  - Required fields: `name`, `remote`, `prefix`; optional: `branch` (defaults to main/master), `squash` (defaults to true), `commit` (SHA for validation), `copies` (extract mappings)
  - **CLARIFIED**: v1 schema omits `update.constraint` and `update.mode` fields - deferred to v2
  - Validation: required fields present; no duplicate `name`; paths normalized; remote URLs syntactically valid.

---

## Review & Acceptance Checklist
*GATE: Automated checks during review*

### Content Quality
- [ ] No implementation details beyond what’s necessary to define behavior
- [ ] Focused on user value and CLI behaviors
- [ ] Written for stakeholders and engineering review
- [ ] All mandatory sections completed

### Requirement Completeness
- [ ] Remaining [NEEDS CLARIFICATION] items identified
- [ ] Requirements are testable and unambiguous
- [ ] Success criteria are measurable
- [ ] Scope clearly bounded
- [ ] Dependencies and assumptions identified

---

## Execution Status
*Updated during processing*

- [ ] User description parsed
- [ ] Key concepts extracted
- [ ] Ambiguities marked
- [ ] User scenarios defined
- [ ] Requirements generated
- [ ] Entities identified
- [ ] Review checklist passed

---
