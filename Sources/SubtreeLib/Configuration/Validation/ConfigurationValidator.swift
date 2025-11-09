import Foundation

/// Main facade for validating SubtreeConfiguration
///
/// Coordinates all validators (Schema, Type, Format, Logic) and collects errors.
/// Implements FR-024 (collect all errors, not just first one).
public struct ConfigurationValidator {
    private let schemaValidator: SchemaValidator
    private let typeValidator: TypeValidator
    private let formatValidator: FormatValidator
    private let logicValidator: LogicValidator
    
    /// Initialize the configuration validator
    public init() {
        self.schemaValidator = SchemaValidator()
        self.typeValidator = TypeValidator()
        self.formatValidator = FormatValidator()
        self.logicValidator = LogicValidator()
    }
    
    /// Validate a complete configuration
    /// - Parameter config: Configuration to validate
    /// - Returns: Array of validation errors (empty if valid)
    public func validate(_ config: SubtreeConfiguration) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Schema validation (FR-001, FR-031)
        errors.append(contentsOf: schemaValidator.validate(config))
        
        // Logic validation (handles duplicate names and other config-level constraints)
        // Must run before entry-level validation to catch duplicates first
        errors.append(contentsOf: logicValidator.validate(config))
        
        // Validate each entry
        for (index, entry) in config.subtrees.enumerated() {
            // Type validation (FR-005, FR-009, FR-010, FR-011)
            errors.append(contentsOf: typeValidator.validate(entry, index: index))
            
            // Format validation (FR-006, FR-007, FR-008, FR-029)
            errors.append(contentsOf: formatValidator.validate(entry, index: index))
            
            // Entry-level logic validation (FR-012, FR-013, FR-014, FR-015)
            errors.append(contentsOf: logicValidator.validate(entry, index: index))
        }
        
        return errors
    }
}
