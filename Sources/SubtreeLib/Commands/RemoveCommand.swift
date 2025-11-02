import ArgumentParser
import Foundation

/// Remove a subtree from the repository
public struct RemoveCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove a subtree from the repository and update configuration atomically"
    )
    
    // T001: Positional argument for subtree name
    @Argument(help: "Name of the subtree to remove")
    var name: String
    
    public init() {}
    
    public func run() async throws {
        // T010: Validate git repository
        guard await GitOperations.isRepository() else {
            print("❌ Must be run inside a git repository")
            Foundation.exit(1)
        }
        
        // T010: Find git root
        let gitRoot: String
        do {
            gitRoot = try await GitOperations.findGitRoot()
        } catch {
            print("❌ Could not find git repository root")
            Foundation.exit(1)
        }
        
        // T011: Check config exists
        let configPath = ConfigFileManager.configPath(gitRoot: gitRoot)
        guard ConfigFileManager.exists(at: configPath) else {
            print("❌ Configuration file not found. Run 'subtree init' first.")
            Foundation.exit(3)
        }
        
        // T012: Load and parse config with error handling
        let config: SubtreeConfiguration
        do {
            config = try ConfigurationParser.parseFile(at: configPath)
        } catch {
            // FR-022: Exit code 3 for malformed config with detailed message
            print("❌ Configuration file is malformed: \(error.localizedDescription)")
            Foundation.exit(3)
        }
        
        // T024: Validate config for corruption (case-insensitive duplicates)
        do {
            try config.validate()
        } catch let error as SubtreeValidationError {
            print(error.localizedDescription)
            Foundation.exit(Int32(error.exitCode))
        }
        
        // Normalize input name (trim whitespace)
        let normalizedName = name.normalized()
        
        // T023: Case-insensitive subtree lookup
        let subtree: SubtreeEntry
        do {
            guard let found = try config.findSubtree(name: normalizedName) else {
                // Not found - use SubtreeValidationError for consistency
                throw SubtreeValidationError.subtreeNotFound(normalizedName)
            }
            subtree = found
        } catch let error as SubtreeValidationError {
            print(error.localizedDescription)
            Foundation.exit(Int32(error.exitCode))
        }
        
        // T014: Validate clean working tree
        let statusResult = try await GitOperations.run(arguments: ["status", "--porcelain"])
        guard statusResult.stdout.isEmpty else {
            // FR-024: Exit code 1 for dirty working tree
            print("❌ Working tree has uncommitted changes. Commit or stash before removing subtrees")
            Foundation.exit(1)
        }
        
        // Validation complete - proceed with removal (Phase 3 implementation)
        
        // T024: Check if directory exists
        let directoryPath = "\(gitRoot)/\(subtree.prefix)"
        let directoryExists = FileManager.default.fileExists(atPath: directoryPath)
        
        // T026: Remove directory if it exists
        if directoryExists {
            do {
                try await GitOperations.remove(prefix: subtree.prefix)
            } catch {
                print("❌ Failed to remove directory: \(error.localizedDescription)")
                Foundation.exit(1)
            }
        }
        
        // T029/T030: Update config (remove entry) - use original subtree.name for case preservation
        let updatedSubtrees = config.subtrees.filter { $0.name != subtree.name }
        let updatedConfig = SubtreeConfiguration(subtrees: updatedSubtrees)
        
        do {
            try await ConfigFileManager.writeConfig(updatedConfig, to: configPath)
        } catch {
            print("❌ Failed to update configuration: \(error.localizedDescription)")
            Foundation.exit(1)
        }
        
        // T034: Format commit message - use original subtree.name for display
        let commitMessage = CommitMessageFormatter.formatRemove(
            name: subtree.name,
            lastCommit: subtree.commit
        )
        
        // T035: Stage config changes
        let stageResult = try await GitOperations.run(arguments: ["add", "subtree.yaml"])
        guard stageResult.exitCode == 0 else {
            print("❌ Failed to stage config changes")
            Foundation.exit(1)
        }
        
        // T036: Create commit with both changes
        let commitResult = try await GitOperations.run(arguments: [
            "commit", "-m", commitMessage
        ])
        
        if commitResult.exitCode != 0 {
            // T037: Handle commit failure
            print("⚠️  Subtree removed but failed to commit changes")
            print("Changes are staged. Complete the commit manually:")
            print("  git commit -m \"\(commitMessage)\"")
            Foundation.exit(1)
        }
        
        // T038/T047: Success output (context-aware for idempotent behavior)
        let shortHash = CommitMessageFormatter.shortHash(from: subtree.commit)
        if directoryExists {
            // Normal removal - directory was present
            print("✅ Removed subtree '\(subtree.name)' (was at \(shortHash))")
        } else {
            // Idempotent removal - directory already deleted
            print("✅ Removed subtree '\(subtree.name)' from config (directory already deleted, was at \(shortHash))")
        }
    }
}
