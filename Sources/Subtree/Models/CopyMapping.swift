import Foundation

/// A copy mapping for a subtree
public struct CopyMapping: Codable, Sendable {
    public let from: String
    public let to: String
    public let exclude: [String]?
    
    public init(from: String, to: String, exclude: [String]? = nil) {
        self.from = from
        self.to = to
        self.exclude = exclude
    }
}
