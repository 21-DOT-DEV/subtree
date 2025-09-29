import ArgumentParser
import Foundation

struct SubtreeCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "subtree",
        abstract: "A Swift CLI for managing git subtrees with declarative configuration",
        discussion: """
        Subtree simplifies managing git subtree operations using a declarative subtree.yaml 
        configuration file at your repository root.
        """,
        version: "0.1.0",
        subcommands: [
            InitCommand.self,
            AddCommand.self,
            RemoveCommand.self,
            UpdateCommand.self,
            ExtractCommand.self,
            ValidateCommand.self,
        ],
        defaultSubcommand: nil
    )
    
    func run() throws {
        // Print help when no arguments provided
        print(SubtreeCLI.helpMessage())
    }
}
