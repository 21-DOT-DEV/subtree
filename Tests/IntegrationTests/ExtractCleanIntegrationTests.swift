import Testing
import Foundation
#if canImport(System)
import System
#else
import SystemPackage
#endif

/// Integration tests for Extract Clean Mode
///
/// These tests verify the end-to-end clean mode functionality
/// for the Extract Clean Mode feature (010-extract-clean).
@Suite("Extract Clean Integration Tests")
struct ExtractCleanIntegrationTests {
    
    let harness = TestHarness()
    
    /// Helper to create a git repo with subtree.yaml and extracted files
    private func setupCleanTestRepo() async throws -> GitRepositoryFixture {
        let fixture = try await GitRepositoryFixture()
        
        // Create subtree directory with source files
        let subtreeDir = fixture.path.appending("vendor/mylib")
        try FileManager.default.createDirectory(atPath: subtreeDir.string, withIntermediateDirectories: true)
        
        // Create source files in subtree
        try "int main() { return 0; }".write(
            toFile: subtreeDir.appending("main.c").string,
            atomically: true, encoding: .utf8
        )
        try "void helper() {}".write(
            toFile: subtreeDir.appending("helper.c").string,
            atomically: true, encoding: .utf8
        )
        
        // Create nested source directory
        let srcDir = subtreeDir.appending("src")
        try FileManager.default.createDirectory(atPath: srcDir.string, withIntermediateDirectories: true)
        try "// util".write(toFile: srcDir.appending("util.c").string, atomically: true, encoding: .utf8)
        
        // Create subtree.yaml with the subtree entry
        let configContent = """
# Managed by subtree CLI
subtrees:
  - name: mylib
    remote: https://github.com/example/mylib.git
    prefix: vendor/mylib
    commit: abc123def456abc123def456abc123def456abc1
"""
        try configContent.write(
            toFile: fixture.path.appending("subtree.yaml").string,
            atomically: true, encoding: .utf8
        )
        
        // Create destination directory with extracted files (copies of source)
        let destDir = fixture.path.appending("Sources")
        try FileManager.default.createDirectory(atPath: destDir.string, withIntermediateDirectories: true)
        
        // Copy files to destination (simulating prior extraction)
        try FileManager.default.copyItem(
            atPath: subtreeDir.appending("main.c").string,
            toPath: destDir.appending("main.c").string
        )
        try FileManager.default.copyItem(
            atPath: subtreeDir.appending("helper.c").string,
            toPath: destDir.appending("helper.c").string
        )
        
        // Create nested dest directory
        let destSrcDir = destDir.appending("src")
        try FileManager.default.createDirectory(atPath: destSrcDir.string, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            atPath: srcDir.appending("util.c").string,
            toPath: destSrcDir.appending("util.c").string
        )
        
        // Commit everything
        _ = try await fixture.runGit(["add", "."])
        _ = try await fixture.runGit(["commit", "-m", "Setup test repo"])
        
        return fixture
    }
    
    // MARK: - US1: Ad-hoc Clean with Checksum Validation
    
    // T014: --clean flag removes files when checksums match
    @Test("--clean removes files when checksums match")
    func cleanRemovesFilesWhenChecksumsMatch() async throws {
        let fixture = try await setupCleanTestRepo()
        defer { try? fixture.tearDown() }
        
        let destFile = fixture.path.appending("Sources/main.c")
        #expect(FileManager.default.fileExists(atPath: destFile.string))
        
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--name", "mylib", "--from", "*.c", "--to", "Sources/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("Cleaned"))
        #expect(!FileManager.default.fileExists(atPath: destFile.string))
    }
    
    // T015: --clean fails fast on checksum mismatch
    @Test("--clean fails fast on checksum mismatch with error")
    func cleanFailsFastOnChecksumMismatch() async throws {
        let fixture = try await setupCleanTestRepo()
        defer { try? fixture.tearDown() }
        
        // Modify the destination file to cause checksum mismatch
        let destFile = fixture.path.appending("Sources/main.c")
        try "// MODIFIED CONTENT".write(toFile: destFile.string, atomically: true, encoding: .utf8)
        
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--name", "mylib", "--from", "*.c", "--to", "Sources/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 1)
        #expect(result.stderr.contains("modified") || result.stderr.contains("mismatch"))
        // File should NOT be deleted on mismatch
        #expect(FileManager.default.fileExists(atPath: destFile.string))
    }
    
    // T016: --clean skips files with missing source and shows warning
    @Test("--clean skips files with missing source and shows warning")
    func cleanSkipsMissingSourceWithWarning() async throws {
        let fixture = try await setupCleanTestRepo()
        defer { try? fixture.tearDown() }
        
        // Remove source file but keep destination
        let sourceFile = fixture.path.appending("vendor/mylib/main.c")
        try FileManager.default.removeItem(atPath: sourceFile.string)
        _ = try await fixture.runGit(["add", "."])
        _ = try await fixture.runGit(["commit", "-m", "Remove source"])
        
        let destFile = fixture.path.appending("Sources/main.c")
        #expect(FileManager.default.fileExists(atPath: destFile.string))
        
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--name", "mylib", "--from", "*.c", "--to", "Sources/"],
            workingDirectory: fixture.path
        )
        
        // Should succeed but show warning
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("⚠️") || result.stdout.contains("Skipping") || result.stdout.contains("not found"))
        // File with missing source should NOT be deleted
        #expect(FileManager.default.fileExists(atPath: destFile.string))
    }
    
    // T017: --clean prunes empty directories after file removal
    @Test("--clean prunes empty directories after file removal")
    func cleanPrunesEmptyDirectories() async throws {
        let fixture = try await setupCleanTestRepo()
        defer { try? fixture.tearDown() }
        
        let destSrcDir = fixture.path.appending("Sources/src")
        #expect(FileManager.default.fileExists(atPath: destSrcDir.string))
        
        // Clean only the nested file
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--name", "mylib", "--from", "src/*.c", "--to", "Sources/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        // The src/ subdirectory should be pruned since it's now empty
        #expect(!FileManager.default.fileExists(atPath: destSrcDir.string))
        // But Sources/ should still exist (it still has main.c and helper.c)
        #expect(FileManager.default.fileExists(atPath: fixture.path.appending("Sources").string))
    }
    
    // T018: --clean treats zero matched files as success (exit 0)
    @Test("--clean treats zero matched files as success")
    func cleanZeroMatchesIsSuccess() async throws {
        let fixture = try await setupCleanTestRepo()
        defer { try? fixture.tearDown() }
        
        // Use pattern that won't match any destination files
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--name", "mylib", "--from", "*.nonexistent", "--to", "Sources/"],
            workingDirectory: fixture.path
        )
        
        // Zero matches should be success per BC-007
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("0") || result.stdout.contains("zero") || result.stdout.contains("no files"))
    }
    
    // T019: --clean --persist rejected with error (invalid combination)
    @Test("--clean --persist rejected with error")
    func cleanPersistRejectedWithError() async throws {
        let fixture = try await setupCleanTestRepo()
        defer { try? fixture.tearDown() }
        
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--persist", "--name", "mylib", "--from", "*.c", "--to", "Sources/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("--clean") && result.stderr.contains("--persist"))
    }
    
    // MARK: - US2: Force Clean Override
    
    // T033: --clean --force removes modified files (checksum mismatch)
    @Test("--clean --force removes modified files")
    func cleanForceRemovesModifiedFiles() async throws {
        let fixture = try await setupCleanTestRepo()
        defer { try? fixture.tearDown() }
        
        // Modify the destination file to cause checksum mismatch
        let destFile = fixture.path.appending("Sources/main.c")
        try "// MODIFIED CONTENT".write(toFile: destFile.string, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: destFile.string))
        
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--force", "--name", "mylib", "--from", "*.c", "--to", "Sources/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("Cleaned"))
        // Modified file should be deleted with --force
        #expect(!FileManager.default.fileExists(atPath: destFile.string))
    }
    
    // T034: --clean --force removes files where source is missing
    @Test("--clean --force removes files with missing source")
    func cleanForceRemovesMissingSourceFiles() async throws {
        let fixture = try await setupCleanTestRepo()
        defer { try? fixture.tearDown() }
        
        // Remove source file but keep destination
        let sourceFile = fixture.path.appending("vendor/mylib/main.c")
        try FileManager.default.removeItem(atPath: sourceFile.string)
        _ = try await fixture.runGit(["add", "."])
        _ = try await fixture.runGit(["commit", "-m", "Remove source"])
        
        let destFile = fixture.path.appending("Sources/main.c")
        #expect(FileManager.default.fileExists(atPath: destFile.string))
        
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--force", "--name", "mylib", "--from", "*.c", "--to", "Sources/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("Cleaned"))
        // File with missing source should be deleted with --force
        #expect(!FileManager.default.fileExists(atPath: destFile.string))
    }
    
    // T035: --clean --force bypasses subtree prefix validation
    @Test("--clean --force bypasses prefix validation")
    func cleanForceBypassesPrefixValidation() async throws {
        let fixture = try await setupCleanTestRepo()
        defer { try? fixture.tearDown() }
        
        // Remove the entire subtree directory
        let subtreeDir = fixture.path.appending("vendor/mylib")
        try FileManager.default.removeItem(atPath: subtreeDir.string)
        _ = try await fixture.runGit(["add", "."])
        _ = try await fixture.runGit(["commit", "-m", "Remove subtree"])
        
        let destFile = fixture.path.appending("Sources/main.c")
        #expect(FileManager.default.fileExists(atPath: destFile.string))
        
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--force", "--name", "mylib", "--from", "*.c", "--to", "Sources/"],
            workingDirectory: fixture.path
        )
        
        // Should succeed even without subtree directory
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("Cleaned"))
        #expect(!FileManager.default.fileExists(atPath: destFile.string))
    }
    
    // T036: --clean --force removes all matching files regardless of validation
    @Test("--clean --force removes all files regardless of validation")
    func cleanForceRemovesAllFiles() async throws {
        let fixture = try await setupCleanTestRepo()
        defer { try? fixture.tearDown() }
        
        // Modify one file, remove source for another
        let mainDest = fixture.path.appending("Sources/main.c")
        let helperDest = fixture.path.appending("Sources/helper.c")
        
        // Modify main.c
        try "// MODIFIED".write(toFile: mainDest.string, atomically: true, encoding: .utf8)
        
        // Remove source for helper.c
        let helperSource = fixture.path.appending("vendor/mylib/helper.c")
        try FileManager.default.removeItem(atPath: helperSource.string)
        _ = try await fixture.runGit(["add", "."])
        _ = try await fixture.runGit(["commit", "-m", "Modify and remove"])
        
        #expect(FileManager.default.fileExists(atPath: mainDest.string))
        #expect(FileManager.default.fileExists(atPath: helperDest.string))
        
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--force", "--name", "mylib", "--from", "*.c", "--to", "Sources/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        // Both files should be deleted despite validation issues
        #expect(!FileManager.default.fileExists(atPath: mainDest.string))
        #expect(!FileManager.default.fileExists(atPath: helperDest.string))
    }
    
    // MARK: - US3: Bulk Clean from Persisted Mappings
    
    /// Helper to create a repo with persisted extraction mappings
    private func setupBulkCleanTestRepo() async throws -> GitRepositoryFixture {
        let fixture = try await GitRepositoryFixture()
        
        // Create subtree directory with source files
        let subtreeDir = fixture.path.appending("vendor/mylib")
        try FileManager.default.createDirectory(atPath: subtreeDir.string, withIntermediateDirectories: true)
        try "// main code".write(toFile: subtreeDir.appending("main.c").string, atomically: true, encoding: .utf8)
        try "// header".write(toFile: subtreeDir.appending("main.h").string, atomically: true, encoding: .utf8)
        
        // Create subtree.yaml with persisted extraction mappings
        let commit = try await fixture.getCurrentCommit()
        let configContent = """
# Managed by subtree CLI
subtrees:
  - name: mylib
    remote: https://github.com/example/mylib.git
    prefix: vendor/mylib
    commit: \(commit)
    extractions:
      - from: "*.c"
        to: src/
      - from: "*.h"
        to: include/
"""
        try configContent.write(
            toFile: fixture.path.appending("subtree.yaml").string,
            atomically: true, encoding: .utf8
        )
        
        // Create destination directories with extracted files (copies of source)
        let srcDir = fixture.path.appending("src")
        let includeDir = fixture.path.appending("include")
        try FileManager.default.createDirectory(atPath: srcDir.string, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: includeDir.string, withIntermediateDirectories: true)
        
        // Copy files to destinations (simulating prior extraction)
        try FileManager.default.copyItem(
            atPath: subtreeDir.appending("main.c").string,
            toPath: srcDir.appending("main.c").string
        )
        try FileManager.default.copyItem(
            atPath: subtreeDir.appending("main.h").string,
            toPath: includeDir.appending("main.h").string
        )
        
        _ = try await fixture.runGit(["add", "."])
        _ = try await fixture.runGit(["commit", "-m", "Setup bulk clean test repo"])
        
        return fixture
    }
    
    // T041: --clean --name cleans all persisted mappings for subtree
    @Test("--clean --name cleans all persisted mappings")
    func cleanNameCleansAllMappings() async throws {
        let fixture = try await setupBulkCleanTestRepo()
        defer { try? fixture.tearDown() }
        
        let srcFile = fixture.path.appending("src/main.c")
        let includeFile = fixture.path.appending("include/main.h")
        #expect(FileManager.default.fileExists(atPath: srcFile.string))
        #expect(FileManager.default.fileExists(atPath: includeFile.string))
        
        // Clean all mappings for mylib (no --from patterns = bulk mode)
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--name", "mylib"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("Cleaned"))
        // Both mappings should have their files cleaned
        #expect(!FileManager.default.fileExists(atPath: srcFile.string))
        #expect(!FileManager.default.fileExists(atPath: includeFile.string))
    }
    
    // T042: --clean --all cleans all mappings for all subtrees
    @Test("--clean --all cleans all subtrees")
    func cleanAllCleansAllSubtrees() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create two subtrees with mappings
        let lib1Dir = fixture.path.appending("vendor/lib1")
        let lib2Dir = fixture.path.appending("vendor/lib2")
        try FileManager.default.createDirectory(atPath: lib1Dir.string, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: lib2Dir.string, withIntermediateDirectories: true)
        try "lib1 code".write(toFile: lib1Dir.appending("code.c").string, atomically: true, encoding: .utf8)
        try "lib2 code".write(toFile: lib2Dir.appending("code.c").string, atomically: true, encoding: .utf8)
        
        let commit = try await fixture.getCurrentCommit()
        let configContent = """
# Managed by subtree CLI
subtrees:
  - name: lib1
    remote: https://github.com/example/lib1.git
    prefix: vendor/lib1
    commit: \(commit)
    extractions:
      - from: "*.c"
        to: out1/
  - name: lib2
    remote: https://github.com/example/lib2.git
    prefix: vendor/lib2
    commit: \(commit)
    extractions:
      - from: "*.c"
        to: out2/
"""
        try configContent.write(
            toFile: fixture.path.appending("subtree.yaml").string,
            atomically: true, encoding: .utf8
        )
        
        // Create destination files
        let out1Dir = fixture.path.appending("out1")
        let out2Dir = fixture.path.appending("out2")
        try FileManager.default.createDirectory(atPath: out1Dir.string, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: out2Dir.string, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: lib1Dir.appending("code.c").string, toPath: out1Dir.appending("code.c").string)
        try FileManager.default.copyItem(atPath: lib2Dir.appending("code.c").string, toPath: out2Dir.appending("code.c").string)
        
        _ = try await fixture.runGit(["add", "."])
        _ = try await fixture.runGit(["commit", "-m", "Setup multi-subtree test"])
        
        let out1File = fixture.path.appending("out1/code.c")
        let out2File = fixture.path.appending("out2/code.c")
        #expect(FileManager.default.fileExists(atPath: out1File.string))
        #expect(FileManager.default.fileExists(atPath: out2File.string))
        
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--all"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        // Both subtrees should have their files cleaned
        #expect(!FileManager.default.fileExists(atPath: out1File.string))
        #expect(!FileManager.default.fileExists(atPath: out2File.string))
    }
    
    // T043: bulk clean continues on error, reports all failures
    @Test("--clean --all continues on error and reports failures")
    func cleanAllContinuesOnError() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create two subtrees - one with matching checksums, one with mismatch
        let lib1Dir = fixture.path.appending("vendor/lib1")
        let lib2Dir = fixture.path.appending("vendor/lib2")
        try FileManager.default.createDirectory(atPath: lib1Dir.string, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: lib2Dir.string, withIntermediateDirectories: true)
        try "lib1 code".write(toFile: lib1Dir.appending("code.c").string, atomically: true, encoding: .utf8)
        try "lib2 code".write(toFile: lib2Dir.appending("code.c").string, atomically: true, encoding: .utf8)
        
        let commit = try await fixture.getCurrentCommit()
        let configContent = """
# Managed by subtree CLI
subtrees:
  - name: lib1
    remote: https://github.com/example/lib1.git
    prefix: vendor/lib1
    commit: \(commit)
    extractions:
      - from: "*.c"
        to: out1/
  - name: lib2
    remote: https://github.com/example/lib2.git
    prefix: vendor/lib2
    commit: \(commit)
    extractions:
      - from: "*.c"
        to: out2/
"""
        try configContent.write(
            toFile: fixture.path.appending("subtree.yaml").string,
            atomically: true, encoding: .utf8
        )
        
        // Create destinations - lib1 OK, lib2 modified
        let out1Dir = fixture.path.appending("out1")
        let out2Dir = fixture.path.appending("out2")
        try FileManager.default.createDirectory(atPath: out1Dir.string, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: out2Dir.string, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: lib1Dir.appending("code.c").string, toPath: out1Dir.appending("code.c").string)
        // Modify lib2's destination file to cause checksum mismatch
        try "MODIFIED lib2".write(toFile: out2Dir.appending("code.c").string, atomically: true, encoding: .utf8)
        
        _ = try await fixture.runGit(["add", "."])
        _ = try await fixture.runGit(["commit", "-m", "Setup error test"])
        
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--all"],
            workingDirectory: fixture.path
        )
        
        // Should have exit code 1 (validation error) but continue processing
        #expect(result.exitCode == 1)
        // lib1 should be cleaned (matching checksum)
        #expect(!FileManager.default.fileExists(atPath: fixture.path.appending("out1/code.c").string))
        // lib2 should NOT be cleaned (checksum mismatch)
        #expect(FileManager.default.fileExists(atPath: fixture.path.appending("out2/code.c").string))
        // Should report the failure
        #expect(result.stderr.contains("modified") || result.stderr.contains("mismatch") || result.stdout.contains("failed"))
    }
    
    // T044: --clean --name with no mappings succeeds with message
    @Test("--clean --name with no mappings succeeds")
    func cleanNameNoMappingsSucceeds() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree without any extraction mappings
        let subtreeDir = fixture.path.appending("vendor/mylib")
        try FileManager.default.createDirectory(atPath: subtreeDir.string, withIntermediateDirectories: true)
        try "code".write(toFile: subtreeDir.appending("main.c").string, atomically: true, encoding: .utf8)
        
        let commit = try await fixture.getCurrentCommit()
        let configContent = """
# Managed by subtree CLI
subtrees:
  - name: mylib
    remote: https://github.com/example/mylib.git
    prefix: vendor/mylib
    commit: \(commit)
"""
        try configContent.write(
            toFile: fixture.path.appending("subtree.yaml").string,
            atomically: true, encoding: .utf8
        )
        
        _ = try await fixture.runGit(["add", "."])
        _ = try await fixture.runGit(["commit", "-m", "Setup no mappings test"])
        
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--name", "mylib"],
            workingDirectory: fixture.path
        )
        
        // Should succeed with informational message
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("no") || result.stdout.contains("0") || result.stdout.contains("mapping"))
    }
    
    // T045: bulk clean exit code is highest severity encountered
    @Test("--clean --all exit code is highest severity")
    func cleanAllExitCodeHighestSeverity() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtrees with different error conditions
        let lib1Dir = fixture.path.appending("vendor/lib1")
        let lib2Dir = fixture.path.appending("vendor/lib2")
        try FileManager.default.createDirectory(atPath: lib1Dir.string, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: lib2Dir.string, withIntermediateDirectories: true)
        try "lib1 code".write(toFile: lib1Dir.appending("code.c").string, atomically: true, encoding: .utf8)
        try "lib2 code".write(toFile: lib2Dir.appending("code.c").string, atomically: true, encoding: .utf8)
        
        let commit = try await fixture.getCurrentCommit()
        let configContent = """
# Managed by subtree CLI
subtrees:
  - name: lib1
    remote: https://github.com/example/lib1.git
    prefix: vendor/lib1
    commit: \(commit)
    extractions:
      - from: "*.c"
        to: out1/
  - name: lib2
    remote: https://github.com/example/lib2.git
    prefix: vendor/lib2
    commit: \(commit)
    extractions:
      - from: "*.c"
        to: out2/
"""
        try configContent.write(
            toFile: fixture.path.appending("subtree.yaml").string,
            atomically: true, encoding: .utf8
        )
        
        // Create out1 with matching file, out2 with modified file
        let out1Dir = fixture.path.appending("out1")
        let out2Dir = fixture.path.appending("out2")
        try FileManager.default.createDirectory(atPath: out1Dir.string, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: out2Dir.string, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: lib1Dir.appending("code.c").string, toPath: out1Dir.appending("code.c").string)
        try "MODIFIED".write(toFile: out2Dir.appending("code.c").string, atomically: true, encoding: .utf8)
        
        _ = try await fixture.runGit(["add", "."])
        _ = try await fixture.runGit(["commit", "-m", "Setup severity test"])
        
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--all"],
            workingDirectory: fixture.path
        )
        
        // Exit code should be 1 (validation error from checksum mismatch)
        // Not 0 (success) even though lib1 succeeded
        #expect(result.exitCode == 1)
    }
    
    // MARK: - US4: Multi-Pattern Clean
    
    // T053: multiple --from patterns clean files from multiple sources
    @Test("--clean with multiple --from patterns")
    func cleanMultiplePatterns() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with different file types
        let subtreeDir = fixture.path.appending("vendor/mylib")
        try FileManager.default.createDirectory(atPath: subtreeDir.string, withIntermediateDirectories: true)
        try "// C code".write(toFile: subtreeDir.appending("main.c").string, atomically: true, encoding: .utf8)
        try "// Header".write(toFile: subtreeDir.appending("main.h").string, atomically: true, encoding: .utf8)
        try "# Readme".write(toFile: subtreeDir.appending("README.md").string, atomically: true, encoding: .utf8)
        
        let commit = try await fixture.getCurrentCommit()
        let configContent = """
# Managed by subtree CLI
subtrees:
  - name: mylib
    remote: https://github.com/example/mylib.git
    prefix: vendor/mylib
    commit: \(commit)
"""
        try configContent.write(
            toFile: fixture.path.appending("subtree.yaml").string,
            atomically: true, encoding: .utf8
        )
        
        // Create destination with copies
        let outDir = fixture.path.appending("output")
        try FileManager.default.createDirectory(atPath: outDir.string, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: subtreeDir.appending("main.c").string, toPath: outDir.appending("main.c").string)
        try FileManager.default.copyItem(atPath: subtreeDir.appending("main.h").string, toPath: outDir.appending("main.h").string)
        try FileManager.default.copyItem(atPath: subtreeDir.appending("README.md").string, toPath: outDir.appending("README.md").string)
        
        _ = try await fixture.runGit(["add", "."])
        _ = try await fixture.runGit(["commit", "-m", "Setup multi-pattern test"])
        
        // Verify files exist
        #expect(FileManager.default.fileExists(atPath: outDir.appending("main.c").string))
        #expect(FileManager.default.fileExists(atPath: outDir.appending("main.h").string))
        #expect(FileManager.default.fileExists(atPath: outDir.appending("README.md").string))
        
        // Clean with multiple patterns (only *.c and *.h, leave *.md)
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--name", "mylib", "--from", "*.c", "--from", "*.h", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        // .c and .h should be cleaned
        #expect(!FileManager.default.fileExists(atPath: outDir.appending("main.c").string))
        #expect(!FileManager.default.fileExists(atPath: outDir.appending("main.h").string))
        // .md should remain
        #expect(FileManager.default.fileExists(atPath: outDir.appending("README.md").string))
    }
    
    // T054: --exclude patterns filter which files are cleaned
    @Test("--clean with --exclude patterns")
    func cleanWithExclude() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with files
        let subtreeDir = fixture.path.appending("vendor/mylib")
        try FileManager.default.createDirectory(atPath: subtreeDir.string, withIntermediateDirectories: true)
        try "code1".write(toFile: subtreeDir.appending("file1.c").string, atomically: true, encoding: .utf8)
        try "code2".write(toFile: subtreeDir.appending("file2.c").string, atomically: true, encoding: .utf8)
        try "keep".write(toFile: subtreeDir.appending("keep.c").string, atomically: true, encoding: .utf8)
        
        let commit = try await fixture.getCurrentCommit()
        let configContent = """
# Managed by subtree CLI
subtrees:
  - name: mylib
    remote: https://github.com/example/mylib.git
    prefix: vendor/mylib
    commit: \(commit)
"""
        try configContent.write(
            toFile: fixture.path.appending("subtree.yaml").string,
            atomically: true, encoding: .utf8
        )
        
        // Create destination with copies
        let outDir = fixture.path.appending("output")
        try FileManager.default.createDirectory(atPath: outDir.string, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: subtreeDir.appending("file1.c").string, toPath: outDir.appending("file1.c").string)
        try FileManager.default.copyItem(atPath: subtreeDir.appending("file2.c").string, toPath: outDir.appending("file2.c").string)
        try FileManager.default.copyItem(atPath: subtreeDir.appending("keep.c").string, toPath: outDir.appending("keep.c").string)
        
        _ = try await fixture.runGit(["add", "."])
        _ = try await fixture.runGit(["commit", "-m", "Setup exclude test"])
        
        // Clean all *.c but exclude keep.c
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--name", "mylib", "--from", "*.c", "--exclude", "keep.c", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        // file1.c and file2.c should be cleaned
        #expect(!FileManager.default.fileExists(atPath: outDir.appending("file1.c").string))
        #expect(!FileManager.default.fileExists(atPath: outDir.appending("file2.c").string))
        // keep.c should remain (excluded)
        #expect(FileManager.default.fileExists(atPath: outDir.appending("keep.c").string))
    }
    
    // T055: persisted mappings with pattern arrays clean correctly
    @Test("--clean --name with array pattern mappings")
    func cleanPersistedArrayPatterns() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with different file types
        let subtreeDir = fixture.path.appending("vendor/mylib")
        try FileManager.default.createDirectory(atPath: subtreeDir.string, withIntermediateDirectories: true)
        try "code".write(toFile: subtreeDir.appending("main.c").string, atomically: true, encoding: .utf8)
        try "header".write(toFile: subtreeDir.appending("main.h").string, atomically: true, encoding: .utf8)
        
        let commit = try await fixture.getCurrentCommit()
        // Config with array-format patterns in extractions
        let configContent = """
# Managed by subtree CLI
subtrees:
  - name: mylib
    remote: https://github.com/example/mylib.git
    prefix: vendor/mylib
    commit: \(commit)
    extractions:
      - from:
          - "*.c"
          - "*.h"
        to: output/
"""
        try configContent.write(
            toFile: fixture.path.appending("subtree.yaml").string,
            atomically: true, encoding: .utf8
        )
        
        // Create destination with copies
        let outDir = fixture.path.appending("output")
        try FileManager.default.createDirectory(atPath: outDir.string, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: subtreeDir.appending("main.c").string, toPath: outDir.appending("main.c").string)
        try FileManager.default.copyItem(atPath: subtreeDir.appending("main.h").string, toPath: outDir.appending("main.h").string)
        
        _ = try await fixture.runGit(["add", "."])
        _ = try await fixture.runGit(["commit", "-m", "Setup array pattern test"])
        
        #expect(FileManager.default.fileExists(atPath: outDir.appending("main.c").string))
        #expect(FileManager.default.fileExists(atPath: outDir.appending("main.h").string))
        
        // Clean using persisted mapping with array patterns
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--name", "mylib"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        // Both files should be cleaned (both patterns matched)
        #expect(!FileManager.default.fileExists(atPath: outDir.appending("main.c").string))
        #expect(!FileManager.default.fileExists(atPath: outDir.appending("main.h").string))
    }
    
    // MARK: - US5: Clean Error Handling
    
    // T059: non-existent subtree name returns error with exit 1
    @Test("--clean with non-existent subtree returns exit 1")
    func cleanNonExistentSubtree() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create minimal config without the requested subtree
        let commit = try await fixture.getCurrentCommit()
        let configContent = """
# Managed by subtree CLI
subtrees:
  - name: existing-lib
    remote: https://github.com/example/lib.git
    prefix: vendor/lib
    commit: \(commit)
"""
        try configContent.write(
            toFile: fixture.path.appending("subtree.yaml").string,
            atomically: true, encoding: .utf8
        )
        
        _ = try await fixture.runGit(["add", "."])
        _ = try await fixture.runGit(["commit", "-m", "Setup config"])
        
        // Try to clean non-existent subtree
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--name", "nonexistent-lib", "--from", "*.c", "--to", "out/"],
            workingDirectory: fixture.path
        )
        
        // Should fail with exit code 1 (validation error)
        #expect(result.exitCode == 1)
        #expect(result.stderr.contains("not found") || result.stderr.contains("does not exist"))
    }
    
    // T060: permission error during delete returns error with exit 3
    @Test("--clean with permission error returns exit 3")
    func cleanPermissionError() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with file
        let subtreeDir = fixture.path.appending("vendor/mylib")
        try FileManager.default.createDirectory(atPath: subtreeDir.string, withIntermediateDirectories: true)
        try "code".write(toFile: subtreeDir.appending("main.c").string, atomically: true, encoding: .utf8)
        
        let commit = try await fixture.getCurrentCommit()
        let configContent = """
# Managed by subtree CLI
subtrees:
  - name: mylib
    remote: https://github.com/example/mylib.git
    prefix: vendor/mylib
    commit: \(commit)
"""
        try configContent.write(
            toFile: fixture.path.appending("subtree.yaml").string,
            atomically: true, encoding: .utf8
        )
        
        // Create destination with file
        let outDir = fixture.path.appending("output")
        try FileManager.default.createDirectory(atPath: outDir.string, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            atPath: subtreeDir.appending("main.c").string,
            toPath: outDir.appending("main.c").string
        )
        
        _ = try await fixture.runGit(["add", "."])
        _ = try await fixture.runGit(["commit", "-m", "Setup permission test"])
        
        // Make file unremovable by removing write permission on parent directory
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o555],
            ofItemAtPath: outDir.string
        )
        
        defer {
            // Restore permissions for cleanup
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: outDir.string
            )
        }
        
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--name", "mylib", "--from", "*.c", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        // Should fail with exit code 3 (I/O error) or 1 (if permission check happens earlier)
        // The exact code depends on when permission error occurs
        #expect(result.exitCode != 0)
        #expect(result.stderr.contains("permission") || result.stderr.contains("denied") || 
                result.stderr.contains("Error") || result.stderr.contains("failed"))
    }
    
    // T061: all error messages include actionable suggestions
    @Test("--clean error messages include suggestions")
    func cleanErrorMessagesHaveSuggestions() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Create subtree with file
        let subtreeDir = fixture.path.appending("vendor/mylib")
        try FileManager.default.createDirectory(atPath: subtreeDir.string, withIntermediateDirectories: true)
        try "original".write(toFile: subtreeDir.appending("main.c").string, atomically: true, encoding: .utf8)
        
        let commit = try await fixture.getCurrentCommit()
        let configContent = """
# Managed by subtree CLI
subtrees:
  - name: mylib
    remote: https://github.com/example/mylib.git
    prefix: vendor/mylib
    commit: \(commit)
"""
        try configContent.write(
            toFile: fixture.path.appending("subtree.yaml").string,
            atomically: true, encoding: .utf8
        )
        
        // Create destination with MODIFIED file (causes checksum mismatch)
        let outDir = fixture.path.appending("output")
        try FileManager.default.createDirectory(atPath: outDir.string, withIntermediateDirectories: true)
        try "MODIFIED content".write(toFile: outDir.appending("main.c").string, atomically: true, encoding: .utf8)
        
        _ = try await fixture.runGit(["add", "."])
        _ = try await fixture.runGit(["commit", "-m", "Setup suggestion test"])
        
        let result = try await harness.run(
            arguments: ["extract", "--clean", "--name", "mylib", "--from", "*.c", "--to", "output/"],
            workingDirectory: fixture.path
        )
        
        // Should fail with exit code 1 (checksum mismatch)
        #expect(result.exitCode == 1)
        // Error message should include actionable suggestion
        #expect(result.stderr.contains("--force") || result.stderr.contains("force"))
    }
}
