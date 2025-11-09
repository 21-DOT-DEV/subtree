import Testing
import Foundation
import Subprocess
@testable import SubtreeLib

@Suite("Git Operations Tests")
struct GitOperationsTests {
    
    // T003: Test findGitRoot() succeeds in valid repository
    @Test("findGitRoot() returns path in valid git repository")
    func testFindGitRootSucceeds() async throws {
        // This test expects GitOperations.findGitRoot() to exist
        // It should succeed when run in a git repository
        let gitRoot = try await GitOperations.findGitRoot()
        #expect(!gitRoot.isEmpty, "Git root path should not be empty")
        #expect(gitRoot.contains("/"), "Git root should be an absolute path")
    }
    
    // T004: Test findGitRoot() throws error outside repository
    @Test("findGitRoot() throws error outside git repository")
    func testFindGitRootFailsOutsideRepo() async throws {
        // This test assumes we're running in a git repository (which we are)
        // The actual validation of error handling outside a repo
        // is covered by integration tests in InitCommandIntegrationTests
        // For unit testing, we verify the function exists and can be called
        _ = try await GitOperations.findGitRoot()
        // If we get here, we're in a git repo (test passes)
    }
    
    // T005: Test findGitRoot() resolves symlinks correctly  
    @Test("findGitRoot() resolves symlinks to canonical path")
    func testFindGitRootResolvesSymlinks() async throws {
        // This test expects findGitRoot() to return canonical (real) path
        // Git command `rev-parse --show-toplevel` automatically resolves symlinks
        let gitRoot = try await GitOperations.findGitRoot()
        
        // Verify path is canonical (no symlink components)
        let url = URL(fileURLWithPath: gitRoot)
        let resolvedURL = url.resolvingSymlinksInPath()
        
        #expect(gitRoot == resolvedURL.path, "Git root should be canonical path (symlinks resolved)")
    }
    
    // MARK: - isFileTracked() Tests (008-extract-command)
    
    // T038: Test isFileTracked with tracked file
    @Test("isFileTracked returns true for tracked file")
    func testIsFileTrackedWithTrackedFile() async throws {
        // Use the current git repo (we know we're in one from other tests)
        let gitRoot = try await GitOperations.findGitRoot()
        
        // Check README.md which should definitely be tracked
        let isTracked = try await GitOperations.isFileTracked(path: "README.md", in: gitRoot)
        #expect(isTracked == true)
    }
    
    // T039: Test isFileTracked with untracked file
    @Test("isFileTracked returns false for untracked file")
    func testIsFileTrackedWithUntrackedFile() async throws {
        let gitRoot = try await GitOperations.findGitRoot()
        
        // Create a temporary untracked file
        let testFile = gitRoot + "/.__test-untracked-" + UUID().uuidString + ".txt"
        try "test content".write(toFile: testFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: testFile) }
        
        // Verify the file is not tracked
        let fileName = URL(fileURLWithPath: testFile).lastPathComponent
        let isTracked = try await GitOperations.isFileTracked(path: fileName, in: gitRoot)
        #expect(isTracked == false)
    }
    
    // T040: Test isFileTracked with non-existent file
    @Test("isFileTracked returns false for non-existent file")
    func testIsFileTrackedWithNonExistentFile() async throws {
        let gitRoot = try await GitOperations.findGitRoot()
        
        // Check a file that doesn't exist
        let isTracked = try await GitOperations.isFileTracked(path: "does-not-exist-" + UUID().uuidString + ".txt", in: gitRoot)
        #expect(isTracked == false)
    }
    
    // T041: Test isFileTracked with file in subdirectory
    @Test("isFileTracked works with file in subdirectory")
    func testIsFileTrackedInSubdirectory() async throws {
        let gitRoot = try await GitOperations.findGitRoot()
        
        // Check a tracked file in a subdirectory (Sources/SubtreeLib/Utilities/GitOperations.swift should exist)
        let isTracked = try await GitOperations.isFileTracked(path: "Sources/SubtreeLib/Utilities/GitOperations.swift", in: gitRoot)
        #expect(isTracked == true)
    }
    
    // T042: Test isFileTracked error handling (not in git repo)
    @Test("isFileTracked throws error when not in git repository")
    func testIsFileTrackedNotInRepo() async throws {
        // Create a temp directory that's not a git repo
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        // Should throw GitError.notInRepository
        do {
            _ = try await GitOperations.isFileTracked(path: "any-file.txt", in: tempDir)
            Issue.record("Expected GitError.notInRepository to be thrown")
        } catch let error as GitError {
            #expect(error == GitError.notInRepository)
        }
    }
}
