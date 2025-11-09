import Testing
import SystemPackage

/// Integration tests for the Subtree CLI
///
/// These tests execute the actual CLI binary and verify end-to-end behavior.
/// Tests use the TestHarness to run commands and validate outputs.
@Suite("Subtree Integration Tests")
struct SubtreeIntegrationTests {
    let harness: TestHarness
    
    init() {
        self.harness = TestHarness()
    }
    
    @Test("subtree --help displays help text and exits with code 0")
    func testHelpFlag() async throws {
        let result = try await harness.run(arguments: ["--help"])
        
        // Verify exit code is 0 (success)
        #expect(result.exitCode == 0)
        
        // Verify help text contains expected content
        #expect(result.stdout.contains("OVERVIEW") || result.stdout.contains("USAGE"))
        #expect(result.stdout.contains("subtree"))
        
        // Verify command list or description is shown
        #expect(result.stdout.contains("--help") || result.stdout.contains("Show help"))
    }
    
    @Test("subtree with no arguments shows help")
    func testNoArguments() async throws {
        let result = try await harness.run(arguments: [])
        
        // Should show help and exit with code 0
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("USAGE") || result.stdout.contains("OVERVIEW"))
    }
    
    @Test("subtree add requires --remote argument")
    func testAddRequiresRemote() async throws {
        let result = try await harness.run(arguments: ["add"])
        // ArgumentParser returns exit code 64 for missing required arguments
        #expect(result.exitCode == 64)
        #expect(result.stderr.contains("--remote"))
    }
    
    @Test("subtree update requires name or --all flag")
    func testUpdateRequiresNameOrAll() async throws {
        let result = try await harness.run(arguments: ["update"])
        // Custom validation returns exit code 1 for missing name/--all
        #expect(result.exitCode == 1)
        #expect(result.stderr.contains("name") || result.stderr.contains("--all") || result.stderr.contains("Must specify"))
    }
    
    @Test("subtree remove requires name argument")
    func testRemoveRequiresName() async throws {
        let result = try await harness.run(arguments: ["remove"])
        // ArgumentParser returns 64 (EX_USAGE) for missing required arguments
        #expect(result.exitCode == 64)
        #expect(result.stderr.contains("name") || result.stderr.contains("Missing expected argument"))
    }
    
    @Test("subtree extract requires --name or --all")
    func testExtractRequiresNameOrAll() async throws {
        let result = try await harness.run(arguments: ["extract"])
        #expect(result.exitCode == 1)
        #expect(result.stderr.contains("--name") || result.stderr.contains("--all"))
    }
    
    @Test("subtree validate stub exits with code 0")
    func testValidateStub() async throws {
        let result = try await harness.run(arguments: ["validate"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("not yet implemented"))
    }
    
    @Test("invalid command returns non-zero exit code")
    func testInvalidCommand() async throws {
        let result = try await harness.run(arguments: ["invalid-command"])
        #expect(result.exitCode != 0)
        #expect(result.stderr.contains("Error") || result.stderr.contains("Unknown"))
    }
}
