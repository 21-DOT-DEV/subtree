import ArgumentParser
import Foundation

/// Initialize a new subtree configuration
public struct InitCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Initialize a new subtree configuration file"
    )
    
    // T047: Add @Flag var force property
    @Flag(name: .long, help: "Overwrite existing configuration file")
    var force: Bool = false
    
    public init() {}
    
    // T032-T063: Implement run() function with --force support and git validation
    public func run() async throws {
        // T060: Add error handling for GitError.notInRepository
        let gitRoot: String
        do {
            // T032: Detect git repository using GitOperations
            gitRoot = try await GitOperations.findGitRoot()
        } catch GitError.notInRepository {
            // T061: Implement error path - output user-friendly git error message
            let errorMessage = "❌ Must be run inside a git repository\n"
            if let data = errorMessage.data(using: .utf8) {
                try FileHandle.standardError.write(contentsOf: data)
            }
            
            // T062: Implement error path - exit with code 1 for git errors
            throw ArgumentParser.ExitCode(1)
        }
        
        // T033: Generate config path using ConfigFileManager
        let configPath = ConfigFileManager.configPath(gitRoot: gitRoot)
        
        // T048: Add file existence check before creation
        let fileExists = ConfigFileManager.exists(at: configPath)
        
        if fileExists && !force {
            // T049: Implement error path - output error message with ❌ emoji
            let currentDir = FileManager.default.currentDirectoryPath
            let relativePath = relativePathFrom(currentDir, to: configPath)
            
            // Write to stderr using FileHandle
            let errorMessage = "❌ \(relativePath) already exists\n"
            if let data = errorMessage.data(using: .utf8) {
                try FileHandle.standardError.write(contentsOf: data)
            }
            
            // T050: Implement error path - output hint about --force
            let hintMessage = "Use --force to overwrite\n"
            if let data = hintMessage.data(using: .utf8) {
                try FileHandle.standardError.write(contentsOf: data)
            }
            
            // T051: Exit with code 1 when file exists without --force
            throw ArgumentParser.ExitCode(1)
        }
        
        // T034: Generate minimal YAML content
        let yamlContent = try ConfigFileManager.generateMinimalConfig()
        
        // T035/T052/T071/T073: Create file atomically with error handling
        do {
            try await ConfigFileManager.createAtomically(at: configPath, content: yamlContent)
        } catch let error as NSError {
            // T071/T073: Handle I/O errors with clear messages
            let currentDir = FileManager.default.currentDirectoryPath
            let relativePath = relativePathFrom(currentDir, to: configPath)
            
            // Check for permission denied (POSIX error 13)
            if error.domain == NSPOSIXErrorDomain && error.code == 13 {
                // T071: Permission denied error
                let errorMessage = "❌ Permission denied: cannot create \(relativePath)\n"
                if let data = errorMessage.data(using: .utf8) {
                    try FileHandle.standardError.write(contentsOf: data)
                }
            } else {
                // T073: Generic I/O error
                let errorMessage = "❌ Failed to create \(relativePath): \(error.localizedDescription)\n"
                if let data = errorMessage.data(using: .utf8) {
                    try FileHandle.standardError.write(contentsOf: data)
                }
            }
            
            throw ArgumentParser.ExitCode(1)
        }
        
        // T036: Calculate relative path for output
        let currentDir = FileManager.default.currentDirectoryPath
        let relativePath = relativePathFrom(currentDir, to: configPath)
        
        // T037: Output success message with ✅ emoji
        print("✅ Created \(relativePath)")
    }
    
    /// Calculate relative path from one directory to a file
    private func relativePathFrom(_ from: String, to: String) -> String {
        let fromURL = URL(fileURLWithPath: from)
        let toURL = URL(fileURLWithPath: to)
        
        // Get path components
        let fromComponents = fromURL.pathComponents
        let toComponents = toURL.pathComponents
        
        // Find common prefix
        var commonCount = 0
        for (f, t) in zip(fromComponents, toComponents) {
            if f == t {
                commonCount += 1
            } else {
                break
            }
        }
        
        // Calculate ".." components needed
        let upComponents = Array(repeating: "..", count: fromComponents.count - commonCount)
        
        // Get remaining path from target
        let remainingComponents = toComponents.dropFirst(commonCount)
        
        // Combine
        let allComponents = upComponents + remainingComponents
        
        // If same directory, just return filename
        if allComponents.isEmpty {
            return toURL.lastPathComponent
        }
        
        return allComponents.joined(separator: "/")
    }
}
