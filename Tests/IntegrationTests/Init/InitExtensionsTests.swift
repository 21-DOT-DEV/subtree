import Testing
import Foundation
@testable import Subtree

struct InitExtensionsTests {
    
    
    @Test("init --interactive prompts for configuration")
    func testInitInteractiveMode() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // For testing, we'll simulate interactive mode (actual implementation would use stdin/stdout)
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["init", "--interactive"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should show interactive prompts in output
        #expect(result.stdout.contains("Interactive") || result.stdout.contains("configuration"))
        #expect(result.stderr.isEmpty)
        
        // Should have created a config file
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        #expect(FileManager.default.fileExists(atPath: configPath.path))
    }
    
    
    
    @Test("init --interactive with existing config fails without --force")
    func testInitInteractiveExistingConfigFails() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create existing config file
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        try "subtrees: []\n".write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["init", "--interactive"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with error code 2 (invalid usage - file exists)
        #expect(result.exitStatus == 2)
        
        // Should report error to stderr
        #expect(result.stderr.contains("already exists") || result.stderr.contains("Use --force"))
    }
    
}
