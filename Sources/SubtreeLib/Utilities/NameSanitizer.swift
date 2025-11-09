import Foundation

/// Sanitizes repository names for filesystem compatibility
public enum NameSanitizer {
    /// Sanitize name by replacing invalid filesystem characters with hyphens
    /// Allows only: alphanumeric (a-z, A-Z, 0-9), hyphens (-), and underscores (_)
    /// Invalid characters include: /, :, \, *, ?, ", <, >, |, whitespace
    /// Uses regex: [^a-zA-Z0-9_-]+ replaced with -
    /// - Parameter name: The name string to sanitize
    /// - Returns: Sanitized name safe for filesystem use
    public static func sanitize(_ name: String) -> String {
        // Replace all characters except alphanumeric (a-z, A-Z, 0-9), hyphen (-), and underscore (_)
        // Pattern: [^a-zA-Z0-9_-]+ matches one or more invalid characters
        // Replace with single hyphen
        let pattern = "[^a-zA-Z0-9_-]+"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return name // Fallback: return original if regex creation fails
        }
        
        let range = NSRange(name.startIndex..., in: name)
        let sanitized = regex.stringByReplacingMatches(
            in: name,
            options: [],
            range: range,
            withTemplate: "-"
        )
        
        return sanitized
    }
}
