import Testing
import Foundation

/// Integration tests for multi-pattern extraction (009-multi-pattern-extraction)
///
/// Tests the complete workflow of extracting files using multiple `--from` patterns.
///
/// **Purist Approach**: No library imports. Tests execute CLI commands only and validate
/// via file system checks, stdout/stderr output, and YAML string matching.
@Suite("Extract Multi-Pattern Integration Tests")
struct ExtractMultiPatternTests {
    
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
    
    // MARK: - Phase 3: P1 User Stories (T016-T021)
    
    // T016: Multiple --from flags extract union of files
    @Test("Multiple --from flags extract union of files")
    func testMultipleFromFlagsExtractUnion() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree directory with files in different subdirs
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("include/header1.h", "// header1"),
            ("include/header2.h", "// header2"),
            ("src/impl1.c", "// impl1"),
            ("src/impl2.c", "// impl2"),
            ("docs/readme.md", "# readme")
        ])
        
        // Create subtree.yaml
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit config
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add lib subtree"])
        
        // Run extract with multiple --from flags
        let result = try await harness.run(
            arguments: [
                "extract", "--name", "lib",
                "--from", "include/**/*.h",
                "--from", "src/**/*.c",
                "--to", "output/"
            ],
            workingDirectory: fixture.path
        )
        
        // Verify success
        #expect(result.exitCode == 0, "Should succeed. stderr: \(result.stderr)")
        #expect(result.stdout.contains("Extracted"), "Should show extraction message")
        
        // Verify files from both patterns extracted (full paths preserved)
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/include/header1.h"), "header1.h should exist")
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/include/header2.h"), "header2.h should exist")
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/src/impl1.c"), "impl1.c should exist")
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/src/impl2.c"), "impl2.c should exist")
        
        // Verify docs NOT extracted (not in patterns)
        #expect(!fm.fileExists(atPath: fixture.path.string + "/output/docs/readme.md"), "readme.md should NOT exist")
    }
    
    // T017: Duplicate files extracted once (no duplicates)
    @Test("Duplicate files extracted once when patterns overlap")
    func testDuplicateFilesExtractedOnce() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree directory with overlapping patterns
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("src/main.c", "// main"),
            ("src/crypto/aes.c", "// aes")  // This will match both patterns
        ])
        
        // Create subtree.yaml
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit config
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add lib subtree"])
        
        // Run extract with overlapping patterns
        let result = try await harness.run(
            arguments: [
                "extract", "--name", "lib",
                "--from", "src/**/*.c",        // Matches all .c files
                "--from", "src/crypto/*.c",    // Also matches crypto .c files
                "--to", "output/"
            ],
            workingDirectory: fixture.path
        )
        
        // Verify success (no duplicate errors)
        #expect(result.exitCode == 0, "Should succeed without duplicate errors. stderr: \(result.stderr)")
        
        // Verify files exist (extracted once, full paths preserved)
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/src/main.c"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/src/crypto/aes.c"))
    }
    
    // T018: Different directory depths preserve relative paths
    @Test("Different directory depths preserve relative paths")
    func testDifferentDepthsPreservePaths() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree directory with varying depths
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("a.h", "// root level"),
            ("level1/b.h", "// one level"),
            ("level1/level2/c.h", "// two levels"),
            ("level1/level2/level3/d.h", "// three levels")
        ])
        
        // Create subtree.yaml
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit config
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add lib subtree"])
        
        // Run extract
        let result = try await harness.run(
            arguments: [
                "extract", "--name", "lib",
                "--from", "**/*.h",
                "--to", "headers/"
            ],
            workingDirectory: fixture.path
        )
        
        // Verify success
        #expect(result.exitCode == 0, "Should succeed. stderr: \(result.stderr)")
        
        // Verify paths preserved at all depths
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/headers/a.h"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/headers/level1/b.h"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/headers/level1/level2/c.h"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/headers/level1/level2/level3/d.h"))
    }
    
    // T019: Legacy string format still works
    @Test("Legacy string format in config still works")
    func testLegacyStringFormatWorks() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree directory
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("docs/readme.md", "# README")
        ])
        
        // Create subtree.yaml with LEGACY string format (single pattern)
        let yaml = """
        subtrees:
          - name: lib
            remote: https://example.com/lib.git
            prefix: vendor/lib
            commit: \(try await fixture.getCurrentCommit())
            extractions:
              - from: "docs/**/*.md"
                to: "output/"
        """
        try yaml.write(toFile: fixture.path.string + "/subtree.yaml", atomically: true, encoding: .utf8)
        
        // Commit config
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add lib subtree"])
        
        // Run bulk extraction (uses saved mapping)
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib"],
            workingDirectory: fixture.path
        )
        
        // Verify success
        #expect(result.exitCode == 0, "Should succeed with legacy format. stderr: \(result.stderr)")
        
        // Verify file extracted (full path preserved)
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/docs/readme.md"))
    }
    
    // T020: Array format in config works
    @Test("Array format in config works")
    func testArrayFormatInConfigWorks() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree directory
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("include/api.h", "// api"),
            ("src/impl.c", "// impl")
        ])
        
        // Create subtree.yaml with NEW array format
        let yaml = """
        subtrees:
          - name: lib
            remote: https://example.com/lib.git
            prefix: vendor/lib
            commit: \(try await fixture.getCurrentCommit())
            extractions:
              - from:
                  - "include/**/*.h"
                  - "src/**/*.c"
                to: "output/"
        """
        try yaml.write(toFile: fixture.path.string + "/subtree.yaml", atomically: true, encoding: .utf8)
        
        // Commit config
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add lib subtree"])
        
        // Run bulk extraction (uses saved mapping with array)
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib"],
            workingDirectory: fixture.path
        )
        
        // Verify success
        #expect(result.exitCode == 0, "Should succeed with array format. stderr: \(result.stderr)")
        
        // Verify files from both patterns extracted (full paths preserved)
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/include/api.h"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/src/impl.c"))
    }
    
    // T021: Mixed formats in same config work
    @Test("Mixed formats in same config work")
    func testMixedFormatsInConfigWork() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree directory
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("docs/readme.md", "# README"),
            ("include/api.h", "// api"),
            ("src/impl.c", "// impl")
        ])
        
        // Create subtree.yaml with MIXED formats (string and array)
        let yaml = """
        subtrees:
          - name: lib
            remote: https://example.com/lib.git
            prefix: vendor/lib
            commit: \(try await fixture.getCurrentCommit())
            extractions:
              - from: "docs/**/*.md"
                to: "docs-output/"
              - from:
                  - "include/**/*.h"
                  - "src/**/*.c"
                to: "code-output/"
        """
        try yaml.write(toFile: fixture.path.string + "/subtree.yaml", atomically: true, encoding: .utf8)
        
        // Commit config
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add lib subtree"])
        
        // Run bulk extraction
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib"],
            workingDirectory: fixture.path
        )
        
        // Verify success
        #expect(result.exitCode == 0, "Should succeed with mixed formats. stderr: \(result.stderr)")
        
        // Verify files from string format mapping (full path preserved)
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/docs-output/docs/readme.md"))
        
        // Verify files from array format mapping (full paths preserved)
        #expect(fm.fileExists(atPath: fixture.path.string + "/code-output/include/api.h"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/code-output/src/impl.c"))
    }
    
    // MARK: - Phase 4: P2 User Stories (T028-T033)
    
    // T028: --persist stores patterns as array
    @Test("--persist with multiple patterns stores as array in config")
    func testPersistStoresAsArray() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree directory with files
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("include/api.h", "// api"),
            ("src/impl.c", "// impl")
        ])
        
        // Create basic subtree.yaml
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit config
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add lib subtree"])
        
        // Run extract with --persist and multiple --from flags
        let result = try await harness.run(
            arguments: [
                "extract", "--name", "lib",
                "--from", "include/**/*.h",
                "--from", "src/**/*.c",
                "--to", "output/",
                "--persist"
            ],
            workingDirectory: fixture.path
        )
        
        // Verify success
        #expect(result.exitCode == 0, "Should succeed. stderr: \(result.stderr)")
        #expect(result.stdout.contains("📝") || result.stdout.contains("Saved"), "Should indicate mapping saved")
        
        // Verify YAML contains array format
        let yaml = try String(contentsOfFile: fixture.path.string + "/subtree.yaml", encoding: .utf8)
        #expect(yaml.contains("extractions:"), "Should have extractions section")
        #expect(yaml.contains("from:"), "Should have from field")
        // Array format should have pattern on separate lines
        #expect(yaml.contains("include/**/*.h"), "Should contain first pattern")
        #expect(yaml.contains("src/**/*.c"), "Should contain second pattern")
    }
    
    // T029: Bulk extract with persisted array works
    @Test("Bulk extract with persisted array patterns works")
    func testBulkExtractWithPersistedArray() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree directory with files
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("include/api.h", "// api"),
            ("src/impl.c", "// impl"),
            ("docs/readme.md", "# README")
        ])
        
        // Create subtree.yaml with array format extraction
        let yaml = """
        subtrees:
          - name: lib
            remote: https://example.com/lib.git
            prefix: vendor/lib
            commit: \(try await fixture.getCurrentCommit())
            extractions:
              - from:
                  - "include/**/*.h"
                  - "src/**/*.c"
                to: "code-output/"
        """
        try yaml.write(toFile: fixture.path.string + "/subtree.yaml", atomically: true, encoding: .utf8)
        
        // Commit config
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add lib subtree"])
        
        // Run bulk extraction
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib"],
            workingDirectory: fixture.path
        )
        
        // Verify success
        #expect(result.exitCode == 0, "Should succeed. stderr: \(result.stderr)")
        
        // Verify files from both patterns extracted
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/code-output/include/api.h"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/code-output/src/impl.c"))
        // Docs should NOT be extracted (not in patterns)
        #expect(!fm.fileExists(atPath: fixture.path.string + "/code-output/docs/readme.md"))
    }
    
    // T030: Duplicate exact mapping skipped (same from, to, exclude)
    @Test("Duplicate exact mapping is skipped with warning")
    func testDuplicateExactMappingSkipped() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree directory with files
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("src/impl.c", "// impl")
        ])
        
        // Create subtree.yaml with existing extraction
        let yaml = """
        subtrees:
          - name: lib
            remote: https://example.com/lib.git
            prefix: vendor/lib
            commit: \(try await fixture.getCurrentCommit())
            extractions:
              - from: "src/**/*.c"
                to: "output/"
        """
        try yaml.write(toFile: fixture.path.string + "/subtree.yaml", atomically: true, encoding: .utf8)
        
        // Commit config
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add lib subtree"])
        
        // Try to persist the EXACT same mapping again
        let result = try await harness.run(
            arguments: [
                "extract", "--name", "lib",
                "--from", "src/**/*.c",
                "--to", "output/",
                "--persist"
            ],
            workingDirectory: fixture.path
        )
        
        // Should succeed but skip saving duplicate
        #expect(result.exitCode == 0, "Should succeed. stderr: \(result.stderr)")
        #expect(result.stdout.contains("⚠️") || result.stdout.contains("already exists") || result.stdout.contains("skipping"),
               "Should indicate duplicate skipped")
        
        // Verify only one extraction in config (not duplicated)
        let updatedYaml = try String(contentsOfFile: fixture.path.string + "/subtree.yaml", encoding: .utf8)
        let fromCount = updatedYaml.components(separatedBy: "src/**/*.c").count - 1
        #expect(fromCount == 1, "Should have exactly one extraction mapping, not duplicated")
    }
    
    // T031: Exclude applies to all patterns
    @Test("Exclude applies to all patterns in multi-pattern extraction")
    func testExcludeAppliesToAllPatterns() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree directory with files including test files
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("include/api.h", "// api"),
            ("include/test_api.h", "// test api"),  // Should be excluded
            ("src/impl.c", "// impl"),
            ("src/test_impl.c", "// test impl")     // Should be excluded
        ])
        
        // Create subtree.yaml
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit config
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add lib subtree"])
        
        // Run extract with multiple patterns and exclude
        let result = try await harness.run(
            arguments: [
                "extract", "--name", "lib",
                "--from", "include/**/*.h",
                "--from", "src/**/*.c",
                "--to", "output/",
                "--exclude", "**/test_*"
            ],
            workingDirectory: fixture.path
        )
        
        // Verify success
        #expect(result.exitCode == 0, "Should succeed. stderr: \(result.stderr)")
        
        // Verify non-test files extracted
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/include/api.h"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/src/impl.c"))
        
        // Verify test files excluded from BOTH patterns
        #expect(!fm.fileExists(atPath: fixture.path.string + "/output/include/test_api.h"),
               "test_api.h should be excluded")
        #expect(!fm.fileExists(atPath: fixture.path.string + "/output/src/test_impl.c"),
               "test_impl.c should be excluded")
    }
    
    // T032: Exclude filters from only matching pattern
    @Test("Exclude only filters files that match the exclude pattern")
    func testExcludeOnlyFiltersMatching() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with specific structure
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("include/api.h", "// api"),
            ("include/internal/private.h", "// private"),  // Should be excluded
            ("src/impl.c", "// impl"),
            ("src/util.c", "// util")
        ])
        
        // Create subtree.yaml
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit config
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add lib subtree"])
        
        // Run extract excluding internal headers
        let result = try await harness.run(
            arguments: [
                "extract", "--name", "lib",
                "--from", "include/**/*.h",
                "--from", "src/**/*.c",
                "--to", "output/",
                "--exclude", "**/internal/**"
            ],
            workingDirectory: fixture.path
        )
        
        // Verify success
        #expect(result.exitCode == 0, "Should succeed. stderr: \(result.stderr)")
        
        // Verify public header extracted
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/include/api.h"))
        
        // Verify internal header excluded
        #expect(!fm.fileExists(atPath: fixture.path.string + "/output/include/internal/private.h"),
               "internal/private.h should be excluded")
        
        // Verify src files unaffected by internal exclude
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/src/impl.c"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/src/util.c"))
    }
    
    // T033: Exclude behavior verified with multiple patterns (comprehensive)
    @Test("Multiple excludes work correctly with multiple patterns")
    func testMultipleExcludesWithMultiplePatterns() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create comprehensive test structure
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("include/api.h", "// api"),
            ("include/test/test_api.h", "// test api"),     // Excluded by test/**
            ("include/internal/secret.h", "// secret"),      // Excluded by internal/**
            ("src/main.c", "// main"),
            ("src/test/test_main.c", "// test main"),       // Excluded by test/**
            ("src/bench/bench_main.c", "// bench")          // Excluded by bench/**
        ])
        
        // Create subtree.yaml
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit config
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add lib subtree"])
        
        // Run extract with multiple excludes
        let result = try await harness.run(
            arguments: [
                "extract", "--name", "lib",
                "--from", "include/**/*.h",
                "--from", "src/**/*.c",
                "--to", "output/",
                "--exclude", "**/test/**",
                "--exclude", "**/bench/**",
                "--exclude", "**/internal/**"
            ],
            workingDirectory: fixture.path
        )
        
        // Verify success
        #expect(result.exitCode == 0, "Should succeed. stderr: \(result.stderr)")
        
        // Verify non-excluded files extracted
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/include/api.h"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/src/main.c"))
        
        // Verify all excluded patterns work
        #expect(!fm.fileExists(atPath: fixture.path.string + "/output/include/test"),
               "test directory should be excluded")
        #expect(!fm.fileExists(atPath: fixture.path.string + "/output/include/internal"),
               "internal directory should be excluded")
        #expect(!fm.fileExists(atPath: fixture.path.string + "/output/src/test"),
               "src/test should be excluded")
        #expect(!fm.fileExists(atPath: fixture.path.string + "/output/src/bench"),
               "src/bench should be excluded")
    }
    
    // MARK: - Phase 5: P3 User Stories (T037-T039)
    
    // T037: Zero-match pattern shows warning
    @Test("Zero-match pattern shows warning while others succeed")
    func testZeroMatchPatternShowsWarning() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with only src files (no include/)
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("src/impl.c", "// impl"),
            ("src/util.c", "// util")
        ])
        
        // Create subtree.yaml
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit config
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add lib subtree"])
        
        // Run extract with one valid and one zero-match pattern
        let result = try await harness.run(
            arguments: [
                "extract", "--name", "lib",
                "--from", "src/**/*.c",       // Matches files
                "--from", "include/**/*.h",    // No matches (include/ doesn't exist)
                "--to", "output/"
            ],
            workingDirectory: fixture.path
        )
        
        // Should succeed (some patterns matched)
        #expect(result.exitCode == 0, "Should succeed when some patterns match. stderr: \(result.stderr)")
        
        // Should show warning for zero-match pattern
        #expect(result.stdout.contains("⚠️") || result.stdout.contains("warning") || result.stdout.contains("no files"),
               "Should warn about zero-match pattern. stdout: \(result.stdout)")
        #expect(result.stdout.contains("include/**/*.h") || result.stdout.contains("0 files"),
               "Should mention the zero-match pattern")
        
        // Verify matching files still extracted
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/src/impl.c"))
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/src/util.c"))
    }
    
    // T038: All patterns zero-match exits with error
    @Test("All patterns zero-match exits with error")
    func testAllPatternsZeroMatchExitsError() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with only docs (no src/ or include/)
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("docs/readme.md", "# README")
        ])
        
        // Create subtree.yaml
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit config
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add lib subtree"])
        
        // Run extract with patterns that match nothing
        let result = try await harness.run(
            arguments: [
                "extract", "--name", "lib",
                "--from", "src/**/*.c",        // No matches
                "--from", "include/**/*.h",    // No matches
                "--to", "output/"
            ],
            workingDirectory: fixture.path
        )
        
        // Should fail with error exit code
        #expect(result.exitCode != 0, "Should fail when all patterns match nothing")
        
        // Should show error message
        #expect(result.stderr.contains("❌") || result.stderr.contains("No files matched"),
               "Should show error message. stderr: \(result.stderr)")
    }
    
    // T039: Exit code 0 when some patterns match
    @Test("Exit code 0 when at least one pattern matches")
    func testExitCodeZeroWhenSomePatternsMatch() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with only specific files
        try createTestFiles(in: fixture.path.string + "/vendor/lib", files: [
            ("include/api.h", "// api"),
            ("docs/readme.md", "# README")
        ])
        
        // Create subtree.yaml
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: try await fixture.getCurrentCommit(),
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit config
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add lib subtree"])
        
        // Run extract with mix of matching and non-matching patterns
        let result = try await harness.run(
            arguments: [
                "extract", "--name", "lib",
                "--from", "include/**/*.h",    // Matches
                "--from", "src/**/*.c",        // No matches
                "--from", "lib/**/*.a",        // No matches
                "--to", "output/"
            ],
            workingDirectory: fixture.path
        )
        
        // Should succeed (at least one pattern matched)
        #expect(result.exitCode == 0, "Should succeed when at least one pattern matches. stderr: \(result.stderr)")
        
        // Verify file extracted
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: fixture.path.string + "/output/include/api.h"))
    }
}
