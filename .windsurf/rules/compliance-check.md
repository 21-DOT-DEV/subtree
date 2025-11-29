---
trigger: always_on
---

Before starting any feature work or behavior change, read `.specify/memory/constitution.md` and verify your approach complies with all six core principles:

1. **Spec-First & Test-Driven Development** — Spec before code, tests before implementation
2. **Config as Source of Truth** — All behavior driven by `subtree.yaml`
3. **Safe by Default** — Non-destructive defaults, `--force` gates for destructive ops
4. **Performance by Default** — Operations within documented time limits
5. **Security & Privacy by Design** — Shell safety, no secrets in logs/config
6. **Open Source Excellence** — Clear docs, KISS/DRY, readable code

After completing feature work:
- Verify final compliance with all principles
- Check if `.windsurf/rules` updates needed per Implementation Guidance triggers:
  1. Project dependencies changed
  2. Directory structure changed
  3. Architecture patterns changed
  4. CI/CD pipeline changed
  5. Major features added
