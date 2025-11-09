import Foundation
import Subprocess
#if canImport(System)
import System
#else
import SystemPackage
#endif

/// A test fixture that creates a temporary git repository for integration testing.
///
/// Each fixture creates a unique temporary directory with a git repository initialized
/// and an initial commit. The fixture is self-contained and handles its own subprocess
/// execution for git commands.
///
/// Usage:
/// ```swift
/// let fixture = try GitRepositoryFixture()
/// defer { try? fixture.tearDown() }
/// 
/// // Use fixture.path for testing
/// ```
struct GitRepositoryFixture {
    /// Path to the temporary git repository
    let path: FilePath
    
    /// Create a new git repository fixture with a unique temporary directory.
    ///
    /// The fixture will:
    /// - Create a unique temp directory using UUID
    /// - Initialize a git repository
    /// - Create an initial commit with a README file
    ///
    /// - Throws: If git commands fail or temp directory cannot be created
    init() async throws {
        // Create unique temp directory using UUID
        let tempDir = FilePath("/tmp")
        let uniqueName = "subtree-test-\(UUID().uuidString)"
        self.path = tempDir.appending(uniqueName)
        
        // Create the directory
        try FileManager.default.createDirectory(
            atPath: path.string,
            withIntermediateDirectories: true
        )
        
        // Initialize git repository
        try await runGit(["init"], in: path)
        
        // Configure git user (required for commits)
        try await runGit(["config", "user.name", "Test User"], in: path)
        try await runGit(["config", "user.email", "test@example.com"], in: path)
        
        // Configure git for parallel test execution isolation
        // Disable automatic garbage collection to prevent lock contention
        try await runGit(["config", "gc.auto", "0"], in: path)
        // Disable credential caching to prevent shared credential store issues
        try await runGit(["config", "credential.helper", ""], in: path)
        // Increase timeout for network operations (helps with parallel network requests)
        try await runGit(["config", "http.lowSpeedLimit", "0"], in: path)
        try await runGit(["config", "http.lowSpeedTime", "999999"], in: path)
        
        // Create initial commit
        let readmePath = path.appending("README.md")
        try "# Test Repository\n".write(
            toFile: readmePath.string,
            atomically: true,
            encoding: .utf8
        )
        
        try await runGit(["add", "README.md"], in: path)
        try await runGit(["commit", "-m", "Initial commit"], in: path)
    }
    
    /// Clean up the temporary repository.
    ///
    /// Removes the entire temporary directory and its contents.
    ///
    /// - Throws: If cleanup fails
    func tearDown() throws {
        try FileManager.default.removeItem(atPath: path.string)
    }
    
    /// Execute a git command in the repository.
    ///
    /// - Parameters:
    ///   - arguments: Git command arguments (e.g., ["log", "--oneline"])
    ///   - workingDirectory: Directory to run command in (defaults to fixture path)
    /// - Returns: Command output as string
    /// - Throws: If git command fails
    @discardableResult
    func runGit(_ arguments: [String], in workingDirectory: FilePath? = nil) async throws -> String {
        let workDir = workingDirectory ?? path
        
        let result = try await Subprocess.run(
            .name("git"),
            arguments: .init(arguments),
            workingDirectory: workDir,
            output: .string(limit: 4096),
            error: .string(limit: 4096)
        )
        
        // Check exit code
        guard case .exited(0) = result.terminationStatus else {
            let stderr = result.standardError ?? ""
            throw GitError.commandFailed(arguments.joined(separator: " "), stderr)
        }
        
        return result.standardOutput ?? ""
    }
    
    /// Verify that a file exists in the repository
    ///
    /// - Parameter relativePath: Path relative to repository root
    /// - Returns: True if file exists
    func fileExists(_ relativePath: String) -> Bool {
        let fullPath = path.appending(relativePath)
        return FileManager.default.fileExists(atPath: fullPath.string)
    }
    
    /// Get the current git commit SHA
    ///
    /// - Returns: Current commit SHA (short form)
    /// - Throws: If git command fails
    func getCurrentCommit() async throws -> String {
        let output = try await runGit(["rev-parse", "--short", "HEAD"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Get the number of commits in the repository
    ///
    /// - Returns: Commit count
    /// - Throws: If git command fails
    func getCommitCount() async throws -> Int {
        let output = try await runGit(["rev-list", "--count", "HEAD"])
        return Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }
}

/// Errors that can occur during git fixture operations
enum GitError: Error, CustomStringConvertible {
    case commandFailed(String, String)
    
    var description: String {
        switch self {
        case .commandFailed(let command, let stderr):
            return "Git command failed: \(command)\n\(stderr)"
        }
    }
}
