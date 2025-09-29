import Testing
import Foundation
@testable import Subtree

struct CopyTests {
    
    @Test("extract with --name --from --to")
    func testCopyBasicOperation() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with extract mappings
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: example-lib
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/example-lib
            branch: master
            squash: true
            copies:
              - from: "src/lib/*.swift"
                to: "Sources/ExampleLib/"
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Create source directory with files to extract
        let sourcePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib/src/lib")
        try FileManager.default.createDirectory(at: sourcePath, withIntermediateDirectories: true)
        
        let sourceFile = sourcePath.appendingPathComponent("Example.swift")
        try "public struct Example {}\n".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["extract", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have copied the file
        let targetPath = fixture.repoRoot.appendingPathComponent("Sources/ExampleLib/Example.swift")
        #expect(FileManager.default.fileExists(atPath: targetPath.path))
        
        // Should have success message
        #expect(result.stdout.contains("Copied") || result.stdout.contains("files"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("extract with multiple mappings")
    func testCopyMultipleMappings() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with multiple extract mappings
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: example-lib
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/example-lib
            branch: master
            squash: true
            copies:
              - from: "src/*.swift"
                to: "Sources/ExampleLib/"
              - from: "docs/*.md"
                to: "Documentation/"
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Create source directories with files
        let srcPath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib/src")
        let docsPath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib/docs")
        try FileManager.default.createDirectory(at: srcPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: docsPath, withIntermediateDirectories: true)
        
        try "public struct Example {}\n".write(to: srcPath.appendingPathComponent("Example.swift"), atomically: true, encoding: .utf8)
        try "# Documentation\n".write(to: docsPath.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["extract", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have copied both files
        let swiftTarget = fixture.repoRoot.appendingPathComponent("Sources/ExampleLib/Example.swift")
        let mdTarget = fixture.repoRoot.appendingPathComponent("Documentation/README.md")
        #expect(FileManager.default.fileExists(atPath: swiftTarget.path))
        #expect(FileManager.default.fileExists(atPath: mdTarget.path))
        
        // Should have success message
        #expect(result.stdout.contains("Copied"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("extract with command-line --from --to overrides")
    func testCopyCommandLineOverrides() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml without extract mappings
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
        
        // Create source file
        let sourcePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib/lib")
        try FileManager.default.createDirectory(at: sourcePath, withIntermediateDirectories: true)
        
        let sourceFile = sourcePath.appendingPathComponent("Custom.swift")
        try "public struct Custom {}\n".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["extract", "--name", "example-lib", "--from", "lib/*.swift", "--to", "Sources/Custom/"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have copied using command-line mapping
        let targetPath = fixture.repoRoot.appendingPathComponent("Sources/Custom/Custom.swift")
        #expect(FileManager.default.fileExists(atPath: targetPath.path))
        
        // Should have success message
        #expect(result.stdout.contains("Copied"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("extract with missing config file")
    func testCopyMissingConfig() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["extract", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with code 4 (config file not found)
        #expect(result.exitStatus == 4)
        
        // Should print error to stderr
        #expect(result.stderr.contains("subtree.yaml not found"))
    }
    
    @Test("extract with non-existent subtree name")
    func testCopyNonExistentName() async throws {
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
            arguments: ["extract", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with code 2 (invalid usage)
        #expect(result.exitStatus == 2)
        
        // Should print error to stderr
        #expect(result.stderr.contains("Subtree 'example-lib' not found"))
    }
}
