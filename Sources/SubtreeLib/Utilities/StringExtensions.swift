import Foundation

/// Extensions to String for validation and normalization operations
extension String {
    
    /// Trim leading and trailing whitespace from a string
    ///
    /// - Returns: A new string with leading/trailing whitespace removed
    ///
    /// This method removes:
    /// - Spaces
    /// - Tabs
    /// - Newlines
    /// - Other whitespace characters
    ///
    /// Internal whitespace is preserved.
    ///
    /// Example:
    /// ```swift
    /// "  Hello World  ".normalized()  // "Hello World"
    /// "\ttest\n".normalized()          // "test"
    /// ```
    public func normalized() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Perform case-insensitive string comparison
    ///
    /// - Parameter other: The string to compare against
    /// - Returns: true if strings match case-insensitively
    ///
    /// This method uses lowercased() for comparison, which works reliably
    /// for ASCII characters (A-Z). Non-ASCII character case handling may
    /// vary by Unicode standard and locale.
    ///
    /// Example:
    /// ```swift
    /// "Hello".matchesCaseInsensitive("hello")     // true
    /// "HELLO".matchesCaseInsensitive("hello")     // true
    /// "Hello".matchesCaseInsensitive("World")     // false
    /// ```
    public func matchesCaseInsensitive(_ other: String) -> Bool {
        return self.lowercased() == other.lowercased()
    }
}
