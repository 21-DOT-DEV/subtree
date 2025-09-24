# Research: Subtree CLI — git subtree manager

## Decisions
- Language/Runtime: Swift + Swift Package Manager (SPM)
- Dependencies:
  - swift-argument-parser — robust command/subcommand definitions and help generation
  - Yams — YAML parsing/writing for `subtree.yaml`
  - swift-subprocess — cross-platform process execution for `git` calls with explicit exit status
- Exit codes (v1): 0 success, 1 general error, 2 invalid usage/config, 3 git command failure, 4 config file not found
- Repo root resolution: always resolve upward to repository root; outside a Git repo returns exit 3
- Interaction model: non-interactive by default; optional interactive init (`subtree init --interactive`, TTY only) for guided setup/import
- Output channels: human-readable output to STDOUT; errors/diagnostics to STDERR; no JSON mode in v1 (constitution permits JSON only when applicable)
- Distribution: GitHub Releases (prebuilt binaries) with SHA-256 checksums and CHANGELOG entry
 - Update mode: default branch tip; support tag/release policies per subtree with SemVer constraints and optional pre-releases
 - SemVer handling: implement minimal SemVer parse/compare in-house to avoid extra dependencies

## Rationale
- argument-parser: standard, maintained, high-quality UX for CLIs
- Yams: mature Swift YAML library, widely used
- swift-subprocess: consistent subprocess handling and exit codes across macOS/Linux/Windows
- Explicit exit codes: align with constitution; simplify scripting and CI integration
- Upward repo resolution: aligns with typical Git tooling behavior; supports running from subdirectories
- Non-interactive default: pipeline-friendly; interactive init available on TTY for guided configuration
 - SemVer in-house: small surface area; keeps dependency footprint minimal; easier to maintain alongside git plumbing approach (e.g., `git hash-object`)

## Alternatives Considered
- Use `Process`/`Foundation` directly (rejected): more boilerplate, less ergonomic error handling
- TOML/JSON for config (rejected): YAML better matches developer expectations for repo tool configs
- Adding JSON output in v1 (deferred): not required for initial user value; can be added later without breaking human-readable flows

## Open Questions (Resolved)
- Outside a Git repo: return 3 (git failure) — decided
- From subdirectories: always resolve to repo root — decided

## Risks & Mitigations
- Windows path handling and quoting: validate `swift-subprocess` behavior; add tests on Windows matrix
- Git availability in PATH: detect and report with clear error (exit 3)
- YAML schema drift: validate on load; provide actionable errors with fix hints
