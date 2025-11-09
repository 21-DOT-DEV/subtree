import Foundation

/// Validates field types and presence in subtree entries
///
/// Handles FR-005 (name non-empty), FR-009 (tag/branch non-empty), 
/// FR-010 (squash boolean), FR-011 (extracts non-empty array)
public struct TypeValidator {
    
    public init() {}
    
    /// Validate types for a single subtree entry
    /// - Parameters:
    ///   - entry: SubtreeEntry to validate
    ///   - index: Index of entry in configuration (for error reporting)
    /// - Returns: Array of validation errors
    public func validate(_ entry: SubtreeEntry, index: Int) -> [ValidationError] {
        var errors: [ValidationError] = []
        let entryName = entry.name.isEmpty ? "index \(index)" : entry.name
        
        // FR-005: Validate name is non-empty
        if entry.name.isEmpty {
            errors.append(ValidationError(
                entry: "index \(index)",
                field: "name",
                message: "Field 'name' cannot be empty",
                suggestion: "Provide a descriptive name for this subtree. Example: name: my-lib"
            ))
        }
        
        // FR-009: Validate tag is non-empty when present
        if let tag = entry.tag, tag.isEmpty {
            errors.append(ValidationError(
                entry: entryName,
                field: "tag",
                message: "Field 'tag' cannot be empty when specified",
                suggestion: "Provide a valid tag or remove the tag field. Example: tag: v1.0.0"
            ))
        }
        
        // FR-009: Validate branch is non-empty when present
        if let branch = entry.branch, branch.isEmpty {
            errors.append(ValidationError(
                entry: entryName,
                field: "branch",
                message: "Field 'branch' cannot be empty when specified",
                suggestion: "Provide a valid branch name or remove the branch field. Example: branch: main"
            ))
        }
        
        // FR-010: squash type validation handled by Swift's type system
        // Bool? only accepts boolean values, non-boolean values won't parse
        
        // FR-011: Validate extracts array is non-empty when present
        if let extracts = entry.extracts, extracts.isEmpty {
            errors.append(ValidationError(
                entry: entryName,
                field: "extracts",
                message: "Field 'extracts' cannot be an empty array",
                suggestion: "Either remove the extracts field or add at least one extract pattern"
            ))
        }
        
        return errors
    }
}
