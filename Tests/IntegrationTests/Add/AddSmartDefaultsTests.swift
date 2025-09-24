import Testing
import Foundation
@testable import Subtree

struct AddSmartDefaultsTests {
    
    @Test("add with remote URL only infers name and prefix")
    func testAddWithRemoteOnlyInfersDefaults() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create empty config
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = "subtrees: []\n"
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: [
                "add", "--remote", "git@github.com:octocat/Hello-World.git",
                "--ref", "master"  // Specify ref to avoid default branch issues
            ],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have success message with inferred values
        #expect(result.stdout.contains("Added subtree 'Hello-World' at 'Vendor/Hello-World'"))
        #expect(result.stderr.isEmpty)
        
        // Should have added subtree to config with inferred values
        let updatedConfig = try ConfigIO.readConfig(from: configPath)
        #expect(updatedConfig.subtrees.count == 1)
        
        let addedSubtree = updatedConfig.subtrees[0]
        #expect(addedSubtree.name == "Hello-World")
        #expect(addedSubtree.remote == "git@github.com:octocat/Hello-World.git")
        #expect(addedSubtree.prefix == "Vendor/Hello-World")
        #expect(addedSubtree.branch == "master")
        #expect(addedSubtree.squash == true)
    }
    
    @Test("add with custom prefix overrides inference")
    func testAddWithCustomPrefixOverride() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create empty config
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = "subtrees: []\n"
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: [
                "add", "--remote", "git@github.com:octocat/Hello-World.git",
                "--prefix", "ThirdParty/custom-name",
                "--ref", "master"
            ],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should use custom prefix while inferring name
        #expect(result.stdout.contains("Added subtree 'Hello-World' at 'ThirdParty/custom-name'"))
        
        // Check config
        let updatedConfig = try ConfigIO.readConfig(from: configPath)
        let addedSubtree = updatedConfig.subtrees[0]
        #expect(addedSubtree.name == "Hello-World")
        #expect(addedSubtree.prefix == "ThirdParty/custom-name")
    }
    
    @Test("add with explicit name overrides inference")
    func testAddWithExplicitNameOverride() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create empty config
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = "subtrees: []\n"
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: [
                "add", "--name", "custom-lib",
                "--remote", "git@github.com:octocat/Hello-World.git",
                "--ref", "master"
            ],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should use explicit name while inferring prefix from name
        #expect(result.stdout.contains("Added subtree 'custom-lib' at 'Vendor/custom-lib'"))
        
        // Check config
        let updatedConfig = try ConfigIO.readConfig(from: configPath)
        let addedSubtree = updatedConfig.subtrees[0]
        #expect(addedSubtree.name == "custom-lib")
        #expect(addedSubtree.prefix == "Vendor/custom-lib")
        #expect(addedSubtree.remote == "git@github.com:octocat/Hello-World.git")
    }
    
    @Test("add without remote or name fails with helpful message")
    func testAddWithoutRemoteOrNameFails() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create empty config
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = "subtrees: []\n"
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["add"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with error
        #expect(result.exitStatus == 2)
        
        // Should have helpful error message mentioning both options
        #expect(result.stderr.contains("--name") && result.stderr.contains("--remote"))
    }
    
    @Test("add inference logic works without real git operations") 
    func testAddInferenceLogicWithoutRealGit() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create empty config
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = "subtrees: []\n"
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Test with example.com URLs (will use simulation mode)
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: [
                "add", "--remote", "git@github.com:octocat/Hello-World.git",
                "--ref", "master"
            ],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully (using simulation)
        #expect(result.exitStatus == 0)
        
        // Should infer correct name and show in output
        #expect(result.stdout.contains("Added subtree 'Hello-World' at 'Vendor/Hello-World'"))
        
        // Should add to config with inferred values
        let updatedConfig = try ConfigIO.readConfig(from: configPath)
        #expect(updatedConfig.subtrees.count == 1)
        #expect(updatedConfig.subtrees[0].name == "Hello-World")
        #expect(updatedConfig.subtrees[0].prefix == "Vendor/Hello-World")
    }
    
    @Test("add with smart defaults preserves existing functionality")
    func testAddSmartDefaultsPreservesExistingFunctionality() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create config with existing subtree
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: existing-lib
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/existing
            branch: master
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Add existing subtree by name (should still work)
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["add", "--name", "existing-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        #expect(result.stdout.contains("Added subtree 'existing-lib' at 'Vendor/existing'"))
        
        // Config should remain unchanged (not duplicated)
        let updatedConfig = try ConfigIO.readConfig(from: configPath)
        #expect(updatedConfig.subtrees.count == 1)
        #expect(updatedConfig.subtrees[0].name == "existing-lib")
    }
    
    @Test("add with remote URL only uses all smart defaults")
    func testAddWithRemoteOnlyUsesAllSmartDefaults() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create empty config
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = "subtrees: []\n"
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Only provide remote URL - everything else should use smart defaults
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: [
                "add", "--remote", "git@github.com:swiftlang/swift-se0270-range-set.git"
                // No --name, --prefix, or --ref provided!
            ],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully  
        #expect(result.exitStatus == 0)
        
        // Should infer all values from smart defaults
        #expect(result.stdout.contains("Added subtree 'swift-se0270-range-set' at 'Vendor/swift-se0270-range-set'"))
        #expect(result.stderr.isEmpty)
        
        // Should have added subtree to config with all smart defaults
        let updatedConfig = try ConfigIO.readConfig(from: configPath)
        #expect(updatedConfig.subtrees.count == 1)
        
        let addedSubtree = updatedConfig.subtrees[0]
        #expect(addedSubtree.name == "swift-se0270-range-set")           // Inferred from URL
        #expect(addedSubtree.remote == "git@github.com:swiftlang/swift-se0270-range-set.git")
        #expect(addedSubtree.prefix == "Vendor/swift-se0270-range-set")  // Inferred from name
        #expect(addedSubtree.branch == "main")                // Smart default
        #expect(addedSubtree.squash == true)                  // Smart default
    }
    
    @Test("add with override flags on existing subtree works")
    func testAddWithOverrideFlagsOnExistingSubtree() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create config with existing subtree
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: lib
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/lib
            branch: master
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Add with remote override
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: [
                "add", "--name", "lib",
                "--remote", "git@github.com:octocat/Hello-World.git"
            ],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        #expect(result.stdout.contains("Added subtree 'lib'"))
        
        // Config should remain unchanged (overrides are temporary)
        let updatedConfig = try ConfigIO.readConfig(from: configPath)
        #expect(updatedConfig.subtrees.count == 1)
        #expect(updatedConfig.subtrees[0].remote == "git@github.com:octocat/Hello-World.git") // Original preserved
    }
}
