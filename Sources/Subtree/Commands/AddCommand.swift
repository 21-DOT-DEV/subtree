import ArgumentParser
import Foundation
import Subprocess
#if canImport(System)
import System
#else
import SystemPackage
#endif

struct AddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add one or more subtrees defined in config"
    )
    
    @Option(name: [.short, .long], help: "Name of the subtree to add")
    var name: String?
    
    @Flag(name: [.short, .long], help: "Add all configured subtrees")
    var all = false
    
    @Flag(name: .long, help: "Disable squashing commits (use --no-squash)")
    var noSquash = false
    
    // Override flags per FR-023
    @Option(name: .long, help: "Override remote URL (cannot be used with --all)")
    var remote: String?
    
    @Option(name: .long, help: "Override prefix path (cannot be used with --all)")  
    var prefix: String?
    
    @Option(name: .long, help: "Override branch or ref (cannot be used with --all)")
    var ref: String?
    
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
            
            // Validate arguments - now support inference from remote
            if name == nil && !all && remote == nil {
                throw SubtreeError.invalidUsage("Must specify either --name <name>, --remote <url>, or --all")
            }
            
            if name != nil && all {
                throw SubtreeError.invalidUsage("Cannot use --name and --all together")
            }
            
            // Per FR-024: Overrides MUST NOT be combined with --all
            if all && (remote != nil || prefix != nil || ref != nil) {
                throw SubtreeError.invalidUsage("Override flags (--remote, --prefix, --ref) cannot be used with --all")
            }
            
            // Determine which subtrees to add
            let subtreesToAdd: [SubtreeEntry]
            if all {
                subtreesToAdd = config.subtrees
            } else {
                // Smart inference support: infer from --remote if --name not provided
                let effectiveName: String
                
                if let targetName = name {
                    effectiveName = targetName
                } else if let remoteUrl = remote {
                    // Infer name from remote URL
                    effectiveName = try RemoteURLParser.inferNameFromRemote(remoteUrl)
                } else {
                    throw SubtreeError.invalidUsage("Must specify either --name or --remote")
                }
                
                // Look for existing configuration first
                if let subtree = config.subtrees.first(where: { $0.name == effectiveName }) {
                    // Apply overrides per FR-023 to existing config
                    let effectiveSubtree = applyOverrides(to: subtree)
                    subtreesToAdd = [effectiveSubtree]
                } else {
                    // Create new subtree with smart defaults
                    let newSubtree = try createNewSubtreeWithInference(
                        name: effectiveName,
                        remoteOverride: remote,
                        prefixOverride: prefix,
                        refOverride: ref
                    )
                    subtreesToAdd = [newSubtree]
                }
            }
            
            // Add each subtree atomically (subtree + config changes in single commit)
            for subtree in subtreesToAdd {
                try addSubtreeAtomically(subtree, config: config, configPath: configPath, in: repoRoot)
            }
            
            if subtreesToAdd.count == 1 {
                print("Added subtree '\(subtreesToAdd[0].name)' at '\(subtreesToAdd[0].prefix)'")
            } else {
                print("Added \(subtreesToAdd.count) subtrees")
            }
            
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
    
    /// Add a subtree atomically with config updates in a single commit
    private func addSubtreeAtomically(
        _ subtree: SubtreeEntry, 
        config: SubtreeConfig,
        configPath: URL,
        in repoRoot: URL
    ) throws {
        // Ensure we're in a git repository
        try validateGitRepository(at: repoRoot)
        
        // Check if subtree already exists (idempotency)
        let subtreePath = repoRoot.appendingPathComponent(subtree.prefix)
        if FileManager.default.fileExists(atPath: subtreePath.path) {
            // Simple idempotency: if directory exists, assume it's correctly added
            return
        }
        
        // Resolve commit hash for recording in config
        let resolvedCommit = try? resolveCommitForRef(subtree.remote, ref: subtree.branch)
        let subtreeWithCommit = SubtreeEntry(
            name: subtree.name,
            remote: subtree.remote,
            prefix: subtree.prefix,
            branch: subtree.branch,
            squash: subtree.squash,
            commit: resolvedCommit,
            copies: subtree.copies,
            update: subtree.update
        )
        
        // Build commit message
        let commitMessage = try buildAddCommitMessage(for: subtree)
        
        // Create atomic operation
        let operation = GitPlumbing.AtomicSubtreeOperation.add(
            prefix: subtree.prefix,
            remote: subtree.remote,
            branch: subtree.branch,
            squash: subtree.squash ?? true,
            message: commitMessage
        )
        
        // Define config update closure
        let configUpdate = {
            // Check if subtree already exists in config
            if config.subtrees.contains(where: { $0.name == subtree.name }) {
                // Update existing entry with commit hash
                try ConfigIO.updateSubtreeCommit(
                    at: configPath,
                    subtreeName: subtree.name,
                    commitHash: resolvedCommit ?? ""
                )
            } else {
                // Add new subtree entry
                try ConfigIO.addSubtreeEntry(at: configPath, subtree: subtreeWithCommit)
            }
        }
        
        // Execute atomically
        try GitPlumbing.executeAtomicSubtreeOperation(
            operation: operation,
            configPath: configPath,
            configUpdate: configUpdate,
            workingDirectory: repoRoot
        )
    }
    
    private func addSubtreeSync(_ subtree: SubtreeEntry, in repoRoot: URL) throws {
        // Ensure we're in a git repository
        try validateGitRepository(at: repoRoot)
        
        // Check if subtree already exists (idempotency)
        let subtreePath = repoRoot.appendingPathComponent(subtree.prefix)
        if FileManager.default.fileExists(atPath: subtreePath.path) {
            // Simple idempotency: if directory exists, assume it's correctly added
            return
        }
        
        // Check if we should use real git operations or simulate them
        // Always use real git operations
        try addSubtreeWithRealGit(subtree, repoRoot: repoRoot, subtreePath: subtreePath)
    }
    
    
    private func addSubtreeWithRealGit(_ subtree: SubtreeEntry, repoRoot: URL, subtreePath: URL) throws {
        // Validate git subtree is available
        try GitPlumbing.validateGitSubtree()
        
        // Build enhanced commit message
        let commitMessage = try buildAddCommitMessage(for: subtree)
        
        // Prepare git subtree add command arguments
        // Correct syntax: git subtree add --prefix=<prefix> [--squash] -m "<message>" <repository> <ref>
        var gitArgs = ["subtree", "add", "--prefix=\(subtree.prefix)"]
        
        // Add squash flag if enabled (default is true)
        if subtree.squash ?? true {
            gitArgs.append("--squash")
        }
        
        // Add custom commit message
        gitArgs.append("-m")
        gitArgs.append(commitMessage)
        
        // Add repository and ref
        gitArgs.append(subtree.remote)
        gitArgs.append(subtree.branch)
        
        // Execute git subtree add command
        let result = try GitPlumbing.runGitCommand(gitArgs, workingDirectory: repoRoot)
        
        // Check if command was successful
        if result.exitCode != 0 {
            throw SubtreeError.gitFailure("git subtree add failed: \(result.stderr)")
        }
        
        // Note: Config pinning could be enhanced to track specific commit hashes
        // Current behavior: Manual config updates when specific commits needed
    }
    
    
    private func applyOverrides(to subtree: SubtreeEntry) -> SubtreeEntry {
        // Per FR-023: Apply command-line overrides without modifying configuration
        return SubtreeEntry(
            name: subtree.name,
            remote: remote ?? subtree.remote,  // Override remote if provided
            prefix: prefix ?? subtree.prefix,  // Override prefix if provided
            branch: ref ?? subtree.branch,     // Override branch/ref if provided
            squash: noSquash ? false : subtree.squash,  // Apply --no-squash override
            commit: subtree.commit,
            copies: subtree.copies,
            update: subtree.update
        )
    }
    
    private func buildAddCommitMessage(for subtree: SubtreeEntry) throws -> String {
        // Try to resolve the commit SHA for the ref
        let resolvedCommit = try? resolveCommitForRef(subtree.remote, ref: subtree.branch)
        
        // Build subtree state
        let currentState = CommitMessageBuilder.SubtreeState(
            name: subtree.name,
            remote: subtree.remote,
            prefix: subtree.prefix,
            ref: subtree.branch,
            commit: resolvedCommit,
            refType: CommitMessageBuilder.determineRefType(subtree.branch)
        )
        
        return CommitMessageBuilder.buildMessage(
            operation: .add,
            currentState: currentState
        )
    }
    
    private func resolveCommitForRef(_ remote: String, ref: String) throws -> String? {
        // Use git ls-remote to resolve the ref to a commit SHA
        let gitArgs = ["ls-remote", remote, ref]
        
        do {
            let result = try GitPlumbing.runGitCommand(gitArgs, workingDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            
            if result.exitCode == 0 && !result.stdout.isEmpty {
                // Parse output: "commit_sha\trefs/heads/branch" or "commit_sha\tHEAD"
                let lines = result.stdout.components(separatedBy: .newlines)
                for line in lines {
                    let components = line.components(separatedBy: "\t")
                    if components.count >= 2 && !components[0].isEmpty {
                        // Return the first 40-character commit SHA
                        let commitSHA = String(components[0].prefix(40))
                        if commitSHA.count == 40 {
                            return commitSHA
                        }
                    }
                }
            }
        } catch {
            // If git ls-remote fails, continue without commit info
            // This allows the operation to succeed even if network is unavailable
        }
        
        return nil
    }
    
    private func createNewSubtreeWithInference(
        name: String,
        remoteOverride: String?,
        prefixOverride: String?,
        refOverride: String?
    ) throws -> SubtreeEntry {
        // Remote URL is required (either provided directly or must be specified)
        guard let remoteUrl = remoteOverride else {
            throw SubtreeError.invalidUsage("Remote URL is required when creating new subtree '\(name)'")
        }
        
        // Infer prefix from name if not provided
        let effectivePrefix = prefixOverride ?? RemoteURLParser.inferPrefixFromName(name)
        
        // Smart default: Use "main" branch if no ref provided
        let effectiveRef = refOverride ?? "main"
        
        return SubtreeEntry(
            name: name,
            remote: remoteUrl,
            prefix: effectivePrefix,
            branch: effectiveRef,
            squash: !noSquash,  // Default to squash=true unless --no-squash
            commit: nil,
            copies: nil,
            update: nil
        )
    }
    
    private func validateGitRepository(at repoRoot: URL) throws {
        let gitDir = repoRoot.appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir.path) else {
            throw SubtreeError.invalidUsage("Not in a git repository. Initialize with 'git init' first.")
        }
    }
}
