import ArgumentParser
import Foundation

struct RemoveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove a configured subtree"
    )
    
    @Argument(help: "Name of the subtree to remove")
    var name: String
    
    mutating func run() throws {
        do {
            // Resolve repository root
            let repoRoot = try GitPlumbing.repositoryRoot()
            let configPath = ConfigIO.configPath(at: repoRoot)
            
            // Check if config exists
            guard ConfigIO.configExists(at: configPath) else {
                throw SubtreeError.configNotFound("subtree.yaml not found. Run 'subtree init' first.")
            }
            
            // Read config
            let config = try ConfigIO.readConfig(from: configPath)
            
            // Find the subtree in config
            guard let subtree = config.subtrees.first(where: { $0.name == name }) else {
                throw SubtreeError.invalidUsage("Subtree '\(name)' not found in configuration")
            }
            
            // Check if subtree directory exists
            let subtreePath = repoRoot.appendingPathComponent(subtree.prefix)
            guard FileManager.default.fileExists(atPath: subtreePath.path) else {
                throw SubtreeError.invalidUsage("Subtree '\(name)' not found at path '\(subtree.prefix)'. It may not have been added yet.")
            }
            
            // Remove the subtree atomically (subtree + config changes in single commit)
            try removeSubtreeAtomically(subtree, configPath: configPath, in: repoRoot)
            
            print("Removed subtree '\(subtree.name)' from '\(subtree.prefix)'")
            
        } catch let error as GitPlumbingError {
            switch error {
            case .notInGitRepository:
                throw SubtreeError.gitFailure("not a git repository (or any of the parent directories)")
            case .gitCommandFailed(let command, let exitCode, let stderr):
                throw SubtreeError.gitFailure("git command '\(command)' failed with exit code \(exitCode): \(stderr)")
            case .gitSubtreeNotAvailable:
                throw SubtreeError.gitFailure("git subtree command is not available")
            }
        } catch let error as SubtreeError {
            throw error
        } catch {
            throw SubtreeError.generalError("\(error)")
        }
    }
    
    /// Remove a subtree atomically with config updates in a single commit
    private func removeSubtreeAtomically(
        _ subtree: SubtreeEntry,
        configPath: URL,
        in repoRoot: URL
    ) throws {
        // Build commit message
        let commitMessage = buildRemoveCommitMessage(for: subtree)
        
        // Create atomic operation for remove
        let operation = GitPlumbing.AtomicSubtreeOperation.remove(
            prefix: subtree.prefix,
            message: commitMessage
        )
        
        // Define config update closure
        let configUpdate = {
            try ConfigIO.removeSubtreeEntry(at: configPath, subtreeName: subtree.name)
        }
        
        // Execute atomically
        try GitPlumbing.executeAtomicSubtreeOperation(
            operation: operation,
            configPath: configPath,
            configUpdate: configUpdate,
            workingDirectory: repoRoot
        )
    }
    
    private func removeSubtree(_ subtree: SubtreeEntry, in repoRoot: URL) throws {
        let subtreePath = repoRoot.appendingPathComponent(subtree.prefix)
        
        // Always use real git operations
        try removeSubtreeWithRealGit(subtree, repoRoot: repoRoot, subtreePath: subtreePath)
    }
    
    
    private func removeSubtreeWithRealGit(_ subtree: SubtreeEntry, repoRoot: URL, subtreePath: URL) throws {
        // Validate git subtree is available
        try GitPlumbing.validateGitSubtree()
        
        // For git subtree removal, we typically:
        // 1. Optionally push any local changes back to the subtree remote
        // 2. Remove the subtree directory from the working tree
        // 3. Create a commit documenting the removal
        
        // Note: git subtree doesn't have a built-in "remove" command like "add"
        // The standard approach is to remove the directory and commit the change
        
        // Remove the subtree directory
        if FileManager.default.fileExists(atPath: subtreePath.path) {
            // Use git rm to properly remove from git tracking
            let result = try GitPlumbing.runGitCommand(
                ["rm", "-rf", subtree.prefix],
                workingDirectory: repoRoot
            )
            
            if result.exitCode != 0 {
                throw SubtreeError.gitFailure("git rm failed: \(result.stderr)")
            }
            
            // Build enhanced commit message
            let commitMessage = buildRemoveCommitMessage(for: subtree)
            
            // Commit the removal
            let commitResult = try GitPlumbing.runGitCommand(
                ["commit", "-m", commitMessage],
                workingDirectory: repoRoot
            )
            
            if commitResult.exitCode != 0 {
                throw SubtreeError.gitFailure("git commit failed: \(commitResult.stderr)")
            }
        }
    }
    
    
    private func buildRemoveCommitMessage(for subtree: SubtreeEntry) -> String {
        // Build subtree state for commit message
        let subtreeState = CommitMessageBuilder.SubtreeState(
            name: subtree.name,
            remote: subtree.remote,
            prefix: subtree.prefix,
            ref: subtree.branch,
            commit: subtree.commit,
            refType: CommitMessageBuilder.determineRefType(subtree.branch)
        )
        
        return CommitMessageBuilder.buildMessage(
            operation: .remove,
            currentState: subtreeState
        )
    }
}
