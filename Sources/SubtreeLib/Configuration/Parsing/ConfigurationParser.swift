import Foundation
import Yams

/// Parser for subtree.yaml configuration files
///
/// Handles YAML parsing and provides user-friendly error messages via YAMLErrorTranslator.
public enum ConfigurationParser {
    
    /// Parse YAML string into SubtreeConfiguration
    /// - Parameter yaml: YAML content as string
    /// - Returns: Parsed SubtreeConfiguration
    /// - Throws: Error if YAML is invalid or empty (FR-026, FR-028)
    public static func parse(yaml: String) throws -> SubtreeConfiguration {
        // Handle empty/whitespace-only YAML per FR-028
        guard !yaml.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ConfigurationError.emptyFile
        }
        
        do {
            let decoder = YAMLDecoder()
            return try decoder.decode(SubtreeConfiguration.self, from: yaml)
        } catch {
            // Translate YAML parsing errors to user-friendly messages per FR-026
            throw YAMLErrorTranslator.translate(error: error)
        }
    }
    
    /// Parse YAML file at given path
    /// - Parameter path: File path to subtree.yaml
    /// - Returns: Parsed SubtreeConfiguration
    /// - Throws: Error if file doesn't exist (FR-027) or YAML is invalid
    public static func parseFile(at path: String) throws -> SubtreeConfiguration {
        // Check if file exists per FR-027
        guard FileManager.default.fileExists(atPath: path) else {
            throw ConfigurationError.missingFile(path: path)
        }
        
        let yaml = try String(contentsOfFile: path, encoding: .utf8)
        return try parse(yaml: yaml)
    }
}

/// Errors that can occur during configuration parsing
public enum ConfigurationError: Error, CustomStringConvertible {
    case emptyFile
    case missingFile(path: String)
    case yamlSyntaxError(message: String)
    
    public var description: String {
        switch self {
        case .emptyFile:
            return "Configuration file is empty or contains only whitespace"
        case .missingFile(let path):
            return "Configuration file not found at: \(path)"
        case .yamlSyntaxError(let message):
            return message
        }
    }
}
