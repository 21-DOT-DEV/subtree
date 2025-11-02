import Foundation

/// Validation result for glob pattern
public struct GlobValidationResult {
    public let isValid: Bool
    public let errorMessage: String?
    
    public init(isValid: Bool, errorMessage: String? = nil) {
        self.isValid = isValid
        self.errorMessage = errorMessage
    }
}

/// Validates glob pattern syntax
///
/// Handles FR-019 (glob pattern validation) for standard glob features:
/// - ** (globstar/recursive)
/// - * (wildcard)
/// - ? (single character)
/// - [...] (character classes)
/// - {...} (brace expansion)
public struct GlobPatternValidator {
    
    public init() {}
    
    /// Quick check if pattern is syntactically valid
    /// - Parameter pattern: Glob pattern to validate
    /// - Returns: True if pattern syntax is valid
    public func isValid(_ pattern: String) -> Bool {
        return validate(pattern).isValid
    }
    
    /// Validate pattern and return detailed result
    /// - Parameter pattern: Glob pattern to validate
    /// - Returns: Validation result with error message if invalid
    public func validate(_ pattern: String) -> GlobValidationResult {
        // Check for unclosed braces
        if let error = validateBraces(pattern) {
            return GlobValidationResult(isValid: false, errorMessage: error)
        }
        
        // Check for unclosed brackets
        if let error = validateBrackets(pattern) {
            return GlobValidationResult(isValid: false, errorMessage: error)
        }
        
        // Pattern is syntactically valid
        return GlobValidationResult(isValid: true)
    }
    
    // MARK: - Validation Helpers
    
    private func validateBraces(_ pattern: String) -> String? {
        var braceDepth = 0
        
        for char in pattern {
            switch char {
            case "{":
                braceDepth += 1
            case "}":
                braceDepth -= 1
                if braceDepth < 0 {
                    return "Unexpected closing brace '}' without matching opening brace"
                }
            default:
                break
            }
        }
        
        if braceDepth > 0 {
            return "Unclosed brace '{' - missing closing brace '}'"
        }
        
        return nil
    }
    
    private func validateBrackets(_ pattern: String) -> String? {
        var bracketDepth = 0
        var escaped = false
        
        for char in pattern {
            if escaped {
                escaped = false
                continue
            }
            
            switch char {
            case "\\":
                escaped = true
            case "[":
                bracketDepth += 1
            case "]":
                bracketDepth -= 1
                if bracketDepth < 0 {
                    return "Unexpected closing bracket ']' without matching opening bracket"
                }
            default:
                break
            }
        }
        
        if bracketDepth > 0 {
            return "Unclosed bracket '[' - missing closing bracket ']'"
        }
        
        return nil
    }
}
