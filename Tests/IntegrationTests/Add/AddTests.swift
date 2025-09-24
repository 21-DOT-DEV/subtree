import Testing
import Foundation

struct AddTests {
    
    @Test("add with valid config and name")
    func testAddWithValidConfig() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with one entry
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: example-lib
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/example-lib
            branch: master
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["add", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have called git subtree add (we can check if the directory exists)
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        #expect(FileManager.default.fileExists(atPath: subtreePath.path))
        
        // Should have success message
        #expect(result.stdout.contains("Added subtree"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("add with missing config file")
    func testAddWithMissingConfig() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["add", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with code 4 (config file not found)
        #expect(result.exitStatus == 4)
        
        // Should print error to stderr
        #expect(result.stderr.contains("subtree.yaml not found"))
    }
    
    @Test("add with non-existent name in config")
    func testAddWithNonExistentName() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml without the requested name
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: other-lib
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/other-lib
            branch: master
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["add", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with code 2 (invalid usage - missing remote)
        #expect(result.exitStatus == 2)
        
        // Should print error about missing remote URL (new behavior with smart defaults)
        #expect(result.stderr.contains("Remote URL is required"))
    }
    
    @Test("add with --all flag")
    func testAddWithAllFlag() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with multiple entries
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: example-lib
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/example-lib
            branch: master
            squash: true
          - name: other-lib
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/other-lib
            branch: master
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["add", "--all"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have created both subtrees
        let subtreePath1 = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        let subtreePath2 = fixture.repoRoot.appendingPathComponent("Vendor/other-lib")
        #expect(FileManager.default.fileExists(atPath: subtreePath1.path))
        #expect(FileManager.default.fileExists(atPath: subtreePath2.path))
        
        // Should have success message mentioning multiple subtrees
        #expect(result.stdout.contains("Added 2 subtrees"))
        #expect(result.stderr.isEmpty)
    }
}
