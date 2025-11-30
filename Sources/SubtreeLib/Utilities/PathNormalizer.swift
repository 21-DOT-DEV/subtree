/// Normalizes paths for deduplication (012-multi-destination-extraction)
///
/// Handles common path variations that users might provide for the same destination:
/// - Trailing slashes: `Lib/` → `Lib`
/// - Leading `./`: `./Lib` → `Lib`
/// - Combinations: `./Lib/` → `Lib`
///
/// Used by `ExtractCommand` to deduplicate multiple `--to` destinations before extraction.
///
/// Example:
/// ```swift
/// // All these normalize to "Lib":
/// PathNormalizer.normalize("Lib")     // "Lib"
/// PathNormalizer.normalize("Lib/")    // "Lib"
/// PathNormalizer.normalize("./Lib")   // "Lib"
/// PathNormalizer.normalize("./Lib/")  // "Lib"
///
/// // Deduplicate equivalent paths:
/// PathNormalizer.deduplicate(["Lib/", "Lib", "./Lib"])  // ["Lib/"]
/// ```
public enum PathNormalizer {
    
    /// Normalize a single path by removing leading `./` and trailing `/`
    ///
    /// - Parameter path: The path to normalize
    /// - Returns: Normalized path with leading `./` and trailing `/` removed
    ///
    /// Edge cases:
    /// - Empty string returns empty string
    /// - Single `.` returns `.` (current directory)
    /// - Single `/` returns `/` (root)
    public static func normalize(_ path: String) -> String {
        var result = path
        
        // Remove leading ./ (can be repeated: ././path → path)
        while result.hasPrefix("./") {
            result = String(result.dropFirst(2))
        }
        
        // Remove trailing / (except for root "/")
        while result.hasSuffix("/") && result.count > 1 {
            result = String(result.dropLast())
        }
        
        return result
    }
    
    /// Deduplicate paths after normalization, preserving order and original form
    ///
    /// Returns the first occurrence of each normalized path, keeping the user's
    /// original formatting. This allows users to write `--to Lib/ --to Lib` and
    /// have it deduplicated to a single copy operation.
    ///
    /// - Parameter paths: Array of paths to deduplicate
    /// - Returns: Array with duplicates removed, preserving order and original form
    ///
    /// Example:
    /// ```swift
    /// deduplicate(["Lib/", "Vendor", "./Lib"])
    /// // Returns: ["Lib/", "Vendor"] — "Lib/" is kept, "./Lib" removed as duplicate
    /// ```
    public static func deduplicate(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        
        for path in paths {
            let normalized = normalize(path)
            if !seen.contains(normalized) {
                seen.insert(normalized)
                unique.append(path)  // Keep original form
            }
        }
        
        return unique
    }
}
