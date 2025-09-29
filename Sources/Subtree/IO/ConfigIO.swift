import Foundation
import Yams

/// Utilities for reading and writing subtree configuration files
public enum ConfigIO {
    
    /// Get the path to the subtree.yaml config file at the given repository root
    public static func configPath(at root: URL) -> URL {
        return root.appendingPathComponent("subtree.yaml")
    }
    
    /// Check if a config file exists at the given path
    public static func configExists(at path: URL) -> Bool {
        return FileManager.default.fileExists(atPath: path.path)
    }
    
    /// Write a minimal configuration to the given path
    public static func writeMinimalConfig(to path: URL) throws {
        let config = SubtreeConfig.minimal
        let yamlString = try YAMLEncoder().encode(config)
        try yamlString.write(to: path, atomically: true, encoding: .utf8)
    }
    
    /// Read configuration from the given path
    public static func readConfig(from path: URL) throws -> SubtreeConfig {
        let yamlString = try String(contentsOf: path, encoding: .utf8)
        return try YAMLDecoder().decode(SubtreeConfig.self, from: yamlString)
    }
    
    /// Update a specific subtree's commit field in the configuration
    public static func updateSubtreeCommit(
        at configPath: URL,
        subtreeName: String,
        commitHash: String
    ) throws {
        // Read current config
        var config = try readConfig(from: configPath)
        
        // Find and update the subtree
        guard let index = config.subtrees.firstIndex(where: { $0.name == subtreeName }) else {
            throw ConfigError.subtreeNotFound(subtreeName)
        }
        
        // Create updated subtree entry
        let currentSubtree = config.subtrees[index]
        let updatedSubtree = SubtreeEntry(
            name: currentSubtree.name,
            remote: currentSubtree.remote,
            prefix: currentSubtree.prefix,
            branch: currentSubtree.branch,
            squash: currentSubtree.squash,
            commit: commitHash,
            copies: currentSubtree.copies,
            update: currentSubtree.update
        )
        
        // Replace the subtree in the config
        config.subtrees[index] = updatedSubtree
        
        // Write back to file atomically
        let yamlString = try YAMLEncoder().encode(config)
        try yamlString.write(to: configPath, atomically: true, encoding: .utf8)
    }
    
    /// Add a new subtree entry to the configuration
    public static func addSubtreeEntry(
        at configPath: URL,
        subtree: SubtreeEntry
    ) throws {
        // Read current config
        var config = try readConfig(from: configPath)
        
        // Check if subtree with same name already exists
        if config.subtrees.contains(where: { $0.name == subtree.name }) {
            throw ConfigError.subtreeAlreadyExists(subtree.name)
        }
        
        // Add the new subtree
        config.subtrees.append(subtree)
        
        // Write back to file atomically
        let yamlString = try YAMLEncoder().encode(config)
        try yamlString.write(to: configPath, atomically: true, encoding: .utf8)
    }
    
    /// Remove a subtree entry from the configuration
    public static func removeSubtreeEntry(
        at configPath: URL,
        subtreeName: String
    ) throws {
        // Read current config
        var config = try readConfig(from: configPath)
        
        // Find and remove the subtree
        guard let index = config.subtrees.firstIndex(where: { $0.name == subtreeName }) else {
            throw ConfigError.subtreeNotFound(subtreeName)
        }
        
        config.subtrees.remove(at: index)
        
        // Write back to file atomically
        let yamlString = try YAMLEncoder().encode(config)
        try yamlString.write(to: configPath, atomically: true, encoding: .utf8)
    }
}

/// Errors that can occur during config operations
public enum ConfigError: Error {
    case subtreeNotFound(String)
    case subtreeAlreadyExists(String)
    case invalidYAML(String)
}
