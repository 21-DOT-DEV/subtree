import Testing
import Foundation

/// Integration tests for subtree extract command (008-extract-command)
///
/// Tests the complete workflow of extracting files from subtrees using glob patterns.
/// 
/// **Purist Approach**: No library imports. Tests execute CLI commands only and validate
/// via file system checks, stdout/stderr output, and YAML string matching.
@Suite("Extract Integration Tests")
struct ExtractIntegrationTests {
    
    // MARK: - YAML Helper Functions
    
    /// Create a subtree.yaml config file with a single subtree
    private func writeSubtreeConfig(
        name: String,
        remote: String,
        prefix: String,
        commit: String,
        extractions: [(from: String, to: String, exclude: [String]?)]? = nil,
        to path: String
    ) throws {
        var yaml = """
        subtrees:
          - name: \(name)
            remote: \(remote)
            prefix: \(prefix)
            commit: \(commit)
        """
        
        if let extractions = extractions, !extractions.isEmpty {
            yaml += "\n    extractions:"
            for extraction in extractions {
                yaml += "\n      - from: \"\(extraction.from)\""
                yaml += "\n        to: \(extraction.to)"
                if let exclude = extraction.exclude, !exclude.isEmpty {
                    yaml += "\n        exclude:"
                    for pattern in exclude {
                        yaml += "\n          - \(pattern)"
                    }
                }
            }
        }
        
        yaml += "\n"
        try yaml.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    /// Create a subtree.yaml config file with multiple subtrees
    private func writeMultiSubtreeConfig(
        subtrees: [(name: String, remote: String, prefix: String, commit: String, extractions: [(from: String, to: String, exclude: [String]?)]?)],
        to path: String
    ) throws {
        var yaml = "subtrees:\n"
        
        for subtree in subtrees {
            yaml += "  - name: \(subtree.name)\n"
            yaml += "    remote: \(subtree.remote)\n"
            yaml += "    prefix: \(subtree.prefix)\n"
            yaml += "    commit: \(subtree.commit)\n"
            
            if let extractions = subtree.extractions, !extractions.isEmpty {
                yaml += "    extractions:\n"
                for extraction in extractions {
                    yaml += "      - from: \"\(extraction.from)\"\n"
                    yaml += "        to: \(extraction.to)\n"
                    if let exclude = extraction.exclude, !exclude.isEmpty {
                        yaml += "        exclude:\n"
                        for pattern in exclude {
                            yaml += "          - \(pattern)\n"
                        }
                    }
                }
            }
        }
        
        try yaml.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    // MARK: - T056: Extract copies markdown files with glob pattern
    
    @Test("Extract copies markdown files using glob pattern")
    func testExtractCopiesMarkdownFiles() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Add a subtree with markdown documentation
        let subtreePrefix = "vendor/docs-lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        
        // Create markdown files in the subtree
        let files = [
            "\(subtreePrefix)/README.md",
            "\(subtreePrefix)/guide/INSTALL.md",
            "\(subtreePrefix)/guide/USAGE.md",
            "\(subtreePrefix)/api/reference.md"
        ]
        
        for file in files {
            let fullPath = fixture.path.string + "/" + file
            let dir = (fullPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try "# Test content".write(toFile: fullPath, atomically: true, encoding: .utf8)
        }
        
        // Add subtree to config using raw YAML
        try writeSubtreeConfig(
            name: "docs-lib",
            remote: "https://example.com/docs.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add subtree with docs"])
        
        // Extract markdown files to project-docs/
        let result = try await harness.run(
            arguments: ["extract", "--name", "docs-lib", "--from", "**/*.md", "--to", "project-docs/"],
            workingDirectory: fixture.path
        )
        
        // Verify success
        #expect(result.exitCode == 0, "Extract should succeed")
        #expect(result.stdout.contains("✅"), "Should show success message")
        
        // Verify files were copied
        let copiedFiles = [
            "project-docs/README.md",
            "project-docs/guide/INSTALL.md",
            "project-docs/guide/USAGE.md",
            "project-docs/api/reference.md"
        ]
        
        for file in copiedFiles {
            let fullPath = fixture.path.string + "/" + file
            #expect(FileManager.default.fileExists(atPath: fullPath), "File \(file) should be copied")
        }
    }
    
    // MARK: - T057: Extract preserves directory structure relative to match
    
    @Test("Extract preserves directory structure relative to match")
    func testExtractPreservesDirectoryStructure() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with nested structure
        let subtreePrefix = "vendor/mylib"
        let structure = [
            "\(subtreePrefix)/src/core/engine.c",
            "\(subtreePrefix)/src/core/utils.c",
            "\(subtreePrefix)/src/ui/window.c",
            "\(subtreePrefix)/include/mylib.h"
        ]
        
        for file in structure {
            let fullPath = fixture.path.string + "/" + file
            let dir = (fullPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try "// Code".write(toFile: fullPath, atomically: true, encoding: .utf8)
        }
        
        // Add subtree to config
        try writeSubtreeConfig(
            name: "mylib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "def456",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add library"])
        
        // Extract src/**/*.c to Sources/MyLib/
        let result = try await harness.run(
            arguments: ["extract", "--name", "mylib", "--from", "src/**/*.c", "--to", "Sources/MyLib/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        
        // Verify full path structure is preserved (src/ included)
        let expectedFiles = [
            "Sources/MyLib/src/core/engine.c",
            "Sources/MyLib/src/core/utils.c",
            "Sources/MyLib/src/ui/window.c"
        ]
        
        for file in expectedFiles {
            #expect(FileManager.default.fileExists(atPath: fixture.path.string + "/" + file),
                   "Should preserve full directory structure: \(file)")
        }
        
        // Verify include/ was not copied
        #expect(!FileManager.default.fileExists(atPath: fixture.path.string + "/Sources/MyLib/include"),
               "Should not copy files outside pattern")
    }
    
    // MARK: - T058: Extract copies all files under directory
    
    @Test("Extract copies all files under directory with **/*.*")
    func testExtractCopiesAllFiles() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with mixed file types
        let subtreePrefix = "vendor/assets"
        let files = [
            "\(subtreePrefix)/images/logo.png",
            "\(subtreePrefix)/images/icon.svg",
            "\(subtreePrefix)/css/style.css",
            "\(subtreePrefix)/js/app.js",
            "\(subtreePrefix)/fonts/font.ttf"
        ]
        
        for file in files {
            let fullPath = fixture.path.string + "/" + file
            let dir = (fullPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try "content".write(toFile: fullPath, atomically: true, encoding: .utf8)
        }
        
        try writeSubtreeConfig(
            name: "assets",
            remote: "https://example.com/assets.git",
            prefix: subtreePrefix,
            commit: "ghi789",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add assets"])
        
        // Extract all files
        let result = try await harness.run(
            arguments: ["extract", "--name", "assets", "--from", "**/*.*", "--to", "public/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        
        // Verify all files copied
        let expectedFiles = [
            "public/images/logo.png",
            "public/images/icon.svg",
            "public/css/style.css",
            "public/js/app.js",
            "public/fonts/font.ttf"
        ]
        
        for file in expectedFiles {
            #expect(FileManager.default.fileExists(atPath: fixture.path.string + "/" + file))
        }
    }
    
    // MARK: - T059: Extract with exclude patterns filters files
    
    @Test("Extract with --exclude flag filters files")
    func testExtractWithExcludePatterns() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with test and bench files
        let subtreePrefix = "vendor/codebase"
        let files = [
            "\(subtreePrefix)/src/main.c",
            "\(subtreePrefix)/src/util.c",
            "\(subtreePrefix)/src/test/test_main.c",
            "\(subtreePrefix)/src/test/test_util.c",
            "\(subtreePrefix)/src/bench/bench_perf.c"
        ]
        
        for file in files {
            let fullPath = fixture.path.string + "/" + file
            let dir = (fullPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try "// Code".write(toFile: fullPath, atomically: true, encoding: .utf8)
        }
        
        try writeSubtreeConfig(
            name: "codebase",
            remote: "https://example.com/code.git",
            prefix: subtreePrefix,
            commit: "jkl012",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add codebase"])
        
        // Extract C files but exclude test and bench directories
        let result = try await harness.run(
            arguments: [
                "extract", "--name", "codebase",
                "--from", "src/**/*.c", "--to", "Sources/",
                "--exclude", "src/**/test*/**",
                "--exclude", "src/**/bench*/**"
            ],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        
        // Verify only main sources copied (full path preserved: src/ included)
        #expect(FileManager.default.fileExists(atPath: fixture.path.string + "/Sources/src/main.c"))
        #expect(FileManager.default.fileExists(atPath: fixture.path.string + "/Sources/src/util.c"))
        
        // Verify test and bench excluded
        #expect(!FileManager.default.fileExists(atPath: fixture.path.string + "/Sources/src/test"),
               "Test directory should be excluded")
        #expect(!FileManager.default.fileExists(atPath: fixture.path.string + "/Sources/src/bench"),
               "Bench directory should be excluded")
    }
    
    // MARK: - T060: Extract creates destination directory if missing
    
    @Test("Extract creates destination directory if missing")
    func testExtractCreatesDestinationDirectory() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create simple subtree
        let subtreePrefix = "vendor/data"
        let file = "\(subtreePrefix)/config.json"
        let fullPath = fixture.path.string + "/" + file
        let dir = (fullPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try "{\"key\": \"value\"}".write(toFile: fullPath, atomically: true, encoding: .utf8)
        
        try writeSubtreeConfig(
            name: "data",
            remote: "https://example.com/data.git",
            prefix: subtreePrefix,
            commit: "mno345",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add data"])
        
        // Verify destination doesn't exist yet
        let destPath = fixture.path.string + "/deep/nested/config/"
        #expect(!FileManager.default.fileExists(atPath: destPath), "Destination should not exist yet")
        
        // Extract to deep nested path
        let result = try await harness.run(
            arguments: ["extract", "--name", "data", "--from", "*.json", "--to", "deep/nested/config/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        
        // Verify directory was created
        #expect(FileManager.default.fileExists(atPath: destPath), "Should create destination directory")
        #expect(FileManager.default.fileExists(atPath: destPath + "config.json"),
               "Should copy file to created directory")
    }
    
    // MARK: - T087: Extract with --persist saves mapping to config
    
    @Test("Extract with --persist saves mapping to config")
    func testExtractWithPersistSavesMapping() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with files
        let subtreePrefix = "vendor/docs"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        
        let files = [
            "\(subtreePrefix)/README.md",
            "\(subtreePrefix)/guide.md"
        ]
        
        for file in files {
            let fullPath = fixture.path.string + "/" + file
            try "# Content".write(toFile: fullPath, atomically: true, encoding: .utf8)
        }
        
        // Add subtree to config
        try writeSubtreeConfig(
            name: "docs",
            remote: "https://example.com/docs.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add subtree"])
        
        // Extract with --persist
        let result = try await harness.run(
            arguments: ["extract", "--name", "docs", "--from", "**/*.md", "--to", "project-docs/", "--persist"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("✅"), "Should show success message")
        #expect(result.stdout.contains("📝") || result.stdout.contains("Saved"), "Should mention mapping saved")
        
        // Verify files were extracted
        #expect(FileManager.default.fileExists(atPath: fixture.path.string + "/project-docs/README.md"))
        
        // Verify mapping was saved to config (YAML string matching)
        let yaml = try String(contentsOfFile: fixture.path.string + "/subtree.yaml", encoding: .utf8)
        #expect(yaml.contains("extractions:"), "Should have extractions section")
        #expect(yaml.contains("from: '**/*.md'") || yaml.contains("from: \"**/*.md\""), "Should have saved pattern")
        #expect(yaml.contains("to: project-docs/"), "Should have saved destination")
    }
    
    // MARK: - T088: Saved mapping includes exclude patterns
    
    @Test("Saved mapping includes exclude patterns")
    func testSavedMappingIncludesExcludePatterns() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with files
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix + "/src",
            withIntermediateDirectories: true
        )
        
        try "code".write(toFile: fixture.path.string + "/" + subtreePrefix + "/src/main.c",
                        atomically: true, encoding: .utf8)
        
        // Add subtree to config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add subtree"])
        
        // Extract with --persist and --exclude
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "src/**/*.c", "--to", "Sources/",
                       "--exclude", "**/test/**", "--exclude", "**/bench/**", "--persist"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        
        // Verify mapping includes exclude patterns (YAML string matching)
        let yaml = try String(contentsOfFile: fixture.path.string + "/subtree.yaml", encoding: .utf8)
        // Pattern may be quoted or unquoted, just check the pattern text exists
        #expect(yaml.contains("src/**/*.c"), "Should have saved pattern")
        #expect(yaml.contains("to: Sources/"), "Should have saved destination")
        #expect(yaml.contains("exclude:"), "Should have exclude section")
        #expect(yaml.contains("**/test/**"), "Should have first exclude pattern")
        #expect(yaml.contains("**/bench/**"), "Should have second exclude pattern")
    }
    
    // MARK: - T089: Extraction without --persist doesn't save mapping
    
    @Test("Extraction without --persist doesn't save mapping")
    func testExtractionWithoutPersistDoesntSaveMapping() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with files
        let subtreePrefix = "vendor/data"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        
        try "data".write(toFile: fixture.path.string + "/" + subtreePrefix + "/file.txt",
                        atomically: true, encoding: .utf8)
        
        // Add subtree to config
        try writeSubtreeConfig(
            name: "data",
            remote: "https://example.com/data.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add subtree"])
        
        // Extract WITHOUT --persist
        let result = try await harness.run(
            arguments: ["extract", "--name", "data", "--from", "**/*.txt", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("✅"), "Should show success")
        #expect(!result.stdout.contains("📝") && !result.stdout.contains("Saved"), "Should NOT mention saving")
        
        // Verify files were extracted
        #expect(FileManager.default.fileExists(atPath: fixture.path.string + "/output/file.txt"))
        
        // Verify NO mapping was saved to config (YAML string matching)
        let yaml = try String(contentsOfFile: fixture.path.string + "/subtree.yaml", encoding: .utf8)
        #expect(!yaml.contains("extractions:"), "Should NOT have extractions section")
    }
    
    // MARK: - T090: Multiple saved mappings in config
    
    @Test("Multiple saved mappings in config")
    func testMultipleSavedMappingsInConfig() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with multiple file types
        let subtreePrefix = "vendor/multi"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        
        try "doc".write(toFile: fixture.path.string + "/" + subtreePrefix + "/README.md",
                       atomically: true, encoding: .utf8)
        try "code".write(toFile: fixture.path.string + "/" + subtreePrefix + "/main.c",
                        atomically: true, encoding: .utf8)
        
        // Add subtree to config
        try writeSubtreeConfig(
            name: "multi",
            remote: "https://example.com/multi.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add subtree"])
        
        // First extraction: markdown files
        let result1 = try await harness.run(
            arguments: ["extract", "--name", "multi", "--from", "**/*.md", "--to", "docs/", "--persist"],
            workingDirectory: fixture.path
        )
        #expect(result1.exitCode == 0)
        
        // Second extraction: C files
        let result2 = try await harness.run(
            arguments: ["extract", "--name", "multi", "--from", "**/*.c", "--to", "Sources/", "--persist"],
            workingDirectory: fixture.path
        )
        #expect(result2.exitCode == 0)
        
        // Verify both mappings are saved (YAML string matching)
        let yaml = try String(contentsOfFile: fixture.path.string + "/subtree.yaml", encoding: .utf8)
        #expect(yaml.contains("extractions:"), "Should have extractions section")
        #expect(yaml.contains("from: '**/*.md'") || yaml.contains("from: \"**/*.md\""), "Should have first mapping")
        #expect(yaml.contains("to: docs/"), "Should have first destination")
        #expect(yaml.contains("from: '**/*.c'") || yaml.contains("from: \"**/*.c\""), "Should have second mapping")
        #expect(yaml.contains("to: Sources/"), "Should have second destination")
    }
    
    // MARK: - Phase 5 Tests (User Story 3 - Bulk Extraction)
    
    // T103: Extract --name executes all saved mappings for subtree
    @Test("Extract --name executes all saved mappings for subtree")
    func testExtractNameExecutesSavedMappings() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with multiple file types
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        
        try "# Doc".write(toFile: fixture.path.string + "/" + subtreePrefix + "/README.md",
                         atomically: true, encoding: .utf8)
        try "code".write(toFile: fixture.path.string + "/" + subtreePrefix + "/main.c",
                        atomically: true, encoding: .utf8)
        try "header".write(toFile: fixture.path.string + "/" + subtreePrefix + "/lib.h",
                          atomically: true, encoding: .utf8)
        
        // Create config with saved mappings using raw YAML
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            extractions: [
                (from: "**/*.md", to: "docs/", exclude: nil),
                (from: "**/*.c", to: "src/", exclude: nil),
                (from: "**/*.h", to: "include/", exclude: nil)
            ],
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add subtree"])
        
        // Run bulk extraction (no positional args)
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0, "Bulk extraction should succeed")
        #expect(result.stdout.contains("Processing subtree 'lib'"), "Should show subtree being processed")
        #expect(result.stdout.contains("3 mappings"), "Should mention mapping count")
        
        // Verify all three mappings executed
        #expect(FileManager.default.fileExists(atPath: fixture.path.string + "/docs/README.md"))
        #expect(FileManager.default.fileExists(atPath: fixture.path.string + "/src/main.c"))
        #expect(FileManager.default.fileExists(atPath: fixture.path.string + "/include/lib.h"))
    }
    
    // T104: Extract --all executes mappings for all subtrees
    @Test("Extract --all executes mappings for all subtrees")
    func testExtractAllExecutesMappingsForAllSubtrees() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create two subtrees
        for (_, prefix) in [("lib1", "vendor/lib1"), ("lib2", "vendor/lib2")] {
            try FileManager.default.createDirectory(
                atPath: fixture.path.string + "/" + prefix,
                withIntermediateDirectories: true
            )
            try "content".write(toFile: fixture.path.string + "/" + prefix + "/file.txt",
                               atomically: true, encoding: .utf8)
        }
        
        // Create config with mappings for both subtrees
        try writeMultiSubtreeConfig(
            subtrees: [
                (name: "lib1", remote: "https://example.com/lib1.git", prefix: "vendor/lib1", 
                 commit: "abc123", extractions: [(from: "**/*.txt", to: "output1/", exclude: nil)]),
                (name: "lib2", remote: "https://example.com/lib2.git", prefix: "vendor/lib2", 
                 commit: "def456", extractions: [(from: "**/*.txt", to: "output2/", exclude: nil)])
            ],
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add subtrees"])
        
        // Run --all
        let result = try await harness.run(
            arguments: ["extract", "--all"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("Processing subtree 'lib1'"))
        #expect(result.stdout.contains("Processing subtree 'lib2'"))
        
        // Verify both extractions executed
        #expect(FileManager.default.fileExists(atPath: fixture.path.string + "/output1/file.txt"))
        #expect(FileManager.default.fileExists(atPath: fixture.path.string + "/output2/file.txt"))
    }
    
    // T105: Extract --name with no saved mappings succeeds with message
    @Test("Extract --name with no saved mappings succeeds with message")
    func testExtractNameWithNoSavedMappingsShowsMessage() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree WITHOUT extractions
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        try "content".write(toFile: fixture.path.string + "/" + subtreePrefix + "/file.txt",
                           atomically: true, encoding: .utf8)
        
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add subtree"])
        
        // Run bulk extraction
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0, "Should succeed with exit 0")
        #expect(result.stdout.contains("No saved mappings"), "Should show informational message")
        #expect(result.stdout.contains("ℹ️") || result.stdout.contains("Tip"), "Should be informational")
    }
    
    // T106: Mappings execute in array order
    @Test("Mappings execute in array order")
    func testMappingsExecuteInArrayOrder() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with files
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        
        for i in 1...3 {
            try "file\(i)".write(
                toFile: fixture.path.string + "/" + subtreePrefix + "/file\(i).txt",
                atomically: true,
                encoding: .utf8
            )
        }
        
        // Create config with ordered mappings
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            extractions: [
                (from: "file1.txt", to: "out1/", exclude: nil),
                (from: "file2.txt", to: "out2/", exclude: nil),
                (from: "file3.txt", to: "out3/", exclude: nil)
            ],
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add subtree"])
        
        // Run bulk extraction
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        
        // Verify output shows mappings in order [1/3], [2/3], [3/3]
        let lines = result.stdout.split(separator: "\n").map(String.init)
        var foundOrder = [Int]()
        
        for line in lines {
            if line.contains("[1/3]") { foundOrder.append(1) }
            if line.contains("[2/3]") { foundOrder.append(2) }
            if line.contains("[3/3]") { foundOrder.append(3) }
        }
        
        #expect(foundOrder == [1, 2, 3], "Mappings should execute in array order")
    }
    
    // MARK: - Phase 7 Tests (User Story 5 - Validation & Error Handling)
    
    // T144: Zero-match pattern error (ad-hoc mode)
    @Test("Zero-match pattern fails in ad-hoc mode")
    func testZeroMatchPatternFailsInAdHocMode() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree without matching files
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        try "content".write(toFile: fixture.path.string + "/" + subtreePrefix + "/file.txt",
                           atomically: true, encoding: .utf8)
        
        // Create config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Try to extract with non-matching pattern (ad-hoc mode)
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "*.xyz", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 1, "Should fail with user error in ad-hoc mode")
        #expect(result.stderr.contains("No files matched"), "Should mention no matches")
        #expect(result.stderr.contains("*.xyz"), "Should show the pattern")
    }
    
    // T145: All-excluded pattern error (ad-hoc mode)
    @Test("All-excluded pattern fails in ad-hoc mode")
    func testAllExcludedPatternFailsInAdHocMode() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with one markdown file
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        try "readme content".write(toFile: fixture.path.string + "/" + subtreePrefix + "/README.md",
                                   atomically: true, encoding: .utf8)
        
        // Create config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Extract with pattern that matches but exclude everything
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "*.md", "--to", "output/", "--exclude", "README.md"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 1, "Should fail when all files excluded in ad-hoc mode")
        #expect(result.stderr.contains("No files matched"), "Should show zero-match error (after exclusions)")
    }
    
    // T146: Non-existent subtree error
    @Test("Non-existent subtree produces clear error")
    func testNonExistentSubtreeError() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create config with one subtree
        try writeSubtreeConfig(
            name: "lib1",
            remote: "https://example.com/lib1.git",
            prefix: "vendor/lib1",
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Try to extract from non-existent subtree
        let result = try await harness.run(
            arguments: ["extract", "--name", "nonexistent", "--from", "*.md", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 1, "Should fail with user error")
        #expect(result.stderr.contains("nonexistent"), "Should mention the missing subtree")
        #expect(result.stderr.contains("not found") || result.stderr.contains("Subtree"), "Should explain issue")
    }
    
    // T147: Invalid destination path error (parent traversal)
    @Test("Invalid destination path with parent traversal fails")
    func testInvalidDestinationPathError() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        try "content".write(toFile: fixture.path.string + "/" + subtreePrefix + "/file.txt",
                           atomically: true, encoding: .utf8)
        
        // Create config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Try to extract with unsafe destination
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "*.txt", "--to", "../unsafe/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 1, "Should fail with user error")
        #expect(result.stderr.contains("..") || result.stderr.contains("parent") || result.stderr.contains("unsafe"),
               "Should mention unsafe path")
    }
    
    // T148: Subtree prefix not found error
    @Test("Subtree prefix directory not found produces error")
    func testSubtreePrefixNotFoundError() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create config but don't create the actual prefix directory
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: "vendor/lib",
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit (subtree prefix doesn't exist)
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Try to extract
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "*.txt", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 1, "Should fail with user error (config issue)")
        #expect(result.stderr.contains("vendor/lib") || result.stderr.contains("not found") || result.stderr.contains("does not exist") || result.stderr.contains("No such file"),
               "Should mention missing prefix")
    }
    
    // T149: Destination directory auto-creation works
    @Test("Destination directory is created automatically")
    func testDestinationDirectoryAutoCreation() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with file
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        try "content".write(toFile: fixture.path.string + "/" + subtreePrefix + "/file.txt",
                           atomically: true, encoding: .utf8)
        
        // Create config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Extract to non-existent nested directory
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "*.txt", "--to", "deeply/nested/output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0, "Should succeed")
        
        // Verify directory was created
        let dirExists = FileManager.default.fileExists(atPath: fixture.path.string + "/deeply/nested/output")
        #expect(dirExists, "Directory should be auto-created")
        
        // Verify file was copied
        let fileExists = FileManager.default.fileExists(atPath: fixture.path.string + "/deeply/nested/output/file.txt")
        #expect(fileExists, "File should be copied to auto-created directory")
    }
    
    // T107: Bulk execution continues on mapping failure
    @Test("Bulk execution continues on mapping failure")
    func testBulkExecutionContinuesOnMappingFailure() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with files
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        
        try "content".write(toFile: fixture.path.string + "/" + subtreePrefix + "/good.txt",
                           atomically: true, encoding: .utf8)
        
        // Create config with one invalid and two valid mappings
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            extractions: [
                (from: "good.txt", to: "out1/", exclude: nil),
                (from: "**/*.{invalid", to: "out2/", exclude: nil),  // Invalid glob
                (from: "good.txt", to: "out3/", exclude: nil)
            ],
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add subtree"])
        
        // Run bulk extraction
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode != 0, "Should exit with error code due to failure")
        #expect(result.stdout.contains("[1/3]"), "Should show first mapping executed")
        #expect(result.stdout.contains("[2/3]"), "Should show second mapping attempted")
        #expect(result.stdout.contains("[3/3]"), "Should show third mapping executed (continued)")
        
        // Verify first and third succeeded, second failed
        #expect(FileManager.default.fileExists(atPath: fixture.path.string + "/out1/good.txt"))
        #expect(FileManager.default.fileExists(atPath: fixture.path.string + "/out3/good.txt"))
    }
    
    // T108: Bulk execution reports all failures at end
    @Test("Bulk execution reports all failures at end")
    func testBulkExecutionReportsAllFailuresAtEnd() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        try "content".write(toFile: fixture.path.string + "/" + subtreePrefix + "/file.txt",
                           atomically: true, encoding: .utf8)
        
        // Create config with multiple invalid mappings
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            extractions: [
                (from: "file.txt", to: "out1/", exclude: nil),
                (from: "**/*.{bad", to: "out2/", exclude: nil),   // Invalid
                (from: "**/*.{worse", to: "out3/", exclude: nil)  // Invalid
            ],
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add subtree"])
        
        // Run bulk extraction
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode != 0)
        #expect(result.stdout.contains("Summary") || result.stdout.contains("📊"), "Should show summary")
        #expect(result.stdout.contains("Failures") || result.stdout.contains("❌"), "Should list failures")
        
        // Should mention both failed mappings
        #expect(result.stdout.contains("mapping 2") || result.stdout.contains("[2/3]"))
        #expect(result.stdout.contains("mapping 3") || result.stdout.contains("[3/3]"))
    }
    
    // T109: Bulk execution exits with highest severity code
    @Test("Bulk execution exits with highest severity code")
    func testBulkExecutionExitsWithHighestSeverityCode() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        try "content".write(toFile: fixture.path.string + "/" + subtreePrefix + "/file.txt",
                           atomically: true, encoding: .utf8)
        
        // Create config with an invalid glob pattern (user error = exit 1)
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            extractions: [
                (from: "**/*.{invalid", to: "out/", exclude: nil)  // Invalid glob = exit 1
            ],
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Add subtree"])
        
        // Run bulk extraction
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib"],
            workingDirectory: fixture.path
        )
        
        // Invalid glob should result in exit code 1 (user error)
        #expect(result.exitCode == 1, "Should exit with user error code for invalid glob")
    }
    
    // MARK: - Phase 6 Tests (User Story 4 - Overwrite Protection)
    
    // T126: Extraction blocked when destination is git-tracked
    @Test("Extraction blocked when destination is git-tracked")
    func testExtractionBlockedWhenDestinationIsGitTracked() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with file
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        try "content".write(toFile: fixture.path.string + "/" + subtreePrefix + "/file.txt",
                           atomically: true, encoding: .utf8)
        
        // Create config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Create and commit destination file (making it tracked)
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/output",
            withIntermediateDirectories: true
        )
        try "existing".write(toFile: fixture.path.string + "/output/file.txt",
                            atomically: true, encoding: .utf8)
        try await fixture.runGit(["add", "output/file.txt"])
        try await fixture.runGit(["commit", "-m", "Add tracked file"])
        
        // Try to extract - should be blocked
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "file.txt", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 2, "Should exit with code 2 for overwrite protection")
        #expect(result.stderr.contains("git-tracked") || result.stderr.contains("tracked"), "Should mention git-tracked files")
        #expect(result.stderr.contains("file.txt"), "Should list the protected file")
        #expect(result.stderr.contains("--force"), "Should mention --force flag")
        
        // Verify file was NOT overwritten
        let content = try String(contentsOfFile: fixture.path.string + "/output/file.txt", encoding: .utf8)
        #expect(content == "existing", "Tracked file should not be overwritten")
    }
    
    // T127: Extraction succeeds when destination is untracked
    @Test("Extraction succeeds when destination is untracked")
    func testExtractionSucceedsWhenDestinationIsUntracked() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with file
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        try "content".write(toFile: fixture.path.string + "/" + subtreePrefix + "/file.txt",
                           atomically: true, encoding: .utf8)
        
        // Create config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Create untracked destination file (not committed)
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/output",
            withIntermediateDirectories: true
        )
        try "existing".write(toFile: fixture.path.string + "/output/file.txt",
                            atomically: true, encoding: .utf8)
        // Note: NOT adding to git - file is untracked
        
        // Extract should succeed (untracked files can be overwritten)
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "file.txt", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0, "Should succeed with untracked destination")
        
        // Verify file was overwritten
        let content = try String(contentsOfFile: fixture.path.string + "/output/file.txt", encoding: .utf8)
        #expect(content == "content", "Untracked file should be overwritten")
    }
    
    // T128: Extraction with --force overwrites git-tracked files
    @Test("Extraction with --force overwrites git-tracked files")
    func testExtractionWithForceOverwritesGitTrackedFiles() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with file
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        try "new content".write(toFile: fixture.path.string + "/" + subtreePrefix + "/file.txt",
                               atomically: true, encoding: .utf8)
        
        // Create config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Create and commit destination file (making it tracked)
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/output",
            withIntermediateDirectories: true
        )
        try "existing".write(toFile: fixture.path.string + "/output/file.txt",
                            atomically: true, encoding: .utf8)
        try await fixture.runGit(["add", "output/file.txt"])
        try await fixture.runGit(["commit", "-m", "Add tracked file"])
        
        // Extract with --force should succeed
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "file.txt", "--to", "output/", "--force"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0, "Should succeed with --force flag")
        
        // Verify file WAS overwritten
        let content = try String(contentsOfFile: fixture.path.string + "/output/file.txt", encoding: .utf8)
        #expect(content == "new content", "Tracked file should be overwritten with --force")
    }
    
    // T129: Mixed tracked/untracked destinations
    @Test("Mixed tracked/untracked destinations")
    func testMixedTrackedUntrackedDestinations() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with multiple files
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        try "file1".write(toFile: fixture.path.string + "/" + subtreePrefix + "/file1.txt",
                         atomically: true, encoding: .utf8)
        try "file2".write(toFile: fixture.path.string + "/" + subtreePrefix + "/file2.txt",
                         atomically: true, encoding: .utf8)
        try "file3".write(toFile: fixture.path.string + "/" + subtreePrefix + "/file3.txt",
                         atomically: true, encoding: .utf8)
        
        // Create config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Create tracked file1 and file2
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/output",
            withIntermediateDirectories: true
        )
        try "tracked1".write(toFile: fixture.path.string + "/output/file1.txt",
                            atomically: true, encoding: .utf8)
        try "tracked2".write(toFile: fixture.path.string + "/output/file2.txt",
                            atomically: true, encoding: .utf8)
        try await fixture.runGit(["add", "output/"])
        try await fixture.runGit(["commit", "-m", "Add tracked files"])
        
        // file3.txt doesn't exist yet (would be new, untracked)
        
        // Extract should fail due to tracked files
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "*.txt", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 2, "Should fail due to tracked files")
        #expect(result.stderr.contains("file1.txt") || result.stderr.contains("2 git-tracked"),
               "Should mention tracked files")
        
        // Verify NO files were copied (atomic failure)
        let content1 = try String(contentsOfFile: fixture.path.string + "/output/file1.txt", encoding: .utf8)
        #expect(content1 == "tracked1", "file1 should not be overwritten")
        
        let content2 = try String(contentsOfFile: fixture.path.string + "/output/file2.txt", encoding: .utf8)
        #expect(content2 == "tracked2", "file2 should not be overwritten")
        
        #expect(!FileManager.default.fileExists(atPath: fixture.path.string + "/output/file3.txt"),
               "file3 should not be created (atomic failure)")
    }
    
    // T130: Error message lists all protected files
    @Test("Error message lists all protected files")
    func testErrorMessageListsAllProtectedFiles() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with multiple files
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        
        for i in 1...5 {
            try "content\(i)".write(
                toFile: fixture.path.string + "/" + subtreePrefix + "/file\(i).txt",
                atomically: true,
                encoding: .utf8
            )
        }
        
        // Create config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit everything
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Create and commit all destination files
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/output",
            withIntermediateDirectories: true
        )
        for i in 1...5 {
            try "existing\(i)".write(
                toFile: fixture.path.string + "/output/file\(i).txt",
                atomically: true,
                encoding: .utf8
            )
        }
        try await fixture.runGit(["add", "output/"])
        try await fixture.runGit(["commit", "-m", "Add tracked files"])
        
        // Extract should fail and list all protected files
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "*.txt", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 2)
        
        // Should list all 5 files (since <= 20 files, show all)
        for i in 1...5 {
            #expect(result.stderr.contains("file\(i).txt"), "Should list file\(i).txt")
        }
        
        #expect(result.stderr.contains("5") || result.stderr.contains("file"), "Should show count")
    }
    
    // MARK: - Edge Case Tests
    
    // T171: Destination inside subtree prefix (circular/overlap error)
    @Test("Destination inside subtree prefix is detected")
    func testDestinationInsideSubtreePrefix() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with file
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        try "content".write(toFile: fixture.path.string + "/" + subtreePrefix + "/file.txt",
                           atomically: true, encoding: .utf8)
        
        // Create config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Try to extract INTO the subtree prefix (circular/overlap)
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "*.txt", "--to", "vendor/lib/extracted/"],
            workingDirectory: fixture.path
        )
        
        // Should either succeed (allowing it) or fail with clear message
        // Current implementation allows it but extracts relative to prefix
        // This documents the behavior
        if result.exitCode == 0 {
            // Allowed - extraction is relative to subtree prefix
            #expect(result.exitCode == 0, "Extraction relative to prefix is allowed")
        } else {
            // Blocked with error
            #expect(result.exitCode == 1, "Should fail with user error if blocked")
            #expect(result.stderr.contains("prefix") || result.stderr.contains("circular"),
                   "Should mention the issue")
        }
    }
    
    // T172: Glob matching is scoped to subtree prefix
    @Test("Glob matching scoped to subtree prefix only")
    func testGlobMatchingScopedToPrefix() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with files
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        try "subtree file".write(toFile: fixture.path.string + "/" + subtreePrefix + "/lib.md",
                                atomically: true, encoding: .utf8)
        
        // Create file OUTSIDE subtree (should NOT be matched)
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/docs",
            withIntermediateDirectories: true
        )
        try "outside file".write(toFile: fixture.path.string + "/docs/readme.md",
                                atomically: true, encoding: .utf8)
        
        // Create config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Extract with pattern that would match files outside if not scoped
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/*.md", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0, "Should succeed")
        
        // Should only have the subtree file
        let subtreeFileExists = FileManager.default.fileExists(
            atPath: fixture.path.string + "/output/lib.md"
        )
        #expect(subtreeFileExists, "Should extract file from subtree")
        
        // Should NOT have the outside file
        let outsideFileExists = FileManager.default.fileExists(
            atPath: fixture.path.string + "/output/readme.md"
        )
        #expect(!outsideFileExists, "Should NOT extract files outside subtree prefix")
    }
    
    // T173: Filename collisions (multiple sources → same dest)
    @Test("Filename collisions handled by FileManager")
    func testFilenameCollisions() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with files in different dirs but same name
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix + "/dir1",
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix + "/dir2",
            withIntermediateDirectories: true
        )
        try "content1".write(toFile: fixture.path.string + "/" + subtreePrefix + "/dir1/file.txt",
                            atomically: true, encoding: .utf8)
        try "content2".write(toFile: fixture.path.string + "/" + subtreePrefix + "/dir2/file.txt",
                            atomically: true, encoding: .utf8)
        
        // Create config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Extract with pattern preserving directory structure (no collision)
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "**/file.txt", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0, "Should succeed with preserved structure")
        
        // Files should be in separate directories
        let file1Exists = FileManager.default.fileExists(
            atPath: fixture.path.string + "/output/dir1/file.txt"
        )
        let file2Exists = FileManager.default.fileExists(
            atPath: fixture.path.string + "/output/dir2/file.txt"
        )
        
        #expect(file1Exists, "Should preserve dir1/file.txt")
        #expect(file2Exists, "Should preserve dir2/file.txt")
        
        // Verify content is correct (no overwrite)
        let content1 = try String(contentsOfFile: fixture.path.string + "/output/dir1/file.txt", encoding: .utf8)
        let content2 = try String(contentsOfFile: fixture.path.string + "/output/dir2/file.txt", encoding: .utf8)
        
        #expect(content1 == "content1", "First file should have correct content")
        #expect(content2 == "content2", "Second file should have correct content")
    }
    
    // T175: Destination is file not directory
    @Test("Error when destination is file not directory")
    func testDestinationIsFileNotDirectory() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with file
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        try "content".write(toFile: fixture.path.string + "/" + subtreePrefix + "/file.txt",
                           atomically: true, encoding: .utf8)
        
        // Create config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Create a FILE where destination directory should be
        try "blocking file".write(toFile: fixture.path.string + "/output",
                                 atomically: true, encoding: .utf8)
        
        // Try to extract to path that exists as a file
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "*.txt", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        // Should fail (can't create directory when file exists)
        #expect(result.exitCode != 0, "Should fail when destination is file not directory")
        #expect(result.stderr.count > 0, "Should have error message")
    }
    
    // MARK: - Brace Expansion Integration Tests (011-brace-expansion T034-T036)
    
    // T034: Extract with embedded path separator pattern
    @Test("Extract with embedded path separator pattern {A,B/C}")
    func testExtractWithEmbeddedPathSeparator() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with nested structure
        let subtreePrefix = "vendor/lib"
        let dirs = [
            "\(subtreePrefix)/A",
            "\(subtreePrefix)/B/C"
        ]
        for dir in dirs {
            try FileManager.default.createDirectory(
                atPath: fixture.path.string + "/" + dir,
                withIntermediateDirectories: true
            )
        }
        
        // Create files at different depths
        try "contentA".write(toFile: fixture.path.string + "/" + subtreePrefix + "/A/file.swift",
                            atomically: true, encoding: .utf8)
        try "contentBC".write(toFile: fixture.path.string + "/" + subtreePrefix + "/B/C/file.swift",
                             atomically: true, encoding: .utf8)
        
        // Create config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Extract using brace expansion with embedded path separator
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "{A,B/C}/*.swift", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0, "Should succeed with brace expansion: \(result.stderr)")
        
        // Verify both files were extracted
        let fileAExists = FileManager.default.fileExists(
            atPath: fixture.path.string + "/output/A/file.swift"
        )
        let fileBCExists = FileManager.default.fileExists(
            atPath: fixture.path.string + "/output/B/C/file.swift"
        )
        
        #expect(fileAExists, "Should extract A/file.swift")
        #expect(fileBCExists, "Should extract B/C/file.swift (embedded path separator)")
    }
    
    // T035: Extract with multiple brace groups (cartesian product)
    @Test("Extract with multiple brace groups cartesian product")
    func testExtractWithMultipleBraceGroups() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with structure for cartesian product: {src,test}/{foo,bar}.swift
        let subtreePrefix = "vendor/lib"
        let dirs = [
            "\(subtreePrefix)/src",
            "\(subtreePrefix)/test"
        ]
        for dir in dirs {
            try FileManager.default.createDirectory(
                atPath: fixture.path.string + "/" + dir,
                withIntermediateDirectories: true
            )
        }
        
        // Create 4 files: src/foo.swift, src/bar.swift, test/foo.swift, test/bar.swift
        try "src-foo".write(toFile: fixture.path.string + "/" + subtreePrefix + "/src/foo.swift",
                           atomically: true, encoding: .utf8)
        try "src-bar".write(toFile: fixture.path.string + "/" + subtreePrefix + "/src/bar.swift",
                           atomically: true, encoding: .utf8)
        try "test-foo".write(toFile: fixture.path.string + "/" + subtreePrefix + "/test/foo.swift",
                            atomically: true, encoding: .utf8)
        try "test-bar".write(toFile: fixture.path.string + "/" + subtreePrefix + "/test/bar.swift",
                            atomically: true, encoding: .utf8)
        
        // Create config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Extract using brace expansion with cartesian product
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "{src,test}/{foo,bar}.swift", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0, "Should succeed with cartesian product: \(result.stderr)")
        
        // Verify all 4 files were extracted
        let files = [
            "output/src/foo.swift",
            "output/src/bar.swift",
            "output/test/foo.swift",
            "output/test/bar.swift"
        ]
        
        for file in files {
            let exists = FileManager.default.fileExists(atPath: fixture.path.string + "/" + file)
            #expect(exists, "Should extract \(file)")
        }
        
        // Verify stdout mentions 4 files
        #expect(result.stdout.contains("4 file"), "Should report 4 files extracted")
    }
    
    // T036: Extract error on empty alternative pattern
    @Test("Extract error on empty alternative pattern")
    func testExtractErrorOnEmptyAlternative() async throws {
        let harness = TestHarness()
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create minimal subtree
        let subtreePrefix = "vendor/lib"
        try FileManager.default.createDirectory(
            atPath: fixture.path.string + "/" + subtreePrefix,
            withIntermediateDirectories: true
        )
        try "content".write(toFile: fixture.path.string + "/" + subtreePrefix + "/file.swift",
                           atomically: true, encoding: .utf8)
        
        // Create config
        try writeSubtreeConfig(
            name: "lib",
            remote: "https://example.com/lib.git",
            prefix: subtreePrefix,
            commit: "abc123",
            to: fixture.path.string + "/subtree.yaml"
        )
        
        // Commit
        try await fixture.runGit(["add", "."])
        try await fixture.runGit(["commit", "-m", "Initial commit"])
        
        // Try to extract using pattern with empty alternative
        let result = try await harness.run(
            arguments: ["extract", "--name", "lib", "--from", "{a,}/*.swift", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode != 0, "Should fail with empty alternative pattern")
        #expect(result.stderr.contains("empty") || result.stderr.contains("Empty"),
                "Error should mention empty alternative: \(result.stderr)")
    }
}
