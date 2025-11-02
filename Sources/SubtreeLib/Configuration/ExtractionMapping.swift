/// Represents a saved file extraction configuration
///
/// Defines how to extract files from a subtree to the project structure using glob patterns.
/// Stored in subtree.yaml under each subtree's `extractions` array.
public struct ExtractionMapping: Codable, Equatable, Sendable {
    /// Source glob pattern for matching files within the subtree
    public let from: String
    
    /// Destination path (relative to repository root) where files are copied
    public let to: String
    
    /// Optional array of glob patterns to exclude from matches
    public let exclude: [String]?
    
    /// Initialize an extraction mapping
    ///
    /// - Parameters:
    ///   - from: Glob pattern matching source files (e.g., "docs/**/*.md")
    ///   - to: Destination path for copied files (e.g., "project-docs/")
    ///   - exclude: Optional array of glob patterns to exclude (e.g., ["docs/internal/**"])
    public init(from: String, to: String, exclude: [String]? = nil) {
        self.from = from
        self.to = to
        self.exclude = exclude
    }
}
