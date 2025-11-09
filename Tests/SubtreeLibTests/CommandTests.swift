import Testing
@testable import SubtreeLib

/// Unit tests for CLI commands
///
/// These tests verify individual command behavior by importing SubtreeLib directly.
@Suite("Command Tests")
struct CommandTests {
    
    @Test("SubtreeCommand has correct configuration")
    func testSubtreeCommandConfiguration() {
        // Verify command name
        #expect(SubtreeCommand.configuration.commandName == "subtree")
        
        // Verify abstract exists and describes the tool
        let abstract = SubtreeCommand.configuration.abstract
        #expect(abstract.contains("git subtree") || abstract.contains("subtree"))
        #expect(!abstract.isEmpty)
        
        // Verify version is provided
        // Since we set version: "0.1.0-bootstrap" in the configuration,
        // we just verify the configuration has this set
        let config = SubtreeCommand.configuration
        #expect(!config.version.isEmpty)
    }
    
    @Test("SubtreeCommand can be instantiated")
    func testSubtreeCommandInstantiation() {
        // Verify the command struct exists
        let _ = SubtreeCommand()
        // If we get here without crashing, test passes
    }
}
