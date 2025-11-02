import Foundation

/// Represents the complete subtree.yaml file structure
///
/// This is the root configuration object containing all subtree entries.
/// Per FR-001 and FR-031, the subtrees array is required but may be empty.
public struct SubtreeConfiguration: Codable, Sendable {
    /// Array of subtree entries. May be empty per FR-031.
    public let subtrees: [SubtreeEntry]
    
    /// Initialize a subtree configuration
    /// - Parameter subtrees: Array of subtree entries (may be empty)
    public init(subtrees: [SubtreeEntry]) {
        self.subtrees = subtrees
    }
}

// MARK: - Case-Insensitive Validation (Feature 007)

extension SubtreeConfiguration {
    
    /// Find a subtree by case-insensitive name match
    ///
    /// - Parameter name: The subtree name to search for (case-insensitive)
    /// - Returns: The matching subtree, or nil if not found
    /// - Throws: SubtreeValidationError.multipleMatches if corruption detected
    ///
    /// This method performs case-insensitive lookup to support flexible name matching.
    /// If multiple case-variant names are found, it indicates manual config corruption
    /// and throws an error with details about all matching entries.
    public func findSubtree(name: String) throws -> SubtreeEntry? {
        let matches = subtrees.filter { $0.name.matchesCaseInsensitive(name) }
        
        guard matches.count <= 1 else {
            throw SubtreeValidationError.multipleMatches(
                name: name,
                found: matches.map(\.name)
            )
        }
        
        return matches.first
    }
    
    /// Validate configuration for case-insensitive duplicates
    ///
    /// - Throws: SubtreeValidationError if duplicates are detected
    ///
    /// This method checks for:
    /// - Duplicate names (case-insensitive)
    /// - Duplicate prefixes (case-insensitive)
    ///
    /// Should be called before operations that read/modify config to ensure
    /// the config is not in a corrupted state from manual edits.
    public func validate() throws {
        try validateNoDuplicateNames()
        try validateNoDuplicatePrefixes()
    }
    
    /// Check for duplicate names (case-insensitive)
    private func validateNoDuplicateNames() throws {
        for i in 0..<subtrees.count {
            for j in (i+1)..<subtrees.count {
                if subtrees[i].name.matchesCaseInsensitive(subtrees[j].name) {
                    throw SubtreeValidationError.duplicateName(
                        attempted: subtrees[i].name,
                        existing: subtrees[j].name
                    )
                }
            }
        }
    }
    
    /// Check for duplicate prefixes (case-insensitive)
    private func validateNoDuplicatePrefixes() throws {
        for i in 0..<subtrees.count {
            for j in (i+1)..<subtrees.count {
                if subtrees[i].prefix.matchesCaseInsensitive(subtrees[j].prefix) {
                    throw SubtreeValidationError.duplicatePrefix(
                        attempted: subtrees[i].prefix,
                        existing: subtrees[j].prefix
                    )
                }
            }
        }
    }
}
