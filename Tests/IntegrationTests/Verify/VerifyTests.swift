import Testing
import Foundation
@testable import Subtree

struct VerifyTests {
    
    @Test("validate with --name shows subtree integrity")
    func testVerifyBasicOperation() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with one entry
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
        
        // Create subtree directory with files
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
        let readmeFile = subtreePath.appendingPathComponent("README.md")
        try "# Example Lib\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["validate", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully for clean subtree
        #expect(result.exitStatus == 0)
        
        // Should show verification results
        #expect(result.stdout.contains("Verified") || result.stdout.contains("integrity"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("validate with --all verifies all subtrees")
    func testVerifyAllSubtrees() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with multiple entries
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
        
        // Create both subtree directories
        for libName in ["lib-a", "lib-b"] {
            let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/\(libName)")
            try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
            let readmeFile = subtreePath.appendingPathComponent("README.md")
            try "# \(libName.capitalized)\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        }
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["validate", "--all"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should show verification results for all
        #expect(result.stdout.contains("Verified") || result.stdout.contains("integrity"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("validate with discrepancies exits with code 5")
    func testVerifyDiscrepancies() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml
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
        
        // Create subtree directory with files including a "DISCREPANCY" marker
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
        let readmeFile = subtreePath.appendingPathComponent("README.md")
        try "# Example Lib\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        // Create a marker file to simulate discrepancy
        let discrepancyFile = subtreePath.appendingPathComponent("DISCREPANCY.txt")
        try "This file simulates a verification discrepancy".write(to: discrepancyFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["validate", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with code 5 for discrepancies
        #expect(result.exitStatus == 5)
        
        // Should report discrepancies
        #expect(result.stdout.contains("discrepancy") || result.stdout.contains("differences"))
    }
    
    @Test("validate with --repair fixes discrepancies")
    func testVerifyRepair() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml
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
        
        // Create subtree directory with discrepancy
        let subtreePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        try FileManager.default.createDirectory(at: subtreePath, withIntermediateDirectories: true)
        let readmeFile = subtreePath.appendingPathComponent("README.md")
        try "# Example Lib\n".write(to: readmeFile, atomically: true, encoding: .utf8)
        
        let discrepancyFile = subtreePath.appendingPathComponent("DISCREPANCY.txt")
        try "Discrepancy content".write(to: discrepancyFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["validate", "--name", "example-lib", "--repair"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully after repair
        #expect(result.exitStatus == 0)
        
        // Should show repair results
        #expect(result.stdout.contains("Repaired") || result.stdout.contains("Fixed"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("validate with missing config file")
    func testVerifyMissingConfig() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["validate", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with code 4 (config file not found)
        #expect(result.exitStatus == 4)
        
        // Should print error to stderr
        #expect(result.stderr.contains("subtree.yaml not found"))
    }
    
    @Test("validate with non-existent subtree name")
    func testVerifyNonExistentName() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create config without the requested subtree
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
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["validate", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with code 2 (invalid usage)
        #expect(result.exitStatus == 2)
        
        // Should print error to stderr
        #expect(result.stderr.contains("Subtree 'example-lib' not found"))
    }
}
