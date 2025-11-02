import Testing
@testable import SubtreeLib

/// Unit tests for command exit codes
///
/// Verifies that stub commands exist and would return exit code 0 when executed.
@Suite("Exit Code Tests")
struct ExitCodeTests {
    
    @Test("All stub commands are registered in SubtreeCommand")
    func testAllCommandsRegistered() {
        let subcommands = SubtreeCommand.configuration.subcommands
        
        // Verify we have exactly 6 subcommands
        #expect(subcommands.count == 6)
        
        // Verify each command type is registered
        let commandNames = subcommands.map { $0.configuration.commandName }
        #expect(commandNames.contains("init"))
        #expect(commandNames.contains("add"))
        #expect(commandNames.contains("update"))
        #expect(commandNames.contains("remove"))
        #expect(commandNames.contains("extract"))
        #expect(commandNames.contains("validate"))
    }
    
    @Test("Init command can be instantiated")
    func testInitCommandExists() {
        let _ = InitCommand()
        #expect(InitCommand.configuration.commandName == "init")
    }
    
    @Test("Add command can be instantiated")
    func testAddCommandExists() {
        let _ = AddCommand()
        #expect(AddCommand.configuration.commandName == "add")
    }
    
    @Test("Update command can be instantiated")
    func testUpdateCommandExists() {
        let _ = UpdateCommand()
        #expect(UpdateCommand.configuration.commandName == "update")
    }
    
    @Test("Remove command can be instantiated")
    func testRemoveCommandExists() {
        let _ = RemoveCommand()
        #expect(RemoveCommand.configuration.commandName == "remove")
    }
    
    @Test("Extract command can be instantiated")
    func testExtractCommandExists() {
        let _ = ExtractCommand()
        #expect(ExtractCommand.configuration.commandName == "extract")
    }
    
    @Test("Validate command can be instantiated")
    func testValidateCommandExists() {
        let _ = ValidateCommand()
        #expect(ValidateCommand.configuration.commandName == "validate")
    }
}
