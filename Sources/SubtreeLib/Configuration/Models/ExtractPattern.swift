import Foundation

/// Represents a file extraction rule for selective file copying from a subtree
///
/// Extract patterns allow users to copy specific files from a subtree to custom
/// locations in their project using glob patterns.
public struct ExtractPattern: Codable, Sendable {
    /// Source glob pattern for files to extract (FR-018, FR-019)
    /// Supports: **, *, ?, [...], {...}
    public let from: String
    
    /// Destination path for extracted files (FR-018, FR-029)
    /// Must be relative path, no `..` components
    public let to: String
    
    /// Optional exclusion patterns (FR-019)
    /// Files matching these patterns are excluded from extraction
    public let exclude: [String]?
    
    /// Initialize an extract pattern
    /// - Parameters:
    ///   - from: Source glob pattern
    ///   - to: Destination path
    ///   - exclude: Optional exclusion patterns
    public init(from: String, to: String, exclude: [String]? = nil) {
        self.from = from
        self.to = to
        self.exclude = exclude
    }
}
