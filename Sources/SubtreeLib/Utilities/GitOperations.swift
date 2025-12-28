import Foundation
import Subprocess

/// Error types for git operations
public enum GitError: Error, Equatable {
    case notInRepository
    case commandFailed(String)
}

/// Atomic subtree operations that combine git subtree commands with config updates
public enum AtomicSubtreeOperation {
    case add(name: String, remote: String, ref: String, prefix: String, squash: Bool)
    case update(name: String, squash: Bool)
    case remove(name: String)
}

/// Utilities for git repository operations
public enum GitOperations {
    
    // T012: Implement findGitRoot() using git rev-parse --show-toplevel
    /// Find the root directory of the current git repository
    /// - Returns: Absolute path to git repository root (with symlinks resolved)
    /// - Throws: GitError.notInRepository if not in a git repository
    /// - Throws: GitError.commandFailed if git command fails unexpectedly
    public static func findGitRoot() async throws -> String {
        let result = try await Subprocess.run(
            .name("git"),
            arguments: .init(["rev-parse", "--show-toplevel"]),
            output: .string(limit: 4096),
            error: .string(limit: 4096)
        )
        
        // T014: Error handling for GitError.notInRepository
        // Use explicit pattern matching for clarity
        guard case .exited(0) = result.terminationStatus else {
            throw GitError.notInRepository
        }
        
        // Get stdout and trim whitespace
        let gitRoot = result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        guard !gitRoot.isEmpty else {
            throw GitError.commandFailed("Git returned empty path")
        }
        
        return gitRoot
    }
    
    // T013: Implement isRepository() helper function
    /// Check if the current directory is within a git repository
    /// - Returns: true if in a git repository, false otherwise
    public static func isRepository() async -> Bool {
        do {
            _ = try await findGitRoot()
            return true
        } catch {
            return false
        }
    }
    
    /// Check if a file is tracked by git (008-extract-command)
    ///
    /// Uses `git ls-files` to check if a file is in the git index.
    /// This is used for overwrite protection when extracting files.
    ///
    /// - Parameters:
    ///   - path: Relative path to the file from repository root
    ///   - repositoryPath: Absolute path to git repository root
    /// - Returns: `true` if file is tracked, `false` if untracked or doesn't exist
    /// - Throws: `GitError.notInRepository` if not in a git repository
    public static func isFileTracked(path: String, in repositoryPath: String) async throws -> Bool {
        // Use git ls-files to check if file is in the index
        // --error-unmatch flag causes git to exit with error if file is not tracked
        let result = try await Subprocess.run(
            .name("git"),
            arguments: .init(["ls-files", "--error-unmatch", path]),
            workingDirectory: .init(repositoryPath),
            output: .string(limit: 4096),
            error: .string(limit: 4096)
        )
        
        // Exit code 0 means file is tracked
        // Exit code 1 means file is not tracked or doesn't exist
        // Other exit codes indicate git errors (e.g., not in a git repo)
        switch result.terminationStatus {
        case .exited(0):
            return true
        case .exited(1):
            // Check if this is a "not in repository" error
            let stderr = result.standardError ?? ""
            if stderr.contains("not a git repository") || stderr.contains("Not a git repository") {
                throw GitError.notInRepository
            }
            // Otherwise, file is simply not tracked
            return false
        default:
            // Any other exit status is an error
            throw GitError.notInRepository
        }
    }
    
    /// Execute a git command with arguments
    /// - Parameter arguments: Git command arguments (e.g., ["status", "--short"])
    /// - Returns: Tuple containing stdout, stderr, and exit code
    /// - Throws: Error if command execution fails
    public static func run(arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int) {
        let result = try await Subprocess.run(
            .name("git"),
            arguments: .init(arguments),
            output: .string(limit: 1024 * 1024), // 1MB limit
            error: .string(limit: 1024 * 1024)
        )
        
        let stdout = result.standardOutput ?? ""
        let stderr = result.standardError ?? ""
        
        let exitCode: Int
        switch result.terminationStatus {
        case .exited(let code):
            exitCode = Int(code)
        default:
            exitCode = 1
        }
        
        return (stdout, stderr, exitCode)
    }
    
    // T006: Git subtree pull wrapper for update operations
    /// Execute git subtree pull to update a subtree
    /// - Parameters:
    ///   - prefix: Local directory path for the subtree
    ///   - remote: Git remote URL
    ///   - ref: Branch or tag to pull from
    ///   - squash: Whether to squash commits
    /// - Returns: Commit hash of the pulled changes
    /// - Throws: GitError if operation fails
    public static func subtreePull(prefix: String, remote: String, ref: String, squash: Bool) async throws -> String {
        var args = ["subtree", "pull", "--prefix=\(prefix)"]
        if squash {
            args.append("--squash")
        }
        args.append(contentsOf: [remote, ref])
        
        let result = try await run(arguments: args)
        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git subtree pull failed: \(result.stderr)")
        }
        
        // Get the commit hash after pull
        let commitResult = try await run(arguments: ["rev-parse", "HEAD"])
        return commitResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // T007: Git ls-remote wrapper for remote commit queries (report mode)
    /// Query remote repository for commit hash of a ref
    /// - Parameters:
    ///   - remote: Git remote URL
    ///   - ref: Branch or tag name
    /// - Returns: Commit hash of the ref
    /// - Throws: GitError if ref not found or command fails
    public static func lsRemote(remote: String, ref: String) async throws -> String {
        let result = try await run(arguments: ["ls-remote", remote, ref])
        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git ls-remote failed: \(result.stderr)")
        }
        
        // Parse output: "HASH\tREF"
        let lines = result.stdout.split(separator: "\n")
        guard let firstLine = lines.first else {
            throw GitError.commandFailed("No output from ls-remote")
        }
        
        let components = firstLine.split(separator: "\t", maxSplits: 1)
        guard let hash = components.first else {
            throw GitError.commandFailed("Failed to parse ls-remote output")
        }
        
        return String(hash)
    }
    
    /// Query remote repository for all tags
    /// - Parameter remote: Git remote URL
    /// - Returns: Array of (tagName, commitHash) tuples sorted by semver (latest first)
    /// - Throws: GitError if command fails
    public static func lsRemoteTags(remote: String) async throws -> [(tag: String, commit: String)] {
        let result = try await run(arguments: ["ls-remote", "--tags", "--refs", remote])
        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git ls-remote --tags failed: \(result.stderr)")
        }
        
        // Parse output: "HASH\trefs/tags/TAG"
        var tags: [(tag: String, commit: String)] = []
        let lines = result.stdout.split(separator: "\n")
        for line in lines {
            let components = line.split(separator: "\t", maxSplits: 1)
            guard components.count == 2 else { continue }
            let hash = String(components[0])
            let refPath = String(components[1])
            // Extract tag name from refs/tags/TAG
            if let tagName = refPath.split(separator: "/").last {
                tags.append((tag: String(tagName), commit: hash))
            }
        }
        
        // Sort by semver (latest first)
        return tags.sorted { lhs, rhs in
            compareSemver(lhs.tag, rhs.tag) == .orderedDescending
        }
    }
    
    /// Compare two version strings using semver-like comparison
    /// Handles formats: "1.2.3", "v1.2.3", "1.2.3-beta", etc.
    private static func compareSemver(_ lhs: String, _ rhs: String) -> ComparisonResult {
        // Strip leading 'v' or 'V' if present
        let lhsClean = lhs.hasPrefix("v") || lhs.hasPrefix("V") ? String(lhs.dropFirst()) : lhs
        let rhsClean = rhs.hasPrefix("v") || rhs.hasPrefix("V") ? String(rhs.dropFirst()) : rhs
        
        // Split by common delimiters
        let lhsParts = lhsClean.split { $0 == "." || $0 == "-" || $0 == "_" }
        let rhsParts = rhsClean.split { $0 == "." || $0 == "-" || $0 == "_" }
        
        let maxCount = max(lhsParts.count, rhsParts.count)
        for i in 0..<maxCount {
            let lhsPart = i < lhsParts.count ? String(lhsParts[i]) : "0"
            let rhsPart = i < rhsParts.count ? String(rhsParts[i]) : "0"
            
            // Try numeric comparison first
            if let lhsNum = Int(lhsPart), let rhsNum = Int(rhsPart) {
                if lhsNum < rhsNum { return .orderedAscending }
                if lhsNum > rhsNum { return .orderedDescending }
            } else {
                // Fall back to string comparison
                let comparison = lhsPart.compare(rhsPart)
                if comparison != .orderedSame { return comparison }
            }
        }
        return .orderedSame
    }
    
    // T008: Git rev-list --count wrapper for commit counting
    /// Count commits between two refs
    /// - Parameters:
    ///   - from: Starting commit/ref
    ///   - to: Ending commit/ref
    /// - Returns: Number of commits between from and to
    /// - Throws: GitError if command fails
    public static func revListCount(from: String, to: String) async throws -> Int {
        let result = try await run(arguments: ["rev-list", "--count", "\(from)..\(to)"])
        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git rev-list --count failed: \(result.stderr)")
        }
        
        let countString = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let count = Int(countString) else {
            throw GitError.commandFailed("Failed to parse commit count")
        }
        
        return count
    }
    
    // T025: Git rm wrapper for removing subtree directories
    /// Remove a directory from the working tree and index
    /// - Parameter prefix: Directory path to remove
    /// - Throws: GitError if git rm command fails
    public static func remove(prefix: String) async throws {
        let result = try await run(arguments: ["rm", "-r", prefix])
        guard result.exitCode == 0 else {
            throw GitError.commandFailed("git rm failed: \(result.stderr)")
        }
    }
    
    // T011: Compute SHA hash of file contents using git hash-object
    /// Compute the git blob SHA hash of a file's contents
    ///
    /// Uses `git hash-object -t blob <file>` to compute the SHA-1 hash
    /// that git would use for this file's contents. This is used for
    /// checksum validation in Extract Clean Mode.
    ///
    /// - Parameter file: Absolute path to the file
    /// - Returns: 40-character hex SHA-1 hash string
    /// - Throws: `GitError.commandFailed` if file doesn't exist or git command fails
    public static func hashObject(file: String) async throws -> String {
        let result = try await Subprocess.run(
            .name("git"),
            arguments: .init(["hash-object", "-t", "blob", file]),
            output: .string(limit: 4096),
            error: .string(limit: 4096)
        )
        
        guard case .exited(0) = result.terminationStatus else {
            let stderr = result.standardError ?? ""
            throw GitError.commandFailed("git hash-object failed: \(stderr)")
        }
        
        let hash = (result.standardOutput ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard hash.count == 40, hash.allSatisfy({ $0.isHexDigit }) else {
            throw GitError.commandFailed("Invalid hash returned: \(hash)")
        }
        
        return hash
    }
}
