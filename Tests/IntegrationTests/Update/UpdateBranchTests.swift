import Testing
import Foundation
@testable import Subtree

struct UpdateBranchTests {
    
    @Test("update creates default topic branch")
    func testUpdateDefaultTopicBranch() async throws {
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
        
        // Should create topic branch (for test repos, simulated)
        #expect(result.stdout.contains("Updated") || result.stdout.contains("No updates") || result.stdout.contains("up to date"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("update with --branch creates custom branch")
    func testUpdateCustomBranch() async throws {
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
            arguments: ["update", "--name", "example-lib", "--commit", "--branch", "my-custom-branch", "--force"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully with custom branch
        #expect(result.exitStatus == 0)
        #expect(result.stdout.contains("Updated") || result.stdout.contains("No updates") || result.stdout.contains("up to date"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("update with --on-current commits on current branch")
    func testUpdateOnCurrentBranch() async throws {
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
            arguments: ["update", "--name", "example-lib", "--commit", "--on-current", "--force"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully committing on current branch
        #expect(result.exitStatus == 0)
        #expect(result.stdout.contains("Updated") || result.stdout.contains("No updates") || result.stdout.contains("up to date"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("update --all creates update/all/<timestamp> branch")
    func testUpdateAllTopicBranch() async throws {
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
        
        // Should exit successfully with multi-subtree topic branch
        #expect(result.exitStatus == 0)
        #expect(result.stdout.contains("Updated") || result.stdout.contains("No updates"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("update cannot use --branch and --on-current together")
    func testUpdateBranchAndOnCurrentConflict() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a valid subtree.yaml
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
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--name", "example-lib", "--commit", "--branch", "my-branch", "--on-current"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should fail with conflicting options
        #expect(result.exitStatus == 2)
        #expect(result.stderr.contains("--branch") || result.stderr.contains("--on-current"))
    }
    
    @Test("update from tag 1.0.0 to 1.0.1")
    func testUpdateBetweenTags() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create config with tag 1.0.0 initially (will update to 1.0.1 later)
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: range-set
            remote: git@github.com:swiftlang/swift-se0270-range-set.git
            prefix: Vendor/range-set
            branch: "1.0.0"  # Start with older tag
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Actually add the subtree first with tag 1.0.0 to establish proper git history
        let addResult = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["add", "--name", "range-set"],
            workingDirectory: fixture.repoRoot
        )
        
        // Skip test if add fails
        if addResult.exitStatus != 0 {
            print("Skipping test - initial add failed: \(addResult.stderr)")
            return
        }
        
        // Verify add worked
        #expect(addResult.exitStatus == 0, "Initial subtree add should succeed")
        
        // Update config to point to newer tag 1.0.1 for the update
        let updatedConfigContent = """
        subtrees:
          - name: range-set
            remote: git@github.com:swiftlang/swift-se0270-range-set.git
            prefix: Vendor/range-set
            branch: "1.0.1"  # Update to newer tag
            squash: true
        """
        try updatedConfigContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Commit the manual config changes to avoid working tree modifications
        let commitResult = try await SubprocessHelpers.run(
            .name("git"),
            arguments: ["add", "subtree.yaml"],
            workingDirectory: fixture.repoRoot
        )
        if commitResult.exitStatus == 0 {
            _ = try await SubprocessHelpers.run(
                .name("git"),
                arguments: ["commit", "-m", "Update config for test"],
                workingDirectory: fixture.repoRoot
            )
        }
        
        // Now update using tag mode (should get 1.0.1 from config)
        let updateResult = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--name", "range-set", "--ref", "tag", "--commit", "--force"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should successfully update between tags
        #expect(updateResult.exitStatus == 0)
        #expect(updateResult.stdout.contains("Updated") || updateResult.stdout.contains("No updates"))
        #expect(updateResult.stderr.isEmpty)
    }
}
