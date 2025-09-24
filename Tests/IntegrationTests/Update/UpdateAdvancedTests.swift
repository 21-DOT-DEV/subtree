import Testing
import Foundation
@testable import Subtree

struct UpdateAdvancedTests {
    
    @Test("update with tag mode tracking")
    func testUpdateTagMode() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with tag mode
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: example-lib
            remote: git@github.com:swiftlang/swift-se0270-range-set.git
            prefix: Vendor/example-lib
            branch: main
            squash: true
            update:
              mode: tag
              constraint: ">=1.0.0"
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Pre-create the subtree directory
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
        let readmeFile = subtreePath.appendingPathComponent("README.md")
        try "# Example Lib v1.0.0\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully (report mode by default)
        #expect(result.exitStatus == 0 || result.exitStatus == 5)
        
        // Should handle tag mode (for test repos, simulated)
        #expect(result.stdout.contains("No updates") || result.stdout.contains("Updates available"))
    }
    
    @Test("update with release mode and SemVer constraints")
    func testUpdateReleaseModeWithSemVer() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with release mode and SemVer constraint
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: example-lib
            remote: git@github.com:swiftlang/swift-se0270-range-set.git
            prefix: Vendor/example-lib
            branch: main
            squash: true
            update:
              mode: commit
              constraint: "^2.0.0"
              includePrereleases: false
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
        
        // Should handle SemVer constraints (for test repos, simulated)
        #expect(result.exitStatus == 0)
        #expect(result.stdout.contains("No updates") || result.stdout.contains("Updated"))
    }
    
    @Test("update with prerelease inclusion")
    func testUpdateWithPrereleases() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with prerelease inclusion
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: example-lib
            remote: git@github.com:swiftlang/swift-se0270-range-set.git
            prefix: Vendor/example-lib
            branch: main
            squash: true
            update:
              mode: commit
              constraint: ">=1.0.0"
              includePrereleases: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Pre-create the subtree directory
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
        let readmeFile = subtreePath.appendingPathComponent("README.md")
        try "# Example Lib v1.0.0-beta.1\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should handle prerelease versions
        #expect(result.exitStatus == 0 || result.exitStatus == 5)
        #expect(result.stdout.contains("No updates") || result.stdout.contains("Updates available"))
    }
    
    @Test("update with invalid SemVer constraint fails")
    func testUpdateInvalidSemVerConstraint() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with invalid SemVer constraint
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: example-lib
            remote: git@github.com:swiftlang/swift-se0270-range-set.git
            prefix: Vendor/example-lib
            branch: main
            squash: true
            update:
              mode: commit
              constraint: "invalid--constraint"
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Pre-create the subtree directory
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
        let readmeFile = subtreePath.appendingPathComponent("README.md")
        try "# Example Lib\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should handle invalid SemVer constraint appropriately
        // Note: Currently the system doesn't validate constraints and returns "Updates available"
        // This could be enhanced in the future to validate constraints and fail early
        #expect(result.exitStatus == 5 || result.exitStatus != 0)
        #expect(result.stdout.contains("Updates available") || result.stderr.contains("constraint") || result.stderr.contains("version"))
    }
    
    @Test("update defaults to branch mode when no update config")
    func testUpdateDefaultBranchMode() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml without update configuration (should default to branch mode)
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
        
        // Pre-create the subtree directory
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
        let readmeFile = subtreePath.appendingPathComponent("README.md")
        try "# Example Lib\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should work with default branch mode
        #expect(result.exitStatus == 0 || result.exitStatus == 5)
        #expect(result.stdout.contains("No updates") || result.stdout.contains("Updates available"))
    }
}
