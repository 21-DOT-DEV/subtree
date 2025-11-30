import Foundation

/// Errors that can occur during brace expansion
public enum BraceExpanderError: Error, Equatable {
    /// Pattern contains an empty alternative (e.g., `{a,}` or `{,b}` or `{a,,b}`)
    /// Associated value is the full pattern for error reporting
    case emptyAlternative(String)
}

/// Expands brace patterns in glob expressions before matching
///
/// Supports bash-style brace expansion with embedded path separators:
/// - `{a,b,c}` → `["a", "b", "c"]`
/// - `{a,b/c}` → `["a", "b/c"]` (embedded path separators)
/// - `{x,y}{1,2}` → `["x1", "x2", "y1", "y2"]` (cartesian product)
///
/// Invalid patterns are passed through unchanged (bash behavior):
/// - `{a}` (no comma) → `["{a}"]`
/// - `{}` (empty) → `["{}"]`
/// - `{a,b` (unclosed) → `["{a,b"]`
///
/// Empty alternatives throw an error (safety deviation from bash):
/// - `{a,}` → throws `BraceExpanderError.emptyAlternative`
///
/// ## Usage
/// ```swift
/// let patterns = try BraceExpander.expand("Sources/{Foo,Bar/Baz}.swift")
/// // Returns: ["Sources/Foo.swift", "Sources/Bar/Baz.swift"]
/// ```
public struct BraceExpander {
    
    // MARK: - Internal Types
    
    /// Represents a brace group found in a pattern
    private struct BraceGroup {
        /// Start index of the opening `{`
        let startIndex: String.Index
        /// End index of the closing `}`
        let endIndex: String.Index
        /// The comma-separated alternatives inside the braces
        let alternatives: [String]
    }
    
    // MARK: - Public API
    
    /// Expand brace patterns in a glob expression
    ///
    /// - Parameter pattern: Input pattern potentially containing braces
    /// - Returns: Array of expanded patterns (or single-element array if no braces)
    /// - Throws: `BraceExpanderError.emptyAlternative` if pattern contains `{a,}`, `{,b}`, or `{a,,b}`
    public static func expand(_ pattern: String) throws -> [String] {
        // Find all valid brace groups
        let groups = findBraceGroups(in: pattern)
        
        // No valid brace groups? Return original pattern
        guard !groups.isEmpty else {
            return [pattern]
        }
        
        // Expand using cartesian product of all groups
        return try expandWithGroups(pattern: pattern, groups: groups)
    }
    
    // MARK: - Private Implementation
    
    /// Find all valid brace groups in a pattern
    ///
    /// A valid brace group must:
    /// - Start with `{`
    /// - End with `}`
    /// - Contain at least one comma (otherwise it's treated as literal)
    ///
    /// - Parameter pattern: The pattern to search
    /// - Returns: Array of brace groups in order of appearance
    private static func findBraceGroups(in pattern: String) -> [BraceGroup] {
        var groups: [BraceGroup] = []
        var searchStart = pattern.startIndex
        
        while searchStart < pattern.endIndex {
            // Find opening brace
            guard let openIndex = pattern[searchStart...].firstIndex(of: "{") else {
                break
            }
            
            // Find matching closing brace
            guard let closeIndex = pattern[pattern.index(after: openIndex)...].firstIndex(of: "}") else {
                // Unclosed brace - no more valid groups
                break
            }
            
            // Extract content between braces
            let contentStart = pattern.index(after: openIndex)
            let content = String(pattern[contentStart..<closeIndex])
            
            // Check for comma (required for valid brace group)
            if content.contains(",") {
                let alternatives = content.components(separatedBy: ",")
                groups.append(BraceGroup(
                    startIndex: openIndex,
                    endIndex: closeIndex,
                    alternatives: alternatives
                ))
            }
            
            // Continue search after this closing brace
            searchStart = pattern.index(after: closeIndex)
        }
        
        return groups
    }
    
    /// Expand pattern using cartesian product of brace groups
    ///
    /// - Parameters:
    ///   - pattern: Original pattern
    ///   - groups: Brace groups to expand
    /// - Returns: All expanded patterns
    /// - Throws: `BraceExpanderError.emptyAlternative` if any alternative is empty
    private static func expandWithGroups(pattern: String, groups: [BraceGroup]) throws -> [String] {
        // Start with empty prefix
        var results = [""]
        var lastEnd = pattern.startIndex
        
        for group in groups {
            // Add literal text between last group and this one
            let prefix = String(pattern[lastEnd..<group.startIndex])
            results = results.map { $0 + prefix }
            
            // Expand this group (cartesian product)
            var newResults: [String] = []
            for partial in results {
                for alternative in group.alternatives {
                    // Check for empty alternative
                    if alternative.isEmpty {
                        throw BraceExpanderError.emptyAlternative(pattern)
                    }
                    newResults.append(partial + alternative)
                }
            }
            results = newResults
            
            // Move past this group
            lastEnd = pattern.index(after: group.endIndex)
        }
        
        // Add any remaining suffix
        if lastEnd < pattern.endIndex {
            let suffix = String(pattern[lastEnd...])
            results = results.map { $0 + suffix }
        }
        
        // Warn if expansion produces many patterns (NFR-002)
        if results.count > 100 {
            FileHandle.standardError.write(
                Data("⚠️ Warning: Brace expansion produced \(results.count) patterns (>100). Consider simplifying the pattern.\n".utf8)
            )
        }
        
        return results
    }
}
