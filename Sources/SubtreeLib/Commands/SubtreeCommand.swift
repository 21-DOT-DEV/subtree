import ArgumentParser

/// Root command for the subtree CLI
///
/// This is the entry point for all subtree operations. Subcommands will be added
/// in subsequent phases as they are implemented.
public struct SubtreeCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "subtree",
        abstract: "Manage git subtrees with declarative YAML configuration",
        discussion: """
            Subtree provides a declarative way to manage git subtrees using a
            subtree.yaml configuration file. It simplifies common subtree operations
            like adding, updating, and removing subtrees from your repository.
            """,
        version: "0.1.0-bootstrap",
        subcommands: [
            InitCommand.self,
            AddCommand.self,
            UpdateCommand.self,
            RemoveCommand.self,
            ExtractCommand.self,
            ValidateCommand.self
        ]
    )
    
    public init() {}
}
