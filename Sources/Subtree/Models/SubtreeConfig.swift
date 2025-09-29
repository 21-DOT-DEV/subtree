import Foundation

/// The root configuration structure for subtree.yaml
public struct SubtreeConfig: Codable, Sendable {
    public var subtrees: [SubtreeEntry]
    
    public init(subtrees: [SubtreeEntry] = []) {
        self.subtrees = subtrees
    }
    
    /// Create a minimal configuration with no subtrees
    public static let minimal = SubtreeConfig(subtrees: [])
}
