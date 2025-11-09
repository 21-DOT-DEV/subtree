import Foundation

/// Represents a validation failure with context for user-friendly error reporting
///
/// Per FR-020 through FR-024, validation errors must:
/// - Identify which subtree entry failed (FR-020)
/// - Identify which field failed (FR-021)
/// - Provide descriptive message (FR-022)
/// - Offer actionable guidance (FR-023)
public struct ValidationError: Error, Sendable {
    /// Subtree name or index that failed validation (FR-020)
    public let entry: String
    
    /// Field name that failed validation (FR-021)
    public let field: String
    
    /// Descriptive error message (FR-022)
    public let message: String
    
    /// Optional actionable guidance for fixing the error (FR-023)
    public let suggestion: String?
    
    /// Initialize a validation error
    /// - Parameters:
    ///   - entry: Subtree name or "index N"
    ///   - field: Field name that failed
    ///   - message: Clear description of the error
    ///   - suggestion: How to fix the error (optional)
    public init(
        entry: String,
        field: String,
        message: String,
        suggestion: String? = nil
    ) {
        self.entry = entry
        self.field = field
        self.message = message
        self.suggestion = suggestion
    }
}

extension ValidationError: CustomStringConvertible {
    public var description: String {
        var result = "Subtree '\(entry)', field '\(field)': \(message)"
        if let suggestion = suggestion {
            result += "\n  → \(suggestion)"
        }
        return result
    }
}
