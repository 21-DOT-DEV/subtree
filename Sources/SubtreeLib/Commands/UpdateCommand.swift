import ArgumentParser
import Foundation

/// Minimal status for report mode output
public enum ReportStatus: String, Codable, Sendable {
    case behind = "behind"
    case upToDate = "up_to_date"
    case error = "error"
}

/// A single entry in the update report, suitable for JSON serialization
public struct ReportEntry: Codable, Sendable {
    public let name: String
    public let status: ReportStatus
    public let currentTag: String?
    public let latestTag: String?
    public let currentCommit: String?
    public let branch: String?
    public let remote: String
    public let error: String?

    private enum CodingKeys: String, CodingKey {
        case name, status, remote, branch, error
        case currentTag = "current_tag"
        case latestTag = "latest_tag"
        case currentCommit = "current_commit"
    }
}

// T037: BatchUpdateResult for tracking bulk update results
struct BatchUpdateResult {
    var updated: [String] = []
    var skipped: [String] = []
    var failed: [(name: String, error: String)] = []
    
    var totalProcessed: Int {
        updated.count + skipped.count + failed.count
    }
    
    var exitCode: Int {
        failed.isEmpty ? 0 : 1
    }
}

/// Update an existing subtree
public struct UpdateCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update an existing subtree to its latest version"
    )
    
    // T015 + T038: ArgumentParser properties (name argument optional, --all and --no-squash flags)
    @Argument(help: "Name of the subtree to update (omit to use --all)")
    var name: String?
    
    @Flag(name: .long, help: "Update all configured subtrees")
    var all: Bool = false
    
    @Flag(name: .long, help: "Disable squash mode (preserves full upstream history)")
    var noSquash: Bool = false
    
    // T048: Add --report flag
    @Flag(name: .long, help: "Check for updates without modifying repository (exit 5 if updates available)")
    var report: Bool = false
    
    @Flag(name: .long, help: "Output report as JSON array to stdout (implies --report)")
    var json: Bool = false
    
    @Option(name: .long, help: "Specific ref (tag, branch, or commit) to update to")
    var ref: String?
    
    public init() {}
    
    // T039: Mutual exclusion validation
    public mutating func validate() throws {
        // Must specify either name OR --all, but not both
        if name == nil && !all {
            struct MissingArgumentError: Error, CustomStringConvertible {
                var description: String { "Must specify either a subtree name or --all flag" }
            }
            throw MissingArgumentError()
        }
        if name != nil && all {
            struct ConflictingArgumentsError: Error, CustomStringConvertible {
                var description: String { "Cannot specify both a subtree name and --all flag" }
            }
            throw ConflictingArgumentsError()
        }
    }
    
    public func run() async throws {
        // T016: Config validation (subtree.yaml exists, name exists in config)
        guard await GitOperations.isRepository() else {
            print("❌ Must be run inside a git repository")
            Foundation.exit(1)
        }
        
        let gitRoot: String
        do {
            gitRoot = try await GitOperations.findGitRoot()
        } catch {
            print("❌ Could not find git repository root")
            Foundation.exit(1)
        }
        
        let configPath = ConfigFileManager.configPath(gitRoot: gitRoot)
        guard ConfigFileManager.exists(at: configPath) else {
            print("❌ Configuration file not found. Run 'subtree init' first.")
            Foundation.exit(3)
        }
        
        // Load config
        let config: SubtreeConfiguration
        do {
            config = try ConfigurationParser.parseFile(at: configPath)
        } catch {
            print("❌ Failed to load configuration: \(error)")
            Foundation.exit(1)
        }
        
        // T029: Validate config for corruption (case-insensitive duplicates)
        do {
            try config.validate()
        } catch let error as SubtreeValidationError {
            print(error.localizedDescription)
            Foundation.exit(Int32(error.exitCode))
        }
        
        // T049-T055: Report mode vs update mode
        if report || json {
            try await runReportMode(config: config, all: all, name: name, asJSON: json)
        } else if all {
            try await runBatchUpdate(config: config, configPath: configPath)
        } else if let singleName = name {
            try await runSingleUpdate(name: singleName, config: config, configPath: configPath)
        }
    }
    
    // Single subtree update
    private func runSingleUpdate(name: String, config: SubtreeConfiguration, configPath: String) async throws {
        // T028: Normalize input name (trim whitespace)
        let normalizedName = name.normalized()
        
        // T028: Case-insensitive subtree lookup
        let entry: SubtreeEntry
        do {
            guard let found = try config.findSubtree(name: normalizedName) else {
                // Not found - use SubtreeValidationError for consistency
                throw SubtreeValidationError.subtreeNotFound(normalizedName)
            }
            entry = found
        } catch let error as SubtreeValidationError {
            print(error.localizedDescription)
            Foundation.exit(Int32(error.exitCode))
        }
        
        // T017: Working tree clean check
        let statusResult = try await GitOperations.run(arguments: ["status", "--porcelain"])
        guard statusResult.stdout.isEmpty else {
            print("❌ Working tree has uncommitted changes. Commit or stash before updating.")
            Foundation.exit(1)
        }
        
        // Determine target ref and commit
        let currentCommit = entry.commit
        let oldTag = entry.tag
        var targetRef: String
        var targetCommit: String
        var newTag: String? = entry.tag
        var newBranch: String? = entry.branch
        
        if let explicitRef = ref {
            // User specified --ref, use it directly
            targetRef = explicitRef
            do {
                targetCommit = try await GitOperations.lsRemote(remote: entry.remote, ref: explicitRef)
            } catch {
                print("❌ Failed to resolve ref '\(explicitRef)': \(error)")
                Foundation.exit(1)
            }
            // Determine if the explicit ref is a tag or branch
            // Check if it matches a tag on remote
            let remoteTags = try? await GitOperations.lsRemoteTags(remote: entry.remote)
            if let tags = remoteTags, tags.contains(where: { $0.tag == explicitRef }) {
                newTag = explicitRef
                newBranch = nil
            } else {
                // Assume it's a branch
                newTag = nil
                newBranch = explicitRef
            }
        } else if entry.tag != nil {
            // Configured with a tag - auto-detect latest tag
            do {
                let remoteTags = try await GitOperations.lsRemoteTags(remote: entry.remote)
                guard let latestTag = remoteTags.first else {
                    print("❌ No tags found on remote")
                    Foundation.exit(1)
                }
                targetRef = latestTag.tag
                targetCommit = latestTag.commit
                newTag = latestTag.tag
            } catch {
                print("❌ Failed to query remote tags: \(error)")
                Foundation.exit(1)
            }
        } else {
            // Configured with a branch - get latest commit on that branch
            targetRef = entry.branch ?? "main"
            do {
                targetCommit = try await GitOperations.lsRemote(remote: entry.remote, ref: targetRef)
            } catch {
                print("❌ Failed to query remote: \(error)")
                Foundation.exit(1)
            }
        }
        
        // T019: Implement "already up-to-date" path (exit 0)
        if currentCommit == targetCommit {
            print("✅ \(entry.name) is already up to date")
            return
        }
        
        // T023: User-facing output messages
        let versionInfo: String
        if let oldT = oldTag, let newT = newTag, oldT != newT {
            versionInfo = " (\(oldT) → \(newT))"
        } else if let newT = newTag {
            versionInfo = " (tag: \(newT))"
        } else {
            versionInfo = ""
        }
        print("🔄 Updating subtree \(entry.name)\(versionInfo)...")
        
        // Record HEAD before subtree pull to check if it creates a commit
        let headBefore = try await GitOperations.run(arguments: ["rev-parse", "HEAD"])
        let headBeforeCommit = headBefore.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // T020: Atomic update using git subtree pull
        let useSquash = !noSquash
        do {
            _ = try await GitOperations.subtreePull(
                prefix: entry.prefix,
                remote: entry.remote,
                ref: targetRef,
                squash: useSquash
            )
        } catch {
            print("❌ Failed to update subtree: \(error)")
            Foundation.exit(1)
        }
        
        // Check if subtree pull created a new commit
        let headAfter = try await GitOperations.run(arguments: ["rev-parse", "HEAD"])
        let headAfterCommit = headAfter.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtreePullCreatedCommit = headBeforeCommit != headAfterCommit
        
        // T021: Config update (new commit hash AND new tag if changed) after successful update
        let updatedSubtrees = config.subtrees.map { subtree in
            if subtree.name == entry.name {
                return SubtreeEntry(
                    name: subtree.name,
                    remote: subtree.remote,
                    prefix: subtree.prefix,
                    commit: targetCommit,
                    tag: newTag,
                    branch: newBranch,
                    squash: subtree.squash,
                    extracts: subtree.extracts
                )
            }
            return subtree
        }
        let updatedConfig = SubtreeConfiguration(subtrees: updatedSubtrees)
        
        do {
            try await ConfigFileManager.writeConfig(updatedConfig, to: configPath)
        } catch {
            print("❌ Failed to update configuration: \(error)")
            Foundation.exit(1)
        }
        
        // Stage the config file
        let addResult = try await GitOperations.run(arguments: ["add", "subtree.yaml"])
        guard addResult.exitCode == 0 else {
            print("❌ Failed to stage configuration file")
            Foundation.exit(1)
        }
        
        // T022: Tag-aware commit message formatting for updates (with version transition)
        let commitMessage = formatUpdateCommitMessage(
            entry: entry,
            oldCommit: currentCommit,
            newCommit: targetCommit,
            oldTag: oldTag,
            newTag: newTag,
            squash: useSquash
        )
        
        // Write commit message to temp file
        let tempMessageFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("subtree-update-msg-\(UUID().uuidString).txt")
        try commitMessage.write(to: tempMessageFile, atomically: true, encoding: String.Encoding.utf8)
        defer { try? FileManager.default.removeItem(at: tempMessageFile) }
        
        // Commit strategy: amend only if subtree pull created a commit, otherwise create new commit
        let commitResult: (stdout: String, stderr: String, exitCode: Int)
        if subtreePullCreatedCommit {
            // Amend the subtree pull commit to include config changes
            commitResult = try await GitOperations.run(arguments: [
                "commit", "--amend", "-F", tempMessageFile.path
            ])
        } else {
            // Subtree pull didn't create a commit (e.g., "Already up to date" from git's perspective)
            // Create a new commit for config changes only
            commitResult = try await GitOperations.run(arguments: [
                "commit", "-F", tempMessageFile.path
            ])
        }
        
        if commitResult.exitCode != 0 {
            print("⚠️  Subtree updated but failed to commit config changes.")
            print("Manually commit subtree.yaml: git commit -m 'Update \(entry.name) config'")
            Foundation.exit(1)
        }
        
        // T023: Success message
        print("✅ Updated \(entry.name)")
    }
    
    // T040-T043: Batch update all subtrees with continue-on-error
    private func runBatchUpdate(config: SubtreeConfiguration, configPath: String) async throws {
        // T036: Handle empty config
        guard !config.subtrees.isEmpty else {
            print("No subtrees configured")
            return
        }
        
        var result = BatchUpdateResult()
        
        // T040: Loop through all subtrees with continue-on-error
        for entry in config.subtrees {
            do {
                let wasUpdated = try await updateSingleSubtree(entry: entry, config: config, configPath: configPath)
                if wasUpdated {
                    result.updated.append(entry.name)
                } else {
                    result.skipped.append(entry.name)
                }
            } catch {
                // T041: Capture errors but continue
                result.failed.append((name: entry.name, error: error.localizedDescription))
            }
        }
        
        // T042: Display batch summary
        print("\n📊 Update Summary:")
        print("   ✅ Updated: \(result.updated.count)")
        print("   ⏭  Skipped: \(result.skipped.count)")
        print("   ❌ Failed: \(result.failed.count)")
        
        if !result.updated.isEmpty {
            print("\n   Updated: \(result.updated.joined(separator: ", "))")
        }
        if !result.failed.isEmpty {
            print("\n   Failed:")
            for (name, error) in result.failed {
                print("     • \(name): \(error)")
            }
        }
        
        // T043: Exit with appropriate code
        Foundation.exit(Int32(result.exitCode))
    }
    
    // Helper: Update single subtree, returns true if updated, false if skipped
    private func updateSingleSubtree(entry: SubtreeEntry, config: SubtreeConfiguration, configPath: String) async throws -> Bool {
        // Working tree check
        let statusResult = try await GitOperations.run(arguments: ["status", "--porcelain"])
        guard statusResult.stdout.isEmpty else {
            throw NSError(domain: "UpdateError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Working tree has uncommitted changes"])
        }
        
        // Determine target ref and commit (same logic as runSingleUpdate)
        let currentCommit = entry.commit
        let oldTag = entry.tag
        var targetRef: String
        var targetCommit: String
        var newTag: String? = entry.tag
        let newBranch: String? = entry.branch
        
        if entry.tag != nil {
            // Configured with a tag - auto-detect latest tag
            let remoteTags = try await GitOperations.lsRemoteTags(remote: entry.remote)
            guard let latestTag = remoteTags.first else {
                throw NSError(domain: "UpdateError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No tags found on remote"])
            }
            targetRef = latestTag.tag
            targetCommit = latestTag.commit
            newTag = latestTag.tag
        } else {
            // Configured with a branch - get latest commit on that branch
            targetRef = entry.branch ?? "main"
            targetCommit = try await GitOperations.lsRemote(remote: entry.remote, ref: targetRef)
        }
        
        // Skip if up-to-date
        if currentCommit == targetCommit {
            print("⏭  \(entry.name) is already up to date")
            return false
        }
        
        // User-facing output
        let versionInfo: String
        if let oldT = oldTag, let newT = newTag, oldT != newT {
            versionInfo = " (\(oldT) → \(newT))"
        } else if let newT = newTag {
            versionInfo = " (tag: \(newT))"
        } else {
            versionInfo = ""
        }
        print("🔄 Updating \(entry.name)\(versionInfo)...")
        
        // Record HEAD before subtree pull
        let headBefore = try await GitOperations.run(arguments: ["rev-parse", "HEAD"])
        let headBeforeCommit = headBefore.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Perform update
        let useSquash = !noSquash
        _ = try await GitOperations.subtreePull(
            prefix: entry.prefix,
            remote: entry.remote,
            ref: targetRef,
            squash: useSquash
        )
        
        // Check if subtree pull created a new commit
        let headAfter = try await GitOperations.run(arguments: ["rev-parse", "HEAD"])
        let headAfterCommit = headAfter.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtreePullCreatedCommit = headBeforeCommit != headAfterCommit
        
        // Update config (commit AND tag if changed)
        let updatedSubtrees = config.subtrees.map { subtree in
            if subtree.name == entry.name {
                return SubtreeEntry(
                    name: subtree.name,
                    remote: subtree.remote,
                    prefix: subtree.prefix,
                    commit: targetCommit,
                    tag: newTag,
                    branch: newBranch,
                    squash: subtree.squash,
                    extracts: subtree.extracts
                )
            }
            return subtree
        }
        let updatedConfig = SubtreeConfiguration(subtrees: updatedSubtrees)
        
        try await ConfigFileManager.writeConfig(updatedConfig, to: configPath)
        _ = try await GitOperations.run(arguments: ["add", "subtree.yaml"])
        
        // Commit with message (with version transition)
        let commitMessage = formatUpdateCommitMessage(
            entry: entry,
            oldCommit: currentCommit,
            newCommit: targetCommit,
            oldTag: oldTag,
            newTag: newTag,
            squash: useSquash
        )
        let tempMessageFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("subtree-update-msg-\(UUID().uuidString).txt")
        try commitMessage.write(to: tempMessageFile, atomically: true, encoding: String.Encoding.utf8)
        defer { try? FileManager.default.removeItem(at: tempMessageFile) }
        
        // Commit strategy: amend only if subtree pull created a commit
        let commitResult: (stdout: String, stderr: String, exitCode: Int)
        if subtreePullCreatedCommit {
            commitResult = try await GitOperations.run(arguments: [
                "commit", "--amend", "-F", tempMessageFile.path
            ])
        } else {
            commitResult = try await GitOperations.run(arguments: [
                "commit", "-F", tempMessageFile.path
            ])
        }
        
        guard commitResult.exitCode == 0 else {
            throw NSError(domain: "UpdateError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to commit config changes"])
        }
        
        print("✅ Updated \(entry.name)")
        return true
    }
    
    // T049-T055: Report mode implementation (fixed tag detection + JSON support)
    private func runReportMode(config: SubtreeConfiguration, all: Bool, name: String?, asJSON: Bool) async throws {
        var hasUpdates = false
        let entriesToCheck: [SubtreeEntry]
        
        if all {
            entriesToCheck = config.subtrees
        } else if let singleName = name {
            // Normalize input name and use case-insensitive lookup
            let normalizedName = singleName.normalized()
            do {
                guard let entry = try config.findSubtree(name: normalizedName) else {
                    throw SubtreeValidationError.subtreeNotFound(normalizedName)
                }
                entriesToCheck = [entry]
            } catch let error as SubtreeValidationError {
                print(error.localizedDescription)
                Foundation.exit(Int32(error.exitCode))
            }
        } else {
            entriesToCheck = []
        }
        
        var reportEntries: [ReportEntry] = []
        
        for entry in entriesToCheck {
            do {
                if entry.tag != nil {
                    // TAG-BASED: Use lsRemoteTags to find latest tag
                    let remoteTags = try await GitOperations.lsRemoteTags(remote: entry.remote)
                    guard let latestTag = remoteTags.first else {
                        let reportEntry = ReportEntry(
                            name: entry.name,
                            status: .error,
                            currentTag: entry.tag,
                            latestTag: nil,
                            currentCommit: nil,
                            branch: nil,
                            remote: entry.remote,
                            error: "No tags found on remote"
                        )
                        reportEntries.append(reportEntry)
                        if !asJSON {
                            print("⚠️  \(entry.name): no tags found on remote")
                        }
                        continue
                    }
                    
                    if entry.tag != latestTag.tag {
                        hasUpdates = true
                        let reportEntry = ReportEntry(
                            name: entry.name,
                            status: .behind,
                            currentTag: entry.tag,
                            latestTag: latestTag.tag,
                            currentCommit: nil,
                            branch: nil,
                            remote: entry.remote,
                            error: nil
                        )
                        reportEntries.append(reportEntry)
                        if !asJSON {
                            print("📦 \(entry.name): \(entry.tag!) → \(latestTag.tag)")
                        }
                    } else {
                        let reportEntry = ReportEntry(
                            name: entry.name,
                            status: .upToDate,
                            currentTag: entry.tag,
                            latestTag: latestTag.tag,
                            currentCommit: nil,
                            branch: nil,
                            remote: entry.remote,
                            error: nil
                        )
                        reportEntries.append(reportEntry)
                        if !asJSON {
                            print("✅ \(entry.name): up to date (\(entry.tag!))")
                        }
                    }
                } else {
                    // BRANCH-BASED: Use lsRemote to get latest commit on branch
                    let branchRef = entry.branch ?? "main"
                    let remoteCommit = try await GitOperations.lsRemote(remote: entry.remote, ref: branchRef)
                    
                    if entry.commit != remoteCommit {
                        hasUpdates = true
                        let shortCurrent = CommitMessageFormatter.shortHash(from: entry.commit)
                        let shortNew = CommitMessageFormatter.shortHash(from: remoteCommit)
                        let reportEntry = ReportEntry(
                            name: entry.name,
                            status: .behind,
                            currentTag: nil,
                            latestTag: nil,
                            currentCommit: shortCurrent,
                            branch: branchRef,
                            remote: entry.remote,
                            error: nil
                        )
                        reportEntries.append(reportEntry)
                        if !asJSON {
                            print("📦 \(entry.name): \(shortCurrent) → \(shortNew)")
                        }
                    } else {
                        let shortCurrent = CommitMessageFormatter.shortHash(from: entry.commit)
                        let reportEntry = ReportEntry(
                            name: entry.name,
                            status: .upToDate,
                            currentTag: nil,
                            latestTag: nil,
                            currentCommit: shortCurrent,
                            branch: branchRef,
                            remote: entry.remote,
                            error: nil
                        )
                        reportEntries.append(reportEntry)
                        if !asJSON {
                            print("✅ \(entry.name): up to date")
                        }
                    }
                }
            } catch {
                let reportEntry = ReportEntry(
                    name: entry.name,
                    status: .error,
                    currentTag: entry.tag,
                    latestTag: nil,
                    currentCommit: entry.tag == nil ? CommitMessageFormatter.shortHash(from: entry.commit) : nil,
                    branch: entry.branch,
                    remote: entry.remote,
                    error: error.localizedDescription
                )
                reportEntries.append(reportEntry)
                if !asJSON {
                    print("⚠️  \(entry.name): failed to check (\(error.localizedDescription))")
                }
            }
        }
        
        // JSON output path
        if asJSON {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(reportEntries)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        }
        
        // T055: Exit with appropriate code
        Foundation.exit(hasUpdates ? 5 : 0)
    }
    
    // T022: Tag-aware commit message formatting with version transition
    private func formatUpdateCommitMessage(
        entry: SubtreeEntry,
        oldCommit: String,
        newCommit: String,
        oldTag: String?,
        newTag: String?,
        squash: Bool
    ) -> String {
        let shortOld = CommitMessageFormatter.shortHash(from: oldCommit)
        let shortNew = CommitMessageFormatter.shortHash(from: newCommit)
        let squashMode = squash ? "squashed" : "non-squashed"
        
        if let newT = newTag {
            // Tag format with version transition
            let titleSuffix: String
            if let oldT = oldTag, oldT != newT {
                titleSuffix = " (\(oldT) → \(newT))"
            } else {
                titleSuffix = " (tag: \(newT))"
            }
            
            var lines = [
                "Update subtree \(entry.name)\(titleSuffix)",
                "",
                "- Updated to tag: \(newT) (commit: \(shortNew))"
            ]
            if let oldT = oldTag, oldT != newT {
                lines.append("- Previous tag: \(oldT) (commit: \(shortOld))")
            } else {
                lines.append("- Previous commit: \(shortOld)")
            }
            lines.append(contentsOf: [
                "- From: \(entry.remote)",
                "- In: \(entry.prefix)",
                "- Mode: \(squashMode)"
            ])
            return lines.joined(separator: "\n")
        } else {
            // Branch format: "Update subtree <name>"
            return """
            Update subtree \(entry.name)
            
            - Updated to commit: \(shortNew)
            - Previous commit: \(shortOld)
            - From: \(entry.remote)
            - In: \(entry.prefix)
            - Mode: \(squashMode)
            """
        }
    }
}
