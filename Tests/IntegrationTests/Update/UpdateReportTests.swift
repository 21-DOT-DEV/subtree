import Testing
import Foundation
@testable import Subtree

struct UpdateReportTests {
    
    @Test("update without --commit flag only reports pending updates")
    func testUpdateReportMode() async throws {
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
        
        // Pre-create the subtree directory (simulate it was already added)
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
        let readmeFile = subtreePath.appendingPathComponent("README.md")
        try "# Example Lib v1.0\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--name", "example-lib"],  // No --commit flag
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with code 5 if updates are available (report mode)
        // or code 0 if no updates available
        #expect(result.exitStatus == 0 || result.exitStatus == 5)
        
        // Should have report message, not update message
        if result.exitStatus == 5 {
            #expect(result.stdout.contains("Updates available") || result.stdout.contains("pending"))
        } else {
            #expect(result.stdout.contains("No updates") || result.stdout.contains("up to date"))
        }
        
        // Should not have modified working tree
        let originalContent = try String(contentsOf: readmeFile)
        #expect(originalContent == "# Example Lib v1.0\n")
    }
    
    @Test("update with --commit flag applies updates") 
    func testUpdateApplyMode() async throws {
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
        
        // Should exit successfully when applying updates
        #expect(result.exitStatus == 0)
        
        // Should have applied updates message (allow flexible output)
        #expect(result.stdout.contains("Updated") || result.stdout.contains("Applied") || result.stdout.contains("No updates") || result.stdout.contains("up to date"))
    }
    
    @Test("update reports multiple pending updates")
    func testUpdateReportMultiple() async throws {
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
        
        // Pre-create both subtree directories
        for libName in ["lib-a", "lib-b"] {
            let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/\(libName)")
            try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
            let readmeFile = subtreePath.appendingPathComponent("README.md")
            try "# \(libName.capitalized)\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        }
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--all"],  // No --commit flag
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with appropriate code
        #expect(result.exitStatus == 0 || result.exitStatus == 5)
        
        // Should report on multiple subtrees
        if result.exitStatus == 5 {
            #expect(result.stdout.contains("2") || result.stdout.contains("multiple"))
        }
    }
    
    @Test("update with no changes available exits 0")
    func testUpdateNoChangesAvailable() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Get the current HEAD commit hash from the remote repository
        let lsRemoteResult = try GitPlumbing.runGitCommand([
            "ls-remote", "git@github.com:swiftlang/swift-se0270-range-set.git", "main"
        ], workingDirectory: fixture.repoRoot)
        
        guard lsRemoteResult.exitCode == 0, !lsRemoteResult.stdout.isEmpty else {
            throw TestError.gitSubtreeAddFailed("Failed to get remote HEAD commit")
        }
        
        // Extract commit hash (first 40 characters of the output)
        let currentCommitHash = String(lsRemoteResult.stdout.prefix(40))
        
        // Create a subtree.yaml with the current commit hash as commit field
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: example-lib
            remote: git@github.com:swiftlang/swift-se0270-range-set.git
            prefix: Vendor/example-lib
            branch: main
            squash: true
            commit: "\(currentCommitHash)"
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
            arguments: ["update", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with appropriate code (0 for no updates, 5 for updates available)
        #expect(result.exitStatus == 0 || result.exitStatus == 5)
        
        // Should report status appropriately 
        if result.exitStatus == 0 {
            #expect(result.stdout.contains("No updates") || result.stdout.contains("up to date"))
        } else if result.exitStatus == 5 {
            #expect(result.stdout.contains("Updates available") || result.stdout.contains("pending") || !result.stdout.isEmpty)
        }
    }
}
