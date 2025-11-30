import Testing
import Foundation
@testable import SubtreeLib

/// Tests for DirectoryPruner functionality
///
/// These tests verify the batch empty directory pruning logic
/// for the Extract Clean Mode feature (010-extract-clean).
@Suite("DirectoryPruner Tests")
struct DirectoryPrunerTests {
    
    /// Helper to create test directory structure
    private func createTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DirectoryPrunerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    // MARK: - T007: add(parentOf:) collects parent directories
    
    @Test("add(parentOf:) collects parent directory of file path")
    func addParentOfCollectsParentDirectory() throws {
        let tempDir = try createTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        var pruner = DirectoryPruner(boundary: tempDir.path)
        
        let filePath = tempDir.appendingPathComponent("subdir/nested/file.txt").path
        pruner.add(parentOf: filePath)
        
        // Should have collected the parent directory
        #expect(pruner.directoryCount > 0)
    }
    
    @Test("add(parentOf:) collects all ancestors up to boundary")
    func addParentOfCollectsAncestors() throws {
        let tempDir = try createTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        var pruner = DirectoryPruner(boundary: tempDir.path)
        
        // Add a deeply nested file path
        let filePath = tempDir.appendingPathComponent("a/b/c/file.txt").path
        pruner.add(parentOf: filePath)
        
        // Should collect a/b/c, a/b, a (3 directories)
        #expect(pruner.directoryCount == 3)
    }
    
    @Test("add(parentOf:) deduplicates directories")
    func addParentOfDeduplicates() throws {
        let tempDir = try createTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        var pruner = DirectoryPruner(boundary: tempDir.path)
        
        // Add multiple files in same directory
        pruner.add(parentOf: tempDir.appendingPathComponent("subdir/file1.txt").path)
        pruner.add(parentOf: tempDir.appendingPathComponent("subdir/file2.txt").path)
        
        // Should only have one directory entry
        #expect(pruner.directoryCount == 1)
    }
    
    // MARK: - T008: pruneEmpty() removes empty directories bottom-up
    
    @Test("pruneEmpty() removes empty directories")
    func pruneEmptyRemovesEmptyDirs() throws {
        let tempDir = try createTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create nested empty directories
        let nestedDir = tempDir.appendingPathComponent("a/b/c")
        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        
        var pruner = DirectoryPruner(boundary: tempDir.path)
        pruner.add(parentOf: nestedDir.appendingPathComponent("file.txt").path)
        
        let prunedCount = try pruner.pruneEmpty()
        
        // All 3 directories should be pruned (c, b, a)
        #expect(prunedCount == 3)
        #expect(!FileManager.default.fileExists(atPath: nestedDir.path))
    }
    
    @Test("pruneEmpty() processes deepest directories first (bottom-up)")
    func pruneEmptyProcessesBottomUp() throws {
        let tempDir = try createTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create structure: a/b/c (empty)
        let dirA = tempDir.appendingPathComponent("a")
        let dirB = dirA.appendingPathComponent("b")
        let dirC = dirB.appendingPathComponent("c")
        try FileManager.default.createDirectory(at: dirC, withIntermediateDirectories: true)
        
        var pruner = DirectoryPruner(boundary: tempDir.path)
        pruner.add(parentOf: dirC.appendingPathComponent("deleted-file.txt").path)
        
        let prunedCount = try pruner.pruneEmpty()
        
        // Should prune c first, then b, then a
        #expect(prunedCount == 3)
        #expect(!FileManager.default.fileExists(atPath: dirA.path))
    }
    
    // MARK: - T009: respects boundary (never prunes destination root)
    
    @Test("pruneEmpty() never prunes boundary directory")
    func pruneEmptyNeverPrunesBoundary() throws {
        let tempDir = try createTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Boundary is the tempDir itself - it should never be deleted
        var pruner = DirectoryPruner(boundary: tempDir.path)
        
        // Add a file directly in boundary
        pruner.add(parentOf: tempDir.appendingPathComponent("file.txt").path)
        
        let prunedCount = try pruner.pruneEmpty()
        
        // No directories should be pruned (boundary is protected)
        #expect(prunedCount == 0)
        #expect(FileManager.default.fileExists(atPath: tempDir.path))
    }
    
    @Test("pruneEmpty() stops at boundary even when empty")
    func pruneEmptyStopsAtBoundary() throws {
        let tempDir = try createTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create boundary subdirectory
        let boundary = tempDir.appendingPathComponent("dest")
        let nested = boundary.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        
        var pruner = DirectoryPruner(boundary: boundary.path)
        pruner.add(parentOf: nested.appendingPathComponent("file.txt").path)
        
        let prunedCount = try pruner.pruneEmpty()
        
        // Only 'sub' should be pruned, not 'dest' (boundary)
        #expect(prunedCount == 1)
        #expect(FileManager.default.fileExists(atPath: boundary.path))
        #expect(!FileManager.default.fileExists(atPath: nested.path))
    }
    
    // MARK: - T010: leaves non-empty directories intact
    
    @Test("pruneEmpty() leaves directories with files intact")
    func pruneEmptyLeavesNonEmptyDirs() throws {
        let tempDir = try createTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create structure: a/b/c where 'b' has a file
        let dirA = tempDir.appendingPathComponent("a")
        let dirB = dirA.appendingPathComponent("b")
        let dirC = dirB.appendingPathComponent("c")
        try FileManager.default.createDirectory(at: dirC, withIntermediateDirectories: true)
        
        // Put a file in 'b'
        let fileInB = dirB.appendingPathComponent("keep-me.txt")
        try "content".write(to: fileInB, atomically: true, encoding: .utf8)
        
        var pruner = DirectoryPruner(boundary: tempDir.path)
        pruner.add(parentOf: dirC.appendingPathComponent("deleted-file.txt").path)
        
        let prunedCount = try pruner.pruneEmpty()
        
        // Only 'c' should be pruned (empty), 'b' and 'a' have content
        #expect(prunedCount == 1)
        #expect(!FileManager.default.fileExists(atPath: dirC.path))
        #expect(FileManager.default.fileExists(atPath: dirB.path))
        #expect(FileManager.default.fileExists(atPath: fileInB.path))
    }
    
    @Test("pruneEmpty() leaves directories with subdirectories intact")
    func pruneEmptyLeavesParentsOfNonEmptyDirs() throws {
        let tempDir = try createTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create structure: a/b/c (empty) and a/b/d (with file)
        let dirB = tempDir.appendingPathComponent("a/b")
        let dirC = dirB.appendingPathComponent("c")
        let dirD = dirB.appendingPathComponent("d")
        try FileManager.default.createDirectory(at: dirC, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dirD, withIntermediateDirectories: true)
        
        // Put a file in 'd'
        try "content".write(to: dirD.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        
        var pruner = DirectoryPruner(boundary: tempDir.path)
        pruner.add(parentOf: dirC.appendingPathComponent("deleted.txt").path)
        
        let prunedCount = try pruner.pruneEmpty()
        
        // Only 'c' should be pruned, 'b' still has 'd', 'a' still has 'b'
        #expect(prunedCount == 1)
        #expect(!FileManager.default.fileExists(atPath: dirC.path))
        #expect(FileManager.default.fileExists(atPath: dirB.path))
        #expect(FileManager.default.fileExists(atPath: dirD.path))
    }
}
