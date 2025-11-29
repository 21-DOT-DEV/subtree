/// Represents a saved file extraction configuration
///
/// Defines how to extract files from a subtree to the project structure using glob patterns.
/// Stored in subtree.yaml under each subtree's `extractions` array.
///
/// The `from` field supports both legacy string format and new array format:
/// - Legacy: `from: "pattern"` (single pattern as string)
/// - New: `from: ["p1", "p2"]` (multiple patterns as array)
///
/// Internally, patterns are always stored as an array for uniform processing.
public struct ExtractionMapping: Equatable, Sendable {
    /// Source glob patterns for matching files within the subtree
    /// Always stored as array internally; single patterns are wrapped
    public let from: [String]
    
    /// Destination path (relative to repository root) where files are copied
    public let to: String
    
    /// Optional array of glob patterns to exclude from matches
    public let exclude: [String]?
    
    // MARK: - CodingKeys
    
    private enum CodingKeys: String, CodingKey {
        case from
        case to
        case exclude
    }
    
    // MARK: - Initializers
    
    /// Initialize an extraction mapping with a single pattern (convenience)
    ///
    /// - Parameters:
    ///   - from: Single glob pattern matching source files (e.g., "docs/**/*.md")
    ///   - to: Destination path for copied files (e.g., "project-docs/")
    ///   - exclude: Optional array of glob patterns to exclude (e.g., ["docs/internal/**"])
    public init(from: String, to: String, exclude: [String]? = nil) {
        self.from = [from]
        self.to = to
        self.exclude = exclude
    }
    
    /// Initialize an extraction mapping with multiple patterns (009-multi-pattern-extraction)
    ///
    /// Use this initializer when extracting files from multiple directories in a single mapping.
    /// Files matching ANY pattern are included (union behavior), and duplicates are removed.
    ///
    /// Example:
    /// ```swift
    /// let mapping = ExtractionMapping(
    ///     fromPatterns: ["include/**/*.h", "src/**/*.c"],
    ///     to: "vendor/"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - fromPatterns: Array of glob patterns matching source files (processed as union)
    ///   - to: Destination path for copied files (relative to repository root)
    ///   - exclude: Optional array of glob patterns to exclude (applies to all patterns)
    public init(fromPatterns: [String], to: String, exclude: [String]? = nil) {
        self.from = fromPatterns
        self.to = to
        self.exclude = exclude
    }
}

// MARK: - Codable

extension ExtractionMapping: Codable {
    
    /// Custom decoder that handles both string and array formats for `from` field
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try decoding as array first, then fall back to single string
        if let patterns = try? container.decode([String].self, forKey: .from) {
            // Validate: reject empty arrays
            guard !patterns.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .from,
                    in: container,
                    debugDescription: "from patterns cannot be empty"
                )
            }
            self.from = patterns
        } else {
            // Fall back to single string (legacy format)
            let single = try container.decode(String.self, forKey: .from)
            self.from = [single]
        }
        
        self.to = try container.decode(String.self, forKey: .to)
        self.exclude = try container.decodeIfPresent([String].self, forKey: .exclude)
    }
    
    /// Custom encoder that outputs string for single pattern, array for multiple
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Serialize as string if single pattern, array if multiple
        if from.count == 1 {
            try container.encode(from[0], forKey: .from)
        } else {
            try container.encode(from, forKey: .from)
        }
        
        try container.encode(to, forKey: .to)
        try container.encodeIfPresent(exclude, forKey: .exclude)
    }
}
