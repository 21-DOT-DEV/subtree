import Foundation
import Subprocess
#if canImport(System)
import System
#else
import SystemPackage
#endif

/// Test harness for executing the subtree CLI in integration tests
///
/// Provides utilities for:
/// - Running CLI commands with arguments
/// - Capturing stdout and stderr
/// - Checking exit codes
/// - Running commands in specific working directories
struct TestHarness {
    /// Path to the subtree executable
    let executablePath: FilePath
    
    /// Result of a CLI command execution
    struct CommandResult {
        let stdout: String
        let stderr: String
        let exitCode: Int
        
        var succeeded: Bool {
            exitCode == 0
        }
    }
    
    /// Initialize the test harness
    ///
    /// - Parameter executablePath: Path to the subtree executable to test
    init(executablePath: FilePath) {
        self.executablePath = executablePath
    }
    
    /// Initialize with the default debug build path
    init() {
        // Default to .build/debug/subtree relative to repository root
        let currentDirectory = FilePath(FileManager.default.currentDirectoryPath)
        self.executablePath = currentDirectory.appending(".build/debug/subtree")
    }
    
    /// Run the CLI with the given arguments
    ///
    /// - Parameters:
    ///   - arguments: Command-line arguments to pass to subtree
    ///   - workingDirectory: Directory to run the command in (optional)
    /// - Returns: Command result with stdout, stderr, and exit code
    func run(arguments: [String], workingDirectory: FilePath? = nil) async throws -> CommandResult {
        let result = try await Subprocess.run(
            .path(executablePath),
            arguments: .init(arguments),
            workingDirectory: workingDirectory,
            output: .string(limit: 65536),
            error: .string(limit: 65536)
        )
        
        let exitCode: Int
        if case .exited(let code) = result.terminationStatus {
            exitCode = Int(code)
        } else {
            exitCode = -1 // Non-zero for any other termination
        }
        
        return CommandResult(
            stdout: result.standardOutput ?? "",
            stderr: result.standardError ?? "",
            exitCode: exitCode
        )
    }
    
    /// Run the CLI with the given arguments (convenience for string arguments)
    ///
    /// - Parameters:
    ///   - arguments: Space-separated command-line arguments
    ///   - workingDirectory: Directory to run the command in (optional)
    /// - Returns: Command result with stdout, stderr, and exit code
    func run(_ arguments: String, workingDirectory: FilePath? = nil) async throws -> CommandResult {
        let args = arguments.split(separator: " ").map(String.init)
        return try await run(arguments: args, workingDirectory: workingDirectory)
    }
    
    // MARK: - Git State Verification Helpers
    
    /// Run a git command and return its output
    ///
    /// - Parameters:
    ///   - arguments: Git command arguments (e.g., ["log", "--oneline"])
    ///   - workingDirectory: Directory to run git in
    /// - Returns: Git command output
    /// - Throws: If git command fails
    func runGit(_ arguments: [String], in workingDirectory: FilePath) async throws -> String {
        let result = try await Subprocess.run(
            .name("git"),
            arguments: .init(arguments),
            workingDirectory: workingDirectory,
            output: .string(limit: 4096),
            error: .string(limit: 4096)
        )
        
        guard case .exited(0) = result.terminationStatus else {
            let stderr = result.standardError ?? ""
            throw TestError.gitCommandFailed(arguments.joined(separator: " "), stderr)
        }
        
        return result.standardOutput ?? ""
    }
    
    /// Verify that a git commit exists with the given message
    ///
    /// - Parameters:
    ///   - message: Expected commit message
    ///   - workingDirectory: Git repository directory
    /// - Returns: True if commit with message exists
    /// - Throws: If git command fails
    func verifyCommitExists(withMessage message: String, in workingDirectory: FilePath) async throws -> Bool {
        let output = try await runGit(["log", "--oneline", "--all"], in: workingDirectory)
        return output.contains(message)
    }
    
    /// Get the git config value for a key
    ///
    /// - Parameters:
    ///   - key: Config key (e.g., "user.name")
    ///   - workingDirectory: Git repository directory
    /// - Returns: Config value
    /// - Throws: If git command fails
    func getGitConfig(_ key: String, in workingDirectory: FilePath) async throws -> String {
        let output = try await runGit(["config", key], in: workingDirectory)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Verify that the directory is a git repository
    ///
    /// - Parameter workingDirectory: Directory to check
    /// - Returns: True if directory is a git repository
    func isGitRepository(_ workingDirectory: FilePath) async -> Bool {
        do {
            _ = try await runGit(["rev-parse", "--git-dir"], in: workingDirectory)
            return true
        } catch {
            return false
        }
    }
}

/// Test-specific errors
enum TestError: Error, CustomStringConvertible {
    case gitCommandFailed(String, String)
    
    var description: String {
        switch self {
        case .gitCommandFailed(let command, let stderr):
            return "Git command failed: \(command)\n\(stderr)"
        }
    }
}
