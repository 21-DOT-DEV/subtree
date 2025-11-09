import Foundation

/// Errors that occur during validation of subtree names, prefixes, and paths
///
/// This error type provides structured, user-friendly error messages with:
/// - Emoji prefixes for visual identification
/// - Clear problem statements
/// - Contextual information
/// - Actionable fix guidance
///
/// Exit codes:
/// - 1: User errors (duplicates, invalid paths)
/// - 2: Config corruption (manual edits created invalid state)
public enum SubtreeValidationError: LocalizedError {
    /// Duplicate subtree name detected (case-insensitive)
    case duplicateName(attempted: String, existing: String)
    
    /// Duplicate subtree prefix detected (case-insensitive)
    case duplicatePrefix(attempted: String, existing: String)
    
    /// Multiple subtrees match the same name (config corruption)
    case multipleMatches(name: String, found: [String])
    
    /// Prefix path is absolute (starts with /)
    case absolutePath(String)
    
    /// Prefix path contains parent directory traversal (..)
    case parentTraversal(String)
    
    /// Prefix path uses invalid separator (backslash)
    case invalidSeparator(String)
    
    /// Subtree not found by name
    case subtreeNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .duplicateName(let attempted, let existing):
            return """
            ❌ Error: Subtree name '\(attempted)' conflicts with existing '\(existing)'
               Names are matched case-insensitively to ensure config portability.
               
               To fix:
               • Choose a different name with --name
               • Remove the existing subtree first
            """
            
        case .duplicatePrefix(let attempted, let existing):
            return """
            ❌ Error: Subtree prefix '\(attempted)' conflicts with existing '\(existing)'
               Prefixes are matched case-insensitively to prevent filesystem conflicts.
               
               To fix:
               • Choose a different prefix with --prefix
               • Remove the existing subtree first
            """
            
        case .multipleMatches(let name, let found):
            let foundList = found.map { "'\($0)'" }.joined(separator: ", ")
            return """
            ❌ Error: Multiple subtrees match '\(name)' (found: \(foundList))
               Case-insensitive duplicates indicate manual config corruption.
               
               To fix:
               • Edit subtree.yaml and remove duplicate entries
               • Keep only one version
               • Run 'subtree lint' to verify config integrity
            """
            
        case .absolutePath(let path):
            return """
            ❌ Error: Prefix '\(path)' must be a relative path
               Absolute paths (starting with '/') are not allowed.
               
               To fix:
               • Use a relative path like 'vendor/lib' instead of '/vendor/lib'
            """
            
        case .parentTraversal(let path):
            return """
            ❌ Error: Prefix '\(path)' contains parent directory traversal
               Paths with '../' are not allowed for security reasons.
               
               To fix:
               • Use a path relative to repository root without '../'
            """
            
        case .invalidSeparator(let path):
            return """
            ❌ Error: Prefix '\(path)' uses invalid path separator
               Use forward slashes ('/') for cross-platform compatibility.
               
               To fix:
               • Replace backslashes with forward slashes: '\(path.replacingOccurrences(of: "\\", with: "/"))'
            """
            
        case .subtreeNotFound(let name):
            return "❌ Error: Subtree '\(name)' not found"
        }
    }
    
    /// Exit code for this validation error
    ///
    /// - Returns: 1 for user errors, 2 for config corruption
    public var exitCode: Int {
        switch self {
        case .duplicateName, .duplicatePrefix, .absolutePath, .parentTraversal, .invalidSeparator, .subtreeNotFound:
            return 1  // User error
        case .multipleMatches:
            return 2  // Config corruption
        }
    }
}
