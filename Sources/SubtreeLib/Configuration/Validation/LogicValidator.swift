import Foundation

/// Validates logical constraints and cross-field rules
///
/// Handles FR-012 (tag/branch mutual exclusivity), FR-013 (commit only), 
/// FR-014 (tag+commit), FR-015 (branch+commit), FR-030 (duplicate names)
public struct LogicValidator {
    
    public init() {}
    
    /// Validate a complete configuration for logical constraints
    /// - Parameter config: Configuration to validate
    /// - Returns: Array of validation errors
    public func validate(_ config: SubtreeConfiguration) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // FR-030: Validate no duplicate names
        var seenNames: [String: Int] = [:]
        for (index, entry) in config.subtrees.enumerated() {
            if let firstIndex = seenNames[entry.name] {
                errors.append(ValidationError(
                    entry: entry.name,
                    field: "name",
                    message: "Duplicate subtree name '\(entry.name)' at index \(index) (first seen at index \(firstIndex))",
                    suggestion: "Ensure each subtree has a unique name. Consider: \(entry.name)-2, \(entry.name)-dev, etc."
                ))
            } else {
                seenNames[entry.name] = index
            }
        }
        
        // Validate each entry's logical constraints
        for (index, entry) in config.subtrees.enumerated() {
            errors.append(contentsOf: validate(entry, index: index))
        }
        
        return errors
    }
    
    /// Validate logical constraints for a single subtree entry
    /// - Parameters:
    ///   - entry: SubtreeEntry to validate
    ///   - index: Index of entry in configuration (for error reporting)
    /// - Returns: Array of validation errors
    public func validate(_ entry: SubtreeEntry, index: Int) -> [ValidationError] {
        var errors: [ValidationError] = []
        let entryName = entry.name.isEmpty ? "index \(index)" : entry.name
        
        // FR-012: tag and branch are mutually exclusive
        if entry.tag != nil && entry.branch != nil {
            errors.append(ValidationError(
                entry: entryName,
                field: "tag/branch",
                message: "Cannot specify both 'tag' and 'branch' for the same subtree",
                suggestion: "Remove either 'tag' or 'branch' field. Use tag for releases, branch for development tracking"
            ))
        }
        
        // FR-013: commit only is valid (no error)
        // FR-014: tag + commit is valid (no error)
        // FR-015: branch + commit is valid (no error)
        // These are all allowed combinations, so no validation needed
        
        return errors
    }
}
