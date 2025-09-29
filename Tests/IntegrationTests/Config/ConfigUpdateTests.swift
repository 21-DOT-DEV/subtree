import Testing
import Foundation
@testable import Subtree

struct ConfigUpdateTests {
    
    @Test("update subtree commit field")  
    func testUpdateSubtreeCommit() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create initial config
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
        
        // Update the commit field
        try ConfigIO.updateSubtreeCommit(
            at: configPath,
            subtreeName: "example-lib", 
            commitHash: "abc123def456"
        )
        
        // Read config back and verify update
        let updatedConfig = try ConfigIO.readConfig(from: configPath)
        #expect(updatedConfig.subtrees.count == 1)
        
        let subtree = updatedConfig.subtrees[0]
        #expect(subtree.name == "example-lib")
        #expect(subtree.commit == "abc123def456")
        #expect(subtree.remote == "git@github.com:octocat/Hello-World.git")
        #expect(subtree.prefix == "Vendor/example-lib")
    }
    
    @Test("update commit field for non-existent subtree fails")
    func testUpdateCommitNonExistentSubtree() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create config without the target subtree
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
        
        // Attempt to update non-existent subtree should throw
        #expect(throws: ConfigError.self) {
            try ConfigIO.updateSubtreeCommit(
                at: configPath,
                subtreeName: "example-lib",
                commitHash: "abc123"
            )
        }
    }
    
    @Test("add new subtree entry")
    func testAddSubtreeEntry() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create minimal config
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        try ConfigIO.writeMinimalConfig(to: configPath) 
        
        // Create new subtree entry
        let newSubtree = SubtreeEntry(
            name: "new-lib",
            remote: "git@github.com:octocat/Hello-World.git",
            prefix: "Vendor/new-lib",
            branch: "main",
            squash: true
        )
        
        // Add the subtree
        try ConfigIO.addSubtreeEntry(at: configPath, subtree: newSubtree)
        
        // Verify it was added
        let config = try ConfigIO.readConfig(from: configPath)
        #expect(config.subtrees.count == 1)
        
        let addedSubtree = config.subtrees[0]
        #expect(addedSubtree.name == "new-lib")
        #expect(addedSubtree.remote == "git@github.com:octocat/Hello-World.git")
        #expect(addedSubtree.prefix == "Vendor/new-lib")
    }
    
    @Test("add duplicate subtree entry fails")
    func testAddDuplicateSubtreeEntry() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create config with existing subtree
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
        
        // Try to add subtree with same name
        let duplicateSubtree = SubtreeEntry(
            name: "example-lib",
            remote: "https://github.com/different/repo.git",
            prefix: "Different/path", 
            branch: "develop"
        )
        
        // Should throw error
        #expect(throws: ConfigError.self) {
            try ConfigIO.addSubtreeEntry(at: configPath, subtree: duplicateSubtree)
        }
    }
    
    @Test("remove subtree entry")
    func testRemoveSubtreeEntry() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create config with multiple subtrees  
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: lib-a
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/lib-a
            branch: master
            squash: true
          - name: lib-b
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/lib-b
            branch: master
            squash: true
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Remove one subtree
        try ConfigIO.removeSubtreeEntry(at: configPath, subtreeName: "lib-a")
        
        // Verify only lib-b remains
        let config = try ConfigIO.readConfig(from: configPath)
        #expect(config.subtrees.count == 1)
        #expect(config.subtrees[0].name == "lib-b")
    }
    
    @Test("remove non-existent subtree entry fails")
    func testRemoveNonExistentSubtreeEntry() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create config with one subtree
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
        
        // Try to remove non-existent subtree
        #expect(throws: ConfigError.self) {
            try ConfigIO.removeSubtreeEntry(at: configPath, subtreeName: "non-existent")
        }
    }
}
