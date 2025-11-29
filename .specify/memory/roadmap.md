# Product Roadmap: Subtree CLI

**Version:** v1.5.0  
**Last Updated:** 2025-11-27

## Vision & Goals

Simplify git subtree management through declarative YAML configuration with safe file extraction and validation capabilities.

**Target Users:**
- Solo developers and small teams managing vendor dependencies
- Open source project maintainers integrating upstream libraries
- Developers building monorepo-style projects with shared code

**Primary Outcomes:**
1. **Reduce complexity** — Replace complex git subtree commands with simple declarative configuration
2. **Improve safety** — Prevent accidental data loss through built-in validation and overwrite protection
3. **Enable automation** — Support CI/CD pipelines with reliable, scriptable subtree operations

## Phases Overview

| Phase | Name / Goal                      | Status   | File Path                                |
|-------|----------------------------------|----------|------------------------------------------|
| 1     | Foundation                       | COMPLETE | roadmap/phase-1-foundation.md            |
| 2     | Core Subtree Operations          | COMPLETE | roadmap/phase-2-core-operations.md       |
| 3     | Advanced Operations & Safety     | ACTIVE   | roadmap/phase-3-advanced-operations.md   |
| 4     | Production Readiness             | PLANNED  | roadmap/phase-4-production-readiness.md  |
| 5     | Future Features (Backlog)        | FUTURE   | roadmap/phase-5-backlog.md               |

## Current Focus: Phase 3

- ✅ Case-Insensitive Names & Validation
- ✅ Extract Command (5 user stories, 411 tests)
- ⏳ **Multi-Pattern Extraction** — Multiple `--from` patterns in single extraction
- ⏳ **Extract Clean Mode** — `--clean` flag to remove extracted files safely
- ⏳ Lint Command — Configuration integrity validation

## Product-Level Metrics & Success Criteria

**Adoption:**
- Successfully manages subtrees in 3+ projects within 6 months of 1.0
- Achieves 50+ GitHub stars and 5+ external contributors within 12 months
- Used in CI pipelines for 3+ open source projects within 6 months

**Usage:**
- Reduces subtree setup time from 15+ minutes (manual) to <5 minutes (declarative)
- 95%+ command success rate without user intervention
- 90%+ error resolution without external help

**Quality:**
- Zero data loss incidents (git repository integrity maintained)
- All operations within documented time limits (init <1s, add <10s, extract <3s)
- 100% test pass rate on macOS 13+ and Ubuntu 20.04 LTS

**Developer Experience:**
- New users complete first subtree add within 10 minutes
- 80%+ find answers in docs without filing issues
- <2 support questions per 100 users per month

## High-Level Dependencies & Sequencing

1. **Phase 1 → Phase 2**: Core operations depend on config foundation
2. **Phase 2 → Phase 3**: Extract and Lint require subtrees to exist (Add command)
3. **Phase 3 → Phase 4**: Packaging requires all commands feature-complete
4. **Multi-Pattern → Clean Mode**: Clean mode benefits from array pattern support

## Global Risks & Assumptions

**Assumptions:**
- Users have basic git knowledge (commits, branches, remotes)
- Git subtree command available in standard git distribution
- Users prefer declarative YAML over CLI flags for repeated operations

**Risks & Mitigations:**
- **Git version variance** → Target git 2.x+, integration tests catch issues
- **Glob pattern complexity** → Clear validation errors, dry-run mode planned
- **Concurrent operations** → Atomic file operations, git handles subtree locking

## Change Log

- **v1.5.0** (2025-11-27): Roadmap refactored to multi-file structure; added Multi-Pattern Extraction and Extract Clean Mode to Phase 3 (MINOR — new features, structural improvement)
- **v1.4.0** (2025-10-29): Phase 2 complete — Remove Command delivered with idempotent behavior (191 tests passing)
- **v1.3.0** (2025-10-28): Phase 2 progress — Add Command and Update Command marked complete
- **v1.2.0** (2025-10-28): Update Command scope clarified — dry-run mode moved to backlog
- **v1.1.0** (2025-10-27): Add Command scope refined — CLI-First workflow only, Config-First to backlog
- **v1.0.0** (2025-10-27): Initial roadmap created
