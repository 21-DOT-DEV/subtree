import Testing
import Foundation
@testable import SubtreeLib

@Suite("Config File Manager Tests")
struct ConfigFileManagerTests {
    
    // T006: Test generateMinimalConfig() returns valid YAML with header
    @Test("generateMinimalConfig() returns valid YAML with header comment")
    func testGenerateMinimalConfig() throws {
        let config = try ConfigFileManager.generateMinimalConfig()
        
        // Verify header comment exists
        #expect(config.contains("# Managed by subtree CLI"), "Should contain header comment")
        #expect(config.contains("https://github.com/21-DOT-DEV/subtree"), "Should contain GitHub URL")
        
        // Verify YAML structure
        #expect(config.contains("subtrees:"), "Should contain subtrees key")
        #expect(config.contains("[]"), "Should contain empty array")
    }
    
    // T007: Test configPath() constructs correct path from git root
    @Test("configPath() constructs correct path from git root")
    func testConfigPath() {
        let gitRoot = "/Users/test/myproject"
        let expectedPath = "/Users/test/myproject/subtree.yaml"
        
        let actualPath = ConfigFileManager.configPath(gitRoot: gitRoot)
        
        #expect(actualPath == expectedPath, "Should construct path as {gitRoot}/subtree.yaml")
    }
    
    // T008: Test createAtomically() creates file with correct content
    @Test("createAtomically() creates file with correct content")
    func testCreateAtomically() async throws {
        // Create temp directory for test
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let testPath = tempDir.appendingPathComponent("test-config.yaml").path
        let testContent = "# Test content\nsubtrees: []"
        
        try await ConfigFileManager.createAtomically(at: testPath, content: testContent)
        
        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: testPath), "File should exist")
        
        // Verify content matches
        let actualContent = try String(contentsOfFile: testPath, encoding: .utf8)
        #expect(actualContent == testContent, "File content should match")
    }
    
    // T009: Test exists() returns true/false correctly
    @Test("exists() returns true when file exists, false otherwise")
    func testExists() throws {
        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent(UUID().uuidString + ".yaml")
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        
        defer {
            try? FileManager.default.removeItem(at: testFile)
        }
        
        // Test file that exists
        #expect(ConfigFileManager.exists(at: testFile.path), "Should return true for existing file")
        
        // Test file that doesn't exist
        let nonExistentPath = "/tmp/nonexistent-\(UUID().uuidString).yaml"
        #expect(!ConfigFileManager.exists(at: nonExistentPath), "Should return false for non-existent file")
    }
    
    // MARK: - appendExtraction() Tests (008-extract-command)
    
    // T045: Test appendExtraction to subtree
    @Test("appendExtraction adds extraction to subtree")
    func testAppendExtractionToSubtree() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let configPath = tempDir.appendingPathComponent("subtree.yaml").path
        
        // Create initial config with one subtree (no extractions)
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "test-lib", remote: "https://github.com/test/lib", 
                        prefix: "vendor/lib", commit: "abc123")
        ])
        try await ConfigFileManager.writeConfig(config, to: configPath)
        
        // Append an extraction
        let extraction = ExtractionMapping(from: "docs/**/*.md", to: "project-docs/")
        try await ConfigFileManager.appendExtraction(extraction, to: "test-lib", in: configPath)
        
        // Load and verify
        let updatedConfig = try await ConfigFileManager.loadConfig(from: configPath)
        #expect(updatedConfig.subtrees.count == 1)
        #expect(updatedConfig.subtrees[0].extractions?.count == 1)
        #expect(updatedConfig.subtrees[0].extractions?[0].from == "docs/**/*.md")
    }
    
    // T046: Test appendExtraction creates extractions array if missing
    @Test("appendExtraction creates extractions array if missing")
    func testAppendExtractionCreatesArray() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let configPath = tempDir.appendingPathComponent("subtree.yaml").path
        
        // Create config with subtree that has nil extractions
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "my-lib", remote: "https://github.com/test/lib",
                        prefix: "vendor/lib", commit: "def456", extractions: nil)
        ])
        try await ConfigFileManager.writeConfig(config, to: configPath)
        
        // Append extraction
        let extraction = ExtractionMapping(from: "src/**/*.h", to: "include/")
        try await ConfigFileManager.appendExtraction(extraction, to: "my-lib", in: configPath)
        
        // Verify array was created
        let updatedConfig = try await ConfigFileManager.loadConfig(from: configPath)
        #expect(updatedConfig.subtrees[0].extractions != nil)
        #expect(updatedConfig.subtrees[0].extractions?.count == 1)
    }
    
    // T047: Test appendExtraction to existing extractions array
    @Test("appendExtraction appends to existing extractions array")
    func testAppendExtractionToExistingArray() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let configPath = tempDir.appendingPathComponent("subtree.yaml").path
        
        // Create config with existing extraction
        let existingExtraction = ExtractionMapping(from: "docs/**/*.md", to: "docs/")
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "secp256k1", remote: "https://github.com/bitcoin-core/secp256k1",
                        prefix: "vendor/secp256k1", commit: "ghi789", 
                        extractions: [existingExtraction])
        ])
        try await ConfigFileManager.writeConfig(config, to: configPath)
        
        // Append second extraction
        let newExtraction = ExtractionMapping(from: "src/**/*.{h,c}", to: "Sources/libsecp256k1/")
        try await ConfigFileManager.appendExtraction(newExtraction, to: "secp256k1", in: configPath)
        
        // Verify both extractions exist
        let updatedConfig = try await ConfigFileManager.loadConfig(from: configPath)
        #expect(updatedConfig.subtrees[0].extractions?.count == 2)
        #expect(updatedConfig.subtrees[0].extractions?[0].from == "docs/**/*.md")
        #expect(updatedConfig.subtrees[0].extractions?[1].from == "src/**/*.{h,c}")
    }
    
    // T048: Test appendExtraction case-insensitive subtree lookup
    @Test("appendExtraction uses case-insensitive subtree lookup")
    func testAppendExtractionCaseInsensitive() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let configPath = tempDir.appendingPathComponent("subtree.yaml").path
        
        // Create config with specific case
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "MyLibrary", remote: "https://github.com/test/lib",
                        prefix: "vendor/lib", commit: "jkl012")
        ])
        try await ConfigFileManager.writeConfig(config, to: configPath)
        
        // Append using different case
        let extraction = ExtractionMapping(from: "include/**/*.h", to: "Headers/")
        try await ConfigFileManager.appendExtraction(extraction, to: "mylibrary", in: configPath)
        
        // Verify it found the right subtree
        let updatedConfig = try await ConfigFileManager.loadConfig(from: configPath)
        #expect(updatedConfig.subtrees[0].name == "MyLibrary") // Original case preserved
        #expect(updatedConfig.subtrees[0].extractions?.count == 1)
    }
    
    // T049: Test appendExtraction error when subtree not found
    @Test("appendExtraction throws error when subtree not found")
    func testAppendExtractionSubtreeNotFound() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let configPath = tempDir.appendingPathComponent("subtree.yaml").path
        
        // Create config without the target subtree
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "other-lib", remote: "https://github.com/test/other",
                        prefix: "vendor/other", commit: "mno345")
        ])
        try await ConfigFileManager.writeConfig(config, to: configPath)
        
        // Try to append to non-existent subtree
        let extraction = ExtractionMapping(from: "**/*.txt", to: "files/")
        
        await #expect(throws: Error.self) {
            try await ConfigFileManager.appendExtraction(extraction, to: "nonexistent", in: configPath)
        }
    }
    
    // T050: Test appendExtraction atomicity (temp file pattern)
    @Test("appendExtraction uses atomic write with temp file")
    func testAppendExtractionAtomicity() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let configPath = tempDir.appendingPathComponent("subtree.yaml").path
        
        // Create initial config
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "atomic-test", remote: "https://github.com/test/atomic",
                        prefix: "vendor/atomic", commit: "pqr678")
        ])
        try await ConfigFileManager.writeConfig(config, to: configPath)
        
        // Append extraction (should use atomic write internally)
        let extraction = ExtractionMapping(from: "lib/**/*.a", to: "Libraries/")
        try await ConfigFileManager.appendExtraction(extraction, to: "atomic-test", in: configPath)
        
        // Verify no temp files left behind
        let contents = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        let tempFiles = contents.filter { $0.contains(".tmp.") }
        #expect(tempFiles.isEmpty, "Should not leave temp files after atomic write")
        
        // Verify config was updated correctly
        let updatedConfig = try await ConfigFileManager.loadConfig(from: configPath)
        #expect(updatedConfig.subtrees[0].extractions?.count == 1)
    }
}
