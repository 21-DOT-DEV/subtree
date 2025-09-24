import Foundation
import Subprocess
#if canImport(System)
import System
#else
import SystemPackage
#endif
@testable import Subtree

/// Utility for creating temporary Git repositories for testing
public struct RepoFixture {
    public let tempDir: URL
    public let repoRoot: URL
    
    private init(tempDir: URL, repoRoot: URL) {
        self.tempDir = tempDir
        self.repoRoot = repoRoot
    }
    
    /// Create a temporary Git repository
    public static func create() async throws -> RepoFixture {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("subtree-test-\(UUID())")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let workingDir = FilePath(tempDir.path)
        
        // Initialize git repo
        _ = try await Subprocess.run(.name("git"), arguments: .init(["init"]), workingDirectory: workingDir, output: .discarded)
        
        // Set git user for commits
        _ = try await Subprocess.run(.name("git"), arguments: .init(["config", "user.name", "Test User"]), workingDirectory: workingDir, output: .discarded)
        _ = try await Subprocess.run(.name("git"), arguments: .init(["config", "user.email", "test@example.com"]), workingDirectory: workingDir, output: .discarded)
        
        // Create initial commit
        let readme = tempDir.appendingPathComponent("README.md")
        try "# Test Repository\n".write(to: readme, atomically: true, encoding: .utf8)
        _ = try await Subprocess.run(.name("git"), arguments: .init(["add", "README.md"]), workingDirectory: workingDir, output: .discarded)
        _ = try await Subprocess.run(.name("git"), arguments: .init(["commit", "-m", "Initial commit"]), workingDirectory: workingDir, output: .discarded)
        
        return RepoFixture(tempDir: tempDir, repoRoot: tempDir)
    }
    
    /// Create a temporary directory that is NOT a Git repository
    public static func createNonGitDir() throws -> RepoFixture {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("subtree-test-non-git-\(UUID())")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        return RepoFixture(tempDir: tempDir, repoRoot: tempDir)
    }
    
    /// Clean up the temporary directory
    public func cleanup() throws {
        try FileManager.default.removeItem(at: tempDir)
    }
    
    /// Set up a subtree by committing config and using git subtree add
    /// This ensures the subtree exists before attempting update operations
    public func setupSubtree(
        name: String,
        remote: String,
        prefix: String,
        branch: String,
        squash: Bool = true
    ) async throws {
        let workingDir = FilePath(repoRoot.path)
        
        // Commit any uncommitted changes first to avoid "uncommitted changes" errors
        let statusResult = try await Subprocess.run(
            .name("git"),
            arguments: .init(["status", "--porcelain"]),
            workingDirectory: workingDir,
            output: .string(limit: 4096)
        )
        
        if let status = statusResult.standardOutput, !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // There are uncommitted changes, commit them
            _ = try await Subprocess.run(.name("git"), arguments: .init(["add", "."]), workingDirectory: workingDir, output: .discarded)
            _ = try await Subprocess.run(.name("git"), arguments: .init(["commit", "-m", "Setup subtree config and initial files"]), workingDirectory: workingDir, output: .discarded)
        }
        
        // Use GitPlumbing to add the subtree
        var gitArgs = ["subtree", "add", "--prefix=\(prefix)"]
        
        if squash {
            gitArgs.append("--squash")
        }
        
        gitArgs.append("-m")
        gitArgs.append("Add \(name) subtree")
        gitArgs.append(remote)
        gitArgs.append(branch)
        
        let result = try GitPlumbing.runGitCommand(gitArgs, workingDirectory: repoRoot)
        
        if result.exitCode != 0 {
            throw TestError.gitSubtreeAddFailed("git subtree add failed for \(name): \(result.stderr)")
        }
    }
    
    /// Set up multiple subtrees in batch
    public func setupSubtrees(_ subtrees: [(name: String, remote: String, prefix: String, branch: String, squash: Bool)]) async throws {
        for subtree in subtrees {
            try await setupSubtree(
                name: subtree.name,
                remote: subtree.remote,
                prefix: subtree.prefix,
                branch: subtree.branch,
                squash: subtree.squash
            )
        }
    }
}

/// Test-specific errors
public enum TestError: Error {
    case gitSubtreeAddFailed(String)
}
