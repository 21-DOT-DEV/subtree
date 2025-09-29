/// A single subtree entry in the configuration
public struct SubtreeEntry: Codable, Sendable {
    public let name: String
    public let remote: String
    public let prefix: String
    public let branch: String
    public let squash: Bool?
    public let commit: String?
    public let copies: [CopyMapping]?
    public let update: UpdatePolicy?
    
    public init(
        name: String,
        remote: String,
        prefix: String,
        branch: String,
        squash: Bool? = true,
        commit: String? = nil,
        copies: [CopyMapping]? = nil,
        update: UpdatePolicy? = nil
    ) {
        self.name = name
        self.remote = remote
        self.prefix = prefix
        self.branch = branch
        self.squash = squash
        self.commit = commit
        self.copies = copies
        self.update = update
    }
}
