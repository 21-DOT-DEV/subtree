import ArgumentParser
import Foundation

struct ExtractCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "Extract files from configured subtrees using glob patterns"
    )
    
    @Option(name: [.short, .long], help: "Name of the subtree to extract from")
    var name: String?
    
    @Flag(name: [.short, .long], help: "Extract files from all configured subtrees")
    var all = false
    
    @Option(name: .long, help: "Source glob pattern (overrides config)")
    var from: String?
    
    @Option(name: .long, help: "Destination path (overrides config)")
    var to: String?
    
    @Option(name: .long, help: "Exclude patterns (can be specified multiple times)")
    var exclude: [String] = []
    
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
            
            // Validate arguments
            if name == nil && !all {
                throw SubtreeError.invalidUsage("Must specify either --name <name> or --all")
            }
            
            if name != nil && all {
                throw SubtreeError.invalidUsage("Cannot use --name and --all together")
            }
            
            // Validate --from and --to must be used together
            if (from != nil) != (to != nil) {
                throw SubtreeError.invalidUsage("--from and --to must be used together")
            }
            
            // Determine which subtrees to copy from
            let subtreesToCopy: [SubtreeEntry]
            if all {
                subtreesToCopy = config.subtrees
            } else if let targetName = name {
                guard let subtree = config.subtrees.first(where: { $0.name == targetName }) else {
                    throw SubtreeError.invalidUsage("Subtree '\(targetName)' not found in configuration")
                }
                subtreesToCopy = [subtree]
            } else {
                subtreesToCopy = []
            }
            
            var totalFilesCopied = 0
            
            // Process each subtree
            for subtree in subtreesToCopy {
                let filesCopied: Int
                
                if let fromPattern = from, let toPath = to {
                    // Use command-line overrides
                    filesCopied = try copyFiles(
                        from: subtree,
                        pattern: fromPattern,
                        destination: toPath,
                        in: repoRoot
                    )
                } else {
                    // Use config mappings
                    filesCopied = try copyFromConfig(subtree, in: repoRoot)
                }
                
                totalFilesCopied += filesCopied
            }
            
            if totalFilesCopied == 0 {
                print("No files to copy")
            } else {
                print("Copied \(totalFilesCopied) file(s)")
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
    
    private func copyFromConfig(_ subtree: SubtreeEntry, in repoRoot: URL) throws -> Int {
        guard let copyMappings = subtree.copies, !copyMappings.isEmpty else {
            return 0
        }
        
        var totalFilesCopied = 0
        
        for mapping in subtree.copies ?? [] {
            let filesCopied = try copyFiles(
                from: subtree,
                pattern: mapping.from,
                destination: mapping.to,
                excludePatterns: mapping.exclude ?? [],
                in: repoRoot
            )
            totalFilesCopied += filesCopied
        }
        
        return totalFilesCopied
    }
    
    private func copyFiles(
        from subtree: SubtreeEntry,
        pattern: String,
        destination: String,
        excludePatterns: [String] = [],
        in repoRoot: URL
    ) throws -> Int {
        let subtreePath = repoRoot.appendingPathComponent(subtree.prefix)
        
        // Check if subtree exists
        guard FileManager.default.fileExists(atPath: subtreePath.path) else {
            throw SubtreeError.invalidUsage("Subtree '\(subtree.name)' not found at path '\(subtree.prefix)'")
        }
        
        // Find matching files and filter out excluded patterns
        let allMatchingFiles = try findMatchingFiles(pattern: pattern, in: subtreePath)
        let sourceFiles = filterExcludedFiles(allMatchingFiles, excludePatterns: excludePatterns, relativeTo: subtreePath)
        
        if sourceFiles.isEmpty {
            return 0
        }
        
        // Create destination directory
        let destinationPath = repoRoot.appendingPathComponent(destination)
        try FileManager.default.createDirectory(at: destinationPath, withIntermediateDirectories: true)
        
        var copiedCount = 0
        
        for sourceFile in sourceFiles {
            let fileName = sourceFile.lastPathComponent
            let targetFile = destinationPath.appendingPathComponent(fileName)
            
            // Copy the file
            do {
                // Remove target if it exists
                if FileManager.default.fileExists(atPath: targetFile.path) {
                    try FileManager.default.removeItem(at: targetFile)
                }
                
                try FileManager.default.copyItem(at: sourceFile, to: targetFile)
                copiedCount += 1
            } catch {
                print("Warning: Failed to copy \(sourceFile.lastPathComponent): \(error)")
            }
        }
        
        return copiedCount
    }
    
    private func findMatchingFiles(pattern: String, in directory: URL) throws -> [URL] {
        // Enhanced glob matching supports common patterns and exclusions
        var matchingFiles: [URL] = []
        
        // Handle recursive patterns: "src/**/*.swift" becomes "src/*.swift" for compatibility
        let simplifiedPattern = pattern.replacingOccurrences(of: "**/", with: "")
        
        // Extract directory and filename pattern
        let pathComponents = simplifiedPattern.split(separator: "/")
        var searchDirectory = directory
        var filePattern = simplifiedPattern
        
        if pathComponents.count > 1 {
            // Pattern has directory components
            let directoryPath = pathComponents.dropLast().joined(separator: "/")
            filePattern = String(pathComponents.last ?? "*")
            searchDirectory = directory.appendingPathComponent(directoryPath)
        }
        
        // Check if search directory exists
        guard FileManager.default.fileExists(atPath: searchDirectory.path) else {
            return matchingFiles
        }
        
        // Get all files in the directory
        let contents = try FileManager.default.contentsOfDirectory(
            at: searchDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        for url in contents {
            let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues.isRegularFile == true {
                if matchesPattern(fileName: url.lastPathComponent, pattern: filePattern) {
                    matchingFiles.append(url)
                }
            }
        }
        
        return matchingFiles
    }
    
    private func matchesPattern(fileName: String, pattern: String) -> Bool {
        // Simple glob matching for * wildcards
        if pattern == "*" {
            return true
        }
        
        if pattern.hasPrefix("*.") {
            let fileExtension = String(pattern.dropFirst(2))
            return fileName.hasSuffix(".\(fileExtension)")
        }
        
        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            return fileName.hasPrefix(prefix)
        }
        
        // Exact match
        return fileName == pattern
    }
    
    private func filterExcludedFiles(_ files: [URL], excludePatterns: [String], relativeTo basePath: URL) -> [URL] {
        guard !excludePatterns.isEmpty else {
            return files
        }
        
        return files.filter { fileURL in
            let relativePath = fileURL.path.replacingOccurrences(of: basePath.path + "/", with: "")
            
            for excludePattern in excludePatterns {
                if matchesExcludePattern(relativePath, pattern: excludePattern) {
                    return false // Exclude this file
                }
            }
            
            return true // Include this file
        }
    }
    
    private func matchesExcludePattern(_ filePath: String, pattern: String) -> Bool {
        // Handle directory exclusions like "test/*", "bench/*"
        if pattern.hasSuffix("/*") {
            let dirPattern = String(pattern.dropLast(2))
            return filePath.hasPrefix(dirPattern + "/")
        }
        
        // Handle file extension exclusions like "*.test"
        if pattern.hasPrefix("*.") {
            let fileExtension = String(pattern.dropFirst(2))
            return filePath.hasSuffix(".\(fileExtension)")
        }
        
        // Handle wildcard patterns
        if pattern.contains("*") {
            // Simple wildcard matching - could be enhanced with proper regex
            let regexPattern = pattern.replacingOccurrences(of: "*", with: ".*")
            return filePath.range(of: "^" + regexPattern + "$", options: .regularExpression) != nil
        }
        
        // Exact match or directory match
        return filePath == pattern || filePath.hasPrefix(pattern + "/")
    }
}
