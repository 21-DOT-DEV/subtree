import Foundation

/// Batch structure for efficient empty directory pruning
///
/// Collects directories that may become empty after file deletions,
/// then removes them bottom-up (deepest first) up to a boundary.
///
/// Used by Extract Clean Mode to prune empty directories after
/// removing extracted files.
///
/// # Usage
/// ```swift
/// var pruner = DirectoryPruner(boundary: "/path/to/dest")
/// pruner.add(parentOf: "/path/to/dest/sub/file.txt")
/// let pruned = try pruner.pruneEmpty()
/// ```
public struct DirectoryPruner {
    
    /// Directories to check for pruning (uses Set for deduplication)
    private var directories: Set<String> = []
    
    /// Boundary path - never prune this directory or its ancestors
    public let boundary: String
    
    /// Number of directories currently queued for potential pruning
    public var directoryCount: Int {
        directories.count
    }
    
    /// Initialize pruner with a boundary directory
    ///
    /// - Parameter boundary: Absolute path to the boundary directory.
    ///   This directory and its ancestors will never be pruned.
    public init(boundary: String) {
        self.boundary = boundary
    }
    
    /// Add the parent directory (and ancestors up to boundary) of a file path
    ///
    /// Call this for each file that has been deleted. The pruner will
    /// collect all ancestor directories up to (but not including) the boundary.
    ///
    /// - Parameter filePath: Absolute path to a deleted file
    public mutating func add(parentOf filePath: String) {
        var currentDir = (filePath as NSString).deletingLastPathComponent
        
        // Walk up the directory tree, collecting directories until we hit boundary
        while currentDir != boundary && currentDir.hasPrefix(boundary) && currentDir != "/" {
            directories.insert(currentDir)
            currentDir = (currentDir as NSString).deletingLastPathComponent
        }
    }
    
    /// Remove all empty directories, processing deepest first (bottom-up)
    ///
    /// Sorts collected directories by depth (deepest first) and attempts
    /// to remove each one. A directory is only removed if it's empty.
    /// Processing bottom-up ensures child directories are removed before
    /// their parents are checked.
    ///
    /// - Returns: Count of directories that were successfully pruned
    /// - Throws: Only throws for unexpected filesystem errors (not for non-empty dirs)
    public func pruneEmpty() throws -> Int {
        let fileManager = FileManager.default
        var prunedCount = 0
        
        // Sort by depth descending (deepest directories first)
        let sortedDirs = directories.sorted { path1, path2 in
            path1.components(separatedBy: "/").count > path2.components(separatedBy: "/").count
        }
        
        for dir in sortedDirs {
            // Skip if directory doesn't exist (already pruned or never existed)
            guard fileManager.fileExists(atPath: dir) else { continue }
            
            // Check if directory is empty
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: dir)
                if contents.isEmpty {
                    try fileManager.removeItem(atPath: dir)
                    prunedCount += 1
                }
            } catch {
                // Skip directories we can't read (permissions, etc.)
                // Don't throw - continue with other directories
                continue
            }
        }
        
        return prunedCount
    }
}
