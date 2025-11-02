import ArgumentParser
import Foundation

/// Extract files from a subtree using glob patterns (008-extract-command / User Story 1)
///
/// This command supports two modes:
/// 1. Ad-hoc extraction: Extract files once using command-line patterns
/// 2. Saved mappings: Extract files using saved extraction mappings from subtree.yaml
///
/// Examples:
/// ```
/// # Ad-hoc: Extract markdown docs from docs subtree
/// subtree extract --name docs "**/*.md" project-docs/
///
/// # With exclusions
/// subtree extract --name mylib "src/**/*.{c,h}" Sources/MyLib/ --exclude "**/test/**"
/// ```
public struct ExtractCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "Extract files from a subtree using glob patterns",
        discussion: """
            Extract files from managed subtrees into your project using flexible glob patterns.
            
            MODES:
              • Ad-hoc extraction: Specify pattern and destination on command line
              • Bulk extraction: Use saved mappings from subtree.yaml (--name or --all)
            
            EXAMPLES:
              # Extract markdown documentation
              subtree extract --name docs "**/*.md" project-docs/
              
              # Extract C source files with exclusions
              subtree extract --name mylib "src/**/*.{c,h}" Sources/ --exclude "**/test/**"
              
              # Save mapping for future use
              subtree extract --name mylib "**/*.h" include/ --persist
              
              # Execute saved mappings
              subtree extract --name mylib
              subtree extract --all
              
              # Override git-tracked file protection
              subtree extract --name lib "*.md" docs/ --force
            
            GLOB PATTERNS:
              *       Match any characters except /
              **      Match any characters including /
              ?       Match single character
              [abc]   Match character class
              {a,b}   Match brace expansion
            
            EXIT CODES:
              0  Success
              1  User error (invalid input, not found)
              2  System error (I/O, git, overwrite protection)
              3  Configuration error (invalid subtree.yaml)
            """
    )
    
    // T063: --name flag for subtree selection (optional for --all mode)
    @Option(name: .long, help: "Name of the subtree to extract files from")
    var name: String?
    
    // T110: --all flag for bulk extraction across all subtrees
    @Flag(name: .long, help: "Execute saved extraction mappings for all subtrees")
    var all: Bool = false
    
    // T064: Source pattern positional argument (optional for bulk mode)
    @Argument(help: "Glob pattern to match files in the subtree (e.g., '**/*.md', 'src/**/*.c')")
    var pattern: String?
    
    // T065: Destination positional argument (optional for bulk mode)
    @Argument(help: "Destination path relative to repository root (e.g., 'docs/', 'Sources/MyLib/')")
    var destination: String?
    
    // T066: --exclude repeatable flag for exclusion patterns
    @Option(name: .long, help: "Glob pattern to exclude files (can be repeated)")
    var exclude: [String] = []
    
    // T091: --persist flag to save extraction mapping
    @Flag(name: .long, help: "Save this extraction mapping to subtree.yaml for future use")
    var persist: Bool = false
    
    // T131: --force flag to override overwrite protection
    @Flag(name: .long, help: "Override git-tracked file protection (allows overwriting tracked files)")
    var force: Bool = false
    
    public init() {}
    
    public func run() async throws {
        // T111: Mode selection based on positional arguments
        let hasPositionalArgs = pattern != nil && destination != nil
        
        if hasPositionalArgs {
            // AD-HOC MODE: Extract specific pattern
            if all {
                fputs("❌ Error: --all flag cannot be used with pattern/destination arguments\n", stderr)
                fputs("   For ad-hoc extraction, use: subtree extract --name <name> <pattern> <destination>\n", stderr)
                fputs("   For bulk extraction, use: subtree extract --all\n", stderr)
                Foundation.exit(1)
            }
            
            guard let subtreeName = name else {
                fputs("❌ Error: --name is required for ad-hoc extraction\n", stderr)
                Foundation.exit(1)
            }
            
            try await runAdHocExtraction(subtreeName: subtreeName)
        } else {
            // BULK MODE: Execute saved mappings
            if pattern != nil || destination != nil {
                fputs("❌ Error: Pattern and destination must both be provided or both omitted\n", stderr)
                Foundation.exit(1)
            }
            
            if !all && name == nil {
                fputs("❌ Error: Must specify either --name or --all for bulk extraction\n", stderr)
                fputs("   Usage: subtree extract --name <name>\n", stderr)
                fputs("          subtree extract --all\n", stderr)
                Foundation.exit(1)
            }
            
            try await runBulkExtraction()
        }
    }
    
    // MARK: - Ad-Hoc Extraction Mode
    
    private func runAdHocExtraction(subtreeName: String) async throws {
        guard let patternValue = pattern, let destinationValue = destination else {
            fputs("❌ Internal error: Missing pattern or destination in ad-hoc mode\n", stderr)
            Foundation.exit(2)
        }
        
        // T068: Subtree validation
        let gitRoot = try await validateGitRepository()
        let configPath = ConfigFileManager.configPath(gitRoot: gitRoot)
        let config = try await validateConfigExists(at: configPath)
        let subtree = try validateSubtreeExists(name: subtreeName, in: config)
        try await validateSubtreePrefix(subtree.prefix, gitRoot: gitRoot)
        
        // T069: Destination path validation
        let normalizedDest = try validateDestination(destinationValue, gitRoot: gitRoot)
        
        // T070: Glob pattern matching using GlobMatcher
        let matchedFiles = try await findMatchingFiles(
            in: subtree.prefix,
            pattern: patternValue,
            excludePatterns: exclude,
            gitRoot: gitRoot
        )
        
        // T150: Zero-match validation (ad-hoc mode = error)
        guard !matchedFiles.isEmpty else {
            fputs("❌ Error: No files matched pattern '\(patternValue)' in subtree '\(subtreeName)'\n\n", stderr)
            fputs("Suggestions:\n", stderr)
            fputs("  • Check pattern syntax\n", stderr)
            fputs("  • Verify files exist in \(subtree.prefix)/\n", stderr)
            fputs("  • Try a broader pattern like '**/*'\n", stderr)
            Foundation.exit(1)  // User error
        }
        
        // T074: Destination directory creation
        let fullDestPath = gitRoot + "/" + normalizedDest
        try createDestinationDirectory(at: fullDestPath)
        
        // T132-T133: Check for git-tracked files before copying (unless --force)
        if !force {
            let trackedFiles = try await checkForTrackedFiles(
                matchedFiles: matchedFiles,
                fullDestPath: fullDestPath,
                gitRoot: gitRoot
            )
            
            if !trackedFiles.isEmpty {
                // T135-T136: Show error and exit with code 2
                try handleOverwriteProtection(trackedFiles: trackedFiles)
            }
        }
        
        // T072: File copying with FileManager
        // T073: Directory structure preservation
        var copiedCount = 0
        for (sourcePath, relativePath) in matchedFiles {
            let destFilePath = fullDestPath + "/" + relativePath
            try copyFilePreservingStructure(from: sourcePath, to: destFilePath)
            copiedCount += 1
        }
        
        // T092: Save mapping if --persist flag is set
        var mappingSaved = false
        if persist {
            mappingSaved = try await saveMappingToConfig(
                pattern: patternValue,
                destination: destinationValue,  // Use original destination to preserve user's formatting
                excludePatterns: exclude,
                subtreeName: subtreeName,
                configPath: configPath
            )
        }
        
        // T095: Contextual success messages
        print("✅ Extracted \(copiedCount) file(s) from '\(subtreeName)' to '\(normalizedDest)'")
        if persist {
            if mappingSaved {
                print("📝 Saved extraction mapping to subtree.yaml")
            } else {
                print("⚠️  Mapping already exists in config, skipping duplicate")
            }
        }
    }
    
    // MARK: - Bulk Extraction Mode (T112-T116)
    
    private func runBulkExtraction() async throws {
        let gitRoot = try await validateGitRepository()
        let configPath = ConfigFileManager.configPath(gitRoot: gitRoot)
        let config = try await validateConfigExists(at: configPath)
        
        // T112: Determine which subtrees to process
        let subtreesToProcess: [SubtreeEntry]
        if all {
            subtreesToProcess = config.subtrees
        } else if let subtreeName = name {
            if let subtree = try? config.findSubtree(name: subtreeName.normalized()) {
                subtreesToProcess = [subtree]
            } else {
                fputs("❌ Error: Subtree '\(subtreeName)' not found in config\n", stderr)
                Foundation.exit(1)
            }
        } else {
            // This shouldn't happen due to validation above
            fputs("❌ Error: Must specify --name or --all\n", stderr)
            Foundation.exit(1)
        }
        
        // T113: Execute mappings with failure collection
        var totalMappings = 0
        var successfulMappings = 0
        var failedMappings: [(subtreeName: String, mappingIndex: Int, error: String, exitCode: Int32)] = []
        var skippedSubtrees = 0
        
        for subtree in subtreesToProcess {
            guard let mappings = subtree.extractions, !mappings.isEmpty else {
                // T116: Show informational message for no saved mappings
                print("Processing subtree '\(subtree.name)'...")
                print("  ℹ️  No saved mappings found")
                if !all {
                    print("")
                    print("Tip: Add mappings with: subtree extract --name \(subtree.name) <pattern> <dest> --persist")
                }
                skippedSubtrees += 1
                continue
            }
            
            print("Processing subtree '\(subtree.name)' (\(mappings.count) mapping\(mappings.count == 1 ? "" : "s"))...")
            
            for (index, mapping) in mappings.enumerated() {
                totalMappings += 1
                let mappingNum = index + 1
                
                do {
                    // Execute single mapping
                    let count = try await executeSingleMapping(
                        mapping: mapping,
                        subtree: subtree,
                        gitRoot: gitRoot,
                        mappingNum: mappingNum,
                        totalMappings: mappings.count
                    )
                    print("  ✅ [\(mappingNum)/\(mappings.count)] \(mapping.from) → \(mapping.to) (\(count) file\(count == 1 ? "" : "s"))")
                    successfulMappings += 1
                } catch let error as GlobMatcherError {
                    print("  ❌ [\(mappingNum)/\(mappings.count)] \(mapping.from) → \(mapping.to) (invalid pattern)")
                    failedMappings.append((
                        subtreeName: subtree.name,
                        mappingIndex: mappingNum,
                        error: error.localizedDescription,
                        exitCode: 1  // User error
                    ))
                } catch let error as LocalizedError where error.errorDescription?.contains("git-tracked") == true {
                    print("  ❌ [\(mappingNum)/\(mappings.count)] \(mapping.from) → \(mapping.to) (blocked: git-tracked files)")
                    failedMappings.append((
                        subtreeName: subtree.name,
                        mappingIndex: mappingNum,
                        error: error.errorDescription ?? "Overwrite protection",
                        exitCode: 2  // System error (overwrite protection)
                    ))
                } catch {
                    print("  ❌ [\(mappingNum)/\(mappings.count)] \(mapping.from) → \(mapping.to) (failed)")
                    failedMappings.append((
                        subtreeName: subtree.name,
                        mappingIndex: mappingNum,
                        error: error.localizedDescription,
                        exitCode: 2  // System error
                    ))
                }
            }
            print("")  // Blank line between subtrees
        }
        
        // T115: Failure summary reporting
        print("📊 Summary: \(totalMappings) executed, \(successfulMappings) succeeded, \(failedMappings.count) failed\(skippedSubtrees > 0 ? ", \(skippedSubtrees) skipped (no mappings)" : "")")
        
        if !failedMappings.isEmpty {
            print("")
            print("❌ Failures:")
            for failure in failedMappings {
                print("  • \(failure.subtreeName) [mapping \(failure.mappingIndex)]: \(failure.error)")
            }
            
            // T114: Exit with highest severity code
            let highestExitCode = failedMappings.map { $0.exitCode }.max() ?? 1
            Foundation.exit(highestExitCode)
        }
    }
    
    /// Execute a single extraction mapping
    private func executeSingleMapping(
        mapping: ExtractionMapping,
        subtree: SubtreeEntry,
        gitRoot: String,
        mappingNum: Int,
        totalMappings: Int
    ) async throws -> Int {
        // Validate destination
        let normalizedDest = try validateDestination(mapping.to, gitRoot: gitRoot)
        
        // Find matching files
        let matchedFiles = try await findMatchingFiles(
            in: subtree.prefix,
            pattern: mapping.from,
            excludePatterns: mapping.exclude ?? [],
            gitRoot: gitRoot
        )
        
        guard !matchedFiles.isEmpty else {
            return 0  // No files matched, but not an error
        }
        
        // Create destination directory
        let fullDestPath = gitRoot + "/" + normalizedDest
        try createDestinationDirectory(at: fullDestPath)
        
        // Check for tracked files (unless --force)
        // In bulk mode, this will be caught as an error for this specific mapping
        if !force {
            let trackedFiles = try await checkForTrackedFiles(
                matchedFiles: matchedFiles,
                fullDestPath: fullDestPath,
                gitRoot: gitRoot
            )
            
            if !trackedFiles.isEmpty {
                // For bulk mode, throw an error that will be caught and reported
                struct OverwriteProtectionError: Error, LocalizedError {
                    let trackedFiles: [String]
                    var errorDescription: String? {
                        "Would overwrite \(trackedFiles.count) git-tracked file(s)"
                    }
                }
                throw OverwriteProtectionError(trackedFiles: trackedFiles)
            }
        }
        
        // Copy files
        var copiedCount = 0
        for (sourcePath, relativePath) in matchedFiles {
            let destFilePath = fullDestPath + "/" + relativePath
            try copyFilePreservingStructure(from: sourcePath, to: destFilePath)
            copiedCount += 1
        }
        
        return copiedCount
    }
    
    // MARK: - T068: Subtree Validation
    
    /// Verify we're in a git repository
    private func validateGitRepository() async throws -> String {
        do {
            return try await GitOperations.findGitRoot()
        } catch {
            fputs("❌ Error: Not in a git repository\n", stderr)
            Foundation.exit(1)
        }
    }
    
    /// Verify subtree.yaml exists
    private func validateConfigExists(at path: String) async throws -> SubtreeConfiguration {
        guard ConfigFileManager.exists(at: path) else {
            fputs("❌ Error: subtree.yaml not found. Run 'subtree init' first.\n", stderr)
            Foundation.exit(3)
        }
        
        do {
            return try await ConfigFileManager.loadConfig(from: path)
        } catch {
            fputs("❌ Error: Failed to parse subtree.yaml: \(error.localizedDescription)\n", stderr)
            Foundation.exit(3)
        }
    }
    
    /// Verify subtree exists in config
    private func validateSubtreeExists(name: String, in config: SubtreeConfiguration) throws -> SubtreeEntry {
        let normalizedName = name.normalized()
        
        do {
            guard let entry = try config.findSubtree(name: normalizedName) else {
                throw SubtreeValidationError.subtreeNotFound(name)
            }
            return entry
        } catch let error as SubtreeValidationError {
            fputs("\(error.errorDescription ?? "Error")\n", stderr)
            Foundation.exit(Int32(error.exitCode))
        }
    }
    
    /// Verify subtree prefix directory exists
    private func validateSubtreePrefix(_ prefix: String, gitRoot: String) async throws {
        let prefixPath = gitRoot + "/" + prefix
        var isDirectory: ObjCBool = false
        
        guard FileManager.default.fileExists(atPath: prefixPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            fputs("❌ Error: Subtree directory '\(prefix)' not found in repository\n", stderr)
            Foundation.exit(1)
        }
    }
    
    // MARK: - T069: Destination Path Validation
    
    /// Validate and normalize destination path
    private func validateDestination(_ dest: String, gitRoot: String) throws -> String {
        // Trim whitespace
        let trimmed = dest.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            fputs("❌ Error: Destination path cannot be empty\n", stderr)
            Foundation.exit(1)
        }
        
        // Check for absolute path
        if trimmed.hasPrefix("/") {
            fputs("❌ Error: Destination must be a relative path (got: '\(trimmed)')\n", stderr)
            Foundation.exit(1)
        }
        
        // Check for parent traversal
        if trimmed.contains("..") {
            fputs("❌ Error: Destination cannot contain '..' (got: '\(trimmed)')\n", stderr)
            Foundation.exit(1)
        }
        
        // Ensure path is within repository
        // Resolve symlinks for proper comparison
        let canonicalGitRoot = URL(fileURLWithPath: gitRoot).resolvingSymlinksInPath().path
        let fullPath = (canonicalGitRoot as NSString).appendingPathComponent(trimmed)
        let canonicalDest = URL(fileURLWithPath: fullPath).resolvingSymlinksInPath().path
        
        guard canonicalDest.hasPrefix(canonicalGitRoot + "/") || canonicalDest == canonicalGitRoot else {
            fputs("❌ Error: Destination must be within git repository\n", stderr)
            Foundation.exit(1)
        }
        
        // Remove trailing slash if present for consistency
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }
    
    // MARK: - T070: Glob Pattern Matching
    
    /// Find all files matching the glob pattern
    private func findMatchingFiles(
        in prefix: String,
        pattern: String,
        excludePatterns: [String],
        gitRoot: String
    ) async throws -> [(sourcePath: String, relativePath: String)] {
        let prefixPath = gitRoot + "/" + prefix
        
        // Create glob matcher for inclusion pattern
        let matcher = try GlobMatcher(pattern: pattern)
        
        // T071: Create exclusion matchers
        let excludeMatchers = try excludePatterns.map { try GlobMatcher(pattern: $0) }
        
        // Determine the literal prefix from the pattern (before any wildcards)
        let patternPrefix = extractLiteralPrefix(from: pattern)
        
        // Find all files in the subtree directory
        var matchedFiles: [(String, String)] = []
        try scanDirectory(
            at: prefixPath,
            relativeTo: prefixPath,
            matcher: matcher,
            excludeMatchers: excludeMatchers,
            patternPrefix: patternPrefix,
            results: &matchedFiles
        )
        
        return matchedFiles
    }
    
    /// Extract the literal path prefix from a glob pattern (before any wildcards)
    ///
    /// Examples:
    /// - "src/**/*.c" → "src/"
    /// - "docs/api/*.md" → "docs/api/"
    /// - "**/*.txt" → ""
    /// - "README.md" → ""
    private func extractLiteralPrefix(from pattern: String) -> String {
        var prefix = ""
        let components = pattern.split(separator: "/", omittingEmptySubsequences: false)
        
        for component in components {
            let compStr = String(component)
            // Stop at first component with wildcards
            if compStr.contains("*") || compStr.contains("?") || compStr.contains("[") || compStr.contains("{") {
                break
            }
            if !prefix.isEmpty {
                prefix += "/"
            }
            prefix += compStr
        }
        
        return prefix.isEmpty ? "" : prefix + "/"
    }
    
    /// Recursively scan directory for matching files
    private func scanDirectory(
        at path: String,
        relativeTo basePath: String,
        matcher: GlobMatcher,
        excludeMatchers: [GlobMatcher],
        patternPrefix: String,
        results: inout [(String, String)]
    ) throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: path)
        
        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            
            // Calculate relative path from base
            let relativePath: String
            if itemPath.hasPrefix(basePath + "/") {
                relativePath = String(itemPath.dropFirst(basePath.count + 1))
            } else if itemPath == basePath {
                relativePath = ""
            } else {
                continue // Skip if not under base path
            }
            
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) else {
                continue
            }
            
            if isDirectory.boolValue {
                // Recurse into subdirectory
                try scanDirectory(
                    at: itemPath,
                    relativeTo: basePath,
                    matcher: matcher,
                    excludeMatchers: excludeMatchers,
                    patternPrefix: patternPrefix,
                    results: &results
                )
            } else {
                // Check if file matches pattern
                if matcher.matches(relativePath) {
                    // T071: Check exclusion patterns
                    let excluded = excludeMatchers.contains { $0.matches(relativePath) }
                    if !excluded {
                        // Strip the pattern prefix to get the destination relative path
                        var destRelativePath = relativePath
                        if !patternPrefix.isEmpty && destRelativePath.hasPrefix(patternPrefix) {
                            destRelativePath = String(destRelativePath.dropFirst(patternPrefix.count))
                        }
                        results.append((itemPath, destRelativePath))
                    }
                }
            }
        }
    }
    
    // MARK: - T072: File Copying
    
    /// Copy a file preserving its directory structure
    private func copyFilePreservingStructure(from sourcePath: String, to destPath: String) throws {
        let fileManager = FileManager.default
        
        // T073: Create parent directories
        let parentDir = (destPath as NSString).deletingLastPathComponent
        if !fileManager.fileExists(atPath: parentDir) {
            try fileManager.createDirectory(
                atPath: parentDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        // Copy the file
        // If destination exists, remove it first (overwrite)
        if fileManager.fileExists(atPath: destPath) {
            try fileManager.removeItem(atPath: destPath)
        }
        
        try fileManager.copyItem(atPath: sourcePath, toPath: destPath)
    }
    
    // MARK: - T074: Destination Directory Creation
    
    /// Create destination directory if it doesn't exist
    private func createDestinationDirectory(at path: String) throws {
        let fileManager = FileManager.default
        
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            // Path exists - verify it's a directory
            guard isDirectory.boolValue else {
                fputs("❌ Error: Destination '\(path)' exists but is not a directory\n", stderr)
                Foundation.exit(1)
            }
            // Directory exists, nothing to do
        } else {
            // Create directory
            try fileManager.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    // MARK: - T092-T093: Mapping Persistence
    
    /// Save extraction mapping to config if not duplicate
    ///
    /// - Parameters:
    ///   - pattern: Glob pattern (from field)
    ///   - destination: Destination path (to field)
    ///   - excludePatterns: Exclusion patterns (exclude field)
    ///   - subtreeName: Name of subtree to save mapping to
    ///   - configPath: Path to subtree.yaml
    /// - Returns: true if mapping was saved, false if duplicate detected
    /// - Throws: I/O errors or config errors
    private func saveMappingToConfig(
        pattern: String,
        destination: String,
        excludePatterns: [String],
        subtreeName: String,
        configPath: String
    ) async throws -> Bool {
        // T093: Construct ExtractionMapping from CLI flags
        let mapping = ExtractionMapping(
            from: pattern,
            to: destination,
            exclude: excludePatterns.isEmpty ? nil : excludePatterns
        )
        
        // Check for duplicate mapping
        let config = try await ConfigFileManager.loadConfig(from: configPath)
        
        if let subtree = try config.findSubtree(name: subtreeName.normalized()),
           let existingMappings = subtree.extractions {
            // Check if exact same mapping already exists
            for existing in existingMappings {
                if existing.from == mapping.from &&
                   existing.to == mapping.to &&
                   existing.exclude == mapping.exclude {
                    // Duplicate found - skip saving
                    return false
                }
            }
        }
        
        // T092 + T094: Save using ConfigFileManager (atomic operation)
        try await ConfigFileManager.appendExtraction(mapping, to: subtreeName, in: configPath)
        
        return true
    }
    
    // MARK: - T132-T136: Overwrite Protection
    
    /// Check which destination files are git-tracked
    ///
    /// - Parameters:
    ///   - matchedFiles: Array of (source path, relative path) tuples
    ///   - fullDestPath: Full destination directory path
    ///   - gitRoot: Git repository root path
    /// - Returns: Array of relative paths that are git-tracked
    private func checkForTrackedFiles(
        matchedFiles: [(sourcePath: String, relativePath: String)],
        fullDestPath: String,
        gitRoot: String
    ) async throws -> [String] {
        var trackedFiles: [String] = []
        
        for (_, relativePath) in matchedFiles {
            let destFilePath = fullDestPath + "/" + relativePath
            
            // Only check if file exists
            guard FileManager.default.fileExists(atPath: destFilePath) else {
                continue  // New file, not tracked
            }
            
            // Check if file is git-tracked
            if try await GitOperations.isFileTracked(path: destFilePath, in: gitRoot) {
                trackedFiles.append(relativePath)
            }
        }
        
        return trackedFiles
    }
    
    /// Handle overwrite protection error
    ///
    /// - Parameter trackedFiles: List of tracked file paths (relative)
    /// - Throws: Never returns, calls Foundation.exit(2)
    private func handleOverwriteProtection(trackedFiles: [String]) throws -> Never {
        let count = trackedFiles.count
        
        fputs("❌ Error: Cannot overwrite \(count) git-tracked file\(count == 1 ? "" : "s")\n\n", stderr)
        fputs("Protected files:\n", stderr)
        
        // Show all files if <= 20, otherwise show first 5 + count
        if count <= 20 {
            for file in trackedFiles {
                fputs("  • \(file)\n", stderr)
            }
        } else {
            for file in trackedFiles.prefix(5) {
                fputs("  • \(file)\n", stderr)
            }
            fputs("  ... and \(count - 5) more\n", stderr)
        }
        
        fputs("\nUse --force to override protection\n", stderr)
        Foundation.exit(2)  // System error code for overwrite protection
    }
}
