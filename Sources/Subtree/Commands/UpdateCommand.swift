import ArgumentParser
import Foundation
import SemanticVersion

struct UpdateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update one or more configured subtrees"
    )
    
    @Option(name: [.short, .long], help: "Name of the subtree to update")
    var name: String?
    
    @Flag(name: [.short, .long], help: "Update all configured subtrees")
    var all = false
    
    @Flag(name: .long, help: "Apply updates (default is report-only mode)")
    var commit = false
    
    @Flag(name: .long, help: "Combine all updates into a single commit (requires --commit)")
    var singleCommit = false
    
    @Option(name: [.short, .long], help: "Override update reference type (branch, tag, commit)")
    var ref: String?
    
    @Option(name: .long, help: "Override SemVer constraint (e.g., ^1.0.0)")
    var constraint: String?
    
    @Flag(name: .long, help: "Override to include prerelease versions")
    var includePrereleases = false
    
    @Option(name: .long, help: "Create/use a specific branch for updates")
    var branch: String?
    
    @Flag(name: .long, help: "Commit updates on the current branch (don't create topic branch)")
    var onCurrent = false
    
    @Flag(name: .long, help: "Show planned changes without applying them")
    var dryRun = false
    
    @Flag(name: .long, help: "Force updates even when subtree paths have modifications")
    var force = false
    
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
            
            // Smart default: if no name or --all specified, default to updating all subtrees
            let shouldUpdateAll = all || name == nil
            
            if name != nil && all {
                throw SubtreeError.invalidUsage("Cannot use --name and --all together")
            }
            
            if singleCommit && !commit {
                throw SubtreeError.invalidUsage("--single-commit requires --commit")
            }
            
            // Validate override options
            if let refString = ref {
                guard UpdateMode(rawValue: refString) != nil else {
                    throw SubtreeError.invalidUsage("Invalid reference type '\(refString)'. Valid types: branch, tag, commit")
                }
            }
            
            if let constraintOverride = constraint {
                // Validate constraint override using the same logic as config validation
                try validateSemVerConstraint(constraintOverride)
            }
            
            // Validate branch options
            if branch != nil && onCurrent {
                throw SubtreeError.invalidUsage("Cannot use --branch and --on-current together")
            }
            
            if (branch != nil || onCurrent) && !commit {
                throw SubtreeError.invalidUsage("Branch options (--branch, --on-current) require --commit")
            }
            
            // Validate safety options
            if dryRun && !commit {
                throw SubtreeError.invalidUsage("--dry-run requires --commit")
            }
            
            if force && !commit {
                throw SubtreeError.invalidUsage("--force requires --commit")
            }
            
            // Determine which subtrees to update
            let subtreesToUpdate: [SubtreeEntry]
            if shouldUpdateAll {
                subtreesToUpdate = config.subtrees
            } else if let targetName = name {
                guard let subtree = config.subtrees.first(where: { $0.name == targetName }) else {
                    throw SubtreeError.invalidUsage("Subtree '\(targetName)' not found in configuration")
                }
                subtreesToUpdate = [subtree]
            } else {
                subtreesToUpdate = []
            }
            
            // Apply overrides to subtrees before processing
            let processedSubtrees = subtreesToUpdate.map { applyOverrides(to: $0) }
            
            if commit {
                // Apply mode: actually perform the updates
                
                // Perform safety checks before applying updates (unless --force)
                if !force && !dryRun {
                    for subtree in processedSubtrees {
                        try performSafetyChecks(for: subtree, in: repoRoot)
                    }
                }
                
                if dryRun {
                    // Dry-run mode: show plan without applying changes
                    try showUpdatePlan(for: processedSubtrees, in: repoRoot)
                } else {
                    // Handle branch strategy before applying updates
                    let originalBranch = try handleBranchStrategy(for: processedSubtrees, in: repoRoot)
                    
                    let subtreesWithUpdates = try applyUpdates(processedSubtrees, in: repoRoot)
                    
                    // Switch back to original branch if we created a topic branch
                    if let originalBranch = originalBranch, !onCurrent && branch == nil {
                        try switchBackToOriginalBranch(originalBranch, in: repoRoot)
                    }
                    
                    if subtreesWithUpdates.isEmpty {
                        if processedSubtrees.count == 1 {
                            print("No updates available for '\(processedSubtrees[0].name)'")
                        } else {
                            print("All \(processedSubtrees.count) subtrees are up to date")
                        }
                    } else {
                        if subtreesWithUpdates.count == 1 {
                            print("Updated subtree '\(subtreesWithUpdates[0].name)' at '\(subtreesWithUpdates[0].prefix)'")
                        } else if singleCommit {
                            print("Updated \(subtreesWithUpdates.count) subtrees in single commit")
                        } else {
                            print("Updated \(subtreesWithUpdates.count) subtrees")
                        }
                    }
                }
            } else {
                // Report mode: check for pending updates without applying
                var pendingUpdates: [SubtreeEntry] = []
                
                for subtree in processedSubtrees {
                    if try hasPendingUpdates(subtree, in: repoRoot) {
                        pendingUpdates.append(subtree)
                    }
                }
                
                if pendingUpdates.isEmpty {
                    if subtreesToUpdate.count == 1 {
                        print("No updates available for '\(subtreesToUpdate[0].name)'")
                    } else {
                        print("All \(subtreesToUpdate.count) subtrees are up to date")
                    }
                } else {
                    if pendingUpdates.count == 1 {
                        print("Updates available for '\(pendingUpdates[0].name)'")
                    } else {
                        print("Updates available for \(pendingUpdates.count) subtrees")
                    }
                    
                    // Exit with code 5 to indicate pending updates available
                    throw SubtreeError.updatesAvailable("Updates available")
                }
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
    
    private func updateSubtreeSync(_ subtree: SubtreeEntry, in repoRoot: URL) throws {
        // Check if subtree directory exists
        let subtreePath = repoRoot.appendingPathComponent(subtree.prefix)
        guard FileManager.default.fileExists(atPath: subtreePath.path) else {
            throw SubtreeError.invalidUsage("Subtree '\(subtree.name)' not found at path '\(subtree.prefix)'. It may not have been added yet.")
        }
        
        // Always use real git operations
        try updateSubtreeWithRealGit(subtree, repoRoot: repoRoot)
    }
    
    
    private func updateSubtreeWithRealGit(_ subtree: SubtreeEntry, repoRoot: URL) throws {
        // Validate git subtree is available
        try GitPlumbing.validateGitSubtree()
        
        // First, fetch the remote to ensure we have the latest changes
        try GitPlumbing.gitFetch(
            remote: subtree.remote,
            branch: subtree.branch,
            workingDirectory: repoRoot
        )
        
        // Execute git subtree pull using the enhanced GitPlumbing
        try GitPlumbing.gitSubtreePull(
            prefix: subtree.prefix,
            remote: subtree.remote,
            branch: subtree.branch,
            squash: subtree.squash ?? true,
            workingDirectory: repoRoot
        )
        
        // Note: Config pinning enhancement could track commit hashes automatically
        // Current behavior: Manual config updates preserve user control
    }
    
    
    private func hasPendingUpdates(_ subtree: SubtreeEntry, in repoRoot: URL) throws -> Bool {
        // Check if subtree directory exists
        let subtreePath = repoRoot.appendingPathComponent(subtree.prefix)
        guard FileManager.default.fileExists(atPath: subtreePath.path) else {
            return false  // Can't update what doesn't exist
        }
        
        // For real repos, check if remote has new commits
        // Get remote HEAD commit
        let remoteResult = try GitPlumbing.runGitCommand([
            "ls-remote", subtree.remote, subtree.branch
        ], workingDirectory: repoRoot)
        
        guard !remoteResult.stdout.isEmpty else {
            return false  // Can't determine remote state
        }
        
        let remoteCommit = String(remoteResult.stdout.prefix(40)) // First 40 chars = commit hash
        
        // Get local commit for this subtree prefix
        let localResult = try GitPlumbing.runGitCommand([
            "log", "-1", "--format=%H", "--", subtree.prefix
        ], workingDirectory: repoRoot)
        
        let localCommit = localResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return remoteCommit != localCommit
    }
    
    
    private func applyUpdates(_ subtrees: [SubtreeEntry], in repoRoot: URL) throws -> [SubtreeEntry] {
        var updatedSubtrees: [SubtreeEntry] = []
        let configPath = ConfigIO.configPath(at: repoRoot)
        
        for subtree in subtrees {
            // Only update if there are pending updates
            if try hasPendingUpdates(subtree, in: repoRoot) {
                try updateSubtreeAtomically(subtree, configPath: configPath, in: repoRoot)
                updatedSubtrees.append(subtree)
            }
        }
        
        return updatedSubtrees
    }
    
    /// Update a subtree atomically with config updates in a single commit
    private func updateSubtreeAtomically(
        _ subtree: SubtreeEntry,
        configPath: URL,
        in repoRoot: URL
    ) throws {
        // First, fetch to ensure latest remote state
        try GitPlumbing.gitFetch(
            remote: subtree.remote,
            branch: subtree.branch,
            workingDirectory: repoRoot
        )
        
        // Get the current remote commit hash for recording
        let remoteResult = try GitPlumbing.runGitCommand([
            "ls-remote", subtree.remote, subtree.branch
        ], workingDirectory: repoRoot)
        
        let newCommitHash = String(remoteResult.stdout.prefix(40)) // First 40 chars = commit hash
        
        // Create atomic operation for update
        let operation = GitPlumbing.AtomicSubtreeOperation.update(
            prefix: subtree.prefix,
            remote: subtree.remote,
            branch: subtree.branch,
            squash: subtree.squash ?? true
        )
        
        // Define config update closure
        let configUpdate = {
            try ConfigIO.updateSubtreeCommit(
                at: configPath,
                subtreeName: subtree.name,
                commitHash: newCommitHash
            )
        }
        
        // Execute atomically
        try GitPlumbing.executeAtomicSubtreeOperation(
            operation: operation,
            configPath: configPath,
            configUpdate: configUpdate,
            workingDirectory: repoRoot
        )
    }
    
    private func validateSemVerConstraint(_ constraint: String) throws {
        if constraint.isEmpty {
            throw SubtreeError.invalidUsage("Empty SemVer constraint")
        }
        
        // Parse and validate SemVer constraint using SemanticVersion package
        let cleanConstraint = constraint.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle constraint operators (^, ~, >=, <=, >, <, =)
        let constraintOperators = [">=", "<=", "^", "~", ">", "<", "="]
        var versionString = cleanConstraint
        var foundOperator = false
        
        for op in constraintOperators {
            if cleanConstraint.hasPrefix(op) {
                versionString = String(cleanConstraint.dropFirst(op.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                foundOperator = true
                break
            }
        }
        
        // If no operator found, assume exact match
        if !foundOperator {
            versionString = cleanConstraint
        }
        
        // Remove 'v' prefix if present
        if versionString.hasPrefix("v") || versionString.hasPrefix("V") {
            versionString = String(versionString.dropFirst())
        }
        
        // Validate that the version string can be parsed as a semantic version
        guard SemanticVersion(versionString) != nil else {
            throw SubtreeError.invalidUsage("Invalid SemVer constraint '\(constraint)'. Expected format: '^1.2.3', '>=2.0.0', '~1.5.0', etc.")
        }
    }
    
    private func applyOverrides(to subtree: SubtreeEntry) -> SubtreeEntry {
        // Create new update policy with overrides applied
        let originalUpdate = subtree.update ?? UpdatePolicy()
        
        let overriddenMode: UpdateMode
        if let refString = ref, let parsedMode = UpdateMode(rawValue: refString) {
            overriddenMode = parsedMode
        } else {
            overriddenMode = originalUpdate.mode
        }
        
        let overriddenConstraint = constraint ?? originalUpdate.constraint
        
        let overriddenIncludePrereleases: Bool?
        if includePrereleases {
            // Flag was set, so override to true
            overriddenIncludePrereleases = true
        } else {
            // Flag not set, use original value
            overriddenIncludePrereleases = originalUpdate.includePrereleases
        }
        
        let overriddenUpdate = UpdatePolicy(
            mode: overriddenMode,
            constraint: overriddenConstraint,
            includePrereleases: overriddenIncludePrereleases
        )
        
        // Return new SubtreeEntry with overridden update policy
        return SubtreeEntry(
            name: subtree.name,
            remote: subtree.remote,
            prefix: subtree.prefix,
            branch: subtree.branch,
            squash: subtree.squash,
            commit: subtree.commit,
            copies: subtree.copies,
            update: overriddenUpdate
        )
    }
    
    private func handleBranchStrategy(for subtrees: [SubtreeEntry], in repoRoot: URL) throws -> String? {
        // If --on-current is specified, stay on current branch
        if onCurrent {
            return nil
        }
        
        // Get current branch name for later restoration
        let currentBranch = try getCurrentBranch(in: repoRoot)
        
        // If --branch is specified, use custom branch name
        if let customBranch = branch {
            try createOrSwitchToBranch(customBranch, in: repoRoot)
            return currentBranch
        }
        
        // Create default topic branch
        let topicBranchName = generateTopicBranchName(for: subtrees)
        try createOrSwitchToBranch(topicBranchName, in: repoRoot)
        
        return currentBranch
    }
    
    private func getCurrentBranch(in repoRoot: URL) throws -> String {
        let result = try GitPlumbing.runGitCommand([
            "rev-parse", "--abbrev-ref", "HEAD"
        ], workingDirectory: repoRoot)
        
        if result.exitCode != 0 {
            throw SubtreeError.gitFailure("Failed to get current branch: \(result.stderr)")
        }
        
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generateTopicBranchName(for subtrees: [SubtreeEntry]) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        
        if subtrees.count == 1 {
            return "update/\(subtrees[0].name)/\(timestamp)"
        } else {
            return "update/all/\(timestamp)"
        }
    }
    
    private func createOrSwitchToBranch(_ branchName: String, in repoRoot: URL) throws {
        // Check if branch exists
        let checkResult = try GitPlumbing.runGitCommand([
            "rev-parse", "--verify", branchName
        ], workingDirectory: repoRoot)
        
        if checkResult.exitCode == 0 {
            // Branch exists, switch to it
            let checkoutResult = try GitPlumbing.runGitCommand([
                "checkout", branchName
            ], workingDirectory: repoRoot)
            
            if checkoutResult.exitCode != 0 {
                throw SubtreeError.gitFailure("Failed to checkout branch '\(branchName)': \(checkoutResult.stderr)")
            }
        } else {
            // Create new branch
            let createResult = try GitPlumbing.runGitCommand([
                "checkout", "-b", branchName
            ], workingDirectory: repoRoot)
            
            if createResult.exitCode != 0 {
                throw SubtreeError.gitFailure("Failed to create branch '\(branchName)': \(createResult.stderr)")
            }
        }
    }
    
    private func switchBackToOriginalBranch(_ branchName: String, in repoRoot: URL) throws {
        let result = try GitPlumbing.runGitCommand([
            "checkout", branchName
        ], workingDirectory: repoRoot)
        
        if result.exitCode != 0 {
            throw SubtreeError.gitFailure("Failed to switch back to branch '\(branchName)': \(result.stderr)")
        }
    }
    
    private func performSafetyChecks(for subtree: SubtreeEntry, in repoRoot: URL) throws {
        // Skip checks when --force is used
        if force {
            return
        }
        
        // Check for uncommitted changes in the subtree path
        let result = try GitPlumbing.runGitCommand([
            "status", "--porcelain", subtree.prefix
        ], workingDirectory: repoRoot)
        
        if !result.stdout.isEmpty {
            throw SubtreeError.invalidUsage(
                "Subtree path '\(subtree.prefix)' has uncommitted changes. Use --force to override."
            )
        }
    }
    
    private func showUpdatePlan(for subtrees: [SubtreeEntry], in repoRoot: URL) throws {
        print("Plan: Update simulation (dry-run mode)")
        
        var updatesAvailable = 0
        
        for subtree in subtrees {
            if try hasPendingUpdates(subtree, in: repoRoot) {
                let updateMode = subtree.update?.mode ?? .branch
                let constraint = subtree.update?.constraint ?? "latest"
                
                print("  • Would update '\(subtree.name)' (\(updateMode.rawValue) mode, constraint: \(constraint))")
                print("    Remote: \(subtree.remote)")
                print("    Prefix: \(subtree.prefix)")
                
                updatesAvailable += 1
            } else {
                print("  • '\(subtree.name)' is up to date")
            }
        }
        
        if updatesAvailable == 0 {
            print("No updates would be applied.")
        } else {
            print("\nWould apply \(updatesAvailable) update(s).")
            
            // Show branch strategy
            if !onCurrent {
                if let customBranch = branch {
                    print("Would create/use branch: \(customBranch)")
                } else {
                    let topicBranch = generateTopicBranchName(for: subtrees)
                    print("Would create topic branch: \(topicBranch)")
                }
            } else {
                print("Would commit on current branch")
            }
        }
    }
}
