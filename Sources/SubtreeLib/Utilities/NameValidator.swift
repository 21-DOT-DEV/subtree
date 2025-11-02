import Foundation

/// Validates subtree names for non-ASCII character detection
///
/// Provides warnings when names contain non-ASCII characters since
/// case-insensitive matching only works reliably for ASCII characters.
public struct NameValidator {
    
    /// Check if a name contains non-ASCII characters
    ///
    /// - Parameter name: The name to check
    /// - Returns: true if name contains any non-ASCII characters
    ///
    /// Non-ASCII characters include:
    /// - Characters outside ASCII range (0-127)
    /// - Unicode characters (accented letters, emojis, etc.)
    ///
    /// Note: ASCII includes A-Z, a-z, 0-9, and common punctuation/symbols
    public static func containsNonASCII(_ name: String) -> Bool {
        return name.unicodeScalars.contains { !$0.isASCII }
    }
    
    /// Generate a warning message for names with non-ASCII characters
    ///
    /// - Parameter name: The name that contains non-ASCII characters
    /// - Returns: Formatted warning message with emoji prefix and explanation
    ///
    /// The warning explains that case-insensitive matching only works for
    /// ASCII characters, so names differing only in non-ASCII case may be
    /// treated as duplicates or fail to match correctly.
    public static func nonASCIIWarning(for name: String) -> String {
        return """
        ⚠️  Warning: Name '\(name)' contains non-ASCII characters
           Case-insensitive matching only works for ASCII characters (A-Z).
           Names differing only in non-ASCII case will be treated as duplicates.
        """
    }
}
