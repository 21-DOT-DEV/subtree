# Data Model: Subtree CLI

## `subtree.yaml` Schema (conceptual)
```yaml
# Repository-root configuration for Subtree CLI
subtrees:
  - name: <string>             # unique identifier (kebab-case recommended)
    remote: <string>           # git remote URL (https or ssh)
    prefix: <string>           # repository path where subtree is placed (e.g., Sources/ThirdParty/Foo)
    branch: <string>           # upstream branch to pull/push (e.g., main)
    squash: <bool>             # optional; default: true. If true, use --squash for add/update
    commit: <git-sha>          # optional; commit used for validate/repair (set on successful add/update)
    copies:                    # optional; declared extract mappings for this subtree
      - from: <path-or-glob>   # relative to subtree prefix; supports files, directories, and globs (e.g., **/*.md)
        to: <path>             # relative to repository root; if multiple matches, must be a directory
    update:                    # optional; update policy for this subtree
      mode: branch|tag|release # default: branch (track configured branch tip)
      constraint: <semver>     # optional; SemVer range (applies to tag/release modes)
      includePrereleases: false# optional; default false (applies to tag/release modes)
```

## Entities
- SubtreeConfig
  - fields:
    - `subtrees`: [SubtreeEntry]
- SubtreeEntry
  - fields:
    - `name`: String (non-empty, unique across entries)
    - `remote`: String (non-empty, valid git URL)
    - `prefix`: String (non-empty, relative path within repo)
    - `branch`: String (non-empty)
    - `squash`: Bool (default true)
    - `commit`: String? (optional git commit SHA used as known-good reference)
    - `copies`: [CopyMapping]? (optional)
    - `update`: UpdatePolicy? (optional)

- CopyMapping
  - fields:
    - `from`: String (relative to subtree `prefix`; file, directory, or glob)
    - `to`: String (relative to repository root). If `from` expands to multiple items, `to` MUST be a directory.

- UpdatePolicy
  - fields:
    - `mode`: Enum(branch, tag, release) — default branch
    - `constraint`: String? — optional SemVer range (tag/release modes)
    - `includePrereleases`: Bool? — optional, default false (tag/release modes)

## Validation Rules
- `subtrees` MUST be present and contain >= 1 entry for add/update/remove to operate
- Each `name` MUST be unique
- `remote` MUST be a syntactically valid URL or SSH spec (e.g., git@github.com:org/repo.git)
- `prefix` MUST be a normalized relative path (no `..`, no leading `/`)
- `branch` MUST be a non-empty string
- `copies[*].from` MUST be relative to `prefix`; `copies[*].to` MUST be relative to repo root
- If `from` is a directory or glob matching multiple items, `to` MUST be a directory; relative structure is preserved
- Globs are allowed in `from`; empty matches are invalid (treated as usage error)
- No duplicate (from, to) pairs per subtree
- If `update.mode` is `tag` or `release` and `constraint` is present, it MUST be a valid SemVer range
- `includePrereleases` applies only to `tag`/`release` modes; defaults to false when omitted

## Derived Behavior
- `add`: `git subtree add --prefix <prefix> <remote> <branch> [--squash]`
- `update`: `git subtree pull --prefix <prefix> <remote> <branch> [--squash]`
  - Target commit determined by `update` policy: default branch tip; in tag/release modes select newest tag/release satisfying `constraint` and `includePrereleases` (release = annotated tags discovered via `git fetch --tags`).
- `remove`: remove subtree content at `<prefix>` and clean history as documented; return exit 0 on success, 3 on git failure
- `extract` (declared): iterate `copies` entries per subtree to extract sources (under `prefix`) to targets (repo root relative)
- `validate`: compare subtree `prefix` against `commit` commit tree; compare each declared `from` vs `to` for identity; `--repair` resets to `commit` and re-copies (no pruning by default)

## Example
```yaml
subtrees:
  - name: "example-lib"
    remote: "https://github.com/example/example-lib.git"
    prefix: "Sources/ThirdParty/ExampleLib"
    branch: "main"
    squash: true
    commit: "0123456789abcdef0123456789abcdef01234567"
    update:
      mode: "tag"
      constraint: "^1.2"
      includePrereleases: false
    copies:
      - from: "docs/README.md"
        to: "Docs/ExampleLib.md"
      - from: "templates/**"
        to: "Templates/ExampleLib/"
```
