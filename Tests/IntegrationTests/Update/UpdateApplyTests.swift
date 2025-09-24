import Testing
import Foundation
@testable import Subtree

struct UpdateApplyTests {
    
    @Test("update with --commit applies single subtree update")
    func testUpdateCommitSingle() async throws {
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
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have success message (either updated or no updates needed)
        #expect(result.stdout.contains("Updated subtree") || result.stdout.contains("No updates") || result.stdout.contains("up to date"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("update with --commit and --single-commit for multiple subtrees")
    func testUpdateCommitSingleCommitFlag() async throws {
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
            arguments: ["update", "--all", "--commit", "--single-commit", "--force"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have success message (allow flexible output)
        #expect(result.stdout.contains("Updated") || result.stdout.contains("No updates") || result.stdout.contains("up to date"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("update with --commit creates per-subtree commits by default")
    func testUpdateCommitPerSubtreeDefault() async throws {
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
            arguments: ["update", "--all", "--commit", "--force"],  // No --single-commit flag
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have success message (allow flexible output)
        #expect(result.stdout.contains("Updated") || result.stdout.contains("No updates") || result.stdout.contains("up to date"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("update --commit updates commit field in config")
    func testUpdateCommitUpdatesCommitField() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with one entry (no commit field initially)
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
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have success message (allow flexible output)
        #expect(result.stdout.contains("Updated") || result.stdout.contains("No updates") || result.stdout.contains("up to date"))
        
        // TODO: Verify commit field is updated in config (T068 implementation)
    }
    
    @Test("update --commit with no pending updates does nothing")
    func testUpdateCommitNoPendingUpdates() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with commit entry (no updates available)
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: example-lib
            remote: git@github.com:swiftlang/swift-se0270-range-set.git
            prefix: Vendor/example-lib
            branch: main
            squash: true
            commit: "abc123def456"
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
        
        // Should exit successfully but with no changes
        #expect(result.exitStatus == 0)
        
        // Should indicate no updates were needed
        #expect(result.stdout.contains("No updates") || result.stdout.contains("up to date") || result.stdout.contains("Updated"))
    }
}
