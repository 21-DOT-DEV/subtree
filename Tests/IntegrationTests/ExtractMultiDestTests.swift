import Testing
import Foundation

/// Integration tests for multi-destination extraction (012-multi-destination-extraction)
///
/// Tests the complete workflow of extracting files to multiple destinations using
/// multiple `--to` flags (fan-out semantics).
///
/// **Purist Approach**: No library imports. Tests execute CLI commands only and validate
/// via file system checks, stdout/stderr output, and YAML string matching.
@Suite("Extract Multi-Destination Integration Tests")
struct ExtractMultiDestTests {
    
    // MARK: - Helper Functions
    
    /// Create a subtree.yaml config file with a single subtree
    private func writeSubtreeConfig(
        name: String,
        remote: String,
        prefix: String,
        commit: String,
        to path: String
    ) throws {
        let yaml = """
        subtrees:
          - name: \(name)
            remote: \(remote)
            prefix: \(prefix)
            commit: \(commit)
        """
        try yaml.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    /// Create test files in a directory structure
    private func createTestFiles(
        in directory: String,
        files: [(path: String, content: String)]
    ) throws {
        let fm = FileManager.default
        for (path, content) in files {
            let fullPath = directory + "/" + path
            let dirPath = (fullPath as NSString).deletingLastPathComponent
            try fm.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
            try content.write(toFile: fullPath, atomically: true, encoding: .utf8)
        }
    }
    
    // MARK: - Phase 3: P1 User Stories (US1 + US2)
    
    // T027: Multiple --to flags extract to all destinations
    @Test("Multiple --to flags extract files to all destinations")
    func testMultipleToFlagsExtractToAllDestinations() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree directory with test files
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("include/header.h", "// header"),
            ("src/impl.c", "// impl")
        ])
        
        // Create subtree config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        // Extract to two destinations
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/*", "--to", "Dest1/", "--to", "Dest2/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0, "Should succeed. stderr: \(result.stderr)")
        
        // Verify files exist in both destinations
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/Dest1/include/header.h"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/Dest1/src/impl.c"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/Dest2/include/header.h"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/Dest2/src/impl.c"))
    }
    
    // T028: Same files appear in every destination
    @Test("Same files appear in every destination with identical content")
    func testSameFilesInEveryDestination() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let content = "// unique content \(UUID())"
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("file.txt", content)
        ])
        
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/*", "--to", "A/", "--to", "B/", "--to", "C/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        
        // All destinations should have identical content
        let contentA = try String(contentsOfFile: fixture.path.string + "/A/file.txt", encoding: .utf8)
        let contentB = try String(contentsOfFile: fixture.path.string + "/B/file.txt", encoding: .utf8)
        let contentC = try String(contentsOfFile: fixture.path.string + "/C/file.txt", encoding: .utf8)
        
        #expect(contentA == content)
        #expect(contentB == content)
        #expect(contentC == content)
    }
    
    // T029: Directory structure preserved identically
    @Test("Directory structure preserved identically at each destination")
    func testDirectoryStructurePreserved() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("a/b/c/deep.txt", "deep"),
            ("x/shallow.txt", "shallow")
        ])
        
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/*", "--to", "Out1/", "--to", "Out2/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        
        let fm = FileManager.default
        // Same structure in both destinations
        #expect(fm.fileExists(atPath: fixture.path.string + "/Out1/a/b/c/deep.txt"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/Out1/x/shallow.txt"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/Out2/a/b/c/deep.txt"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/Out2/x/shallow.txt"))
    }
    
    // T030: Duplicate destinations deduplicated (./Lib = Lib/ = Lib)
    @Test("Duplicate destinations are deduplicated")
    func testDuplicateDestinationsDeduplicated() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("file.txt", "content")
        ])
        
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        // Use equivalent paths that should deduplicate
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/*", "--to", "Lib/", "--to", "./Lib", "--to", "Lib"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        
        // Should only show one destination in output (deduplicated)
        let outputLines = result.stdout.components(separatedBy: "\n")
            .filter { $0.contains("Extracted") }
        #expect(outputLines.count == 1, "Should deduplicate to single destination. Got: \(result.stdout)")
    }
    
    // T031: Per-destination success output shown
    @Test("Per-destination success output is shown")
    func testPerDestinationOutput() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("file.txt", "content")
        ])
        
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/*", "--to", "Dest1/", "--to", "Dest2/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        
        // Should show output for each destination
        #expect(result.stdout.contains("Dest1") || result.stdout.contains("Dest1/"), "Should mention Dest1")
        #expect(result.stdout.contains("Dest2") || result.stdout.contains("Dest2/"), "Should mention Dest2")
    }
    
    // T031b: Overlapping destinations both receive files
    @Test("Overlapping destinations both receive files")
    func testOverlappingDestinations() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("file.txt", "content")
        ])
        
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        // Overlapping: Lib/ and Lib/Sub/
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/*", "--to", "Lib/", "--to", "Lib/Sub/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        
        let fm = FileManager.default
        // Both destinations should have the file
        #expect(fm.fileExists(atPath: fixture.path.string + "/Lib/file.txt"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/Lib/Sub/file.txt"))
    }
    
    // T032: Legacy string `to` format still works
    @Test("Legacy single --to flag still works")
    func testLegacySingleToWorks() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("file.txt", "content")
        ])
        
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        // Single --to (backward compatible)
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/*", "--to", "Output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/Output/file.txt"))
    }
    
    // T033: --persist stores destinations as array
    @Test("Persist stores multiple destinations as array")
    func testPersistStoresDestinationsAsArray() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("file.txt", "content")
        ])
        
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        // Extract with persist and multiple destinations
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/*.txt", "--to", "Lib/", "--to", "Vendor/", "--persist"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0, "Should succeed. stderr: \(result.stderr)")
        
        // Check YAML has array format for to
        let configContent = try String(contentsOfFile: fixture.path.string + "/subtree.yaml", encoding: .utf8)
        #expect(configContent.contains("- Lib/") || configContent.contains("- \"Lib/\""), 
                "Should have array with Lib/. Config: \(configContent)")
        #expect(configContent.contains("- Vendor/") || configContent.contains("- \"Vendor/\""),
                "Should have array with Vendor/. Config: \(configContent)")
    }
    
    // T034: Bulk extract with persisted array destinations works
    @Test("Bulk extract with persisted multi-destination mappings")
    func testBulkExtractWithPersistedMultiDest() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("file.txt", "content")
        ])
        
        // Create config with multi-destination mapping already saved
        let yaml = """
        subtrees:
          - name: lib
            remote: https://example.com/lib.git
            prefix: vendor/lib
            commit: \(try await fixture.getCurrentCommit())
            extractions:
              - from: "**/*.txt"
                to:
                  - "BulkDest1/"
                  - "BulkDest2/"
        """
        try yaml.write(toFile: fixture.path.string + "/subtree.yaml", atomically: true, encoding: .utf8)
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        // Run bulk extraction
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0, "Should succeed. stderr: \(result.stderr)")
        
        // Both destinations should have the file
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/BulkDest1/file.txt"), 
                "BulkDest1 should have file")
        #expect(fm.fileExists(atPath: fixture.path.string + "/BulkDest2/file.txt"),
                "BulkDest2 should have file")
    }
    
    // MARK: - Phase 4: US3 (Clean Mode)
    
    // T043: --clean removes files from all destinations
    @Test("Clean removes files from all destinations")
    func testCleanRemovesFromAllDestinations() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("file.txt", "content")
        ])
        
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        // First extract to multiple destinations
        _ = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/*", "--to", "Dest1/", "--to", "Dest2/"],
            workingDirectory: fixture.path
        )
        
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/Dest1/file.txt"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/Dest2/file.txt"))
        
        // Now clean from all destinations
        let cleanResult = try await harness.run(
            arguments: ["extract", "--clean", "--name", "lib", "--from", "**/*", "--to", "Dest1/", "--to", "Dest2/"],
            workingDirectory: fixture.path
        )
        
        #expect(cleanResult.exitCode == 0, "Clean should succeed. stderr: \(cleanResult.stderr)")
        #expect(!fm.fileExists(atPath: fixture.path.string + "/Dest1/file.txt"), "Dest1 file should be removed")
        #expect(!fm.fileExists(atPath: fixture.path.string + "/Dest2/file.txt"), "Dest2 file should be removed")
    }
    
    // T044: Clean with persisted multi-dest mapping works
    @Test("Clean with persisted multi-destination mapping")
    func testCleanWithPersistedMultiDestMapping() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("file.txt", "content")
        ])
        
        // Create config with multi-destination mapping
        let yaml = """
        subtrees:
          - name: lib
            remote: https://example.com/lib.git
            prefix: vendor/lib
            commit: \(try await fixture.getCurrentCommit())
            extractions:
              - from: "**/*.txt"
                to:
                  - "CleanDest1/"
                  - "CleanDest2/"
        """
        try yaml.write(toFile: fixture.path.string + "/subtree.yaml", atomically: true, encoding: .utf8)
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        // Extract using bulk mode
        _ = try await harness.run(
            arguments: ["extract", "--name", "lib"],
            workingDirectory: fixture.path
        )
        
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/CleanDest1/file.txt"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/CleanDest2/file.txt"))
        
        // Clean using bulk mode
        let cleanResult = try await harness.run(
            arguments: ["extract", "--clean", "--name", "lib"],
            workingDirectory: fixture.path
        )
        
        #expect(cleanResult.exitCode == 0, "Clean should succeed. stderr: \(cleanResult.stderr)")
        #expect(!fm.fileExists(atPath: fixture.path.string + "/CleanDest1/file.txt"))
        #expect(!fm.fileExists(atPath: fixture.path.string + "/CleanDest2/file.txt"))
    }
    
    // T045: Clean fails-fast if checksum mismatch in any destination
    @Test("Clean fails if checksum mismatch in any destination")
    func testCleanFailsOnChecksumMismatch() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("file.txt", "original")
        ])
        
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        // Extract to multiple destinations
        _ = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/*", "--to", "Dest1/", "--to", "Dest2/"],
            workingDirectory: fixture.path
        )
        
        // Modify file in one destination
        try "modified".write(toFile: fixture.path.string + "/Dest2/file.txt", atomically: true, encoding: .utf8)
        
        // Clean should fail due to checksum mismatch
        let cleanResult = try await harness.run(
            arguments: ["extract", "--clean", "--name", "lib", "--from", "**/*", "--to", "Dest1/", "--to", "Dest2/"],
            workingDirectory: fixture.path
        )
        
        #expect(cleanResult.exitCode != 0, "Clean should fail on checksum mismatch")
        #expect(cleanResult.stderr.contains("modified") || cleanResult.stderr.contains("checksum"),
                "Should mention modification. stderr: \(cleanResult.stderr)")
    }
    
    // T046: Per-destination clean output shown
    @Test("Per-destination clean output is shown")
    func testPerDestinationCleanOutput() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("file.txt", "content")
        ])
        
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        // Extract to multiple destinations
        _ = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/*", "--to", "Out1/", "--to", "Out2/"],
            workingDirectory: fixture.path
        )
        
        // Clean
        let cleanResult = try await harness.run(
            arguments: ["extract", "--clean", "--name", "lib", "--from", "**/*", "--to", "Out1/", "--to", "Out2/"],
            workingDirectory: fixture.path
        )
        
        #expect(cleanResult.exitCode == 0)
        // Output should mention both destinations
        #expect(cleanResult.stdout.contains("Out1") || cleanResult.stdout.contains("Out1/"),
                "Should mention Out1. stdout: \(cleanResult.stdout)")
        #expect(cleanResult.stdout.contains("Out2") || cleanResult.stdout.contains("Out2/"),
                "Should mention Out2. stdout: \(cleanResult.stdout)")
    }
    
    // MARK: - Phase 4: US4 (Fail-Fast Overwrite Protection)
    
    // T047: Overwrite protection validates ALL destinations upfront
    @Test("Overwrite protection validates all destinations upfront")
    func testOverwriteProtectionValidatesAllDestinations() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("file.txt", "content")
        ])
        
        // Create tracked file in second destination only
        try createTestFiles(in: fixture.path.string + "/Dest2", files: [
            ("file.txt", "tracked")
        ])
        
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup with tracked file"])
        
        // Extract should fail because Dest2 has tracked file
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/*", "--to", "Dest1/", "--to", "Dest2/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode != 0, "Should fail due to tracked file conflict")
        #expect(result.stderr.contains("git-tracked") || result.stderr.contains("Dest2"),
                "Should mention conflict. stderr: \(result.stderr)")
    }
    
    // T048: No files copied if any destination has conflicts
    @Test("No files copied if any destination has conflicts")
    func testNoFilesCopiedOnConflict() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("newfile.txt", "new content")
        ])
        
        // Create tracked file in second destination
        try createTestFiles(in: fixture.path.string + "/Dest2", files: [
            ("newfile.txt", "tracked")
        ])
        
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        // Extract should fail
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/*", "--to", "Dest1/", "--to", "Dest2/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode != 0)
        
        // Verify Dest1 was NOT populated (fail-fast)
        let fm = FileManager.default
        #expect(!fm.fileExists(atPath: fixture.path.string + "/Dest1/newfile.txt"),
                "Dest1 should not have file when Dest2 has conflict")
    }
    
    // T049: Error lists conflicts across all destinations
    @Test("Error lists conflicts across all destinations")
    func testErrorListsAllConflicts() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("file1.txt", "content1"),
            ("file2.txt", "content2")
        ])
        
        // Create tracked files in BOTH destinations
        try createTestFiles(in: fixture.path.string + "/Dest1", files: [
            ("file1.txt", "tracked1")
        ])
        try createTestFiles(in: fixture.path.string + "/Dest2", files: [
            ("file2.txt", "tracked2")
        ])
        
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup with conflicts in both dests"])
        
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/*", "--to", "Dest1/", "--to", "Dest2/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode != 0)
        // Should mention files from both destinations in error
        #expect(result.stderr.contains("file1.txt") || result.stderr.contains("file2.txt"),
                "Should list conflicting files. stderr: \(result.stderr)")
    }
    
    // T050: --force bypasses protection for all destinations
    @Test("Force flag bypasses protection for all destinations")
    func testForceBypasses() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("file.txt", "new content")
        ])
        
        // Create tracked files in both destinations
        try createTestFiles(in: fixture.path.string + "/Dest1", files: [
            ("file.txt", "tracked1")
        ])
        try createTestFiles(in: fixture.path.string + "/Dest2", files: [
            ("file.txt", "tracked2")
        ])
        
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        // With --force, should succeed
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/*", "--to", "Dest1/", "--to", "Dest2/", "--force"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0, "Should succeed with --force. stderr: \(result.stderr)")
        
        // Both destinations should have new content
        let content1 = try String(contentsOfFile: fixture.path.string + "/Dest1/file.txt", encoding: .utf8)
        let content2 = try String(contentsOfFile: fixture.path.string + "/Dest2/file.txt", encoding: .utf8)
        #expect(content1 == "new content")
        #expect(content2 == "new content")
    }
    
    // MARK: - Phase 4: US5 (Bulk Mode)
    
    // T051: --all processes multi-dest mappings correctly
    @Test("Bulk --all processes multi-destination mappings")
    func testBulkAllMultiDest() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib1", files: [
            ("file1.txt", "lib1 content")
        ])
        try createTestFiles(in: fixture.path.string + "/vendor/lib2", files: [
            ("file2.txt", "lib2 content")
        ])
        
        // Config with two subtrees, each with multi-dest mappings
        let yaml = """
        subtrees:
          - name: lib1
            remote: https://example.com/lib1.git
            prefix: vendor/lib1
            commit: \(try await fixture.getCurrentCommit())
            extractions:
              - from: "**/*.txt"
                to:
                  - "Lib1A/"
                  - "Lib1B/"
          - name: lib2
            remote: https://example.com/lib2.git
            prefix: vendor/lib2
            commit: \(try await fixture.getCurrentCommit())
            extractions:
              - from: "**/*.txt"
                to:
                  - "Lib2A/"
                  - "Lib2B/"
        """
        try yaml.write(toFile: fixture.path.string + "/subtree.yaml", atomically: true, encoding: .utf8)
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        let result = try await harness.run(
            arguments: ["extract", "--all"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0, "Should succeed. stderr: \(result.stderr)")
        
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/Lib1A/file1.txt"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/Lib1B/file1.txt"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/Lib2A/file2.txt"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/Lib2B/file2.txt"))
    }
    
    // T052: --clean --all removes from all destinations
    @Test("Clean --all removes from all multi-destination mappings")
    func testCleanAllMultiDest() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("file.txt", "content")
        ])
        
        let yaml = """
        subtrees:
          - name: lib
            remote: https://example.com/lib.git
            prefix: vendor/lib
            commit: \(try await fixture.getCurrentCommit())
            extractions:
              - from: "**/*.txt"
                to:
                  - "AllDest1/"
                  - "AllDest2/"
        """
        try yaml.write(toFile: fixture.path.string + "/subtree.yaml", atomically: true, encoding: .utf8)
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup"])
        
        // Extract first
        _ = try await harness.run(
            arguments: ["extract", "--all"],
            workingDirectory: fixture.path
        )
        
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/AllDest1/file.txt"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/AllDest2/file.txt"))
        
        // Clean all
        let cleanResult = try await harness.run(
            arguments: ["extract", "--clean", "--all"],
            workingDirectory: fixture.path
        )
        
        #expect(cleanResult.exitCode == 0, "Should succeed. stderr: \(cleanResult.stderr)")
        #expect(!fm.fileExists(atPath: fixture.path.string + "/AllDest1/file.txt"))
        #expect(!fm.fileExists(atPath: fixture.path.string + "/AllDest2/file.txt"))
    }
    
    // T053: Continue-on-error per subtree (not per destination)
    @Test("Continue-on-error applies per subtree not per destination")
    func testContinueOnErrorPerSubtree() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        try createTestFiles(in: fixture.path.string + "/vendor/lib1", files: [
            ("file1.txt", "lib1")
        ])
        try createTestFiles(in: fixture.path.string + "/vendor/lib2", files: [
            ("file2.txt", "lib2")
        ])
        
        // Create conflict in lib1's second destination
        try createTestFiles(in: fixture.path.string + "/Lib1B", files: [
            ("file1.txt", "conflict")
        ])
        
        let yaml = """
        subtrees:
          - name: lib1
            remote: https://example.com/lib1.git
            prefix: vendor/lib1
            commit: \(try await fixture.getCurrentCommit())
            extractions:
              - from: "**/*.txt"
                to:
                  - "Lib1A/"
                  - "Lib1B/"
          - name: lib2
            remote: https://example.com/lib2.git
            prefix: vendor/lib2
            commit: \(try await fixture.getCurrentCommit())
            extractions:
              - from: "**/*.txt"
                to:
                  - "Lib2A/"
                  - "Lib2B/"
        """
        try yaml.write(toFile: fixture.path.string + "/subtree.yaml", atomically: true, encoding: .utf8)
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Setup with conflict in lib1"])
        
        let result = try await harness.run(
            arguments: ["extract", "--all"],
            workingDirectory: fixture.path
        )
        
        // Should have non-zero exit (lib1 failed), but lib2 should still complete
        #expect(result.exitCode != 0, "Should fail due to lib1 conflict")
        
        let fm = FileManager.default
        // lib1 destinations should NOT be populated (failed)
        #expect(!fm.fileExists(atPath: fixture.path.string + "/Lib1A/file1.txt"),
                "Lib1A should not have file when Lib1B has conflict")
        
        // lib2 destinations SHOULD be populated (continue-on-error)
        #expect(fm.fileExists(atPath: fixture.path.string + "/Lib2A/file2.txt"),
                "Lib2 should still succeed despite lib1 failure")
        #expect(fm.fileExists(atPath: fixture.path.string + "/Lib2B/file2.txt"))
    }
}
