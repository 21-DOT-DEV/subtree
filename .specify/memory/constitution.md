<!--
SYNC IMPACT REPORT - Constitution Update
═══════════════════════════════════════════════════════════════════════════════
Version Change: [NEW] → 1.0.0

Modified Principles:
  - [ALL PRINCIPLES NEW - Initial constitution ratification]

Added Sections:
  ✅ Core Principles (I-V)
  ✅ CI & Quality Gates
  ✅ Agent Maintenance Rules
  ✅ Governance

Removed Sections:
  - None (initial version)

Template Alignment Status:
  ✅ spec-template.md - Aligned with spec-first principle (supports Implementation Notes block)
  ✅ plan-template.md - Contains Constitution Check section ready for gates
  ✅ tasks-template.md - Organized by user stories with test-first guidance
  ⚠️  .windsurf/rules - Must be created/updated after each successful spec implementation

Follow-up TODOs:
  - Agent must create/update .windsurf/rules after first spec completion
  - Ensure bootstrap spec (spec 000 or spec 001) establishes test & CI harness
═══════════════════════════════════════════════════════════════════════════════
-->

# Subtree CLI Constitution

## Core Principles

### I. Spec-First Development (NON-NEGOTIABLE)

Every behavior change or feature MUST begin with a `spec.md` file that defines:

- User scenarios with acceptance criteria in Given-When-Then format
- Failing tests that encode the acceptance criteria
- Measurable success criteria
- Functional requirements (technology-agnostic)

**Bootstrap Requirement**: The first spec (spec 000 or spec 001) MUST establish the test harness and CI infrastructure used by all subsequent specs. This bootstrap spec defines the testing framework, test organization, CI configuration, and quality gates that govern the project.

**Spec Organization**: Each spec MUST be small, independent, and focused on a single feature or small subfeature. Specs are stored in `specs/###-feature-name/spec.md` with related design artifacts (plan.md, tasks.md, etc.).

**Implementation Notes**: Specs MAY include an optional "Implementation Notes" section at the end for language-specific guidance (preferably Swift for this project). However, the main spec body MUST remain behavior-focused, test-driven, and technology-agnostic.

**Rationale**: Spec-first development ensures clear requirements, prevents scope creep, enables independent testing, and creates executable documentation. The bootstrap spec prevents test infrastructure drift across features.

### II. Test-Driven Development (NON-NEGOTIABLE)

All implementation MUST follow strict TDD discipline:

1. **Write tests first** based on spec.md acceptance criteria
2. **Verify tests fail** before any implementation
3. **Implement minimal code** to pass the tests
4. **Refactor** while keeping tests green
5. Tests MUST pass before merge

**Test Organization**: Unit tests validate individual components, integration tests verify feature workflows, contract tests ensure API/CLI stability.

**Rationale**: TDD forces clear design, prevents regression, documents behavior through tests, and ensures testability. Failing tests first proves tests actually validate the requirement.

### III. Small, Independent Specs

Each spec.md MUST represent:

- A single feature or small subfeature
- An independently testable unit of work
- A deployable increment of value
- User stories prioritized by importance (P1, P2, P3)

Specs MUST NOT:

- Combine multiple unrelated features
- Create dependencies on incomplete specs
- Describe implementation details instead of behavior

**Rationale**: Small specs enable parallel work, reduce risk, accelerate feedback cycles, and allow incremental delivery. Independent specs prevent cascading failures and enable selective rollback.

### IV. CI & Quality Gates

All code changes MUST pass automated quality gates defined in the bootstrap spec. Required gates include:

**CI Matrix**: Tests MUST run across representative platforms (e.g., macOS, Linux, Swift versions as appropriate for the project).

**Test Requirements**:
- Unit tests MUST pass (validate individual components)
- Integration tests MUST pass (validate feature workflows)
- Contract tests MUST pass (validate CLI/API stability)

**Merge Policy**: CI MUST pass green before merge. No exceptions.

**Rationale**: Automated gates prevent regressions, ensure cross-platform compatibility, maintain quality consistency, and reduce manual review burden. Representative platform coverage catches environment-specific issues early.

### V. Agent Maintenance Rules

The agent MUST maintain `.windsurf/rules` as a small, surgical file describing:

- Agent expectations for the codebase
- Current project structure and conventions
- Update procedures for rules file

**Mandatory Update Triggers**: The agent MUST update `.windsurf/rules` after successfully implementing any spec that introduces changes to:

1. **Project dependencies** (new packages, version bumps, removals)
2. **Directory structure or module organization** (new directories, moved components)
3. **Architecture patterns** (new layers, communication patterns, design patterns)
4. **CI/CD pipeline or quality gates** (new workflows, test requirements, deployment steps)
5. **Major feature areas** (new commands, core functionality additions)

**Rationale**: Living documentation prevents drift between code reality and agent expectations. Specific triggers ensure updates happen consistently without excessive maintenance burden. Surgical scope keeps rules actionable and focused.

## CI & Quality Gates

### Platform Coverage

CI pipeline MUST test on:
- Primary target platforms (defined in bootstrap spec)
- Representative platform matrix (e.g., macOS latest, Ubuntu LTS)
- Relevant language/runtime versions

### Required Checks

Before merge, ALL of the following MUST pass:
- ✅ All unit tests across all platforms
- ✅ All integration tests across all platforms
- ✅ All contract tests (CLI interface stability)
- ✅ Linting and formatting checks
- ✅ Build success on all platforms

### Failure Policy

If any check fails:
- Merge is BLOCKED
- Developer MUST fix root cause
- Re-run full CI suite
- No bypassing checks (no force merge)

## Agent Maintenance Rules

### .windsurf/rules Lifecycle

**Initial State**: Agent creates `.windsurf/rules` during or immediately after bootstrap spec implementation.

**Maintenance**: Agent updates `.windsurf/rules` after each successful spec implementation that triggers one of the five mandatory categories (dependencies, structure, architecture, CI, major features).

**Content**: Rules file MUST remain small and surgical:
- Current dependencies and their purpose
- Directory structure and module organization
- Established architectural patterns
- CI/CD pipeline overview
- Major feature areas and their locations
- Conventions (naming, organization, testing)

**Update Procedure**: When triggered:
1. Agent reads current `.windsurf/rules`
2. Identifies what changed in the completed spec
3. Updates relevant sections surgically (add/modify/remove only affected parts)
4. Keeps file concise and actionable

### Rules File Format

```markdown
# Subtree CLI - Agent Rules

Last Updated: [DATE] | Spec: [###-feature-name]

## Dependencies
- [List current dependencies and purpose]

## Structure
- [Current directory organization]

## Architecture
- [Established patterns and conventions]

## CI/CD
- [Pipeline overview and quality gates]

## Features
- [Major feature areas and locations]

## Conventions
- [Naming, testing, organization rules]
```

## Governance

### Supremacy

This constitution supersedes all other development practices, guidelines, and conventions. In case of conflict, constitution principles take precedence.

### Compliance

- All pull requests MUST verify compliance with constitutional principles
- Code reviews MUST check for spec-first discipline and test coverage
- CI gates enforce test and quality requirements automatically
- Complexity MUST be justified against constitutional simplicity principles

### Amendments

Constitution amendments require:
1. Clear documentation of the proposed change
2. Rationale for the amendment (why current principles insufficient)
3. Migration plan for existing code/specs if needed
4. Version bump following semantic versioning rules

### Versioning Rules

- **MAJOR**: Backward-incompatible governance changes, principle removals, or redefinitions
- **MINOR**: New principles added or material expansions to existing principles
- **PATCH**: Clarifications, wording improvements, typo fixes, non-semantic refinements

### Living Document

This constitution is a living document that evolves with the project. Agents and developers MUST keep it synchronized with project reality through the amendment process.

**Version**: 1.0.0 | **Ratified**: 2025-10-25 | **Last Amended**: 2025-10-25
