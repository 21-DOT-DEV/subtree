/// Represents a saved file extraction configuration
///
/// Defines how to extract files from a subtree to the project structure using glob patterns.
/// Stored in subtree.yaml under each subtree's `extractions` array.
///
/// Both `from` and `to` fields support legacy string format and new array format:
/// - Legacy: `from: "pattern"`, `to: "path/"` (single value as string)
/// - New: `from: ["p1", "p2"]`, `to: ["Lib/", "Vendor/"]` (multiple values as array)
///
/// Internally, both fields are always stored as arrays for uniform processing.
/// Multi-destination extraction (012) enables fan-out: N files × M destinations.
public struct ExtractionMapping: Equatable, Sendable {
    /// Source glob patterns for matching files within the subtree
    /// Always stored as array internally; single patterns are wrapped
    public let from: [String]
    
    /// Destination paths (relative to repository root) where files are copied
    /// Always stored as array internally; single destinations are wrapped
    /// Fan-out: files are copied to EVERY destination in this array
    public let to: [String]
    
    /// Optional array of glob patterns to exclude from matches
    public let exclude: [String]?
    
    // MARK: - CodingKeys
    
    private enum CodingKeys: String, CodingKey {
        case from
        case to
        case exclude
    }
    
    // MARK: - Initializers
    
    /// Initialize an extraction mapping with a single pattern and single destination (common case)
    ///
    /// - Parameters:
    ///   - from: Single glob pattern matching source files (e.g., "docs/**/*.md")
    ///   - to: Single destination path for copied files (e.g., "project-docs/")
    ///   - exclude: Optional array of glob patterns to exclude (e.g., ["docs/internal/**"])
    public init(from: String, to: String, exclude: [String]? = nil) {
        self.from = [from]
        self.to = [to]
        self.exclude = exclude
    }
    
    /// Initialize an extraction mapping with multiple patterns and single destination
    ///
    /// Use this initializer when extracting files from multiple directories to one destination.
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
    ///   - to: Single destination path for copied files (relative to repository root)
    ///   - exclude: Optional array of glob patterns to exclude (applies to all patterns)
    public init(fromPatterns: [String], to: String, exclude: [String]? = nil) {
        self.from = fromPatterns
        self.to = [to]
        self.exclude = exclude
    }
    
    /// Initialize an extraction mapping with a single pattern and multiple destinations (012-multi-destination)
    ///
    /// Use this initializer for fan-out extraction: one pattern → multiple destinations.
    /// Files matching the pattern are copied to EVERY destination.
    ///
    /// Example:
    /// ```swift
    /// let mapping = ExtractionMapping(
    ///     from: "include/**/*.h",
    ///     toDestinations: ["Lib/", "Vendor/"]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - from: Single glob pattern matching source files
    ///   - toDestinations: Array of destination paths (each receives all matched files)
    ///   - exclude: Optional array of glob patterns to exclude
    public init(from: String, toDestinations: [String], exclude: [String]? = nil) {
        self.from = [from]
        self.to = toDestinations
        self.exclude = exclude
    }
    
    /// Initialize an extraction mapping with multiple patterns and multiple destinations (012-multi-destination)
    ///
    /// Use this initializer for combined fan-out: union of patterns → multiple destinations.
    /// Files matching ANY pattern are copied to EVERY destination (N files × M destinations).
    ///
    /// Example:
    /// ```swift
    /// let mapping = ExtractionMapping(
    ///     fromPatterns: ["include/**/*.h", "src/**/*.c"],
    ///     toDestinations: ["Lib/", "Vendor/"]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - fromPatterns: Array of glob patterns (processed as union)
    ///   - toDestinations: Array of destination paths (each receives all matched files)
    ///   - exclude: Optional array of glob patterns to exclude
    public init(fromPatterns: [String], toDestinations: [String], exclude: [String]? = nil) {
        self.from = fromPatterns
        self.to = toDestinations
        self.exclude = exclude
    }
}

// MARK: - Codable

extension ExtractionMapping: Codable {
    
    /// Custom decoder that handles both string and array formats for `from` and `to` fields
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode `from`: try array first, fall back to single string
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
        
        // Decode `to`: try array first, fall back to single string (012-multi-destination)
        if let destinations = try? container.decode([String].self, forKey: .to) {
            // Validate: reject empty arrays
            guard !destinations.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .to,
                    in: container,
                    debugDescription: "to destinations cannot be empty"
                )
            }
            self.to = destinations
        } else {
            // Fall back to single string (legacy format)
            let single = try container.decode(String.self, forKey: .to)
            self.to = [single]
        }
        
        self.exclude = try container.decodeIfPresent([String].self, forKey: .exclude)
    }
    
    /// Custom encoder that outputs string for single value, array for multiple
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Serialize `from` as string if single, array if multiple
        if from.count == 1 {
            try container.encode(from[0], forKey: .from)
        } else {
            try container.encode(from, forKey: .from)
        }
        
        // Serialize `to` as string if single, array if multiple (012-multi-destination)
        if to.count == 1 {
            try container.encode(to[0], forKey: .to)
        } else {
            try container.encode(to, forKey: .to)
        }
        
        try container.encodeIfPresent(exclude, forKey: .exclude)
    }
}
