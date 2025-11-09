# Product Roadmap: Subtree CLI

**Version:** v1.4.0  
**Last Updated:** 2025-10-29

## Vision & Goals

Simplify git subtree management through declarative YAML configuration with safe file extraction and validation capabilities.

**Target Users:**
- Solo developers and small teams managing vendor dependencies
- Open source project maintainers integrating upstream libraries
- Developers building monorepo-style projects with shared code

**Primary Outcomes:**
1. **Reduce complexity** - Replace complex git subtree commands with simple declarative configuration
2. **Improve safety** - Prevent accidental data loss through built-in validation and overwrite protection
3. **Enable automation** - Support CI/CD pipelines with reliable, scriptable subtree operations

## Release Plan

> Timing is flexible based on development velocity. Each phase delivers complete, production-ready functionality.

### Phase 1 — Foundation (✅ COMPLETE)

**Goal:** Establish project infrastructure and configuration management

**Status:** All features delivered and tested across macOS 13+ and Ubuntu 20.04 LTS

**Key Features:**

1. **CLI Bootstrap**  
   - Purpose & user value: Provides command-line interface skeleton with discoverable help system, enabling users to explore available commands and understand tool capabilities without external documentation  
   - Success metrics:  
     - Command help accessible in <5 seconds via `subtree --help`  
     - All stub commands execute without crashing (exit code 0)  
     - CI pipeline runs tests on macOS + Ubuntu completing in <10 minutes  
   - Dependencies: None  
   - Notes: Includes test infrastructure (unit + integration test harness) and GitHub Actions CI

2. **Configuration Schema & Validation**  
   - Purpose & user value: Defines `subtree.yaml` structure and validation rules, enabling users to manage subtree dependencies declaratively with clear error messages when configuration is invalid  
   - Success metrics:  
     - Valid configs parse successfully on first attempt when following docs  
     - Invalid configs produce clear, actionable error messages within 1 second  
     - 100% of format/constraint violations caught before git operations  
   - Dependencies: CLI Bootstrap  
   - Notes: Format-only validation (no network/git checks), supports glob patterns for extract mappings

3. **Init Command**  
   - Purpose & user value: Creates initial `subtree.yaml` configuration file at git repository root, providing starting point for declarative subtree management with overwrite protection  
   - Success metrics:  
     - Initialization completes in <1 second  
     - Users successfully initialize on first attempt without documentation  
     - 100% of initialization attempts either succeed or fail with clear error  
   - Dependencies: Configuration Schema & Validation  
   - Notes: Works from any subdirectory, follows symlinks to find git root, atomic file operations for concurrent safety

**Next:** `/speckit.specify "Feature: Add Command - Add configured subtrees to repository with atomic commit strategy"`

---

### Phase 2 — Core Subtree Operations (✅ COMPLETE)

**Goal:** Enable complete subtree lifecycle management with atomic commits

**Status:** All core subtree operations delivered and tested across macOS 13+ and Ubuntu 20.04 LTS

**Key Features:**

1. **Add Command (CLI-First)** ✅ COMPLETE  
   - Purpose & user value: Adds subtrees to repository via CLI flags in single atomic commits, creating config entries automatically and ensuring configuration always reflects repository state  
   - Success metrics:  
     - Subtree addition completes in <10 seconds for typical repositories  
     - 100% of add operations produce single commit (subtree + config update)  
     - Users can add subtrees with minimal flags (only --remote required)  
     - Smart defaults reduce typing: name from URL, prefix from name, ref defaults to 'main'  
   - Dependencies: Init Command  
   - Notes: CLI-First workflow (flags create config entry), atomic commit-amend pattern, duplicate detection via config check (name OR prefix), squash enabled by default (--no-squash to disable)  
   - Delivered: All 5 user stories implemented (MVP with smart defaults, override defaults, no-squash mode, duplicate prevention, error handling), 150 tests passing

2. **Update Command** ✅ COMPLETE  
   - Purpose & user value: Updates subtrees to latest versions with flexible commit strategies, enabling users to keep dependencies current with report-only mode for CI/CD safety checks  
   - Success metrics:  
     - Update check (report mode) completes in <5 seconds  
     - Users understand update status without applying changes (exit code 5 if updates available)  
     - 100% of applied updates tracked in config with correct commit hash  
   - Dependencies: Add Command  
   - Notes: Report mode (no changes), current branch commits only, single-commit squashing option (--squash/--no-squash)  
   - Delivered: All 5 user stories implemented (selective update with squash, bulk update --all, report mode for CI/CD, no-squash mode, error handling), tag-aware commit messages, atomic commit pattern

3. **Remove Command** ✅ COMPLETE  
   - Purpose & user value: Safely removes subtrees and updates configuration atomically, ensuring clean repository state and preventing orphaned configuration entries with idempotent behavior  
   - Success metrics:  
     - Removal completes in <5 seconds  
     - 100% of remove operations produce single commit (removal + config update)  
     - Config entries removed atomically with subtree directory  
     - Idempotent: succeeds when directory already deleted (exit code 0)  
   - Dependencies: Add Command  
   - Notes: Single atomic commit for removal + config update, validates subtree exists before removal, smart detection for directory state with context-aware success messages  
   - Delivered: All 2 user stories implemented (clean removal, idempotent removal), 191 tests passing, comprehensive error handling with exit codes 0/1/2/3

**Next:** `/speckit.specify "Feature: Case-Insensitive Names - Portable config validation and flexible name matching"`

---

### Phase 3 — Advanced Operations & Safety

**Goal:** Enable portable configuration validation and selective file extraction with comprehensive safety features

**Key Features:**

0. **Case-Insensitive Names & Validation**  
   - Purpose & user value: Enables flexible name matching for all commands (add, remove, update) while preventing duplicate names/prefixes across case variations, ensuring configs work portably across macOS (case-insensitive) and Linux (case-sensitive) filesystems  
   - Success metrics:  
     - Users can remove/update subtrees without remembering exact case (e.g., `remove hello-world` matches `Hello-World`)  
     - 100% of case-variant duplicate names detected during add (e.g., reject adding `Hello-World` + `hello-world`)  
     - 100% of case-variant duplicate prefixes detected during add (e.g., reject `vendor/lib` + `vendor/Lib`)  
     - Configs portable across all platforms (no macOS/Windows path conflicts)  
   - Dependencies: Add Command, Remove Command, Update Command  
   - Notes: Case-insensitive lookup for name matching in commands, case-insensitive duplicate validation for names AND prefixes, stores original case in config (case-preserving), prevents portability issues

1. **Extract Command (Complete)**  
   - Purpose & user value: Copies files from subtrees to project structure using glob patterns with smart overwrite protection, enabling selective integration of upstream files (docs, templates, configs) without manual copying  
   - Success metrics:  
     - Ad-hoc extraction completes in <3 seconds for typical file sets  
     - Glob patterns match expected files with 100% accuracy  
     - Git-tracked files protected unless `--force` explicitly used  
   - Dependencies: Add Command  
   - Notes: Unified feature covering basic (`--from/--to`) and advanced (glob patterns, `**` globstar, `--all` for declared mappings, `--match` for filtering), `--persist` for saving mappings, `--force` for overrides, directory structure preserved relative to glob match

2. **Lint Command**  
   - Purpose & user value: Validates subtree integrity and synchronization state offline and with remote checks, enabling users to detect configuration drift, missing subtrees, or desync between config and repository state  
   - Success metrics:  
     - Offline validation completes in <2 seconds  
     - 100% of config/repository mismatches detected and reported clearly  
     - Repair mode fixes discrepancies without manual intervention  
     - Remote validation detects divergence from upstream within 10 seconds  
   - Dependencies: Add Command  
   - Notes: Renamed from "validate" for clarity, offline mode (commit hash checks), `--with-remote` for upstream comparison, `--repair` mode, `--name` and `--from` for targeted validation

**Next:** `/speckit.specify "Feature: CI Packaging - Automated releases with platform-specific binaries"`

---

### Phase 4 — Production Readiness

**Goal:** Deliver production-grade packaging and polished user experience

**Key Features:**

1. **CI Packaging & Binary Releases**  
   - Purpose & user value: Automated release packaging with platform-specific binaries distributed via GitHub Releases, enabling users to install pre-built binaries without Swift toolchain  
   - Success metrics:  
     - Release artifacts generated automatically on version tags  
     - Binaries available for macOS (arm64/x86_64) and Linux (x86_64/arm64)  
     - Users can install via single download + chmod command  
     - Swift artifact bundles include checksums for SPM integration  
   - Dependencies: Lint Command (all commands complete)  
   - Notes: GitHub Actions release workflow, artifact bundles for SPM, SHA256 checksums, installation instructions in releases

2. **Polish & UX Refinements**  
   - Purpose & user value: Comprehensive UX improvements including progress indicators, enhanced error messages, and documentation site, reducing friction for new users and improving troubleshooting experience  
   - Success metrics:  
     - Long-running operations show progress indicators (no silent hangs)  
     - Error messages include suggested fixes 100% of the time  
     - New users complete first subtree add within 5 minutes using only docs  
     - Documentation site covers all commands with runnable examples  
   - Dependencies: CI Packaging  
   - Notes: Progress bars for git operations, emoji-prefixed messages throughout, comprehensive CHANGELOG, documentation site (GitHub Pages or similar), example repositories

**Next:** Post-1.0 enhancements (interactive mode, config migration tools, advanced remapping)

---

### Future Phases / Backlog

**Not Yet Scheduled:**

- **Config-First Add Workflow** — Add subtrees by reading pre-configured entries from `subtree.yaml` (declarative workflow)  
  - Purpose: Enables declarative workflow where users edit config first, then run `subtree add --name <name>` to apply  
  - Success metrics: Users can define subtrees in config and apply them without repeating CLI flags  
  - Dependencies: Add Command (CLI-First)

- **Batch Add (--all flag)** — Add all configured subtrees in one command  
  - Purpose: Initial repository setup and bulk operations (e.g., `git clone && subtree add --all`)  
  - Success metrics: Users can populate all subtrees without manual iteration  
  - Dependencies: Config-First Add Workflow  
  - Notes: Requires detection logic to skip already-added subtrees

- **Interactive Init Mode** — Guided configuration setup with prompts and validation (TTY-only feature for improved onboarding)  
  - Purpose: Reduces new user friction by providing step-by-step subtree configuration  
  - Success metrics: Users complete interactive init without documentation in <3 minutes  
  - Dependencies: Init Command

- **Config Migration Tools** — Import existing git subtrees into `subtree.yaml` by scanning repository history  
  - Purpose: Enables adoption by projects already using git subtrees manually  
  - Success metrics: 90% of existing subtrees detected and imported correctly  
  - Dependencies: Lint Command

- **Advanced Extract Remapping** — Complex path transformations and multi-source merging for extract operations  
  - Purpose: Supports advanced monorepo scenarios with nested subtree structures  
  - Success metrics: Users can remap nested paths without manual post-processing  
  - Dependencies: Extract Command

- **Extract Flatten Mode (`--flatten` flag)** — Flatten extracted files into destination directory without preserving subdirectory structure  
  - Purpose: Enables simplified file layouts when subdirectory structure is unnecessary (e.g., copying all config files to single directory)  
  - Success metrics: Users can extract files flat when needed without manual post-processing  
  - Dependencies: Extract Command  
  - Notes: Complements default behavior (preserve structure relative to glob match); handles filename conflicts with clear errors

- **Extract Dry-Run Mode (`--dry-run` flag)** — Preview extraction results without actually copying files  
  - Purpose: Enables users to validate glob patterns and check for conflicts before executing extraction  
  - Success metrics: Users can verify extraction plan (files matched, conflicts detected) without modifying filesystem  
  - Dependencies: Extract Command  
  - Notes: Shows file list with status indicators (new/overwrite/blocked), conflict warnings for git-tracked files, summary statistics

- **Extract Auto-Stage Mode (`--stage` flag)** — Automatically stage extracted files for git commit  
  - Purpose: Streamlines workflow by staging extracted files immediately, reducing manual git add steps  
  - Success metrics: Users can extract and stage files in single command when desired  
  - Dependencies: Extract Command  
  - Notes: Optional flag (default behavior is manual staging); runs `git add` on extracted files after successful copy

- **Dry-Run Mode** — Simulate git operations without committing changes for Update command  
  - Purpose: Enables safe testing of update commands to preview changes before applying  
  - Success metrics: Users can validate update behavior (fetch, merge simulation) without repository modification  
  - Dependencies: Update Command  
  - Notes: Complements report mode (which only checks availability); dry-run performs full validation including conflict detection

- **Network Retry with Exponential Backoff** — Automatic retry logic for transient network failures during git operations  
  - Purpose: Improves reliability in unstable network environments and CI/CD pipelines  
  - Success metrics: 95% of transient network errors recover without manual intervention  
  - Dependencies: Update Command (primary use case), applies to Add/Remove as well  
  - Notes: Configurable retry count and backoff strategy, distinguishes transient errors (timeout, 503) from permanent failures (auth, 404)

## Feature Areas

**Core Management:**
- Init, Add, Update, Remove commands
- Atomic commit strategies ensuring config/repository synchronization
- Supports configuration-driven workflows

**Validation & Safety:**
- Lint command for integrity checks (offline + remote)
- Overwrite protection for tracked files
- Git repository validation (must be inside git repo)
- Path safety validation (no `..`, no absolute paths)
- Repair mode for automatic fix of discrepancies

**File Operations:**
- Extract command with glob pattern support
- Selective file copying from subtrees
- Copy mappings in config for repeatable extractions
- Dry-run and force modes

**Developer Experience:**
- Comprehensive help system (`--help` at all levels)
- Clear, emoji-prefixed error messages
- Progress indicators for long operations
- Consistent exit codes for scripting

**Platform & CI:**
- Cross-platform support (macOS 13+, Ubuntu 20.04 LTS)
- CI/CD friendly (report modes, predictable exit codes)
- Automated release packaging
- Swift Package Manager integration

## Dependencies & Sequencing

**Implementation Order:**

1. **Foundation First** (Phase 1): Bootstrap → Schema → Init  
   *Rationale: Establishes test infrastructure, config format, and entry point*

2. **Core Operations** (Phase 2): Add → Update → Remove  
   *Rationale: Enables complete subtree lifecycle, each builds on Add's atomic commit pattern*

3. **Advanced Features** (Phase 3): Extract (unified) → Lint  
   *Rationale: Extract depends on subtrees existing (Add), Lint validates all previous operations*

4. **Production Polish** (Phase 4): Packaging → UX Refinements  
   *Rationale: Distribution and polish come after feature completeness*

**Cross-Release Dependencies:**

- All Phase 2 commands depend on Phase 1 (Init) for config access
- Phase 3 Extract requires Phase 2 Add (subtrees must exist to extract from)
- Phase 3 Lint validates Phase 2 operations (add/update/remove state)
- Phase 4 Packaging requires all commands complete (nothing to package otherwise)

## Metrics & Success Criteria (product-level)

**Adoption Metrics:**
- **Personal/Team Use**: Successfully manages subtrees in 3+ personal/team projects within 6 months of 1.0 release
- **Open Source Community**: Achieves 50+ GitHub stars and 5+ external contributors within 12 months
- **CI Integration**: Used in CI pipelines for 3+ open source projects within 6 months

**Usage Metrics:**
- **Time Savings**: Reduces subtree setup time from 15+ minutes (manual git commands) to <5 minutes (declarative config)
- **Command Success Rate**: 95%+ of commands complete successfully without user intervention
- **Error Recovery**: Users resolve errors without external help 90%+ of the time (clear error messages)

**Quality Metrics:**
- **Reliability**: Zero data loss incidents in production use (git repository integrity maintained)
- **Performance**: All operations complete within documented time limits (init <1s, add <10s, update check <5s, extract <3s, lint <2s)
- **Cross-Platform**: 100% test pass rate on macOS 13+ and Ubuntu 20.04 LTS

**Developer Experience:**
- **Onboarding**: New users complete first successful subtree add within 10 minutes
- **Documentation Quality**: Users find answers in docs without filing issues 80%+ of the time
- **Support Volume**: <2 support questions per 100 users per month (clarity of errors and docs)

## Risks & Assumptions

**Assumptions:**

- Users have basic git knowledge (understand commits, branches, remotes)
- Git subtree command is available in user environments (standard git distribution)
- Users prefer declarative YAML configuration over CLI flags for repeated operations
- Most subtrees use standard git URL formats (https://, git@, file://)
- Users run commands from within git working directories (not bare repos)

**Risks & Mitigations:**

- **Risk:** Git subtree command behavior varies across git versions  
  *Mitigation:* Target git 2.x+ minimum, document tested versions, integration tests catch breaking changes

- **Risk:** Users attempt to manage too many subtrees (100+), causing performance issues  
  *Mitigation:* Document recommended limits, optimize config parsing, add progress indicators for batch operations

- **Risk:** Glob pattern complexity leads to unexpected file matches  
  *Mitigation:* Dry-run mode shows exactly what would be extracted, clear pattern validation errors

- **Risk:** Concurrent operations on same repository cause conflicts  
  *Mitigation:* Atomic file operations for config updates (write temp + rename), git handles subtree operation locking

- **Risk:** Limited adoption due to niche use case (subtrees less popular than submodules)  
  *Mitigation:* Focus on quality over quantity, highlight subtree advantages (simpler history, no .gitmodules), target users frustrated with submodules

## Change Log

- v1.4.0 (2025-10-29): Phase 2 complete - Remove Command delivered with idempotent behavior (191 tests passing), added Case-Insensitive Names feature to Phase 3 roadmap (MINOR - Phase 2 complete, Phase 3 refined scope)
- v1.3.0 (2025-10-28): Phase 2 progress update - Add Command and Update Command marked complete with production-ready implementations (MINOR - significant feature completion milestone, 2 of 3 Phase 2 commands delivered)
- v1.2.0 (2025-10-28): Update Command scope clarified - removed dry-run mode and topic branch mode from Phase 2, moved dry-run to backlog (MINOR - scope refinement for focused MVP)
- v1.1.0 (2025-10-27): Refined Phase 2 Add Command scope - CLI-First workflow only, moved Config-First workflow and --all flag to backlog (MINOR - scope reduction for simpler MVP)
- v1.0.0 (2025-10-27): Initial Subtree CLI roadmap created - complete product scope from foundation through production readiness