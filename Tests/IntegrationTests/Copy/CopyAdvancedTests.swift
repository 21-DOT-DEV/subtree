import Testing
import Foundation
@testable import Subtree

struct CopyAdvancedTests {
    
    @Test("extract with glob patterns")
    func testCopyGlobPatterns() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with glob pattern
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: example-lib
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/example-lib
            branch: master
            squash: true
            copies:
              - from: "src/**/*.swift"
                to: "Sources/ExampleLib/"
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Create nested source structure
        let sourcePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib/src")
        let nestedPath = sourcePath.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nestedPath, withIntermediateDirectories: true)
        
        try "public struct Example {}\n".write(to: sourcePath.appendingPathComponent("Example.swift"), atomically: true, encoding: .utf8)
        try "public struct Nested {}\n".write(to: nestedPath.appendingPathComponent("Nested.swift"), atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["extract", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have copied both files (basic implementation copies from immediate directory)
        let targetPath = fixture.repoRoot.appendingPathComponent("Sources/ExampleLib/Example.swift")
        #expect(FileManager.default.fileExists(atPath: targetPath.path))
        
        // Should have success message
        #expect(result.stdout.contains("Copied"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("extract with no matching files")
    func testCopyNoMatchingFiles() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with pattern that won't match
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: example-lib
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/example-lib
            branch: master
            squash: true
            copies:
              - from: "*.nonexistent"
                to: "Sources/ExampleLib/"
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Create subtree directory with different files
        let sourcePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        try FileManager.default.createDirectory(at: sourcePath, withIntermediateDirectories: true)
        try "# Example\n".write(to: sourcePath.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["extract", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully but with no files copied
        #expect(result.exitStatus == 0)
        #expect(result.stdout.contains("No files to extract") || result.stdout.contains("No files to copy"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("extract with --all flag")
    func testCopyAllSubtrees() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml with multiple subtrees
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: lib-a
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/lib-a
            branch: master
            squash: true
            copies:
              - from: "*.swift"
                to: "Sources/LibA/"
          - name: lib-b
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/lib-b
            branch: master
            squash: true
            copies:
              - from: "*.swift"
                to: "Sources/LibB/"
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Create source files for both subtrees
        for libName in ["lib-a", "lib-b"] {
            let sourcePath = fixture.repoRoot.appendingPathComponent("Vendor/\(libName)")
            try FileManager.default.createDirectory(at: sourcePath, withIntermediateDirectories: true)
            try "public struct \(libName.capitalized) {}\n".write(
                to: sourcePath.appendingPathComponent("\(libName.capitalized).swift"),
                atomically: true, 
                encoding: .utf8
            )
        }
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["extract", "--all"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should have copied files from both subtrees
        let targetA = fixture.repoRoot.appendingPathComponent("Sources/LibA/Lib-a.swift")
        let targetB = fixture.repoRoot.appendingPathComponent("Sources/LibB/Lib-b.swift")
        #expect(FileManager.default.fileExists(atPath: targetA.path))
        #expect(FileManager.default.fileExists(atPath: targetB.path))
        
        // Should have success message
        #expect(result.stdout.contains("Copied"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("extract with existing destination files")
    func testCopyOverwriteExisting() async throws {
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
            copies:
              - from: "*.swift"
                to: "Sources/ExampleLib/"
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Create source file
        let sourcePath = fixture.repoRoot.appendingPathComponent("Vendor/example-lib")
        try FileManager.default.createDirectory(at: sourcePath, withIntermediateDirectories: true)
        try "public struct NewExample {}\n".write(to: sourcePath.appendingPathComponent("Example.swift"), atomically: true, encoding: .utf8)
        
        // Create existing destination file
        let targetDir = fixture.repoRoot.appendingPathComponent("Sources/ExampleLib")
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        let targetFile = targetDir.appendingPathComponent("Example.swift")
        try "public struct OldExample {}\n".write(to: targetFile, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["extract", "--name", "example-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit successfully and overwrite
        #expect(result.exitStatus == 0)
        
        // Should have overwritten the file
        let newContent = try String(contentsOf: targetFile)
        #expect(newContent.contains("NewExample"))
        #expect(!newContent.contains("OldExample"))
        
        // Should have success message
        #expect(result.stdout.contains("Copied"))
        #expect(result.stderr.isEmpty)
    }
    
    @Test("extract with subtree that doesn't exist on filesystem")
    func testCopyMissingSubtreeDirectory() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Create a subtree.yaml but don't create the actual directory
        let configPath = fixture.repoRoot.appendingPathComponent("subtree.yaml")
        let configContent = """
        subtrees:
          - name: missing-lib
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/missing-lib
            branch: master
            squash: true
            copies:
              - from: "*.swift"
                to: "Sources/MissingLib/"
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)
        
        let result = try await SubprocessHelpers.runSubtreeCLI(
            arguments: ["extract", "--name", "missing-lib"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with error
        #expect(result.exitStatus == 2)
        #expect(result.stderr.contains("not found at path"))
    }
}
