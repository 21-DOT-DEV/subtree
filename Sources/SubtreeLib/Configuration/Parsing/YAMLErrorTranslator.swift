import Foundation
import Yams

/// Translates YAML parsing errors to user-friendly messages (FR-026)
///
/// Yams errors are technical and difficult for users to understand.
/// This translator converts them to actionable, clear messages.
public enum YAMLErrorTranslator {
    
    /// Translate a YAML parsing error to user-friendly message
    /// - Parameter error: Original error from Yams
    /// - Returns: ConfigurationError with user-friendly message
    public static func translate(error: Error) -> ConfigurationError {
        // If it's already our error, pass through
        if let configError = error as? ConfigurationError {
            return configError
        }
        
        // Translate Yams errors to user-friendly messages
        let errorString = String(describing: error)
        
        // Common YAML syntax errors
        if errorString.contains("Scanner") || errorString.contains("unexpected") {
            return .yamlSyntaxError(message: """
                Invalid YAML syntax: \(extractErrorContext(from: errorString))
                Suggestion: Check for unclosed quotes, missing colons, or incorrect indentation. \
                YAML requires consistent spacing (use spaces, not tabs).
                """)
        }
        
        if errorString.contains("Parser") || errorString.contains("expected") {
            return .yamlSyntaxError(message: """
                Invalid YAML structure: \(extractErrorContext(from: errorString))
                Suggestion: Verify indentation is consistent. YAML requires 2 or 4 spaces per level.
                """)
        }
        
        if errorString.contains("end of file") || errorString.contains("EOF") {
            return .yamlSyntaxError(message: """
                Unexpected end of file
                Suggestion: Check for unclosed brackets, braces, or quotes at the end of the file.
                """)
        }
        
        // Generic YAML error
        return .yamlSyntaxError(message: """
            YAML parsing error: \(errorString)
            Suggestion: Verify YAML syntax is correct. Common issues: missing colons, incorrect indentation, unclosed quotes.
            """)
    }
    
    /// Extract useful context from error message
    private static func extractErrorContext(from message: String) -> String {
        // Try to extract line/column information if present
        if let lineRange = message.range(of: "line \\d+", options: .regularExpression),
           let colRange = message.range(of: "column \\d+", options: .regularExpression) {
            let line = String(message[lineRange])
            let col = String(message[colRange])
            return "at \(line), \(col)"
        }
        
        // Return first reasonable chunk of error message
        let lines = message.components(separatedBy: .newlines)
        return lines.first ?? message
    }
}
