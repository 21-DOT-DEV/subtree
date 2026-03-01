import Foundation

/// Extracts repository name from git remote URLs
public enum URLParser {
    /// Extract name from remote URL by parsing the final path segment
    /// Supports https://, git@, and file:// URL schemes
    /// - Parameter url: The remote URL string
    /// - Returns: The extracted repository name
    /// - Throws: URLParseError if URL format is invalid
    public static func extractName(from url: String) throws -> String {
        guard !url.isEmpty else {
            throw URLParseError.emptyResult
        }
        
        var processedURL = url
        
        // Handle git@ format: git@github.com:user/repo.git
        if processedURL.hasPrefix("git@") {
            // Replace first colon with slash to normalize path
            if let colonRange = processedURL.range(of: ":") {
                processedURL.replaceSubrange(colonRange, with: "/")
            }
        }
        
        // Remove scheme prefixes (https://, file://, git@)
        let schemes = ["https://", "http://", "file://", "git@"]
        for scheme in schemes {
            if processedURL.hasPrefix(scheme) {
                processedURL = String(processedURL.dropFirst(scheme.count))
            }
        }
        
        // Split by "/" and get last component
        let components = processedURL.split(separator: "/")
        guard let lastComponent = components.last, components.count > 1 || processedURL.contains("/") else {
            // Require at least a path structure (e.g., "host/repo" not just "invalid-url")
            throw URLParseError.invalidFormat(url)
        }
        
        var name = String(lastComponent)
        
        // Remove .git extension if present
        if name.hasSuffix(".git") {
            name = String(name.dropLast(4))
        }
        
        guard !name.isEmpty else {
            throw URLParseError.emptyResult
        }
        
        return name
    }
    
    /// Construct a GitHub compare URL from a remote URL and two refs.
    ///
    /// Supports both HTTPS and SSH (`git@`) GitHub URLs. Non-GitHub URLs return `nil`.
    ///
    /// - Parameters:
    ///   - remote: Git remote URL (e.g., "https://github.com/bitcoin-core/secp256k1" or "git@github.com:user/repo.git")
    ///   - oldRef: Old tag, branch, or commit
    ///   - newRef: New tag, branch, or commit
    /// - Returns: Compare URL string, or `nil` if remote is not a GitHub URL
    public static func compareURL(remote: String, oldRef: String, newRef: String) -> String? {
        var processedURL = remote
        
        // Handle git@ format: git@github.com:user/repo.git → github.com/user/repo.git
        if processedURL.hasPrefix("git@") {
            if let colonRange = processedURL.range(of: ":") {
                processedURL.replaceSubrange(colonRange, with: "/")
            }
        }
        
        // Remove scheme prefixes
        let schemes = ["https://", "http://", "git@"]
        for scheme in schemes {
            if processedURL.hasPrefix(scheme) {
                processedURL = String(processedURL.dropFirst(scheme.count))
            }
        }
        
        // Check that the host is github.com
        guard processedURL.hasPrefix("github.com/") else {
            return nil
        }
        
        // Extract the path after github.com/
        let path = String(processedURL.dropFirst("github.com/".count))
        
        // Remove .git suffix if present
        var cleanPath = path
        if cleanPath.hasSuffix(".git") {
            cleanPath = String(cleanPath.dropLast(4))
        }
        
        // Remove trailing slash if present
        if cleanPath.hasSuffix("/") {
            cleanPath = String(cleanPath.dropLast())
        }
        
        guard !cleanPath.isEmpty else {
            return nil
        }
        
        return "https://github.com/\(cleanPath)/compare/\(oldRef)...\(newRef)"
    }
}

public enum URLParseError: Error {
    case invalidFormat(String)
    case emptyResult
}
