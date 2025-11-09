import ArgumentParser
import Foundation

/// Add a new subtree to the repository
public struct AddCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a new subtree to the repository with smart defaults and atomic commits"
    )
    
    // T031: Command-line flags
    @Option(name: .long, help: "Remote repository URL (required)")
    var remote: String
    
    @Option(name: .long, help: "Subtree name (default: derived from URL)")
    var name: String?
    
    @Option(name: .long, help: "Subtree prefix path (default: same as name)")
    var prefix: String?
    
    @Option(name: .long, help: "Branch or tag reference (default: main)")
    var ref: String?
    
    @Flag(name: .long, help: "Disable squash mode (preserves full upstream history)")
    var noSquash: Bool = false
    
    public init() {}
    
    public func run() async throws {
        // T032: Validate git repository
        guard await GitOperations.isRepository() else {
            print("❌ Must be run inside a git repository")
            Foundation.exit(1)
        }
        
        // T033: Check config exists
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
            Foundation.exit(1)
        }
        
        // T034: Validate URL format
        guard isValidURL(remote) else {
            print("❌ Invalid remote URL format: \(remote)")
            Foundation.exit(1)
        }
        
        // T035: Derive name from URL if not provided
        let rawName: String
        if let providedName = name {
            rawName = providedName
        } else {
            do {
                let extractedName = try URLParser.extractName(from: remote)
                rawName = NameSanitizer.sanitize(extractedName)
            } catch {
                print("❌ Could not extract repository name from URL: \(remote)")
                Foundation.exit(1)
            }
        }
        
        // T017: Normalize whitespace from name and prefix
        let derivedName = rawName.normalized()
        let rawPrefix = prefix ?? derivedName
        let finalPrefix = rawPrefix.normalized()
        
        // T018: Display non-ASCII warning if detected
        if NameValidator.containsNonASCII(derivedName) {
            let warning = NameValidator.nonASCIIWarning(for: derivedName)
            FileHandle.standardError.write(Data((warning + "\n").utf8))
        }
        
        // T037: Default ref to 'main'
        let finalRef = ref ?? "main"
        
        // Determine squash setting
        let useSquash = !noSquash
        
        // T019: Validate prefix path format (security)
        do {
            try PathValidator.validate(finalPrefix)
        } catch let error as SubtreeValidationError {
            print(error.localizedDescription)
            Foundation.exit(Int32(error.exitCode))
        }
        
        // Load existing config for validation
        let config: SubtreeConfiguration
        do {
            config = try ConfigurationParser.parseFile(at: configPath)
        } catch {
            print("❌ Failed to parse configuration: \(error)")
            Foundation.exit(1)
        }
        
        // Validate config for corruption (case-insensitive duplicates)
        do {
            try config.validate()
        } catch let error as SubtreeValidationError {
            print(error.localizedDescription)
            Foundation.exit(Int32(error.exitCode))
        }
        
        // T016: Case-insensitive duplicate detection
        do {
            // Check for duplicate names (case-insensitive)
            if let _ = try config.findSubtree(name: derivedName) {
                // Name exists - throw duplicate name error
                throw SubtreeValidationError.duplicateName(
                    attempted: derivedName,
                    existing: config.subtrees.first { $0.name.matchesCaseInsensitive(derivedName) }!.name
                )
            }
            
            // Check for duplicate prefixes (case-insensitive)
            if let existingEntry = config.subtrees.first(where: { $0.prefix.matchesCaseInsensitive(finalPrefix) }) {
                throw SubtreeValidationError.duplicatePrefix(
                    attempted: finalPrefix,
                    existing: existingEntry.prefix
                )
            }
        } catch let error as SubtreeValidationError {
            print(error.localizedDescription)
            Foundation.exit(Int32(error.exitCode))
        }
        
        // T039: Execute git subtree add
        var subtreeArgs = ["subtree", "add", "--prefix", finalPrefix]
        if useSquash {
            subtreeArgs.append("--squash")
        }
        subtreeArgs.append(contentsOf: [remote, finalRef])
        
        let subtreeResult = try await GitOperations.run(arguments: subtreeArgs)
        guard subtreeResult.exitCode == 0 else {
            print("❌ Git subtree add failed:")
            print(subtreeResult.stderr)
            Foundation.exit(1)
        }
        
        // T040: Capture commit hash
        let hashResult = try await GitOperations.run(arguments: ["rev-parse", "HEAD"])
        guard hashResult.exitCode == 0 else {
            print("❌ Failed to capture commit hash")
            Foundation.exit(1)
        }
        let commitHash = hashResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // T041: Update config (create new entry)
        let refType = CommitMessageFormatter.deriveRefType(from: finalRef)
        
        let newEntry = SubtreeEntry(
            name: derivedName,
            remote: remote,
            prefix: finalPrefix,
            commit: commitHash,
            tag: refType == "tag" ? finalRef : nil,
            branch: refType == "branch" ? finalRef : nil,
            squash: useSquash
        )
        
        // Create new config with appended entry
        let updatedConfig = SubtreeConfiguration(subtrees: config.subtrees + [newEntry])
        
        // Write updated config
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
        
        // T042: Atomic commit (git commit --amend with custom message)
        let commitMessage = CommitMessageFormatter.format(
            name: derivedName,
            ref: finalRef,
            refType: refType,
            commit: commitHash,
            remote: remote,
            prefix: finalPrefix
        )
        
        // Write commit message to temp file
        let tempMessageFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("subtree-commit-msg-\(UUID().uuidString).txt")
        try commitMessage.write(to: tempMessageFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempMessageFile) }
        
        // Amend the commit
        let amendResult = try await GitOperations.run(arguments: [
            "commit", "--amend", "-F", tempMessageFile.path
        ])
        
        if amendResult.exitCode != 0 {
            // T047: Handle commit amend failure
            print("⚠️  Subtree added successfully but failed to update config in commit.")
            print("Manually edit subtree.yaml to add entry, then run: git commit --amend")
            print("\nEntry to add:")
            print("- name: \(derivedName)")
            print("  remote: \(remote)")
            print("  prefix: \(finalPrefix)")
            if refType == "tag" {
                print("  tag: \(finalRef)")
            } else {
                print("  branch: \(finalRef)")
            }
            print("  commit: \(commitHash)")
            print("  squash: \(useSquash)")
            Foundation.exit(1)
        }
        
        // T043: Success output
        let shortHash = CommitMessageFormatter.shortHash(from: commitHash)
        print("✅ Added subtree '\(derivedName)' at \(finalPrefix) (ref: \(finalRef), commit: \(shortHash))")
    }
    
    // T034: URL format validation helper
    private func isValidURL(_ url: String) -> Bool {
        let validSchemes = ["https://", "http://", "git@", "file://"]
        return validSchemes.contains(where: { url.hasPrefix($0) })
    }
}
