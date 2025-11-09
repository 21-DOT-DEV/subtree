import Foundation
import Testing
import Yams
#if canImport(System)
import System
#else
import SystemPackage
#endif

/// Integration tests for subtree remove command
@Suite("Remove Integration Tests")
struct RemoveIntegrationTests {
    
    // MARK: - Phase 2: Error Message Tests (TDD)
    
    // T015: Test config not found error
    @Test("Config not found error shows helpful message with exit code 3")
    func testConfigNotFoundError() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Don't initialize config - leave it missing
        let result = try await harness.run(
            arguments: ["remove", "nonexistent"],
            workingDirectory: fixture.path
        )
        
        // Verify exit code 3 and error message
        #expect(result.exitCode == 3)
        #expect(result.stdout.contains("❌"))
        #expect(result.stdout.contains("Configuration file not found"))
        #expect(result.stdout.contains("subtree init"))
    }
    
    // T016: Test config malformed error
    @Test("Config malformed error shows parse details with exit code 3")
    func testConfigMalformedError() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Create malformed config file
        let configPath = "\(fixture.path.string)/subtree.yaml"
        let malformedContent = "subtrees: [unclosed bracket"
        try malformedContent.write(toFile: configPath, atomically: true, encoding: .utf8)
        
        let result = try await harness.run(
            arguments: ["remove", "test"],
            workingDirectory: fixture.path
        )
        
        // Verify exit code 3 and error message mentions malformed config
        #expect(result.exitCode == 3)
        #expect(result.stdout.contains("❌"))
        #expect(result.stdout.contains("malformed") || result.stdout.contains("parse"))
    }
    
    // T017: Test subtree not found error
    @Test("Subtree not found error shows clear message with exit code 1")
    func testSubtreeNotFoundError() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize with empty config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Try to remove non-existent subtree
        let result = try await harness.run(
            arguments: ["remove", "nonexistent"],
            workingDirectory: fixture.path
        )
        
        // Verify exit code 1 (user error - not found) and error message
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains("❌"))
        #expect(result.stdout.contains("nonexistent"))
        #expect(result.stdout.contains("not found"))
    }
    
    // T018: Test dirty working tree error
    @Test("Dirty working tree error shows helpful message with exit code 1")
    func testDirtyWorkingTreeError() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Add a subtree (minimal setup)
        // Note: This would require network access, so we'll create a mock subtree entry
        // For now, create a dummy file to make working tree dirty
        let dummyFile = "\(fixture.path.string)/uncommitted.txt"
        try "uncommitted change".write(toFile: dummyFile, atomically: true, encoding: .utf8)
        
        // Add to git but don't commit
        _ = try await harness.runGit(["add", "uncommitted.txt"], in: fixture.path)
        
        // Add a dummy subtree to config manually
        let configPath = "\(fixture.path.string)/subtree.yaml"
        let configWithSubtree = """
        subtrees:
          - name: test-lib
            remote: https://example.com/test.git
            prefix: test
            commit: abc1234567890123456789012345678901234567
            branch: main
        """
        try configWithSubtree.write(toFile: configPath, atomically: true, encoding: .utf8)
        
        // Try to remove with dirty tree
        let result = try await harness.run(
            arguments: ["remove", "test-lib"],
            workingDirectory: fixture.path
        )
        
        // Verify exit code 1 and error message
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains("❌"))
        #expect(result.stdout.contains("uncommitted") || result.stdout.contains("changes"))
    }
    
    // T019: Test not in git repo error  
    @Test("Not in git repo error shows clear message with exit code 1")
    func testNotInGitRepoError() async throws {
        let harness = TestHarness()
        
        // Create temporary non-git directory
        let tempDir = FilePath("/tmp/non-git-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: tempDir.string, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir.string) }
        
        // Try to remove in non-git directory
        let result = try await harness.run(
            arguments: ["remove", "test"],
            workingDirectory: tempDir
        )
        
        // Verify exit code 1 and error message
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains("❌"))
        #expect(result.stdout.contains("git repository"))
    }
    
    // MARK: - Phase 3: Clean Removal Tests (US1)
    
    // T023: Test successful directory removal
    @Test("Successful directory removal works end-to-end")
    func testSuccessfulDirectoryRemoval() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Add a real subtree using AddCommand
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "hello", "--ref", "master"],
            workingDirectory: fixture.path
        )
        #expect(addResult.exitCode == 0)
        
        // Verify directory was created
        let subtreeDir = "\(fixture.path.string)/hello"
        let dirExists = FileManager.default.fileExists(atPath: subtreeDir)
        #expect(dirExists == true)
        
        // Remove the subtree
        let removeResult = try await harness.run(
            arguments: ["remove", "hello"],
            workingDirectory: fixture.path
        )
        
        // Verify success
        #expect(removeResult.exitCode == 0)
        #expect(removeResult.stdout.contains("✅"))
        #expect(removeResult.stdout.contains("Removed subtree"))
        #expect(removeResult.stdout.contains("hello"))
        
        // Verify directory was removed
        let dirStillExists = FileManager.default.fileExists(atPath: subtreeDir)
        #expect(dirStillExists == false)
    }
    
    // T032: Test single atomic commit
    @Test("Single atomic commit created for removal")
    func testSingleAtomicCommit() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize and add subtree
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "hello", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Get commit count before removal
        let beforeCount = try await fixture.getCommitCount()
        
        // Remove subtree
        let removeResult = try await harness.run(
            arguments: ["remove", "hello"],
            workingDirectory: fixture.path
        )
        #expect(removeResult.exitCode == 0)
        
        // Get commit count after removal
        let afterCount = try await fixture.getCommitCount()
        
        // Should have exactly 1 new commit
        #expect(afterCount == beforeCount + 1)
    }
    
    // T033: Test commit contains both changes
    @Test("Commit contains both directory removal and config update")
    func testCommitContainsBothChanges() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize and add subtree
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "hello", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Remove subtree
        let removeResult = try await harness.run(
            arguments: ["remove", "hello"],
            workingDirectory: fixture.path
        )
        #expect(removeResult.exitCode == 0)
        
        // Check git show HEAD to verify both changes in single commit
        let showResult = try await harness.runGit(["show", "HEAD", "--name-only"], in: fixture.path)
        
        // Should show both hello directory and subtree.yaml in the commit
        #expect(showResult.contains("hello"))
        #expect(showResult.contains("subtree.yaml"))
        
        // Verify commit message
        let logResult = try await harness.runGit(["log", "-1", "--pretty=%s"], in: fixture.path)
        #expect(logResult.contains("Remove subtree"))
        #expect(logResult.contains("hello"))
    }
    
    // T037: Commit failure recovery (staged changes remain, recovery instructions)
    // T038: Success message format
    
    // MARK: - Phase 4: Idempotent Removal Tests (US2)
    
    // T041: Test removal when directory already gone
    @Test("Removal succeeds when directory already deleted")
    func testRemovalWhenDirectoryAlreadyGone() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize and add subtree
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "hello", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Manually delete the subtree directory (simulating manual cleanup)
        let subtreeDir = "\(fixture.path.string)/hello"
        try FileManager.default.removeItem(atPath: subtreeDir)
        
        // Commit the manual deletion (simulates real-world scenario where user cleaned up)
        _ = try await harness.runGit(["add", "-A"], in: fixture.path)
        _ = try await harness.runGit(["commit", "-m", "Manually removed directory"], in: fixture.path)
        
        // Remove subtree (should succeed idempotently)
        let removeResult = try await harness.run(
            arguments: ["remove", "hello"],
            workingDirectory: fixture.path
        )
        
        // Should succeed with exit code 0
        #expect(removeResult.exitCode == 0)
        #expect(removeResult.stdout.contains("✅"))
        #expect(removeResult.stdout.contains("hello"))
    }
    
    // T042: Test idempotent success message
    @Test("Idempotent success message indicates directory already deleted")
    func testIdempotentSuccessMessage() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize and add subtree
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "hello", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Manually delete the directory
        let subtreeDir = "\(fixture.path.string)/hello"
        try FileManager.default.removeItem(atPath: subtreeDir)
        
        // Commit the manual deletion
        _ = try await harness.runGit(["add", "-A"], in: fixture.path)
        _ = try await harness.runGit(["commit", "-m", "Manually removed directory"], in: fixture.path)
        
        // Remove subtree
        let removeResult = try await harness.run(
            arguments: ["remove", "hello"],
            workingDirectory: fixture.path
        )
        
        // Should show idempotent message
        #expect(removeResult.exitCode == 0)
        #expect(removeResult.stdout.contains("from config") || removeResult.stdout.contains("already deleted"))
    }
    
    // T043: Test double-removal error
    @Test("Second removal attempt fails with 'not found' error")
    func testDoubleRemovalError() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize and add subtree
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "hello", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // First removal (should succeed)
        let firstRemoval = try await harness.run(
            arguments: ["remove", "hello"],
            workingDirectory: fixture.path
        )
        #expect(firstRemoval.exitCode == 0)
        
        // Second removal (should fail - config entry gone)
        let secondRemoval = try await harness.run(
            arguments: ["remove", "hello"],
            workingDirectory: fixture.path
        )
        
        // Should fail with exit code 1 (subtree not found is user error)
        #expect(secondRemoval.exitCode == 1)
        #expect(secondRemoval.stdout.contains("not found") || secondRemoval.stdout.contains("❌"))
    }
    
    // T049: Verify second removal fails gracefully (validates existing behavior)
    @Test("Second removal fails with clear error message")
    func testSecondRemovalFailureMessage() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize and add subtree
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "hello", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // First removal
        _ = try await harness.run(arguments: ["remove", "hello"], workingDirectory: fixture.path)
        
        // Second removal (config entry is gone)
        let result = try await harness.run(
            arguments: ["remove", "hello"],
            workingDirectory: fixture.path
        )
        
        // Should fail gracefully with "not found" error (exit code 1)
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains("❌"))
        #expect(result.stdout.contains("'hello'"))
        #expect(result.stdout.contains("not found") || result.stdout.contains("configuration"))
    }
    
    // MARK: - Feature 007: Case-Insensitive Lookup Tests
    
    // T020 [P] [US1] - Case-insensitive removal tests
    @Test("Removes subtree using different case")
    func testRemoveWithDifferentCase() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize and add subtree with name "Hello-World"
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "Hello-World", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Remove using lowercase "hello-world" (should succeed)
        let result = try await harness.run(
            arguments: ["remove", "hello-world"],
            workingDirectory: fixture.path
        )
        
        // Should succeed with case-insensitive match
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("✅") || result.stdout.contains("Removed"))
        
        // Verify config entry was removed
        let configPath = fixture.path.appending("/subtree.yaml")
        let configData = try String(contentsOfFile: configPath.string, encoding: .utf8)
        #expect(!configData.contains("Hello-World"))
        #expect(!configData.contains("hello-world"))
    }
    
    @Test("Preserves original case in success message")
    func testPreservesOriginalCaseInMessage() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize and add subtree with name "MyLib"
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "MyLib", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Remove using different case "mylib"
        let result = try await harness.run(
            arguments: ["remove", "mylib"],
            workingDirectory: fixture.path
        )
        
        // Should succeed and message should reference the original "MyLib"
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("MyLib"))
    }
    
    // T021 [P] [US1] - Not-found error tests
    @Test("Shows clear error when subtree not found (any case)")
    func testNotFoundErrorCaseInsensitive() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize with a subtree named "existing"
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "existing", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Try to remove non-existent subtree
        let result = try await harness.run(
            arguments: ["remove", "nonexistent"],
            workingDirectory: fixture.path
        )
        
        // Should fail with not found error
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains("❌"))
        #expect(result.stdout.contains("not found"))
        #expect(result.stdout.contains("nonexistent"))
    }
    
    @Test("Detects multiple case-variant matches (corruption)")
    func testDetectsMultipleMatches() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        
        // Manually create corrupted config with case-variant duplicates
        let configPath = fixture.path.appending("/subtree.yaml")
        let corruptedConfig = """
        # Subtree Configuration
        subtrees:
          - name: Hello-World
            remote: git@github.com:octocat/Hello-World.git
            prefix: Hello-World
            commit: abc123
            branch: master
            squash: true
          - name: hello-world
            remote: git@github.com:octocat/Spoon-Knife.git
            prefix: other
            commit: def456
            branch: main
            squash: true
        """
        try corruptedConfig.write(toFile: configPath.string, atomically: true, encoding: .utf8)
        
        // Try to remove - should detect corruption during config validation
        let result = try await harness.run(
            arguments: ["remove", "hello-world"],
            workingDirectory: fixture.path
        )
        
        // Should fail when validate() detects duplicate names (corruption caught early)
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains("❌"))
        #expect(result.stdout.contains("conflicts") || result.stdout.contains("duplicate"))
        // Error should mention both case variants
        #expect(result.stdout.contains("Hello-World") || result.stdout.contains("hello-world"))
    }
    
    // T022 [P] [US1] - Whitespace trimming tests
    @Test("Trims whitespace from name input")
    func testTrimsWhitespaceFromName() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize and add subtree
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "MyLib", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Remove with whitespace padding (should be trimmed)
        let result = try await harness.run(
            arguments: ["remove", "  MyLib  "],
            workingDirectory: fixture.path
        )
        
        // Should succeed after trimming
        #expect(result.exitCode == 0)
        
        // Verify config entry was removed
        let configPath = fixture.path.appending("/subtree.yaml")
        let configData = try String(contentsOfFile: configPath.string, encoding: .utf8)
        #expect(!configData.contains("MyLib"))
    }
    
    // MARK: - Phase 5: Additional Corruption Detection Tests
    
    // T030 [P] [US4] - Additional corruption test: Remove with prefix corruption
    @Test("Detects corrupted config with duplicate prefixes before remove")
    func testDetectsPrefixCorruptionBeforeRemove() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        
        // Manually corrupt config with duplicate prefixes (different case)
        let configPath = fixture.path.appending("/subtree.yaml")
        let corruptedConfig = """
        # Subtree Configuration
        subtrees:
          - name: lib-one
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/Shared
            commit: abc123
            branch: master
            squash: true
          - name: lib-two
            remote: git@github.com:octocat/Spoon-Knife.git
            prefix: vendor/shared
            commit: def456
            branch: main
            squash: true
        """
        try corruptedConfig.write(toFile: configPath.string, atomically: true, encoding: .utf8)
        
        // Attempt to remove a subtree
        let result = try await harness.run(
            arguments: ["remove", "lib-one"],
            workingDirectory: fixture.path
        )
        
        // Should fail when validate() detects duplicate prefixes
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains("❌"))
        #expect(result.stdout.contains("conflicts") || result.stdout.contains("duplicate"))
    }
}
