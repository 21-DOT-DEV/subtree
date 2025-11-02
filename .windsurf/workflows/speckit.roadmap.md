---
description: Create or update the product roadmap from a natural language product description (user-facing features, milestones, releases)
auto_execution_mode: 1
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

You are creating or updating the user-facing **product roadmap** at `.specify/memory/roadmap.md`. The roadmap gives a **high-level view** of the product: feature areas, phased releases, dependencies, and success metrics. It is designed to feed directly into follow‑on Spec‑Kit flows (e.g., `/speckit.specify` for individual features). **Roadmap versioning MUST mirror the constitution style: version and dates live INSIDE the markdown document, not in a separate JSON file.**

Follow this execution flow:

1. **Load or create the roadmap artifact**
   - If `.specify/memory/roadmap.md` exists, load it and treat this run as an update (append and revise).
   - If it doesn’t exist, create a new file with the structure below.

2. **Gather context (if present)**
   - Read `.specify/memory/constitution.md` for principles, guardrails, and constraints that should inform prioritization.
   - Read `README.md` (or top-level docs) for product positioning and target audience.
   - Prefer explicit user input from `$ARGUMENTS`; otherwise infer from context and document assumptions.

3. **Interpret the user request**
   - The user’s input describes the **product vision** and any **must‑have** areas.
   - If timing is mentioned, include it. If not, keep timing **optional** and express releases as **Phase 1, Phase 2, ...**

4. **Propose Roadmap Structure (auto‑generated)**
   - **Vision & Goals** (succinct product statement, target users, primary outcomes)
   - **Release Plan** (Phases or dated milestones; timing optional)
   - **Feature Areas** (grouped capabilities aligned to outcomes)
   - **Feature Backlog** (sortable list for future phases)
   - **Dependencies & Sequencing** (what must exist before what)
   - **Metrics & Success Criteria** (user‑facing, technology‑agnostic)
   - **Risks & Assumptions**
   - **Change Log** (roadmap versioning metadata)

5. **Generate feature entries (moderate detail for each item)**
   For each feature/milestone include exactly these fields:
   - **Name** — concise, user‑recognizable
   - **Purpose & user value** — the “why” in 1–2 sentences
   - **Success metrics** — measurable, user‑facing outcomes (3–5 bullets)
   - **Dependencies** — other features or prerequisites
   - **(Optional) Notes** — constraints, policy, or rollout considerations

6. **Create releases/phases**
   - If **time granularity** was provided, render releases with dates/quarters.
   - If **time is not provided**, render **Phase 1/2/3** (or **MVP / v1 / v2**) with a short goal statement and 3–7 features each.
   - Ensure **each release delivers user value** end‑to‑end.

7. **Derive Dependencies & Sequencing**
   - Build a simple ordering list (e.g., `Auth → Profiles → Sharing → Notifications`) and annotate any cross‑release dependencies.
   - Keep it readable (bullets or simple table), not an engineering Gantt.

8. **Define Metrics & Success Criteria (product‑level)**
   - Choose 4–8 KPIs tied to user value (adoption, activation, retention, satisfaction, revenue proxy, support volume, etc.).
   - Keep them **technology‑agnostic** and verifiable without implementation details.

9. **Seed next steps for feature iteration**
   - For every feature, output a one‑line **follow‑on command hint** to create a spec later, e.g.:
     ```text
     Next: /speckit.specify "Feature: Smart Notifications — deliver timely, non‑spammy updates to increase 7‑day retention"
     ```

10. **Versioning & write output**
    - Maintain version **inside** `.specify/memory/roadmap.md` header.
    - If creating a new roadmap: set `Version: v1.0.0`, set `Last Updated` to today, and add a Change Log entry (“initial roadmap”). Optionally include `Initiated Date` in the header if helpful.
    - If updating an existing roadmap: **increment version** using semantic rules aligned with the constitution:
      - **MAJOR**: Backward‑incompatible strategy shift or phase re‑architecture (significant scope redefinition).
      - **MINOR**: New feature area added, milestone reordered materially, or notable scope expansion.
      - **PATCH**: Textual clarifications or minor edits that don’t change intent or sequencing.
    - If the bump type is ambiguous, **propose reasoning** in a one‑line note under the Change Log entry.
    - Write the full roadmap to `.specify/memory/roadmap.md` (overwrite or create). **Do not write any JSON file.**

11. **Validation before final output**
    - Roadmap contains **Vision & Goals**, **Release Plan**, **Feature Areas**, **Metrics**, **Dependencies**, **Risks/Assumptions**, **Change Log**.
    - Each feature has **Name, Purpose, Success metrics, Dependencies** (Notes optional).
    - Success metrics are **user‑facing** and **technology‑agnostic**.
    - If critical unknowns remain, include up to **3** `[NEEDS CLARIFICATION: …]` markers (max three). Prioritize by impact (scope > compliance/privacy > UX > technical).

12. **Report completion (console output)**
    - Show: roadmap version change, number of releases, feature count, and a short list of the next three `/speckit.specify` hints.

---

## Roadmap Document Structure (use this exact Markdown scaffold)

```markdown
# Product Roadmap

**Version:** vX.Y.Z  
**Last Updated:** YYYY-MM-DD

## Vision & Goals
- One-sentence product vision.
- Target users / personas.
- Top 3 outcomes (business/user).

## Release Plan
> Timing is optional. Use Phase 1/2/3 if dates are not provided.

### Phase 1 — Goal: <short phrase or date/quarter>
**Key Features**
1. <Feature Name>  
   - Purpose & user value: <1–2 sentences>  
   - Success metrics:  
     - <metric 1>  
     - <metric 2>  
     - <metric 3>  
   - Dependencies: <list or “none”>  
   - Notes: <optional>

2. <Feature Name> …

### Phase 2 — Goal: <short phrase or date/quarter>
**Key Features**
- …

### Future Phases / Backlog
- <Backlog Feature> — Purpose, success metrics (brief), dependencies
- …

## Feature Areas (capability map)
- Area A: features that support <outcome>
- Area B: …

## Dependencies & Sequencing
- Ordering: A → B → C (brief rationale)
- Cross-release dependencies: <if any>

## Metrics & Success Criteria (product‑level)
- Activation rate reaches <X%>
- 7-day retention improves to <Y%>
- NPS ≥ <Z>
- Support tickets per active user ≤ <T>

## Risks & Assumptions
- Assumptions: <bullets>
- Risks & mitigations: <bullets>

## Change Log
- vX.Y.Z (YYYY-MM-DD): <summary> — <bump type & rationale>
- vX.Y.(Z-1) (YYYY-MM-DD): <summary>
```

---

## General Guidelines

### Quick Guidelines
- Focus on **WHAT** users get and **WHY** it matters.
- Avoid **HOW** to implement (no frameworks, APIs, code structures).
- Each release must ship a coherent **slice of value**.
- Keep wording accessible to non‑technical stakeholders.
- Keep timing **optional** unless the user provided it.

### Section Requirements
- **Mandatory**: Vision & Goals, Release Plan, Feature list with metrics, Dependencies & Sequencing, Metrics (product‑level), Risks & Assumptions, Change Log.
- **Optional**: Dates/quarters for releases, Notes per feature, Capability map if already clear.

### For AI Generation
1. **Make informed guesses** using domain norms when unspecified; document in **Assumptions**.
2. **Limit clarifications** to max **3** markers; only when multiple reasonable interpretations with material impact exist.
3. **Prioritize clarifications**: scope > privacy/compliance > UX > technical.
4. **Think like a PM & tester**: every feature must have measurable user outcomes.

### Success Metrics Guidelines (user‑facing, tech‑agnostic)
Good examples:
- “Users can complete onboarding in under 2 minutes.”
- “Weekly active creators ↑ 25% within one release.”
- “Support tickets per 1k MAU ↓ 30%.”
- “Checkout conversion improves from 18% → 25%.”

Avoid (implementation‑focused):
- “API latency under 200ms.”
- “Database handles 1k TPS.”
- “React components render efficiently.”

---

## Write Target
- `.specify/memory/roadmap.md` (single authoritative source; versioned inline)

## Output Summary (console)
- `roadmap: vA.B.C → vX.Y.Z` (reason for bump)
- `releases: <n> | features: <m>`
- Next steps:
  - `Next: /speckit.specify "<Feature 1: …>"`
  - `Next: /speckit.specify "<Feature 2: …>"`
  - `Next: /speckit.specify "<Feature 3: …>"`

## IMPORTANT
- Do **not** embed implementation details.
- Keep metrics **verifiable without code**.
- Respect the project constitution if present.
- If no product description was provided in `$ARGUMENTS`, return: `ERROR "No product description provided"`.
