import Foundation

/// Validates field formats (URLs, paths, commit hashes)
///
/// Handles FR-006 (remote URL format), FR-007 (prefix path safety), 
/// FR-008 (commit hash format), FR-029 (extracts.to path safety)
public struct FormatValidator {
    private let globValidator: GlobPatternValidator
    
    public init() {
        self.globValidator = GlobPatternValidator()
    }
    
    /// Validate formats for a single subtree entry
    /// - Parameters:
    ///   - entry: SubtreeEntry to validate
    ///   - index: Index of entry in configuration (for error reporting)
    /// - Returns: Array of validation errors
    public func validate(_ entry: SubtreeEntry, index: Int) -> [ValidationError] {
        var errors: [ValidationError] = []
        let entryName = entry.name.isEmpty ? "index \(index)" : entry.name
        
        // FR-006: Validate remote URL format
        if !isValidGitURL(entry.remote) {
            errors.append(ValidationError(
                entry: entryName,
                field: "remote",
                message: "Invalid git URL format: unsupported protocol or malformed URL",
                suggestion: "Use https://, git@, or file:// protocols. Example: https://github.com/org/repo"
            ))
        }
        
        // FR-007: Validate prefix path safety
        if !isPathSafe(entry.prefix) {
            let reason = getPathUnsafeReason(entry.prefix)
            errors.append(ValidationError(
                entry: entryName,
                field: "prefix",
                message: "Path contains unsafe component: \(reason)",
                suggestion: "Use relative paths only, without '..' or leading '/'. Example: Vendors/lib"
            ))
        }
        
        // FR-008: Validate commit hash format
        if !isValidCommitHash(entry.commit) {
            errors.append(ValidationError(
                entry: entryName,
                field: "commit",
                message: "Invalid commit hash format: expected 40 hexadecimal characters, got \(entry.commit.count)",
                suggestion: "Provide a full SHA-1 commit hash (40 characters). Example: bf4f0bc877e4d6771e48611cc9e66ab9db576bac"
            ))
        }
        
        // FR-029: Validate extracts.to path safety
        // FR-019: Validate glob patterns in extracts.from and extracts.exclude
        if let extracts = entry.extracts {
            for (idx, pattern) in extracts.enumerated() {
                // Validate destination path safety
                if !isPathSafe(pattern.to) {
                    let reason = getPathUnsafeReason(pattern.to)
                    errors.append(ValidationError(
                        entry: entryName,
                        field: "extracts[\(idx)].to",
                        message: "Extract destination path contains unsafe component: \(reason)",
                        suggestion: "Use relative paths only, without '..' or leading '/'"
                    ))
                }
                
                // Validate source glob pattern (FR-019)
                let fromResult = globValidator.validate(pattern.from)
                if !fromResult.isValid {
                    errors.append(ValidationError(
                        entry: entryName,
                        field: "extracts[\(idx)].from",
                        message: "Invalid glob pattern: \(fromResult.errorMessage ?? "syntax error")",
                        suggestion: "Check pattern syntax. Supported: *, ?, **, [...], {...}"
                    ))
                }
                
                // Validate exclude glob patterns (FR-019)
                if let excludePatterns = pattern.exclude {
                    for (excludeIdx, excludePattern) in excludePatterns.enumerated() {
                        let excludeResult = globValidator.validate(excludePattern)
                        if !excludeResult.isValid {
                            errors.append(ValidationError(
                                entry: entryName,
                                field: "extracts[\(idx)].exclude[\(excludeIdx)]",
                                message: "Invalid glob pattern: \(excludeResult.errorMessage ?? "syntax error")",
                                suggestion: "Check pattern syntax. Supported: *, ?, **, [...], {...}"
                            ))
                        }
                    }
                }
            }
        }
        
        return errors
    }
    
    // MARK: - Validation Helpers
    
    private func isValidGitURL(_ url: String) -> Bool {
        // Format-only validation per spec clarifications
        // Accept: https://, git@, file://
        return url.hasPrefix("https://") || 
               url.hasPrefix("git@") || 
               url.hasPrefix("file://")
    }
    
    private func isPathSafe(_ path: String) -> Bool {
        // Reject absolute paths (leading /)
        if path.hasPrefix("/") {
            return false
        }
        
        // Reject paths containing ..
        if path.contains("..") {
            return false
        }
        
        // Reject empty paths
        if path.isEmpty {
            return false
        }
        
        return true
    }
    
    private func getPathUnsafeReason(_ path: String) -> String {
        if path.hasPrefix("/") {
            return "absolute path (leading '/')"
        }
        if path.contains("..") {
            return "parent directory navigation (contains '..')"
        }
        if path.isEmpty {
            return "empty path"
        }
        return "unknown"
    }
    
    private func isValidCommitHash(_ commit: String) -> Bool {
        // Must be exactly 40 characters
        guard commit.count == 40 else {
            return false
        }
        
        // Must be hexadecimal (0-9, a-f, A-F)
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return commit.unicodeScalars.allSatisfy { hexCharacterSet.contains($0) }
    }
}
