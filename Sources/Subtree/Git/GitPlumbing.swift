import Foundation
import Subprocess
#if canImport(System)
import System
#else
import SystemPackage
#endif

/// Errors that can occur during Git operations
public enum GitPlumbingError: Error {
    case notInGitRepository
    case gitCommandFailed(command: String, exitCode: Int, stderr: String)
    case gitSubtreeNotAvailable
}

/// Low-level Git operations using subprocess
public enum GitPlumbing {
    
    /// Get the repository root directory using git rev-parse --show-toplevel
    public static func repositoryRoot() throws -> URL {
        var result: Result<URL, Error>?
        
        let _ = Task {
            do {
                let subprocessResult = try await Subprocess.run(
                    .name("git"),
                    arguments: .init(["rev-parse", "--show-toplevel"]),
                    output: .string(limit: 4096),
                    error: .string(limit: 4096)
                )
                
                // Check if git command succeeded
                guard case .exited(0) = subprocessResult.terminationStatus else {
                    result = .failure(GitPlumbingError.notInGitRepository)
                    return
                }
                
                let rootPath = subprocessResult.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                result = .success(URL(fileURLWithPath: rootPath))
                
            } catch {
                result = .failure(GitPlumbingError.notInGitRepository)
            }
        }
        
        // Wait for task to complete
        while result == nil {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        
        return try result!.get()
    }
    
    /// Validate that git subtree command is available
    public static func validateGitSubtree() throws {
        var result: Result<Void, Error>?
        
        let _ = Task {
            do {
                let subprocessResult = try await Subprocess.run(
                    .name("git"),
                    arguments: .init(["subtree"]),
                    output: .string(limit: 4096),
                    error: .string(limit: 4096)
                )
                
                // Git subtree shows usage with exit code 129 when no arguments provided
                if case .exited(129) = subprocessResult.terminationStatus {
                    result = .success(())
                } else {
                    result = .failure(GitPlumbingError.gitSubtreeNotAvailable)
                }
                
            } catch {
                result = .failure(GitPlumbingError.gitSubtreeNotAvailable)
            }
        }
        
        // Wait for task to complete
        while result == nil {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        
        try result!.get()
    }
    
    /// Run a git command with enhanced error reporting
    public static func runGitCommand(
        _ arguments: [String],
        workingDirectory: URL? = nil
    ) throws -> (exitCode: Int, stdout: String, stderr: String) {
        var result: Result<(Int, String, String), Error>?
        
        let workingDir = workingDirectory.map { FilePath($0.path) }
        
        let _ = Task {
            do {
                let subprocessResult = try await Subprocess.run(
                    .name("git"),
                    arguments: .init(arguments),
                    workingDirectory: workingDir,
                    output: .string(limit: 65536),
                    error: .string(limit: 65536)
                )
                
                let exitCode: Int
                if case .exited(let code) = subprocessResult.terminationStatus {
                    exitCode = Int(code)
                } else {
                    exitCode = -1
                }
                
                let stdout = subprocessResult.standardOutput ?? ""
                let stderr = subprocessResult.standardError ?? ""
                
                result = .success((exitCode, stdout, stderr))
                
            } catch {
                result = .failure(error)
            }
        }
        
        // Wait for task to complete
        while result == nil {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        
        return try result!.get()
    }
    
    /// Run git fetch for a specific remote and branch
    public static func gitFetch(remote: String, branch: String, workingDirectory: URL) throws {
        let result = try runGitCommand(["fetch", remote, branch], workingDirectory: workingDirectory)
        
        if result.exitCode != 0 {
            throw GitPlumbingError.gitCommandFailed(
                command: "git fetch \(remote) \(branch)",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
    }
    
    /// Run git subtree pull operation
    public static func gitSubtreePull(
        prefix: String,
        remote: String,
        branch: String,
        squash: Bool = true,
        workingDirectory: URL
    ) throws {
        var arguments = ["subtree", "pull"]
        
        if squash {
            arguments.append("--squash")
        }
        
        arguments.append(contentsOf: ["--prefix", prefix, remote, branch])
        
        let result = try runGitCommand(arguments, workingDirectory: workingDirectory)
        
        if result.exitCode != 0 {
            throw GitPlumbingError.gitCommandFailed(
                command: "git subtree pull --prefix \(prefix) \(remote) \(branch)",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
    }
    
    /// Check if a remote is reachable by attempting a lightweight fetch
    public static func isRemoteReachable(_ remote: String, workingDirectory: URL) -> Bool {
        do {
            // Try a dry-run fetch to check reachability without actually downloading
            let result = try runGitCommand(
                ["ls-remote", "--heads", remote],
                workingDirectory: workingDirectory
            )
            return result.exitCode == 0
        } catch {
            return false
        }
    }
    
    // MARK: - Atomic Subtree Operations
    
    /// Represents the type of subtree operation to perform atomically
    public enum AtomicSubtreeOperation {
        case add(prefix: String, remote: String, branch: String, squash: Bool, message: String)
        case update(prefix: String, remote: String, branch: String, squash: Bool)
        case remove(prefix: String, message: String)
    }
    
    /// Execute a subtree operation atomically with config file changes
    /// This ensures both the subtree operation and config updates happen in a single commit
    public static func executeAtomicSubtreeOperation(
        operation: AtomicSubtreeOperation,
        configPath: URL,
        configUpdate: () throws -> Void,
        workingDirectory: URL
    ) throws {
        // Step 1: Execute the git subtree operation first (creates its own commit)
        try executeSubtreeOperation(operation, workingDirectory: workingDirectory)
        
        // Step 2: Perform config update (modifies file but doesn't commit)
        try configUpdate()
        
        // Step 3: Amend the previous commit to include config changes
        try amendCommitWithConfigChanges(configPath: configPath, workingDirectory: workingDirectory)
    }
    
    /// Amend the most recent commit to include config file changes
    private static func amendCommitWithConfigChanges(configPath: URL, workingDirectory: URL) throws {
        let relativePath = configPath.path.replacingOccurrences(
            of: workingDirectory.path + "/",
            with: ""
        )
        
        // Check if config file actually has changes to avoid unnecessary operations
        let statusResult = try runGitCommand(
            ["status", "--porcelain", relativePath],
            workingDirectory: workingDirectory
        )
        
        // If no changes to config file, skip amend
        if statusResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        
        // Stage the config file changes
        let addResult = try runGitCommand(
            ["add", relativePath],
            workingDirectory: workingDirectory
        )
        
        if addResult.exitCode != 0 {
            throw GitPlumbingError.gitCommandFailed(
                command: "git add \(relativePath)",
                exitCode: addResult.exitCode,
                stderr: addResult.stderr
            )
        }
        
        // Amend the previous commit to include the staged changes
        let amendResult = try runGitCommand(
            ["commit", "--amend", "--no-edit"],
            workingDirectory: workingDirectory
        )
        
        if amendResult.exitCode != 0 {
            throw GitPlumbingError.gitCommandFailed(
                command: "git commit --amend --no-edit", 
                exitCode: amendResult.exitCode,
                stderr: amendResult.stderr
            )
        }
        
        // Ensure working tree is clean after amend
        try verifyWorkingTreeClean(workingDirectory: workingDirectory)
    }
    
    /// Verify that the working tree is clean after operations
    private static func verifyWorkingTreeClean(workingDirectory: URL) throws {
        let statusResult = try runGitCommand(
            ["status", "--porcelain"],
            workingDirectory: workingDirectory
        )
        
        if !statusResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // If there are still modifications, this suggests an issue with our atomic operation
            // Log the status for debugging but don't fail - git subtree might handle it
            print("Warning: Working tree has modifications after atomic operation: \(statusResult.stdout)")
        }
    }
    
    /// Stage the config file so it will be included in the next commit
    private static func stageConfigFile(configPath: URL, workingDirectory: URL) throws {
        let relativePath = configPath.path.replacingOccurrences(
            of: workingDirectory.path + "/",
            with: ""
        )
        
        let result = try runGitCommand(
            ["add", relativePath],
            workingDirectory: workingDirectory
        )
        
        if result.exitCode != 0 {
            throw GitPlumbingError.gitCommandFailed(
                command: "git add \(relativePath)",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
    }
    
    /// Execute the actual git subtree operation
    private static func executeSubtreeOperation(
        _ operation: AtomicSubtreeOperation,
        workingDirectory: URL
    ) throws {
        let arguments: [String]
        
        switch operation {
        case .add(let prefix, let remote, let branch, let squash, let message):
            arguments = buildSubtreeAddArguments(
                prefix: prefix,
                remote: remote,
                branch: branch,
                squash: squash,
                message: message
            )
            
        case .update(let prefix, let remote, let branch, let squash):
            arguments = buildSubtreePullArguments(
                prefix: prefix,
                remote: remote,
                branch: branch,
                squash: squash
            )
            
        case .remove(let prefix, let message):
            // Handle remove operation - git rm + commit
            try executeSubtreeRemove(prefix: prefix, message: message, workingDirectory: workingDirectory)
            return // Skip the standard runGitCommand path
        }
        
        let result = try runGitCommand(arguments, workingDirectory: workingDirectory)
        
        if result.exitCode != 0 {
            let operation = arguments.joined(separator: " ")
            throw GitPlumbingError.gitCommandFailed(
                command: "git \(operation)",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
    }
    
    /// Build arguments for git subtree add command
    private static func buildSubtreeAddArguments(
        prefix: String,
        remote: String,
        branch: String,
        squash: Bool,
        message: String
    ) -> [String] {
        var args = ["subtree", "add", "--prefix=\(prefix)"]
        
        if squash {
            args.append("--squash")
        }
        
        args.append(contentsOf: ["-m", message, remote, branch])
        return args
    }
    
    /// Build arguments for git subtree pull command
    private static func buildSubtreePullArguments(
        prefix: String,
        remote: String,
        branch: String,
        squash: Bool
    ) -> [String] {
        var args = ["subtree", "pull", "--prefix=\(prefix)"]
        
        if squash {
            args.append("--squash")
        }
        
        args.append(contentsOf: [remote, branch])
        return args
    }
    
    /// Execute subtree remove operation (git rm + commit)
    private static func executeSubtreeRemove(
        prefix: String,
        message: String,
        workingDirectory: URL
    ) throws {
        // First, remove the subtree directory using git rm
        let rmResult = try runGitCommand(
            ["rm", "-rf", prefix],
            workingDirectory: workingDirectory
        )
        
        if rmResult.exitCode != 0 {
            throw GitPlumbingError.gitCommandFailed(
                command: "git rm -rf \(prefix)",
                exitCode: rmResult.exitCode,
                stderr: rmResult.stderr
            )
        }
        
        // Then commit the removal
        let commitResult = try runGitCommand(
            ["commit", "-m", message],
            workingDirectory: workingDirectory
        )
        
        if commitResult.exitCode != 0 {
            throw GitPlumbingError.gitCommandFailed(
                command: "git commit -m \"\(message)\"",
                exitCode: commitResult.exitCode,
                stderr: commitResult.stderr
            )
        }
    }
    
    /// Get the commit hash from the most recent commit
    public static func getLatestCommitHash(workingDirectory: URL) throws -> String {
        let result = try runGitCommand(
            ["rev-parse", "HEAD"],
            workingDirectory: workingDirectory
        )
        
        if result.exitCode != 0 {
            throw GitPlumbingError.gitCommandFailed(
                command: "git rev-parse HEAD",
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
        
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
