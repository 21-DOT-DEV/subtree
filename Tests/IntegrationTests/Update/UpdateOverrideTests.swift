import Testing
import Foundation
@testable import Subtree

struct UpdateOverrideTests {
    
    @Test("update with --mode override")
    func testUpdateModeOverride() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with branch mode
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: example-lib
            remote: git@github.com:swiftlang/swift-se0270-range-set.git
            prefix: Vendor/example-lib
            branch: main
            squash: true
            update:
              mode: branch
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Pre-create the subtree directory
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
        let readmeFile = subtreePath.appendingPathComponent("README.md")
        try "# Example Lib v1.0.0\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--name", "example-lib", "--ref", "commit"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should accept mode override
        #expect(result.exitStatus == 0 || result.exitStatus == 5)
        #expect(result.stdout.contains("No updates") || result.stdout.contains("Updates available"))
    }
    
    @Test("update with --constraint override")
    func testUpdateConstraintOverride() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with release mode but no constraint
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
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Pre-create the subtree directory
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
        let readmeFile = subtreePath.appendingPathComponent("README.md")
        try "# Example Lib v2.0.0\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--name", "example-lib", "--constraint", "^2.0.0"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should accept constraint override
        #expect(result.exitStatus == 0 || result.exitStatus == 5)
        #expect(result.stdout.contains("No updates") || result.stdout.contains("Updates available"))
    }
    
    @Test("update with --include-prereleases override")
    func testUpdateIncludePrereleasesOverride() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with prereleases disabled
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
              includePrereleases: false
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Pre-create the subtree directory
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
        let readmeFile = subtreePath.appendingPathComponent("README.md")
        try "# Example Lib v1.0.0-beta.1\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["update", "--name", "example-lib", "--include-prereleases"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should accept prerelease override
        #expect(result.exitStatus == 0 || result.exitStatus == 5)
        #expect(result.stdout.contains("No updates") || result.stdout.contains("Updates available"))
    }
    
    @Test("update with multiple overrides")
    func testUpdateMultipleOverrides() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with basic config
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
        try "# Example Lib v1.0.0-alpha.1\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: [
                "update", "--name", "example-lib", 
                "--ref", "commit", 
                "--constraint", ">=1.0.0", 
                "--include-prereleases"
            ],
            workingDirectory: fixture.repoRoot
        )
        
        // Should accept all overrides
        #expect(result.exitStatus == 0 || result.exitStatus == 5)
        #expect(result.stdout.contains("No updates") || result.stdout.contains("Updates available"))
    }
    
    @Test("update override with invalid constraint fails")
    func testUpdateOverrideInvalidConstraint() async throws {
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
        
        // Pre-create the subtree directory
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
        let readmeFile = subtreePath.appendingPathComponent("README.md")
        try "# Example Lib\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: [
                "update", "--name", "example-lib", 
                "--ref", "commit", 
                "--constraint", "invalid..constraint"
            ],
            workingDirectory: fixture.repoRoot
        )
        
        // Should fail with invalid constraint override
        #expect(result.exitStatus == 2)
        #expect(result.stderr.contains("constraint"))
    }
}
