
# Implementation Plan: Subtree CLI — git subtree manager

**Branch**: `001-i-am-building` | **Date**: 2025-09-22 | **Spec**: /Users/csjones/Developer/subtree/specs/001-i-am-building/spec.md
**Input**: Feature specification from /Users/csjones/Developer/subtree/specs/001-i-am-building/spec.md

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Build a Swift + SPM CLI named `subtree` to simplify managing `git subtree` operations with a declarative `subtree.yaml` at the repository root. The CLI provides `init`, `add`, `update`, `remove`, `extract`, and `validate` commands, prints a short description and top‑level commands with no arguments, emits human‑readable output to STDOUT, and uses explicit exit codes with diagnostics to STDERR. Implementation will use `swift-argument-parser`, `Yams` for YAML, and `swift-subprocess` for robust `git` execution. Outside a Git repo returns exit 3; the tool resolves upward to the repo root when run from subdirectories. For `init`, we support non‑interactive minimal config (may import when safe), an explicit non‑interactive `--import` scan, and a TTY‑only `--interactive` guided setup. `extract` supports files/dirs/globs and records mappings under each subtree; `validate` is offline by default against a commit hash with optional `--repair` and `--with-remote`.

## Technical Context
**Language/Version**: Swift (SPM), toolchain 6.x  
**Primary Dependencies**: swift-argument-parser; Yams; swift-subprocess  
**Storage**: N/A  
**Testing**: swift-testing (TDD; unit + integration via subprocess)  
**Target Platform**: macOS (arm64, x86_64); Linux glibc (x86_64, arm64); Windows (arm64, x86_64)  
**Project Type**: single (CLI)  
**Performance Goals**: Typical command latency < 1s on small repos; graceful progress on large histories  
**Constraints**: Deterministic exit codes; non-interactive by default; upward repo root resolution; no network calls beyond `git`; dereference symlinks by default on copy; overwrite untracked by default, block modified/tracked unless `--force`; declared vs ad‑hoc copy modes are mutually exclusive  
**Scale/Scope**: Single executable `subtree`; v1 scope includes init/add/update/remove and new extract/validate flows

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Gates derived from `.specify/memory/constitution.md` (v1.0.0):
- CLI I/O Contract: STDOUT for normal output; STDERR for errors; explicit exit codes (0,1,2,3,4). PASS (spec §§ User Scenarios, FR-007/FR-008)
- Test-First & CI: TDD required; tests for success/failure/edge cases; multi-OS matrix planned. PASS (documented in plan; to be enforced in CI)
- Versioning & Releases: SemVer; GitHub Releases with checksums and CHANGELOG. PASS (documented; to set up in release workflow)
- Cross-Platform Builds: macOS/Linux/Windows targets; avoid OS-specific assumptions. PASS (dependencies selected for portability)
- Exit Codes & Error Handling: deterministic codes; clear diagnostics; no secret leakage. PASS (FR-007/FR-008; research notes)

Initial Constitution Check: PASS

## Project Structure

### Documentation (this feature)
```
specs/[###-feature]/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
# Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure]
```

**Structure Decision**: Option 1 (single project, Swift + SPM). SPM layout:
```
Sources/Subtree/
Tests/SubtreeTests/
```

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas
   - Tests must fail (no implementation yet)

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `.specify/scripts/bash/update-agent-context.sh windsurf`
     **IMPORTANT**: Execute it exactly as specified above. Do not add or remove any arguments.
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Load `.specify/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (contracts, data model, quickstart)
- Each contract → contract test task [P]
- Each entity → model creation task [P] 
- Each user story → integration test task
- Implementation tasks to make tests pass

**Ordering Strategy**:
- TDD order: Tests before implementation 
- Dependency order: Models before services before UI
- Mark [P] for parallel execution (independent files)

**Estimated Output**: 25-30 numbered, ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |


## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented

---
*Based on Constitution v1.0.0 - See `.specify/memory/constitution.md`*
