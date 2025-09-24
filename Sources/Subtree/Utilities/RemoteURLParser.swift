import Foundation

/// Utility for parsing remote URLs and inferring names/prefixes
struct RemoteURLParser {
    
    /// Infer subtree name from remote URL
    /// Examples:
    /// - https://github.com/user/repo.git -> repo
    /// - git@github.com:user/repo.git -> repo  
    /// - https://github.com/user/awesome-lib -> awesome-lib
    static func inferNameFromRemote(_ remote: String) throws -> String {
        var cleanURL = remote
        
        // Remove common protocols
        for prefix in ["https://", "http://", "git@", "ssh://"] {
            if cleanURL.hasPrefix(prefix) {
                cleanURL = String(cleanURL.dropFirst(prefix.count))
                break
            }
        }
        
        // Handle git@github.com:user/repo format
        if cleanURL.contains(":") && cleanURL.contains("/") {
            let parts = cleanURL.components(separatedBy: ":")
            if parts.count >= 2 {
                cleanURL = parts[1]
            }
        }
        
        // Extract last path component
        let pathComponents = cleanURL.components(separatedBy: "/")
        guard let lastComponent = pathComponents.last, !lastComponent.isEmpty else {
            throw SubtreeError.invalidUsage("Cannot infer name from remote URL: \(remote)")
        }
        
        // Remove .git suffix if present
        let name = lastComponent.hasSuffix(".git") ? String(lastComponent.dropLast(4)) : lastComponent
        
        // Validate name
        guard !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
            throw SubtreeError.invalidUsage("Inferred name '\(name)' is invalid")
        }
        
        return name
    }
    
    /// Infer prefix from name
    /// Examples:
    /// - "awesome-lib" -> "Vendor/awesome-lib"
    static func inferPrefixFromName(_ name: String) -> String {
        return "Vendor/\(name)"
    }
}
