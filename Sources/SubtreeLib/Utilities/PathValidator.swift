import Foundation

/// Validates prefix path format for security and cross-platform compatibility
///
/// Requirements:
/// - Paths must be relative (no leading /)
/// - No parent directory traversal (../)
/// - Forward slashes only (no backslashes)
/// - Spaces in path names are allowed
public struct PathValidator {
    
    /// Validate that a prefix path is safe and portable
    ///
    /// - Parameter path: The prefix path to validate
    /// - Throws: SubtreeValidationError if path is invalid
    ///
    /// Validation rules:
    /// - Rejects absolute paths (starting with /)
    /// - Rejects parent traversal (contains ../)
    /// - Rejects backslashes (Windows-style separators)
    /// - Allows spaces in directory names
    /// - Allows forward slashes for path separation
    public static func validate(_ path: String) throws {
        // Reject absolute paths
        guard !path.starts(with: "/") else {
            throw SubtreeValidationError.absolutePath(path)
        }
        
        // Reject parent directory traversal
        // Pattern matches: ../ or ../anything or path/../anything or path/..
        let traversalPattern = #"\.\.(/|$)"#
        if path.range(of: traversalPattern, options: .regularExpression) != nil {
            throw SubtreeValidationError.parentTraversal(path)
        }
        
        // Reject backslashes (Windows separator)
        guard !path.contains("\\") else {
            throw SubtreeValidationError.invalidSeparator(path)
        }
        
        // Valid: relative path with forward slashes
        // Spaces, hyphens, underscores, dots (not ..) are all allowed
    }
}
