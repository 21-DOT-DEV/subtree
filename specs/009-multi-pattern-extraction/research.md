# Research: Multi-Pattern Extraction

**Feature**: 009-multi-pattern-extraction  
**Date**: 2025-11-28

## Research Questions

### Q1: How to implement union type for `from` field in Swift Codable?

**Decision**: Use custom `init(from decoder:)` with `singleValueContainer` fallback.

**Rationale**: Swift's `Codable` supports custom decoding. Try decoding as array first, then fall back to single string (wrapped in array). This provides seamless backward compatibility.

**Implementation Pattern**:
```swift
public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    // Try array first, then single string
    if let patterns = try? container.decode([String].self, forKey: .from) {
        self.from = patterns
    } else {
        let single = try container.decode(String.self, forKey: .from)
        self.from = [single]
    }
    // ... rest of fields
}
```

**Alternatives Considered**:
- **Separate `fromPatterns` field**: Rejected — adds config verbosity, requires deprecation cycle
- **Always array in storage**: Rejected — breaks backward compatibility with existing configs

---

### Q2: How to accept multiple `--from` flags in swift-argument-parser?

**Decision**: Change `@Option var from: String` to `@Option var from: [String]`.

**Rationale**: swift-argument-parser natively supports array options. Users can repeat the flag: `--from 'a' --from 'b'`. Single usage still works.

**Implementation Pattern**:
```swift
@Option(name: .long, help: "Glob pattern(s) to match files")
var from: [String] = []
```

**Alternatives Considered**:
- **Comma-separated string**: Rejected — conflicts with brace expansion in globs `{a,b}`
- **Positional arguments**: Rejected — conflicts with existing CLI structure

---

### Q3: How to merge pattern results without duplicates?

**Decision**: Use `Set<String>` to collect matched file paths, then convert to sorted array.

**Rationale**: Set automatically deduplicates. Sorting ensures deterministic output order.

**Implementation Pattern**:
```swift
var matchedFiles = Set<String>()
for pattern in patterns {
    let matches = try globMatcher.match(pattern: pattern, in: subtreePath)
    matchedFiles.formUnion(matches)
}
let sortedFiles = matchedFiles.sorted()
```

**Alternatives Considered**:
- **Array with contains check**: Rejected — O(n²) for large file sets
- **Dictionary keyed by path**: Rejected — Set is simpler for this use case

---

### Q4: How to serialize array format when persisting?

**Decision**: Always serialize `from` as array when multiple patterns exist, string when single.

**Rationale**: Preserves human-readable YAML for simple cases while supporting arrays.

**Implementation Pattern**:
```swift
public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    
    if from.count == 1 {
        try container.encode(from[0], forKey: .from)  // String format
    } else {
        try container.encode(from, forKey: .from)     // Array format
    }
    // ... rest of fields
}
```

**Alternatives Considered**:
- **Always array**: Rejected — makes simple configs verbose
- **User choice flag**: Rejected — unnecessary complexity

---

## Technology Decisions Summary

| Decision | Choice | Confidence |
|----------|--------|------------|
| Union type implementation | Custom Codable with try/fallback | High |
| CLI multiple values | Native `[String]` option type | High |
| Deduplication | Set-based collection | High |
| Serialization format | Single=string, multiple=array | High |

## Dependencies

No new dependencies required. All implementation uses existing:
- swift-argument-parser 1.6.1 (native array option support)
- Yams 6.1.0 (handles both string and array YAML)
- Swift standard library (Set for deduplication)
