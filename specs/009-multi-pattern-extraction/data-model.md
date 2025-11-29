# Data Model: Multi-Pattern Extraction

**Feature**: 009-multi-pattern-extraction  
**Date**: 2025-11-28

## Entity Changes

### ExtractionMapping (Modified)

**Location**: `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`

**Current**:
```swift
public struct ExtractionMapping: Codable, Equatable, Sendable {
    public let from: String           // Single pattern
    public let to: String
    public let exclude: [String]?
}
```

**Proposed**:
```swift
public struct ExtractionMapping: Codable, Equatable, Sendable {
    public let from: [String]         // Array of patterns (always normalized)
    public let to: String
    public let exclude: [String]?
    
    // Convenience for single pattern
    public init(from: String, to: String, exclude: [String]? = nil) {
        self.from = [from]
        self.to = to
        self.exclude = exclude
    }
    
    // Full initializer for multiple patterns
    public init(fromPatterns: [String], to: String, exclude: [String]? = nil) {
        self.from = fromPatterns
        self.to = to
        self.exclude = exclude
    }
    
    // Custom Codable for backward compatibility
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try array first, then single string
        if let patterns = try? container.decode([String].self, forKey: .from) {
            self.from = patterns
        } else {
            let single = try container.decode(String.self, forKey: .from)
            self.from = [single]
        }
        
        self.to = try container.decode(String.self, forKey: .to)
        self.exclude = try container.decodeIfPresent([String].self, forKey: .exclude)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Serialize as string if single, array if multiple
        if from.count == 1 {
            try container.encode(from[0], forKey: .from)
        } else {
            try container.encode(from, forKey: .from)
        }
        
        try container.encode(to, forKey: .to)
        try container.encodeIfPresent(exclude, forKey: .exclude)
    }
}
```

### Field Changes

| Field | Before | After | Notes |
|-------|--------|-------|-------|
| `from` | `String` | `[String]` | Internal representation always array |

### Validation Rules

| Rule | Enforcement | Error |
|------|-------------|-------|
| `from` cannot be empty | Decoding + init | "from patterns cannot be empty" |
| All elements must be strings | Decoding | "from must contain only strings" |
| At least one pattern required | Init validation | "at least one pattern required" |

### State Transitions

No state transitions — `ExtractionMapping` is a value type with no lifecycle.

## YAML Schema

### Before (Single Pattern Only)
```yaml
extractions:
  - from: "include/**/*.h"
    to: "vendor/headers/"
    exclude:
      - "**/internal/**"
```

### After (Both Formats Supported)
```yaml
extractions:
  # Legacy format (still works)
  - from: "include/**/*.h"
    to: "vendor/headers/"
  
  # New array format
  - from:
      - "include/**/*.h"
      - "src/**/*.c"
    to: "vendor/source/"
    exclude:
      - "**/test_*"
```

## Relationships

```
SubtreeEntry
  └── extractions: [ExtractionMapping]?
        └── from: [String]        # Modified
        └── to: String
        └── exclude: [String]?
```

No relationship changes — `ExtractionMapping` remains a child of `SubtreeEntry.extractions`.
