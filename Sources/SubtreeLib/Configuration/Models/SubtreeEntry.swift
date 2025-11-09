import Foundation

/// Represents a single subtree dependency definition
///
/// This model captures all information about a subtree including its source repository,
/// local path, version tracking, and optional file extraction rules.
public struct SubtreeEntry: Codable, Sendable {
    /// Unique name identifying this subtree (FR-005, FR-030)
    public let name: String
    
    /// Git repository URL (FR-006)
    /// Format: https://, git@, or file://
    public let remote: String
    
    /// Local path where subtree is placed (FR-007)
    /// Must be relative path, no `..` components
    public let prefix: String
    
    /// Git commit SHA-1 hash (FR-008)
    /// Must be 40 hexadecimal characters
    public let commit: String
    
    /// Optional git tag (FR-009)
    /// Mutually exclusive with branch per FR-012
    public let tag: String?
    
    /// Optional git branch (FR-009)
    /// Mutually exclusive with tag per FR-012
    public let branch: String?
    
    /// Optional squash flag (FR-010)
    /// Controls whether subtree history is squashed
    public let squash: Bool?
    
    /// Optional file extraction patterns (FR-011)
    /// Defines selective file copying from subtree
    public let extracts: [ExtractPattern]?
    
    /// Optional extraction mappings (008-extract-command)
    /// Defines saved file extraction configurations from subtree to project
    public let extractions: [ExtractionMapping]?
    
    /// Initialize a subtree entry with required and optional fields
    public init(
        name: String,
        remote: String,
        prefix: String,
        commit: String,
        tag: String? = nil,
        branch: String? = nil,
        squash: Bool? = nil,
        extracts: [ExtractPattern]? = nil,
        extractions: [ExtractionMapping]? = nil
    ) {
        self.name = name
        self.remote = remote
        self.prefix = prefix
        self.commit = commit
        self.tag = tag
        self.branch = branch
        self.squash = squash
        self.extracts = extracts
        self.extractions = extractions
    }
}
