import Testing
import Foundation
@testable import SubtreeLib

/// Tests for GitOperations.hashObject() functionality
///
/// These tests verify the checksum computation using `git hash-object`
/// for the Extract Clean Mode feature (010-extract-clean).
@Suite("GitOperations Hash Tests")
struct GitOperationsHashTests {
    
    // MARK: - T005: hashObject returns SHA hash
    
    @Test("hashObject returns 40-character SHA hash for valid file")
    func hashObjectReturnsSHA() async throws {
        // Create a temporary file with known content
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let testFile = tempDir.appendingPathComponent("test.txt")
        let testContent = "Hello, World!\n"
        try testContent.write(to: testFile, atomically: true, encoding: .utf8)
        
        // Get hash
        let hash = try await GitOperations.hashObject(file: testFile.path)
        
        // Verify it's a valid 40-character hex SHA hash
        #expect(hash.count == 40)
        #expect(hash.allSatisfy { $0.isHexDigit })
    }
    
    @Test("hashObject returns consistent hash for same content")
    func hashObjectConsistentForSameContent() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let content = "Identical content\n"
        
        // Create two files with identical content
        let file1 = tempDir.appendingPathComponent("file1.txt")
        let file2 = tempDir.appendingPathComponent("file2.txt")
        try content.write(to: file1, atomically: true, encoding: .utf8)
        try content.write(to: file2, atomically: true, encoding: .utf8)
        
        let hash1 = try await GitOperations.hashObject(file: file1.path)
        let hash2 = try await GitOperations.hashObject(file: file2.path)
        
        #expect(hash1 == hash2)
    }
    
    @Test("hashObject returns different hash for different content")
    func hashObjectDifferentForDifferentContent() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let file1 = tempDir.appendingPathComponent("file1.txt")
        let file2 = tempDir.appendingPathComponent("file2.txt")
        try "Content A\n".write(to: file1, atomically: true, encoding: .utf8)
        try "Content B\n".write(to: file2, atomically: true, encoding: .utf8)
        
        let hash1 = try await GitOperations.hashObject(file: file1.path)
        let hash2 = try await GitOperations.hashObject(file: file2.path)
        
        #expect(hash1 != hash2)
    }
    
    // MARK: - T006: hashObject throws for nonexistent file
    
    @Test("hashObject throws GitError for nonexistent file")
    func hashObjectThrowsForNonexistentFile() async throws {
        let nonexistentPath = "/nonexistent/path/to/file.txt"
        
        await #expect(throws: GitError.self) {
            _ = try await GitOperations.hashObject(file: nonexistentPath)
        }
    }
    
    @Test("hashObject throws specific error with path info")
    func hashObjectThrowsWithPathInfo() async throws {
        let nonexistentPath = "/tmp/definitely-does-not-exist-\(UUID().uuidString).txt"
        
        do {
            _ = try await GitOperations.hashObject(file: nonexistentPath)
            Issue.record("Expected error to be thrown")
        } catch let error as GitError {
            // Verify we get a commandFailed error with useful info
            if case .commandFailed(let message) = error {
                #expect(message.contains("hash-object") || message.contains("fatal"))
            } else {
                Issue.record("Expected commandFailed error, got \(error)")
            }
        }
    }
}
