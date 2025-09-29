import Foundation

/// Update policy for a subtree
public struct UpdatePolicy: Codable, Sendable {
    public let mode: UpdateMode
    public let constraint: String?
    public let includePrereleases: Bool?
    
    public init(
        mode: UpdateMode = .branch,
        constraint: String? = nil,
        includePrereleases: Bool? = nil
    ) {
        self.mode = mode
        self.constraint = constraint
        self.includePrereleases = includePrereleases
    }
}

/// Update modes supported by subtree
public enum UpdateMode: String, Codable, CaseIterable, Sendable {
    case branch = "branch"
    case tag = "tag"
    case commit = "commit"
}
