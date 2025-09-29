import Testing
import Foundation
@testable import Subtree

struct UpdateNetworkTests {
    
    @Test("update with unreachable remote exits 3", .disabled("Network test - needs real git operations"))
    func testUpdateWithUnreachableRemote() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create config with unreachable remote (localhost on unused port - fails fast)
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: unreachable-lib
            remote: http://localhost:19999/nonexistent-repo.git
            prefix: Vendor/unreachable-lib
            branch: main
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Pre-create the subtree directory
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/unreachable-lib")
        try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
        let readmeFile = subtreePath.appendingPathComponent("README.md")
        try "# Unreachable Lib\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--name", "unreachable-lib", "--commit"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with code 3 (git failure due to unreachable remote)
        #expect(result.exitStatus == 3)
        
        // Should print git error to stderr
        #expect(result.stderr.contains("git fetch failed") || result.stderr.contains("Connection refused") || result.stderr.contains("Could not resolve host"))
    }
    
    @Test("git fetch operations are attempted for real repos", .disabled("Network test - needs real git operations"))
    func testGitFetchForRealRepos() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create config with a smaller, more reasonable test repo
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: test-repo
            remote: https://github.com/octocat/Hello-World.git
            prefix: Vendor/hello-world
            branch: main
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Pre-create the subtree directory
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/hello-world")
        try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
        let readmeFile = subtreePath.appendingPathComponent("README")
        try "Hello World!\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        let startTime = Date()
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--name", "test-repo", "--commit"],
            workingDirectory: fixture.repoRoot
        )
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Should complete within reasonable time (60 seconds max)
        #expect(elapsed < 60.0, "Update should complete within reasonable time")
        
        // This test may pass or fail depending on network connectivity
        // The important thing is that it attempts real git operations
        if result.exitStatus != 0 {
            // If it fails, should be git-related error, not command not found
            #expect(!result.stderr.contains("command not found"))
            #expect(!result.stderr.contains("Unknown option"))
        } else {
            // If it succeeds, should have success message
            #expect(result.stdout.contains("Updated subtree"))
        }
    }
    
    @Test("update with invalid git URL format", .disabled("Network test - needs real git operations"))
    func testUpdateWithInvalidURL() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create config with invalid URL format that should fail quickly
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: invalid-url
            remote: not-a-valid-url
            prefix: Vendor/invalid
            branch: main
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Pre-create the subtree directory
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/invalid")
        try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
        let readmeFile = subtreePath.appendingPathComponent("README.md")
        try "# Invalid URL Test\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        let startTime = Date()
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--name", "invalid-url", "--commit"],
            workingDirectory: fixture.repoRoot
        )
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Should fail quickly (within 10 seconds)
        #expect(elapsed < 10.0, "Invalid URL should fail quickly")
        
        // Should exit with error code for invalid git remote
        #expect(result.exitStatus == 3)
        
        // Should have meaningful error message
        #expect(result.stderr.contains("git fetch failed") || result.stderr.contains("not appear to be a git repository"))
    }
}
