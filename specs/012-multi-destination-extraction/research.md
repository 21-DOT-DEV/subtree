# Research: Multi-Destination Extraction (Fan-Out)

**Feature**: 012-multi-destination-extraction  
**Date**: 2025-11-30  
**Purpose**: Document patterns from 009-multi-pattern-extraction for reuse

## Research Summary

This feature mirrors 009-multi-pattern-extraction but applies to the `to` field instead of `from`. The implementation patterns are well-established and require no new research — only formal documentation for reference during implementation.

## Decision 1: Data Model Pattern (from 009)

**Decision**: Use `[String]` internally with custom `Codable` for backward compatibility.

**Rationale**: Proven pattern from 009. Internal array simplifies processing logic while custom encoding preserves clean YAML for single-element case.

**Alternatives Considered**:
- **Union type (enum)**: More complex code, no practical benefit over array approach
- **Always array in YAML**: Noisier config files for common single-destination case

**Source Reference**: `specs/009-multi-pattern-extraction/data-model.md`

```swift
// Pattern from 009 (for `from` field)
public struct ExtractionMapping: Codable {
    public let from: [String]  // Always array internally
    
    public init(from decoder: Decoder) throws {
        // Try array first, then single string
        if let patterns = try? container.decode([String].self, forKey: .from) {
            self.from = patterns
        } else {
            let single = try container.decode(String.self, forKey: .from)
            self.from = [single]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        // Serialize as string if single, array if multiple
        if from.count == 1 {
            try container.encode(from[0], forKey: .from)
        } else {
            try container.encode(from, forKey: .from)
        }
    }
}
```

## Decision 2: CLI Flag Pattern (from 009)

**Decision**: Use swift-argument-parser's native repeated `@Option` support.

**Rationale**: ArgumentParser handles `--to X --to Y` automatically when declared as `[String]`. No custom parsing needed.

**Source Reference**: `Sources/SubtreeLib/Commands/ExtractCommand.swift` line 131

```swift
// Current pattern (for --from)
@Option(name: .long, help: "Glob pattern to match files (can be repeated)")
var from: [String] = []

// New pattern (for --to) — identical
@Option(name: .long, help: "Destination path (can be repeated for fan-out)")
var to: [String] = []
```

## Decision 3: Deduplication Pattern

**Decision**: Normalize paths then deduplicate using `Set`.

**Rationale**: Simple and deterministic. Normalization handles common user variations.

**Normalization Rules** (from spec clarification):
1. Remove trailing slashes (`Lib/` → `Lib`)
2. Remove leading `./` (`./Lib` → `Lib`)
3. Compare after normalization

```swift
// New utility: PathNormalizer
public enum PathNormalizer {
    public static func normalize(_ path: String) -> String {
        var result = path
        // Remove leading ./
        while result.hasPrefix("./") {
            result = String(result.dropFirst(2))
        }
        // Remove trailing /
        while result.hasSuffix("/") && result.count > 1 {
            result = String(result.dropLast())
        }
        return result
    }
    
    public static func deduplicate(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for path in paths {
            let normalized = normalize(path)
            if !seen.contains(normalized) {
                seen.insert(normalized)
                unique.append(path)  // Preserve original form
            }
        }
        return unique
    }
}
```

## Decision 4: Fan-Out Execution Pattern

**Decision**: Sequential iteration over destinations with per-destination output.

**Rationale**: Simpler than parallel execution, sufficient for ≤10 destinations, easier to debug.

**Pattern**:
```swift
// Fan-out: copy same files to each destination
for destination in normalizedDestinations {
    for (sourcePath, relativePath) in matchedFiles {
        let destFilePath = destination + "/" + relativePath
        try copyFilePreservingStructure(from: sourcePath, to: destFilePath)
    }
    print("✅ Extracted \(matchedFiles.count) files to '\(destination)'")
}
```

## Decision 5: Fail-Fast Validation Pattern

**Decision**: Collect all conflicts across all destinations before any writes.

**Rationale**: Consistent with existing overwrite protection. Prevents partial state.

**Pattern**:
```swift
// Phase 1: Validate ALL destinations
var allConflicts: [(destination: String, file: String)] = []
for destination in destinations {
    let conflicts = checkForTrackedFiles(matchedFiles, destination)
    for file in conflicts {
        allConflicts.append((destination, file))
    }
}

// Phase 2: Fail if any conflicts (before any writes)
if !allConflicts.isEmpty {
    displayConflictErrors(allConflicts)
    exit(2)
}

// Phase 3: Execute (all destinations validated)
for destination in destinations {
    // ... copy files ...
}
```

## Decision 6: Progress Output Pattern

**Decision**: Per-destination summary lines (FR-017).

**Rationale**: Provides visibility without verbose per-file output. Matches existing emoji style.

**Pattern**:
```
✅ Extracted 5 files to 'Lib/'
✅ Extracted 5 files to 'Vendor/'
```

## Decision 7: Soft Limit Warning

**Decision**: Warn at >10 destinations, don't block (FR-016).

**Rationale**: Prevents accidental abuse while remaining permissive for edge cases.

**Pattern**:
```swift
if destinations.count > 10 {
    print("⚠️  Warning: \(destinations.count) destinations specified (>10)")
}
```

## No Further Research Needed

All patterns are established from:
- **009-multi-pattern-extraction**: Data model, CLI, deduplication
- **008-extract-command**: Overwrite protection, file copying
- **010-extract-clean**: Clean mode infrastructure

Implementation can proceed directly to Phase 1.
