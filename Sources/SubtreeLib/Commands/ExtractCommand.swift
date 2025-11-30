import ArgumentParser
import Foundation

// MARK: - Clean Mode Data Types (010-extract-clean)

/// A file identified for cleaning
struct CleanFileEntry {
    /// Absolute path to source file in subtree (for checksum)
    let sourcePath: String
    
    /// Absolute path to destination file (to be deleted)
    let destinationPath: String
    
    /// Relative path from destination root (for display)
    let relativePath: String
}

/// Result of validating a file before deletion
enum CleanValidationResult {
    /// Checksums match, safe to delete
    case valid
    
    /// Destination file was modified (checksum mismatch)
    case modified(sourceHash: String, destHash: String)
    
    /// Source file no longer exists in subtree
    case sourceMissing
}

// MARK: - Concurrency-Safe Error Output

/// Writes a message to stderr in a concurrency-safe way
private func writeStderr(_ message: String) {
    FileHandle.standardError.write(Data(message.utf8))
}

/// Extract files from a subtree using glob patterns (008-extract-command + 009-multi-pattern)
///
/// This command supports two modes:
/// 1. Ad-hoc extraction: Extract files using command-line patterns (supports multiple `--from` flags)
/// 2. Saved mappings: Extract files using saved extraction mappings from subtree.yaml
///
/// Multi-pattern extraction (009): Use multiple `--from` flags to extract files from several
/// directories in a single command. Files are deduplicated by relative path.
///
/// Examples:
/// ```
/// # Ad-hoc: Extract markdown docs from docs subtree
/// subtree extract --name docs --from "**/*.md" --to project-docs/
///
/// # Multi-pattern: Extract headers AND sources in one command
/// subtree extract --name mylib --from "include/**/*.h" --from "src/**/*.c" --to vendor/
///
/// # With exclusions (applies to all patterns)
/// subtree extract --name mylib --from "src/**/*.c" --to Sources/ --exclude "**/test/**"
/// ```
public struct ExtractCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "Extract or clean files from a subtree using glob patterns",
        discussion: """
            Extract files from managed subtrees into your project, or clean (remove) previously
            extracted files using the --clean flag. Uses flexible glob patterns.
            
            EXTRACTION MODES:
              • Ad-hoc extraction: Specify pattern and destination on command line
              • Bulk extraction: Use saved mappings from subtree.yaml (--name or --all)
            
            CLEAN MODES (--clean):
              • Ad-hoc clean: Remove files matching patterns from destination
              • Bulk clean: Remove all files from saved mappings (--name or --all)
              
              Clean mode validates checksums before deletion to protect modified files.
              Use --force to override checksum validation and delete modified files.
            
            EXTRACTION EXAMPLES:
              # Extract markdown documentation
              subtree extract --name docs --from "**/*.md" --to project-docs/
              
              # Multi-pattern: Extract headers AND sources together
              subtree extract --name mylib --from "include/**/*.h" --from "src/**/*.c" --to vendor/
              
              # With exclusions (applies to all patterns)
              subtree extract --name mylib --from "src/**/*.c" --to Sources/ --exclude "**/test/**"
              
              # Save mapping for future use
              subtree extract --name mylib --from "src/**/*.c" --to Sources/ --persist
              
              # Execute saved mappings
              subtree extract --name mylib
              subtree extract --all
            
            CLEAN EXAMPLES:
              # Clean extracted files (checksum validated)
              subtree extract --clean --name mylib --from "src/**/*.c" --to Sources/
              
              # Force clean modified files
              subtree extract --clean --force --name mylib --from "*.c" --to Sources/
              
              # Clean all saved mappings for a subtree
              subtree extract --clean --name mylib
              
              # Clean all saved mappings for all subtrees
              subtree extract --clean --all
            
            GLOB PATTERNS:
              *       Match any characters except /
              **      Match any characters including /
              ?       Match single character
              [abc]   Match character class
              {a,b}   Match brace expansion
            
            EXIT CODES:
              0  Success
              1  Validation error (checksum mismatch, not found)
              2  User error (invalid flag combination)
              3  I/O error (permission denied, filesystem error)
            """
    )
    
    // T063: --name flag for subtree selection (optional for --all mode)
    @Option(name: .long, help: "Name of the subtree to extract files from")
    var name: String?
    
    // T110: --all flag for bulk extraction across all subtrees
    @Flag(name: .long, help: "Execute saved extraction mappings for all subtrees")
    var all: Bool = false
    
    // T022: Source pattern option (repeatable for multi-pattern extraction)
    @Option(name: .long, help: "Glob pattern to match files (can be repeated for multi-pattern extraction)")
    var from: [String] = []
    
    // T022: Destination option
    @Option(name: .long, help: "Destination path relative to repository root (e.g., 'docs/', 'Sources/MyLib/')")
    var to: String?
    
    // T066: --exclude repeatable flag for exclusion patterns
    @Option(name: .long, help: "Glob pattern to exclude files (can be repeated)")
    var exclude: [String] = []
    
    // T091: --persist flag to save extraction mapping
    @Flag(name: .long, help: "Save this extraction mapping to subtree.yaml for future use")
    var persist: Bool = false
    
    // T131: --force flag to override overwrite protection
    @Flag(name: .long, help: "Override git-tracked file protection (allows overwriting tracked files)")
    var force: Bool = false
    
    // T021: --clean flag to trigger removal mode (010-extract-clean)
    @Flag(name: .long, help: "Remove previously extracted files (opposite of extraction)")
    var clean: Bool = false
    
    public init() {}
    
    public func run() async throws {
        // T022: Validate --clean and --persist cannot be combined
        if clean && persist {
            writeStderr("❌ Error: --clean and --persist cannot be used together\n")
            writeStderr("   --clean removes files, --persist saves mappings for extraction\n")
            Foundation.exit(2)
        }
        
        // T023: Route to clean mode if --clean flag is set
        if clean {
            try await runCleanMode()
            return
        }
        
        // T111: Mode selection based on --from/--to options
        let hasAdHocArgs = !from.isEmpty && to != nil
        
        if hasAdHocArgs {
            // AD-HOC MODE: Extract specific pattern
            if all {
                writeStderr("❌ Error: --all flag cannot be used with pattern/destination arguments\n")
                writeStderr("   For ad-hoc extraction, use: subtree extract --name <name> <pattern> <destination>\n")
                writeStderr("   For bulk extraction, use: subtree extract --all\n")
                Foundation.exit(1)
            }
            
            guard let subtreeName = name else {
                writeStderr("❌ Error: --name is required for ad-hoc extraction\n")
                Foundation.exit(1)
            }
            
            try await runAdHocExtraction(subtreeName: subtreeName)
        } else {
            // BULK MODE: Execute saved mappings
            if !from.isEmpty || to != nil {
                writeStderr("❌ Error: --from and --to must both be provided or both omitted\n")
                Foundation.exit(1)
            }
            
            if !all && name == nil {
                writeStderr("❌ Error: Must specify either --name or --all for bulk extraction\n")
                writeStderr("   Usage: subtree extract --name <name>\n")
                writeStderr("          subtree extract --all\n")
                Foundation.exit(1)
            }
            
            try await runBulkExtraction()
        }
    }
    
    // MARK: - Ad-Hoc Extraction Mode
    
    private func runAdHocExtraction(subtreeName: String) async throws {
        guard let destinationValue = to else {
            writeStderr("❌ Internal error: Missing --to in ad-hoc mode\n")
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
        
        // T039: Expand brace patterns in --from before matching (011-brace-expansion)
        let expandedFromPatterns = expandBracePatterns(from)
        
        // T040: Expand brace patterns in --exclude before matching (011-brace-expansion)
        let expandedExcludePatterns = expandBracePatterns(exclude)
        
        // T023-T025 + T040: Multi-pattern matching with deduplication and per-pattern tracking
        // Process all --from patterns and collect unique files
        var allMatchedFiles: [(sourcePath: String, relativePath: String)] = []
        var seenPaths = Set<String>()  // T024: Deduplicate by relative path
        var patternMatchCounts: [(pattern: String, count: Int)] = []  // T040: Per-pattern tracking
        
        for pattern in expandedFromPatterns {
            let matchedFiles = try await findMatchingFiles(
                in: subtree.prefix,
                pattern: pattern,
                excludePatterns: expandedExcludePatterns,
                gitRoot: gitRoot
            )
            
            // T040: Track match count for this pattern
            var patternUniqueCount = 0
            
            // T024: Add files not already seen (deduplication)
            for file in matchedFiles {
                if !seenPaths.contains(file.relativePath) {
                    seenPaths.insert(file.relativePath)
                    allMatchedFiles.append(file)
                    patternUniqueCount += 1
                }
            }
            
            patternMatchCounts.append((pattern: pattern, count: patternUniqueCount))
        }
        
        // T150 + T042: Zero-match validation (ad-hoc mode = error only if ALL patterns match nothing)
        guard !allMatchedFiles.isEmpty else {
            let patternsDesc = from.joined(separator: "', '")
            writeStderr("❌ Error: No files matched pattern(s) '\(patternsDesc)' in subtree '\(subtreeName)'\n\n")
            writeStderr("Suggestions:\n")
            writeStderr("  • Check pattern syntax\n")
            writeStderr("  • Verify files exist in \(subtree.prefix)/\n")
            writeStderr("  • Try a broader pattern like '**/*'\n")
            Foundation.exit(1)  // User error
        }
        
        // T041: Display warnings for zero-match patterns (when some patterns do match)
        let zeroMatchPatterns = patternMatchCounts.filter { $0.count == 0 }
        for zeroMatch in zeroMatchPatterns {
            print("⚠️  Pattern '\(zeroMatch.pattern)' matched 0 files")
        }
        
        // T074: Destination directory creation
        let fullDestPath = gitRoot + "/" + normalizedDest
        try createDestinationDirectory(at: fullDestPath)
        
        // T132-T133: Check for git-tracked files before copying (unless --force)
        if !force {
            let trackedFiles = try await checkForTrackedFiles(
                matchedFiles: allMatchedFiles,
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
        for (sourcePath, relativePath) in allMatchedFiles {
            let destFilePath = fullDestPath + "/" + relativePath
            try copyFilePreservingStructure(from: sourcePath, to: destFilePath)
            copiedCount += 1
        }
        
        // T092: Save mapping if --persist flag is set
        var mappingSaved = false
        if persist {
            mappingSaved = try await saveMappingToConfig(
                patterns: from,
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
                writeStderr("❌ Error: Subtree '\(subtreeName)' not found in config\n")
                Foundation.exit(1)
            }
        } else {
            // This shouldn't happen due to validation above
            writeStderr("❌ Error: Must specify --name or --all\n")
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
                    print("  ✅ [\(mappingNum)/\(mappings.count)] \(mapping.from.joined(separator: ", ")) → \(mapping.to) (\(count) file\(count == 1 ? "" : "s"))")
                    successfulMappings += 1
                } catch let error as GlobMatcherError {
                    print("  ❌ [\(mappingNum)/\(mappings.count)] \(mapping.from.joined(separator: ", ")) → \(mapping.to) (invalid pattern)")
                    failedMappings.append((
                        subtreeName: subtree.name,
                        mappingIndex: mappingNum,
                        error: error.localizedDescription,
                        exitCode: 1  // User error
                    ))
                } catch let error as LocalizedError where error.errorDescription?.contains("git-tracked") == true {
                    print("  ❌ [\(mappingNum)/\(mappings.count)] \(mapping.from.joined(separator: ", ")) → \(mapping.to) (blocked: git-tracked files)")
                    failedMappings.append((
                        subtreeName: subtree.name,
                        mappingIndex: mappingNum,
                        error: error.errorDescription ?? "Overwrite protection",
                        exitCode: 2  // System error (overwrite protection)
                    ))
                } catch {
                    print("  ❌ [\(mappingNum)/\(mappings.count)] \(mapping.from.joined(separator: ", ")) → \(mapping.to) (failed)")
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
    
    // MARK: - Clean Mode (010-extract-clean T023-T031)
    
    /// T023: Route clean mode based on arguments (ad-hoc vs bulk)
    private func runCleanMode() async throws {
        let hasAdHocArgs = !from.isEmpty && to != nil
        
        if hasAdHocArgs {
            // AD-HOC CLEAN MODE
            if all {
                writeStderr("❌ Error: --all flag cannot be used with pattern arguments\n")
                Foundation.exit(1)
            }
            
            guard let subtreeName = name else {
                writeStderr("❌ Error: --name is required for ad-hoc clean\n")
                Foundation.exit(1)
            }
            
            try await runAdHocClean(subtreeName: subtreeName)
        } else {
            // BULK CLEAN MODE
            if !from.isEmpty || to != nil {
                writeStderr("❌ Error: --from and --to must both be provided or both omitted\n")
                Foundation.exit(1)
            }
            
            if !all && name == nil {
                writeStderr("❌ Error: Must specify either --name or --all for clean\n")
                writeStderr("   Usage: subtree extract --clean --name <name>\n")
                writeStderr("          subtree extract --clean --all\n")
                Foundation.exit(1)
            }
            
            // T046: Run bulk clean from persisted mappings
            try await runBulkClean()
        }
    }
    
    /// T046: Bulk clean from persisted extraction mappings
    private func runBulkClean() async throws {
        // Validate git repo and config
        let gitRoot = try await validateGitRepository()
        let configPath = ConfigFileManager.configPath(gitRoot: gitRoot)
        let config = try await validateConfigExists(at: configPath)
        
        // T047-T048: Collect subtrees to process
        var subtreesToClean: [SubtreeEntry] = []
        
        if let subtreeName = name {
            // T047: Single-subtree bulk clean
            let subtree = try validateSubtreeExists(name: subtreeName, in: config)
            subtreesToClean = [subtree]
        } else if all {
            // T048: All-subtrees bulk clean
            subtreesToClean = config.subtrees
        }
        
        // Track results for continue-on-error (T049)
        var totalCleaned = 0
        var failedMappings: [(subtree: String, mapping: Int, exitCode: Int32, message: String)] = []
        var highestExitCode: Int32 = 0
        
        for subtree in subtreesToClean {
            guard let extractions = subtree.extractions, !extractions.isEmpty else {
                // T044: No mappings = success with message
                print("ℹ️  '\(subtree.name)': No extraction mappings to clean")
                continue
            }
            
            print("📋 Cleaning '\(subtree.name)' (\(extractions.count) mapping(s))...")
            
            // Validate subtree prefix exists (unless --force)
            var prefixValid = true
            if !force {
                do {
                    try await validateSubtreePrefix(subtree.prefix, gitRoot: gitRoot)
                } catch {
                    prefixValid = false
                    if !force {
                        writeStderr("   ⚠️  Subtree prefix '\(subtree.prefix)' not found\n")
                    }
                }
            }
            
            for (mappingIndex, mapping) in extractions.enumerated() {
                let mappingNum = mappingIndex + 1
                
                // Process this mapping
                do {
                    let cleaned = try await cleanSingleMapping(
                        mapping: mapping,
                        subtree: subtree,
                        gitRoot: gitRoot,
                        prefixValid: prefixValid,
                        mappingNum: mappingNum,
                        totalMappings: extractions.count
                    )
                    totalCleaned += cleaned
                } catch let error as CleanMappingError {
                    // T049: Continue on error, collect failure
                    failedMappings.append((
                        subtree: subtree.name,
                        mapping: mappingNum,
                        exitCode: error.exitCode,
                        message: error.message
                    ))
                    highestExitCode = max(highestExitCode, error.exitCode)
                }
            }
        }
        
        // T050: Report summary
        if failedMappings.isEmpty {
            print("\n✅ Cleaned \(totalCleaned) file(s) total")
        } else {
            // T050: Failure summary
            print("\n📊 Bulk clean completed with errors:")
            print("   ✅ Cleaned \(totalCleaned) file(s)")
            print("   ❌ \(failedMappings.count) mapping(s) failed")
            
            for failure in failedMappings {
                writeStderr("   • \(failure.subtree) mapping \(failure.mapping): \(failure.message)\n")
            }
            
            // T051: Exit with highest severity
            Foundation.exit(highestExitCode)
        }
    }
    
    /// Error type for clean mapping failures
    private struct CleanMappingError: Error {
        let exitCode: Int32
        let message: String
    }
    
    /// Clean files for a single extraction mapping
    private func cleanSingleMapping(
        mapping: ExtractionMapping,
        subtree: SubtreeEntry,
        gitRoot: String,
        prefixValid: Bool,
        mappingNum: Int,
        totalMappings: Int
    ) async throws -> Int {
        // Normalize destination
        let normalizedDest = try validateDestination(mapping.to, gitRoot: gitRoot)
        let fullDestPath = gitRoot + "/" + normalizedDest
        
        // 011-brace-expansion: Expand brace patterns before matching
        let expandedFromPatterns = expandBracePatterns(mapping.from)
        let expandedExcludePatterns = expandBracePatterns(mapping.exclude ?? [])
        
        // Find files to clean
        let filesToClean = try await findFilesToClean(
            patterns: expandedFromPatterns,
            excludePatterns: expandedExcludePatterns,
            subtreePrefix: subtree.prefix,
            destinationPath: fullDestPath,
            gitRoot: gitRoot
        )
        
        // Zero files = success for this mapping
        guard !filesToClean.isEmpty else {
            print("   [\(mappingNum)/\(totalMappings)] → '\(normalizedDest)': 0 files (no matches)")
            return 0
        }
        
        // Validate checksums (unless --force)
        var validatedFiles: [CleanFileEntry] = []
        var skippedCount = 0
        
        for file in filesToClean {
            let validationResult = await validateChecksumForClean(file: file, force: force)
            
            switch validationResult {
            case .valid:
                validatedFiles.append(file)
            case .modified(let sourceHash, let destHash):
                // In bulk mode, report error but throw to be caught by continue-on-error
                throw CleanMappingError(
                    exitCode: 1,
                    message: "File '\(file.relativePath)' modified (src: \(sourceHash.prefix(8))..., dst: \(destHash.prefix(8))...)"
                )
            case .sourceMissing:
                if force {
                    validatedFiles.append(file)
                } else {
                    skippedCount += 1
                }
            }
        }
        
        // Delete validated files
        var pruner = DirectoryPruner(boundary: fullDestPath)
        var deletedCount = 0
        
        for file in validatedFiles {
            do {
                try FileManager.default.removeItem(atPath: file.destinationPath)
                pruner.add(parentOf: file.destinationPath)
                deletedCount += 1
            } catch {
                throw CleanMappingError(
                    exitCode: 3,
                    message: "Failed to delete '\(file.relativePath)': \(error.localizedDescription)"
                )
            }
        }
        
        // Prune empty directories
        let prunedDirs = try pruner.pruneEmpty()
        
        // Report progress
        var statusParts: [String] = ["\(deletedCount) file(s)"]
        if prunedDirs > 0 {
            statusParts.append("\(prunedDirs) dir(s) pruned")
        }
        if skippedCount > 0 {
            statusParts.append("\(skippedCount) skipped")
        }
        print("   [\(mappingNum)/\(totalMappings)] → '\(normalizedDest)': \(statusParts.joined(separator: ", "))")
        
        return deletedCount
    }
    
    /// T024: Ad-hoc clean with pattern arguments
    private func runAdHocClean(subtreeName: String) async throws {
        guard let destinationValue = to else {
            writeStderr("❌ Internal error: Missing --to in ad-hoc clean mode\n")
            Foundation.exit(2)
        }
        
        // Validate git repo and config
        let gitRoot = try await validateGitRepository()
        let configPath = ConfigFileManager.configPath(gitRoot: gitRoot)
        let config = try await validateConfigExists(at: configPath)
        let subtree = try validateSubtreeExists(name: subtreeName, in: config)
        
        // Validate subtree prefix exists (unless --force)
        if !force {
            try await validateSubtreePrefix(subtree.prefix, gitRoot: gitRoot)
        }
        
        // Normalize destination
        let normalizedDest = try validateDestination(destinationValue, gitRoot: gitRoot)
        let fullDestPath = gitRoot + "/" + normalizedDest
        
        // 011-brace-expansion: Expand brace patterns before matching
        let expandedFromPatterns = expandBracePatterns(from)
        let expandedExcludePatterns = expandBracePatterns(exclude)
        
        // T025: Find files to clean in destination
        let filesToClean = try await findFilesToClean(
            patterns: expandedFromPatterns,
            excludePatterns: expandedExcludePatterns,
            subtreePrefix: subtree.prefix,
            destinationPath: fullDestPath,
            gitRoot: gitRoot
        )
        
        // BC-007: Zero files matched = success
        guard !filesToClean.isEmpty else {
            print("✅ Cleaned 0 file(s) from '\(subtreeName)' destination '\(normalizedDest)'")
            print("   ℹ️  No files matched the pattern(s)")
            return
        }
        
        // T026-T028: Validate checksums and handle missing sources
        var validatedFiles: [CleanFileEntry] = []
        var skippedCount = 0
        
        for file in filesToClean {
            let validationResult = await validateChecksumForClean(file: file, force: force)
            
            switch validationResult {
            case .valid:
                validatedFiles.append(file)
            case .modified(let sourceHash, let destHash):
                // T027: Fail fast on checksum mismatch (unless --force)
                writeStderr("❌ Error: File '\(file.relativePath)' has been modified\n\n")
                writeStderr("   Source hash:  \(sourceHash)\n")
                writeStderr("   Dest hash:    \(destHash)\n\n")
                writeStderr("Suggestion: Use --force to delete modified files, or restore original content.\n")
                Foundation.exit(1)
            case .sourceMissing:
                // T028: Skip with warning for missing source (unless --force)
                if force {
                    validatedFiles.append(file)
                } else {
                    print("⚠️  Skipping '\(file.relativePath)': source file not found in subtree")
                    skippedCount += 1
                }
            }
        }
        
        // T029: Delete validated files
        var pruner = DirectoryPruner(boundary: fullDestPath)
        var deletedCount = 0
        
        for file in validatedFiles {
            do {
                try FileManager.default.removeItem(atPath: file.destinationPath)
                pruner.add(parentOf: file.destinationPath)
                deletedCount += 1
            } catch {
                writeStderr("❌ Error: Failed to delete '\(file.relativePath)': \(error.localizedDescription)\n")
                Foundation.exit(3)
            }
        }
        
        // T030: Prune empty directories
        let prunedDirs = try pruner.pruneEmpty()
        
        // T031: Success output
        print("✅ Cleaned \(deletedCount) file(s) from '\(subtreeName)' destination '\(normalizedDest)'")
        if prunedDirs > 0 {
            print("   📁 Pruned \(prunedDirs) empty director\(prunedDirs == 1 ? "y" : "ies")")
        }
        if skippedCount > 0 {
            print("   ⚠️  Skipped \(skippedCount) file(s) with missing source")
        }
    }
    
    /// T025: Find files in destination that match source patterns
    private func findFilesToClean(
        patterns: [String],
        excludePatterns: [String],
        subtreePrefix: String,
        destinationPath: String,
        gitRoot: String
    ) async throws -> [CleanFileEntry] {
        var allFiles: [CleanFileEntry] = []
        var seenPaths = Set<String>()
        
        // Create exclusion matchers
        let excludeMatchers = try excludePatterns.map { try GlobMatcher(pattern: $0) }
        
        for pattern in patterns {
            let matcher = try GlobMatcher(pattern: pattern)
            let patternPrefix = extractLiteralPrefix(from: pattern)
            
            // Scan destination directory for matching files
            var matchedFiles: [(String, String)] = []
            
            // Check if destination exists
            guard FileManager.default.fileExists(atPath: destinationPath) else {
                continue
            }
            
            try scanDirectory(
                at: destinationPath,
                relativeTo: destinationPath,
                matcher: matcher,
                excludeMatchers: excludeMatchers,
                patternPrefix: patternPrefix,
                results: &matchedFiles
            )
            
            // Convert to CleanFileEntry with source paths
            let sourcePrefixPath = gitRoot + "/" + subtreePrefix
            for (destPath, relativePath) in matchedFiles {
                if !seenPaths.contains(relativePath) {
                    seenPaths.insert(relativePath)
                    let sourcePath = sourcePrefixPath + "/" + relativePath
                    allFiles.append(CleanFileEntry(
                        sourcePath: sourcePath,
                        destinationPath: destPath,
                        relativePath: relativePath
                    ))
                }
            }
        }
        
        return allFiles
    }
    
    /// T026: Validate checksum for a file before deletion
    private func validateChecksumForClean(file: CleanFileEntry, force: Bool) async -> CleanValidationResult {
        // If force mode, skip validation
        if force {
            return .valid
        }
        
        // Check if source file exists
        guard FileManager.default.fileExists(atPath: file.sourcePath) else {
            return .sourceMissing
        }
        
        // Compute checksums
        do {
            let sourceHash = try await GitOperations.hashObject(file: file.sourcePath)
            let destHash = try await GitOperations.hashObject(file: file.destinationPath)
            
            if sourceHash == destHash {
                return .valid
            } else {
                return .modified(sourceHash: sourceHash, destHash: destHash)
            }
        } catch {
            // If we can't compute hash, treat as modified for safety
            return .modified(sourceHash: "unknown", destHash: "unknown")
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
        
        // 011-brace-expansion: Expand brace patterns before matching
        let expandedFromPatterns = expandBracePatterns(mapping.from)
        let expandedExcludePatterns = expandBracePatterns(mapping.exclude ?? [])
        
        // T026: Find matching files from ALL patterns (multi-pattern support)
        var allMatchedFiles: [(sourcePath: String, relativePath: String)] = []
        var seenPaths = Set<String>()  // Deduplicate by relative path
        
        for pattern in expandedFromPatterns {
            let matchedFiles = try await findMatchingFiles(
                in: subtree.prefix,
                pattern: pattern,
                excludePatterns: expandedExcludePatterns,
                gitRoot: gitRoot
            )
            
            // Add files not already seen (deduplication)
            for file in matchedFiles {
                if !seenPaths.contains(file.relativePath) {
                    seenPaths.insert(file.relativePath)
                    allMatchedFiles.append(file)
                }
            }
        }
        
        guard !allMatchedFiles.isEmpty else {
            return 0  // No files matched, but not an error
        }
        
        // Create destination directory
        let fullDestPath = gitRoot + "/" + normalizedDest
        try createDestinationDirectory(at: fullDestPath)
        
        // Check for tracked files (unless --force)
        // In bulk mode, this will be caught as an error for this specific mapping
        if !force {
            let trackedFiles = try await checkForTrackedFiles(
                matchedFiles: allMatchedFiles,
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
        for (sourcePath, relativePath) in allMatchedFiles {
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
            writeStderr("❌ Error: Not in a git repository\n")
            Foundation.exit(1)
        }
    }
    
    /// Verify subtree.yaml exists
    private func validateConfigExists(at path: String) async throws -> SubtreeConfiguration {
        guard ConfigFileManager.exists(at: path) else {
            writeStderr("❌ Error: subtree.yaml not found. Run 'subtree init' first.\n")
            Foundation.exit(3)
        }
        
        do {
            return try await ConfigFileManager.loadConfig(from: path)
        } catch {
            writeStderr("❌ Error: Failed to parse subtree.yaml: \(error.localizedDescription)\n")
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
            writeStderr("\(error.errorDescription ?? "Error")\n")
            Foundation.exit(Int32(error.exitCode))
        }
    }
    
    /// Verify subtree prefix directory exists
    private func validateSubtreePrefix(_ prefix: String, gitRoot: String) async throws {
        let prefixPath = gitRoot + "/" + prefix
        var isDirectory: ObjCBool = false
        
        guard FileManager.default.fileExists(atPath: prefixPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            writeStderr("❌ Error: Subtree directory '\(prefix)' not found in repository\n")
            Foundation.exit(1)
        }
    }
    
    // MARK: - T069: Destination Path Validation
    
    /// Validate and normalize destination path
    private func validateDestination(_ dest: String, gitRoot: String) throws -> String {
        // Trim whitespace
        let trimmed = dest.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            writeStderr("❌ Error: Destination path cannot be empty\n")
            Foundation.exit(1)
        }
        
        // Check for absolute path
        if trimmed.hasPrefix("/") {
            writeStderr("❌ Error: Destination must be a relative path (got: '\(trimmed)')\n")
            Foundation.exit(1)
        }
        
        // Check for parent traversal
        if trimmed.contains("..") {
            writeStderr("❌ Error: Destination cannot contain '..' (got: '\(trimmed)')\n")
            Foundation.exit(1)
        }
        
        // Ensure path is within repository
        // Resolve symlinks for proper comparison
        let canonicalGitRoot = URL(fileURLWithPath: gitRoot).resolvingSymlinksInPath().path
        let fullPath = (canonicalGitRoot as NSString).appendingPathComponent(trimmed)
        let canonicalDest = URL(fileURLWithPath: fullPath).resolvingSymlinksInPath().path
        
        guard canonicalDest.hasPrefix(canonicalGitRoot + "/") || canonicalDest == canonicalGitRoot else {
            writeStderr("❌ Error: Destination must be within git repository\n")
            Foundation.exit(1)
        }
        
        // Remove trailing slash if present for consistency
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }
    
    // MARK: - T038: Brace Expansion Helper (011-brace-expansion)
    
    /// Expand brace patterns in a list of patterns
    ///
    /// Applies `BraceExpander` to each pattern, handling errors with user-friendly messages.
    /// Returns flattened array of all expanded patterns.
    ///
    /// - Parameter patterns: Array of patterns potentially containing braces
    /// - Returns: Array of expanded patterns
    /// - Throws: Never (exits with error code on failure)
    private func expandBracePatterns(_ patterns: [String]) -> [String] {
        var expandedPatterns: [String] = []
        
        for pattern in patterns {
            do {
                let expanded = try BraceExpander.expand(pattern)
                expandedPatterns.append(contentsOf: expanded)
            } catch BraceExpanderError.emptyAlternative(let invalidPattern) {
                // T041: User-friendly error message
                writeStderr("❌ Error: Invalid brace pattern '\(invalidPattern)'\n")
                writeStderr("   Empty alternatives like {a,} or {,b} are not supported.\n\n")
                writeStderr("Suggestions:\n")
                writeStderr("  • Remove trailing/leading commas: {a,b} instead of {a,}\n")
                writeStderr("  • Use separate --from flags for different patterns\n")
                Foundation.exit(1)
            } catch {
                writeStderr("❌ Error: Failed to expand pattern '\(pattern)': \(error)\n")
                Foundation.exit(1)
            }
        }
        
        return expandedPatterns
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
                        // Preserve full relative path (industry standard behavior)
                        // Future: --flatten flag could strip pattern prefix
                        results.append((itemPath, relativePath))
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
                writeStderr("❌ Error: Destination '\(path)' exists but is not a directory\n")
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
    ///   - patterns: Array of glob patterns (from field)
    ///   - destination: Destination path (to field)
    ///   - excludePatterns: Exclusion patterns (exclude field)
    ///   - subtreeName: Name of subtree to save mapping to
    ///   - configPath: Path to subtree.yaml
    /// - Returns: true if mapping was saved, false if duplicate detected
    /// - Throws: I/O errors or config errors
    private func saveMappingToConfig(
        patterns: [String],
        destination: String,
        excludePatterns: [String],
        subtreeName: String,
        configPath: String
    ) async throws -> Bool {
        // T093: Construct ExtractionMapping from CLI flags
        // Use single-pattern init for single pattern, multi-pattern for multiple
        let mapping: ExtractionMapping
        if patterns.count == 1 {
            mapping = ExtractionMapping(
                from: patterns[0],
                to: destination,
                exclude: excludePatterns.isEmpty ? nil : excludePatterns
            )
        } else {
            mapping = ExtractionMapping(
                fromPatterns: patterns,
                to: destination,
                exclude: excludePatterns.isEmpty ? nil : excludePatterns
            )
        }
        
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
        
        writeStderr("❌ Error: Cannot overwrite \(count) git-tracked file\(count == 1 ? "" : "s")\n\n")
        writeStderr("Protected files:\n")
        
        // Show all files if <= 20, otherwise show first 5 + count
        if count <= 20 {
            for file in trackedFiles {
                writeStderr("  • \(file)\n")
            }
        } else {
            for file in trackedFiles.prefix(5) {
                writeStderr("  • \(file)\n")
            }
            writeStderr("  ... and \(count - 5) more\n")
        }
        
        writeStderr("\nUse --force to override protection\n")
        Foundation.exit(2)  // System error code for overwrite protection
    }
}
