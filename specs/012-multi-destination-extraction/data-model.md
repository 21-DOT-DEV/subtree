# Data Model: Multi-Destination Extraction (Fan-Out)

**Feature**: 012-multi-destination-extraction  
**Date**: 2025-11-30

## Entity Changes

### ExtractionMapping (Modified)

**Location**: `Sources/SubtreeLib/Configuration/ExtractionMapping.swift`

**Current**:
```swift
public struct ExtractionMapping: Codable, Equatable, Sendable {
    public let from: [String]          // Array of patterns (from 009)
    public let to: String              // Single destination
    public let exclude: [String]?
}
```

**Proposed**:
```swift
public struct ExtractionMapping: Codable, Equatable, Sendable {
    public let from: [String]          // Array of patterns (unchanged)
    public let to: [String]            // Array of destinations (NEW - mirrors from)
    public let exclude: [String]?
    
    // MARK: - Initializers
    
    /// Single pattern, single destination (common case)
    public init(from: String, to: String, exclude: [String]? = nil) {
        self.from = [from]
        self.to = [to]
        self.exclude = exclude
    }
    
    /// Multiple patterns, single destination
    public init(fromPatterns: [String], to: String, exclude: [String]? = nil) {
        self.from = fromPatterns
        self.to = [to]
        self.exclude = exclude
    }
    
    /// Single pattern, multiple destinations (NEW)
    public init(from: String, toDestinations: [String], exclude: [String]? = nil) {
        self.from = [from]
        self.to = toDestinations
        self.exclude = exclude
    }
    
    /// Multiple patterns, multiple destinations (NEW)
    public init(fromPatterns: [String], toDestinations: [String], exclude: [String]? = nil) {
        self.from = fromPatterns
        self.to = toDestinations
        self.exclude = exclude
    }
    
    // MARK: - Custom Codable
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode `from` (existing logic from 009)
        if let patterns = try? container.decode([String].self, forKey: .from) {
            guard !patterns.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .from, in: container,
                    debugDescription: "from patterns cannot be empty"
                )
            }
            self.from = patterns
        } else {
            let single = try container.decode(String.self, forKey: .from)
            self.from = [single]
        }
        
        // Decode `to` (NEW - mirrors from)
        if let destinations = try? container.decode([String].self, forKey: .to) {
            guard !destinations.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .to, in: container,
                    debugDescription: "to destinations cannot be empty"
                )
            }
            self.to = destinations
        } else {
            let single = try container.decode(String.self, forKey: .to)
            self.to = [single]
        }
        
        self.exclude = try container.decodeIfPresent([String].self, forKey: .exclude)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode `from` as string if single, array if multiple
        if from.count == 1 {
            try container.encode(from[0], forKey: .from)
        } else {
            try container.encode(from, forKey: .from)
        }
        
        // Encode `to` as string if single, array if multiple (NEW)
        if to.count == 1 {
            try container.encode(to[0], forKey: .to)
        } else {
            try container.encode(to, forKey: .to)
        }
        
        try container.encodeIfPresent(exclude, forKey: .exclude)
    }
}
```

### Field Changes

| Field | Before | After | Notes |
|-------|--------|-------|-------|
| `to` | `String` | `[String]` | Internal representation always array |

### Validation Rules

| Rule | Enforcement | Error |
|------|-------------|-------|
| `to` cannot be empty | Decoding + init | "to destinations cannot be empty" |
| All elements must be strings | Decoding | "to must contain only strings" |
| At least one destination required | Init validation | "at least one destination required" |

### State Transitions

No state transitions — `ExtractionMapping` is a value type with no lifecycle.

## New Entity: PathNormalizer

**Location**: `Sources/SubtreeLib/Utilities/PathNormalizer.swift`

**Purpose**: Normalize and deduplicate destination paths.

```swift
/// Normalizes paths for deduplication (012-multi-destination-extraction)
///
/// Handles common path variations:
/// - Trailing slashes: `Lib/` → `Lib`
/// - Leading `./`: `./Lib` → `Lib`
/// - Combinations: `./Lib/` → `Lib`
public enum PathNormalizer {
    
    /// Normalize a single path
    public static func normalize(_ path: String) -> String {
        var result = path
        
        // Remove leading ./
        while result.hasPrefix("./") {
            result = String(result.dropFirst(2))
        }
        
        // Remove trailing / (except for root)
        while result.hasSuffix("/") && result.count > 1 {
            result = String(result.dropLast())
        }
        
        return result
    }
    
    /// Deduplicate paths after normalization, preserving order
    ///
    /// Returns the first occurrence of each normalized path,
    /// preserving the user's original formatting.
    public static func deduplicate(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        
        for path in paths {
            let normalized = normalize(path)
            if !seen.contains(normalized) {
                seen.insert(normalized)
                unique.append(path)  // Keep original form
            }
        }
        
        return unique
    }
}
```

## YAML Schema

### Before (Single Destination Only)
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
  
  # New array format for destinations
  - from: "include/**/*.h"
    to:
      - "Lib/headers/"
      - "Vendor/headers/"
    exclude:
      - "**/internal/**"
  
  # Combined: multi-pattern + multi-destination
  - from:
      - "include/**/*.h"
      - "src/**/*.c"
    to:
      - "Lib/"
      - "Vendor/"
```

## Relationships

```
SubtreeEntry
  └── extractions: [ExtractionMapping]?
        ├── from: [String]
        ├── to: [String]         # Modified: String → [String]
        └── exclude: [String]?
```

No relationship changes — `ExtractionMapping` remains a child of `SubtreeEntry.extractions`.

## Migration Notes

**Backward Compatibility**: 100% compatible. Existing configs with `to: "path/"` continue to work unchanged. The custom `Codable` implementation handles both string and array formats transparently.

**No Migration Required**: Users can optionally adopt array format when needed.
