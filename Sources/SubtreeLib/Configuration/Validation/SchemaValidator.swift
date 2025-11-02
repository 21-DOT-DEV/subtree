import Foundation

/// Validates top-level schema structure of subtree.yaml
///
/// Handles FR-001 (subtrees array required) and FR-031 (empty array valid)
public struct SchemaValidator {
    
    public init() {}
    
    /// Validate the schema structure of a configuration
    /// - Parameter config: Configuration to validate
    /// - Returns: Array of validation errors (empty if valid)
    public func validate(_ config: SubtreeConfiguration) -> [ValidationError] {
        let errors: [ValidationError] = []
        
        // FR-001: subtrees array exists (always true since it's required in model)
        // FR-031: Empty array is valid - no error
        
        // Schema validator only checks top-level structure
        // Individual entry validation handled by other validators
        
        return errors
    }
}
