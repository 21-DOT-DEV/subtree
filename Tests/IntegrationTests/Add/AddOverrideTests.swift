import Testing
import Foundation
@testable import Subtree

struct AddOverrideTests {
    
    @Test("add with --remote --prefix --ref overrides creates new subtree")
    func testAddWithCompleteOverrides() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create minimal config without the target subtree
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = "subtrees: []\n"
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: [
                "add", "--name", "libfoo",
                "--remote", "git@github.com:octocat/Hello-World.git",
                "--prefix", "Vendor/libfoo", 
                "--ref", "master"
            ],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have added the subtree
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/libfoo")
        #expect(FileManager.default.fileExists(atPath: subtreePath.path))
        
        // Should have success message
        #expect(result.stdout.contains("Added subtree 'libfoo'"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("add with overrides to existing config entry")
    func testAddWithOverridesToExistingConfig() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create config with existing subtree
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml") 
        let configContent = """
        subtrees:
          - name: libfoo
            remote: git@github.com:octocat/Hello-World.git
            prefix: Original/path
            branch: master
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: [
                "add", "--name", "libfoo",
                "--remote", "git@github.com:octocat/Hello-World.git",
                "--prefix", "Override/path",
                "--ref", "master"
            ],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have added subtree using override path, not original
        let overridePath = fixture.repoRoot.appendingPathComponent("Override/path")
        let originalPath = fixture.repoRoot.appendingPathComponent("Original/path")
        #expect(FileManager.default.fileExists(atPath: overridePath.path))
        #expect(!FileManager.default.fileExists(atPath: originalPath.path))
        
        // Should have success message with override path
        #expect(result.stdout.contains("Added subtree 'libfoo' at 'Override/path'"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("add with --no-squash override")
    func testAddWithNoSquashOverride() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create config with squash enabled
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: libfoo
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/libfoo
            branch: master  
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["add", "--name", "libfoo", "--no-squash"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have added the subtree
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/libfoo")
        #expect(FileManager.default.fileExists(atPath: subtreePath.path))
        
        // Should have success message
        #expect(result.stdout.contains("Added subtree 'libfoo'"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("add overrides cannot be used with --all")
    func testAddOverridesCannotUseWithAll() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create minimal config
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: libfoo
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/libfoo
            branch: master
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: [
                "add", "--all",
                "--remote", "git@github.com:octocat/Hello-World.git"
            ],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with invalid usage error (FR-024)
        #expect(result.exitStatus == 2)
        #expect(result.stderr.contains("Override flags") && result.stderr.contains("--all"))
    }
    
    @Test("add with smart defaults works when subtree not in config")
    func testAddWithSmartDefaultsWhenNotInConfig() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create minimal config without target subtree
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = "subtrees: []\n"
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Only provide name and remote - prefix and ref should use smart defaults
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: [
                "add", "--name", "libfoo",
                "--remote", "git@github.com:octocat/Hello-World.git",
                "--ref", "master"
            ],
            workingDirectory: fixture.repoRoot
        )
        
        // Should succeed with smart defaults
        #expect(result.exitStatus == 0)
        
        // Should create subtree with inferred prefix and default branch
        #expect(result.stdout.contains("Added subtree 'libfoo' at 'Vendor/libfoo'"))
        
        // Should add to config with smart defaults
        let updatedConfig = try ConfigIO.readConfig(from: configPath)
        #expect(updatedConfig.subtrees.count == 1)
        
        let addedSubtree = updatedConfig.subtrees[0]
        #expect(addedSubtree.name == "libfoo")
        #expect(addedSubtree.prefix == "Vendor/libfoo") // Smart default
        #expect(addedSubtree.branch == "master") // Smart default
    }
    
    @Test("add with partial overrides to existing config works")
    func testAddWithPartialOverridesWorks() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create config with existing subtree
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: libfoo
            remote: git@github.com:octocat/Hello-World.git
            prefix: Original/path
            branch: master
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Only override the remote, keep other settings from config
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: [
                "add", "--name", "libfoo",
                "--remote", "git@github.com:octocat/Hello-World.git"
            ],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have added subtree using original path (from config)
        let originalPath = fixture.repoRoot.appendingPathComponent("Original/path")
        #expect(FileManager.default.fileExists(atPath: originalPath.path))
        
        // Should have success message with original path
        #expect(result.stdout.contains("Added subtree 'libfoo' at 'Original/path'"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("add with overrides persists new subtree to config")
    func testAddWithOverridesPersistsToConfig() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create minimal config without the target subtree
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = "subtrees: []\n"
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: [
                "add", "--name", "newlib",
                "--remote", "git@github.com:octocat/Hello-World.git",
                "--prefix", "Vendor/newlib", 
                "--ref", "master"
            ],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have added the subtree
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/newlib")
        #expect(FileManager.default.fileExists(atPath: subtreePath.path))
        
        // Should have updated the config file
        let updatedConfig = try ConfigIO.readConfig(from: configPath)
        #expect(updatedConfig.subtrees.count == 1)
        
        let addedSubtree = updatedConfig.subtrees[0]
        #expect(addedSubtree.name == "newlib")
        #expect(addedSubtree.remote == "git@github.com:octocat/Hello-World.git")
        #expect(addedSubtree.prefix == "Vendor/newlib")
        #expect(addedSubtree.branch == "master")
        #expect(addedSubtree.squash == true) // Default when using --no-squash=false
        
        // Should have success message
        #expect(result.stdout.contains("Added subtree 'newlib'"))
        #expect(result.stderr.isEmpty)
    }
}
