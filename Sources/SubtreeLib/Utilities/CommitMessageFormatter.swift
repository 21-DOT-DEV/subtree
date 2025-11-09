import Foundation

/// Formats custom commit messages for subtree operations
public enum CommitMessageFormatter {
    /// Format a commit message for subtree add operation
    /// Format:
    ///   Add subtree <name>
    ///   - Added from <ref-type>: <ref> (commit: <short-hash>)
    ///   - From: <remote-url>
    ///   - In: <prefix>
    /// - Parameters:
    ///   - name: Subtree name
    ///   - ref: Branch or tag reference
    ///   - refType: Type of reference (tag or branch)
    ///   - commit: Full commit SHA-1 hash
    ///   - remote: Remote repository URL
    ///   - prefix: Subtree prefix path
    /// - Returns: Formatted commit message
    public static func format(
        name: String,
        ref: String,
        refType: String,
        commit: String,
        remote: String,
        prefix: String
    ) -> String {
        let short = shortHash(from: commit)
        
        return """
        Add subtree \(name)
        - Added from \(refType): \(ref) (commit: \(short))
        - From: \(remote)
        - In: \(prefix)
        """
    }
    
    // T011: Tag detection utility for identifying version tags
    /// Check if a ref is a tag (matches semver pattern)
    /// - Parameter ref: The reference string to check
    /// - Returns: true if ref appears to be a tag, false otherwise
    public static func isTagRef(_ ref: String) -> Bool {
        return deriveRefType(from: ref) == "tag"
    }
    
    /// Derive ref-type from ref value
    /// Rules:
    /// - 'tag' if ref matches pattern: ^v?\d+\.\d+(\.\d+)?
    ///   (starts with 'v' followed by digits OR matches semver without 'v')
    ///   Examples: v1.0.0, v0.7.0, 1.0.0, 0.7.0
    /// - 'branch' for all other cases
    ///   Examples: main, develop, feature/xyz
    /// - Parameter ref: The reference string
    /// - Returns: "tag" or "branch"
    public static func deriveRefType(from ref: String) -> String {
        // Match semver pattern: ^v?\d+\.\d+(\\.d+)?
        // Examples: v1.0.0, v0.7.0, 1.0.0, 0.7.0, v2.1, 2.1
        let pattern = "^v?\\d+\\.\\d+(\\.\\d+)?$"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return "branch" // Fallback
        }
        
        let range = NSRange(ref.startIndex..., in: ref)
        let matches = regex.matches(in: ref, options: [], range: range)
        
        return matches.isEmpty ? "branch" : "tag"
    }
    
    /// Extract short hash (first 8 characters) from full commit hash
    /// - Parameter commit: Full SHA-1 commit hash
    /// - Returns: First 8 characters of the hash
    public static func shortHash(from commit: String) -> String {
        // Extract first 8 characters of SHA-1 hash
        return String(commit.prefix(8))
    }
    
    /// Format a commit message for subtree remove operation
    /// Format: Remove subtree <name> (was at <short-hash>)
    /// - Parameters:
    ///   - name: Subtree name being removed
    ///   - lastCommit: Last commit SHA-1 hash before removal
    /// - Returns: Formatted commit message
    public static func formatRemove(name: String, lastCommit: String) -> String {
        let short = shortHash(from: lastCommit)
        return "Remove subtree \(name) (was at \(short))"
    }
}
