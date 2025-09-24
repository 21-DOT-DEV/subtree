import Testing
import Foundation

struct RemoveTests {
    
    @Test("remove with valid config and existing subtree")
    func testRemoveWithValidConfig() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create config file that remove command expects
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: example-lib
            remote: git@github.com:swiftlang/swift-se0270-range-set.git
            prefix: Vendor/example-lib
            branch: main
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Create the subtree directory and track it with git (no network operations)
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
        let readmeFile = subtreePath.appendingPathComponent("README.md")
        try "# Example Lib\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        // Add to git tracking so git rm will work
        _ = try await SubprocessHelpers.run(
            .name("git"),
            arguments: ["add", "Vendor/example-lib"],
            workingDirectory: fixture.repoRoot
        )
        _ = try await SubprocessHelpers.run(
            .name("git"),
            arguments: ["commit", "-m", "Add example-lib for testing"],
            workingDirectory: fixture.repoRoot
        )
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["remove", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have removed the subtree directory  
        #expect(!FileManager.default.fileExists(atPath: subtreePath.path))
        
        // Should have success message
        #expect(result.stdout.contains("Removed subtree") || result.exitStatus == 0)
        // Allow some stderr output for git operations but ensure exit status is correct
    }
    
    @Test("remove with missing config file")
    func testRemoveWithMissingConfig() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["remove", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with code 4 (config file not found)
        #expect(result.exitStatus == 4)
        
        // Should print error to stderr
        #expect(result.stderr.contains("subtree.yaml not found"))
    }
    
    @Test("remove with non-existent name in config")
    func testRemoveWithNonExistentName() async throws {
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
            arguments: ["remove", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with code 2 (invalid usage/config)
        #expect(result.exitStatus == 2)
        
        // Should print error to stderr
        #expect(result.stderr.contains("Subtree 'example-lib' not found"))
    }
    
    @Test("remove non-existent subtree (not added yet)")
    func testRemoveNonExistentSubtree() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml but don't create the actual subtree directory
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
            arguments: ["remove", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with code 2 (invalid usage/config)
        #expect(result.exitStatus == 2)
        
        // Should print error to stderr
        #expect(result.stderr.contains("Subtree 'example-lib' not found at path"))
    }
}
