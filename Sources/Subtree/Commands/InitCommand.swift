import ArgumentParser
import Foundation
import Yams

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create a starter subtree.yaml with optional interactive wizard"
    )
    
    @Flag(name: .long, help: "Overwrite existing subtree.yaml file")
    var force = false
    
    @Flag(name: .long, help: "Interactive configuration wizard")
    var interactive = false
    
    mutating func run() throws {
        do {
            // Resolve repository root
            let repoRoot = try GitPlumbing.repositoryRoot()
            let configPath = ConfigIO.configPath(at: repoRoot)
            
            // Check if config already exists
            if ConfigIO.configExists(at: configPath) && !force {
                throw SubtreeError.invalidUsage("subtree.yaml already exists. Use --force to overwrite.")
            }
            
            // Create configuration based on mode
            let config: SubtreeConfig
            
            if interactive {
                // Interactive mode: prompt for configuration
                config = try createConfigInteractively()
                print("Created interactive subtree.yaml at \(configPath.path)")
            } else {
                // Default mode: minimal config
                config = SubtreeConfig(subtrees: [])
                print("Created minimal subtree.yaml at \(configPath.path)")
            }
            
            // Write the configuration
            try writeConfig(config, to: configPath)
            
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
            throw error // Re-throw our custom errors
        } catch {
            throw SubtreeError.generalError("\(error)")
        }
    }
    
    
    private func createConfigInteractively() throws -> SubtreeConfig {
        print("🚀 Interactive Subtree Configuration Wizard")
        print("This wizard will help you add subtrees to your project.\n")
        
        var subtrees: [SubtreeEntry] = []
        
        // Allow multiple entries
        while true {
            print("Enter subtree details (press Enter on empty remote URL to finish):")
            
            // Get remote URL (required)
            print("Remote URL: ", terminator: "")
            guard let remoteInput = readLine()?.trimmingCharacters(in: .whitespaces),
                  !remoteInput.isEmpty else {
                break // Exit on empty input
            }
            
            do {
                let subtree = try createSubtreeEntryInteractively(remote: remoteInput)
                subtrees.append(subtree)
                print("✅ Added subtree '\(subtree.name)' at '\(subtree.prefix)'\n")
            } catch {
                print("❌ Error: \(error)")
                print("Please try again.\n")
                continue
            }
        }
        
        return SubtreeConfig(subtrees: subtrees)
    }
    
    private func createSubtreeEntryInteractively(remote: String) throws -> SubtreeEntry {
        // Infer name from remote URL
        let inferredName = try RemoteURLParser.inferNameFromRemote(remote)
        
        // Get name (with smart default)
        print("Subtree name [\(inferredName)]: ", terminator: "")
        let nameInput = readLine()?.trimmingCharacters(in: .whitespaces)
        let name = nameInput?.isEmpty == false ? nameInput! : inferredName
        
        // Get prefix (with smart default)
        let inferredPrefix = RemoteURLParser.inferPrefixFromName(name)
        print("Local prefix [\(inferredPrefix)]: ", terminator: "")
        let prefixInput = readLine()?.trimmingCharacters(in: .whitespaces)
        let prefix = prefixInput?.isEmpty == false ? prefixInput! : inferredPrefix
        
        // Get branch/ref (with smart default)
        print("Branch/tag [main]: ", terminator: "")
        let refInput = readLine()?.trimmingCharacters(in: .whitespaces)
        let branch = refInput?.isEmpty == false ? refInput! : "main"
        
        // Get squash setting (with smart default)
        print("Squash commits? [Y/n]: ", terminator: "")
        let squashInput = readLine()?.trimmingCharacters(in: .whitespaces).lowercased()
        let squash = squashInput != "n" && squashInput != "no"
        
        // Validate remote URL (optional)
        print("Validate remote URL? [Y/n]: ", terminator: "")
        let validateInput = readLine()?.trimmingCharacters(in: .whitespaces).lowercased()
        let shouldValidate = validateInput != "n" && validateInput != "no"
        
        if shouldValidate {
            try validateRemoteAndRef(remote: remote, ref: branch)
        }
        
        return SubtreeEntry(
            name: name,
            remote: remote,
            prefix: prefix,
            branch: branch,
            squash: squash,
            commit: nil,
            copies: nil,
            update: nil
        )
    }
    
    
    private func validateRemoteAndRef(remote: String, ref: String) throws {
        print("🔍 Validating remote URL and reference...")
        
        // Use git ls-remote to validate
        let result = try GitPlumbing.runGitCommand(
            ["ls-remote", "--heads", "--tags", remote, ref],
            workingDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        )
        
        if result.exitCode != 0 {
            throw SubtreeError.gitFailure("Cannot reach remote '\(remote)' or reference '\(ref)' not found")
        }
        
        if result.stdout.trimmingCharacters(in: .whitespaces).isEmpty {
            throw SubtreeError.gitFailure("Reference '\(ref)' not found in remote '\(remote)'")
        }
        
        print("✅ Remote URL and reference validated successfully")
    }
    
    private func writeConfig(_ config: SubtreeConfig, to url: URL) throws {
        // Encode the config to YAML format
        let yamlString = try YAMLEncoder().encode(config)
        
        // Write to file
        try yamlString.write(to: url, atomically: true, encoding: String.Encoding.utf8)
    }
}

/// Helper for writing to stderr
struct StderrWriter: TextOutputStream {
    static let shared = StderrWriter()
    
    func write(_ string: String) {
        FileHandle.standardError.write(string.data(using: .utf8) ?? Data())
    }
}
