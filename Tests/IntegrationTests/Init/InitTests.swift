import Testing
import Foundation

struct InitTests {
    
    @Test("init creates minimal subtree.yaml")
    func testInitCreatesMinimalConfig() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["init"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should create subtree.yaml file
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        #expect(FileManager.default.fileExists(atPath: configPath.path))
        
        // Should contain minimal config
        let configContent = try String(contentsOf: configPath)
        #expect(configContent.contains("subtrees: []"))
        
        // Should print success message to stdout
        #expect(result.stdout.contains("Created minimal subtree.yaml"))
        
        // Should have no stderr output
        #expect(result.stderr.isEmpty)
    }
    
    @Test("init refuses when file exists without --force")
    func testInitRefusesExistingFile() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Pre-create subtree.yaml
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        try "existing content".write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["init"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with code 2 (invalid usage/config)
        #expect(result.exitStatus == 2)
        
        // Should print error to stderr
        #expect(result.stderr.contains("subtree.yaml already exists"))
        
        // Should not modify existing file
        let configContent = try String(contentsOf: configPath)
        #expect(configContent == "existing content")
    }
    
    @Test("init outside a Git repo exits with code 3")
    func testInitOutsideGitRepo() async throws {
        let fixture = try RepoFixture.createNonGitDir()
        defer { try? fixture.cleanup() }
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["init"],
            workingDirectory: fixture.tempDir
        )
        
        // Should exit with code 3 (git failure)
        #expect(result.exitStatus == 3)
        
        // Should print error to stderr
        #expect(result.stderr.contains("not a git repository"))
    }
}
