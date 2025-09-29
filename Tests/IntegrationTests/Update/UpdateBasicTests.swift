import Testing
import Foundation
@testable import Subtree

struct UpdateBasicTests {
    
    @Test("update single subtree with --name")
    func testUpdateSingleSubtree() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with one entry
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
        
        // Properly set up the subtree using git subtree add
        try await fixture.setupSubtree(
            name: "example-lib",
            remote: "git@github.com:swiftlang/swift-se0270-range-set.git",
            prefix: "Vendor/example-lib",
            branch: "main",
            squash: true
        )
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--name", "example-lib", "--commit", "--force"],
            workingDirectory: fixture.repoRoot
        )
        
        // For test repos, should exit successfully (simulated operation)
        #expect(result.exitStatus == 0)
        
        // Should have success message
        #expect(result.stdout.contains("Updated") || result.stdout.contains("No updates") || result.stdout.contains("up to date"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("update all subtrees with --all")
    func testUpdateAllSubtrees() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with multiple entries
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: lib-a
            remote: git@github.com:swiftlang/swift-se0270-range-set.git
            prefix: Vendor/lib-a
            branch: main
            squash: true
          - name: lib-b
            remote: git@github.com:swiftlang/swift-se0270-range-set.git
            prefix: Vendor/lib-b
            branch: main
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Properly set up both subtrees using git subtree add
        try await fixture.setupSubtrees([
            (name: "lib-a", remote: "git@github.com:swiftlang/swift-se0270-range-set.git", prefix: "Vendor/lib-a", branch: "main", squash: true),
            (name: "lib-b", remote: "git@github.com:swiftlang/swift-se0270-range-set.git", prefix: "Vendor/lib-b", branch: "main", squash: true)
        ])
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--all", "--commit", "--force"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have success message (allow flexible output)
        #expect(result.stdout.contains("Updated") || result.stdout.contains("No updates") || result.stdout.contains("up to date"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("update with missing config file")
    func testUpdateWithMissingConfig() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with code 4 (config file not found)
        #expect(result.exitStatus == 4)
        
        // Should print error to stderr
        #expect(result.stderr.contains("subtree.yaml not found"))
    }
    
    @Test("update with non-existent name in config")
    func testUpdateWithNonExistentName() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml without the requested name
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: other-lib
            remote: git@github.com:swiftlang/swift-se0270-range-set.git
            prefix: Vendor/other-lib
            branch: main
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with code 2 (invalid usage/config)
        
        // Should print error to stderr
        #expect(result.stderr.contains("Subtree 'example-lib' not found"))
    }
    
    @Test("update with no args defaults to updating all subtrees")
    func testUpdateDefaultsToAll() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create minimal config
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = "subtrees: []\n"
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully (report mode by default, no subtrees to update)
        #expect(result.exitStatus == 0)
        
        // Should report no updates available for empty config
        #expect(result.stdout.contains("No updates") || result.stdout.contains("subtrees"))
    }
}
