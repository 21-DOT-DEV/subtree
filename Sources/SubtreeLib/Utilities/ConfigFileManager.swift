import Foundation
import Yams

// T016: Define SubtreeConfig struct conforming to Codable
/// Root configuration structure for subtree.yaml
/// For init command, we only need the empty container - no entries yet
struct MinimalConfig: Codable {
    let subtrees: [String]  // Empty array for minimal config
    
    init() {
        self.subtrees = []
    }
}

/// Utilities for managing subtree.yaml configuration files
public enum ConfigFileManager {
    
    // T017: Implement generateMinimalConfig() using Yams encoder with header comment
    /// Generate minimal valid subtree.yaml content
    /// - Returns: YAML string with header comment and empty subtrees array
    /// - Throws: Error if YAML encoding fails
    public static func generateMinimalConfig() throws -> String {
        let config = MinimalConfig()
        let yamlContent = try YAMLEncoder().encode(config)
        let header = "# Managed by subtree CLI - https://github.com/21-DOT-DEV/subtree\n"
        return header + yamlContent
    }
    
    // T018: Implement configPath(gitRoot:) function
    /// Construct the path to subtree.yaml for a given git repository root
    /// - Parameter gitRoot: Absolute path to git repository root
    /// - Returns: Absolute path to subtree.yaml file
    public static func configPath(gitRoot: String) -> String {
        return "\(gitRoot)/subtree.yaml"
    }
    
    // T019/T070/T072/T075: Implement createAtomically with comprehensive error handling
    /// Create a file atomically using temporary file and rename
    /// - Parameters:
    ///   - path: Absolute path where file should be created
    ///   - content: Content to write to file
    /// - Throws: Error if file creation fails
    public static func createAtomically(at path: String, content: String) async throws {
        // T074: UUID-based temp files prevent concurrent corruption
        let tempPath = "\(path).tmp.\(UUID().uuidString)"
        let fileManager = FileManager.default
        
        do {
            // T070/T072: Write to temporary file with error handling
            try content.write(toFile: tempPath, atomically: true, encoding: .utf8)
            
            // Atomic rename (overwrites if exists)
            // Remove existing file if present (for atomic overwrite)
            if fileManager.fileExists(atPath: path) {
                try fileManager.removeItem(atPath: path)
            }
            
            // Atomic move
            try fileManager.moveItem(atPath: tempPath, toPath: path)
            
        } catch let error as NSError {
            // T075: Clean up temp file on error
            try? fileManager.removeItem(atPath: tempPath)
            
            // T070: Re-throw with context for better error messages
            // The error will be caught and reported by InitCommand
            throw error
        }
    }
    
    // T020: Implement exists(at:) file existence check
    /// Check if a file exists at the given path
    /// - Parameter path: Absolute path to check
    /// - Returns: true if file exists, false otherwise
    public static func exists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    /// Write a SubtreeConfiguration to file atomically
    /// - Parameters:
    ///   - config: The configuration to write
    ///   - path: Absolute path where file should be written
    /// - Throws: Error if serialization or writing fails
    public static func writeConfig(_ config: SubtreeConfiguration, to path: String) async throws {
        // Serialize config to YAML
        let yamlContent = try YAMLEncoder().encode(config)
        
        // Add header comment
        let header = "# Managed by subtree CLI - https://github.com/21-DOT-DEV/subtree\n"
        let fullContent = header + yamlContent
        
        // Write atomically
        try await createAtomically(at: path, content: fullContent)
    }
    
    /// Load a SubtreeConfiguration from file (008-extract-command)
    /// - Parameter path: Absolute path to config file
    /// - Returns: Parsed configuration
    /// - Throws: Error if file doesn't exist or parsing fails
    public static func loadConfig(from path: String) async throws -> SubtreeConfiguration {
        let yamlContent = try String(contentsOfFile: path, encoding: .utf8)
        return try YAMLDecoder().decode(SubtreeConfiguration.self, from: yamlContent)
    }
    
    /// Append an extraction mapping to a subtree's configuration (008-extract-command)
    ///
    /// This method:
    /// 1. Loads the current config
    /// 2. Finds the target subtree by name (case-insensitive)
    /// 3. Appends the extraction to the subtree's extractions array
    /// 4. Writes the updated config atomically
    ///
    /// - Parameters:
    ///   - extraction: The extraction mapping to append
    ///   - subtreeName: Name of the subtree (case-insensitive)
    ///   - configPath: Path to subtree.yaml
    /// - Throws: SubtreeValidationError if subtree not found, or I/O errors
    public static func appendExtraction(
        _ extraction: ExtractionMapping,
        to subtreeName: String,
        in configPath: String
    ) async throws {
        // Load current config
        let config = try await loadConfig(from: configPath)
        
        // Find the subtree (case-insensitive, whitespace-trimmed)
        let normalizedName = subtreeName.normalized()
        guard let subtreeIndex = config.subtrees.firstIndex(where: {
            $0.name.normalized().matchesCaseInsensitive(normalizedName)
        }) else {
            throw SubtreeValidationError.subtreeNotFound(subtreeName)
        }
        
        // Get the current subtree entry
        let subtree = config.subtrees[subtreeIndex]
        
        // Append to extractions array (create if nil)
        var extractions = subtree.extractions ?? []
        extractions.append(extraction)
        
        // Create updated subtree with new extractions
        let updatedSubtree = SubtreeEntry(
            name: subtree.name,
            remote: subtree.remote,
            prefix: subtree.prefix,
            commit: subtree.commit,
            tag: subtree.tag,
            branch: subtree.branch,
            squash: subtree.squash,
            extracts: subtree.extracts,
            extractions: extractions
        )
        
        // Create new subtrees array with the updated entry
        var updatedSubtrees = config.subtrees
        updatedSubtrees[subtreeIndex] = updatedSubtree
        
        // Create new config with updated subtrees
        let updatedConfig = SubtreeConfiguration(subtrees: updatedSubtrees)
        
        // Write back atomically
        try await writeConfig(updatedConfig, to: configPath)
    }
}
