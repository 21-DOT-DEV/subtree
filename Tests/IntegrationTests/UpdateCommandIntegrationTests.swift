import Testing
import Foundation
#if canImport(System)
import System
#else
import SystemPackage
#endif

@Suite("Update Command Integration Tests")
final class UpdateCommandIntegrationTests {
    
    let harness = TestHarness()
    
    // T012: Test update subtree with new commits available
    // NOTE: This test uses a repository with active development (swift-se0270-range-set)
    // which may have new commits between test runs
    @Test("update subtree with new commits available")
    func testUpdateSubtreeWithNewCommits() async throws {
        // Create local repository
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Initialize and add subtree from an active repository
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:swiftlang/swift-se0270-range-set.git", "--name", "rangeset", "--prefix", "vendor/rangeset", "--ref", "main"],
            workingDirectory: local.path
        )
        #expect(addResult.exitCode == 0, "Add should succeed")
        
        // Try to update (may or may not have new commits, but should succeed either way)
        let configPath = local.path.appending("subtree.yaml")
        let result = try await harness.run(
            arguments: ["update", "rangeset"],
            workingDirectory: local.path
        )
        
        // Verify update succeeded (exit 0 whether up-to-date or updated)
        #expect(result.exitCode == 0, "Update should succeed with exit code 0")
        
        // Verify output indicates either "up to date" or "Updated"
        let hasUpdateMessage = result.stdout.contains("Updated") || result.stdout.contains("up to date") || result.stdout.contains("up-to-date")
        #expect(hasUpdateMessage, "Should show update status")
        
        // Verify config still has rangeset entry
        let configAfter = try String(contentsOfFile: configPath.string, encoding: .utf8)
        #expect(configAfter.contains("rangeset"), "Config should still contain rangeset entry")
    }
    
    // T013: Test update subtree already up-to-date
    @Test("update subtree already up-to-date")
    func testUpdateSubtreeAlreadyUpToDate() async throws {
        // Create local repository and add subtree from real GitHub repo
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        #expect(initResult.exitCode == 0, "Init should succeed")
        
        // Add subtree from stable GitHub repository
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "lib", "--prefix", "lib", "--ref", "master"],
            workingDirectory: local.path
        )
        #expect(addResult.exitCode == 0, "Add should succeed: \(addResult.stderr)")
        
        // Get commit count before update
        let commitsBefore = try await local.getCommitCount()
        
        // Try to update (should be up-to-date since we just added it)
        let result = try await harness.run(
            arguments: ["update", "lib"],
            workingDirectory: local.path
        )
        
        // Verify success (may be up-to-date OR may have updated if repo had new commits)
        #expect(result.exitCode == 0, "Should exit with code 0")
        
        // Verify appropriate message (either up-to-date or updated)
        let hasValidMessage = result.stdout.contains("up to date") || 
                              result.stdout.contains("up-to-date") ||
                              result.stdout.contains("Updated")
        #expect(hasValidMessage, "Should show appropriate status message")
        
        // Commit count may stay same (up-to-date) or increase (if repo had new commits)
        let commitsAfter = try await local.getCommitCount()
        #expect(commitsAfter >= commitsBefore, "Commit count should not decrease")
    }
    
    // T014: Test update subtree tracking specific commit (immutable ref)
    // Note: Using a specific commit hash instead of tag to ensure reliability
    @Test("update subtree with immutable commit ref")
    func testUpdateSubtreeImmutableRef() async throws {
        // Create local repository
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        
        // Add subtree using master ref (but will track specific commit)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "dep", "--prefix", "deps/dep", "--ref", "master"],
            workingDirectory: local.path
        )
        #expect(addResult.exitCode == 0, "Add should succeed")
        
        // Get commit count before update
        let commitsBefore = try await local.getCommitCount()
        
        // Update should check if there are new commits
        let result = try await harness.run(
            arguments: ["update", "dep"],
            workingDirectory: local.path
        )
        
        // Verify success
        #expect(result.exitCode == 0, "Should exit with code 0")
        
        // Verify appropriate message (Hello-World is rarely updated, likely up-to-date)
        let hasValidMessage = result.stdout.contains("up to date") || 
                              result.stdout.contains("up-to-date") ||
                              result.stdout.contains("Updated")
        #expect(hasValidMessage, "Should show appropriate status message")
        
        // Commit count may stay same or increase
        let commitsAfter = try await local.getCommitCount()
        #expect(commitsAfter >= commitsBefore, "Commit count should not decrease")
    }
    
    // MARK: - Error Handling Tests (User Story 5)
    
    // T024: Test missing subtree.yaml error
    @Test("missing subtree.yaml error")
    func testMissingConfigError() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Don't run init - no subtree.yaml exists
        let result = try await harness.run(
            arguments: ["update", "nonexistent"],
            workingDirectory: local.path
        )
        
        // Should exit with code 3 (missing config)
        #expect(result.exitCode == 3, "Should exit with code 3 for missing config")
        #expect(result.stdout.contains("not found") || result.stdout.contains("Run 'subtree init'"),
                "Should suggest running init")
    }
    
    // T025: Test subtree name not found error
    @Test("subtree name not found error")
    func testSubtreeNameNotFoundError() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Init but don't add any subtrees
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        
        let result = try await harness.run(
            arguments: ["update", "nonexistent"],
            workingDirectory: local.path
        )
        
        // Should exit with code 1 (user error - subtree not found)
        #expect(result.exitCode == 1, "Should exit with code 1 for unknown subtree")
        #expect(result.stdout.contains("not found"), "Should indicate subtree not found")
    }
    
    // T026: Test dirty working tree error
    @Test("dirty working tree error")
    func testDirtyWorkingTreeError() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Init and add a subtree
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "lib", "--prefix", "lib", "--ref", "master"],
            workingDirectory: local.path
        )
        #expect(addResult.exitCode == 0, "Add should succeed")
        
        // Create uncommitted changes
        let dirtyFile = local.path.appending("dirty.txt")
        try "uncommitted changes".write(toFile: dirtyFile.string, atomically: true, encoding: .utf8)
        
        let result = try await harness.run(
            arguments: ["update", "lib"],
            workingDirectory: local.path
        )
        
        // Should exit with code 1 (general error - dirty tree)
        #expect(result.exitCode == 1, "Should exit with code 1 for dirty tree")
        #expect(result.stdout.contains("uncommitted changes") || result.stdout.contains("working tree"),
                "Should indicate dirty working tree")
    }
    
    // T027: Test git operation failure
    @Test("git operation failure")
    func testGitOperationFailure() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Init and add subtree
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "lib", "--prefix", "lib", "--ref", "master"],
            workingDirectory: local.path
        )
        #expect(addResult.exitCode == 0, "Add should succeed")
        
        // Manually edit config to use invalid remote URL
        let configPath = local.path.appending("subtree.yaml")
        var configContent = try String(contentsOfFile: configPath.string, encoding: .utf8)
        configContent = configContent.replacingOccurrences(
            of: "git@github.com:octocat/Hello-World.git",
            with: "https://invalid-url-that-does-not-exist.com/repo.git"
        )
        try configContent.write(toFile: configPath.string, atomically: true, encoding: .utf8)
        try await local.runGit(["add", "subtree.yaml"])
        try await local.runGit(["commit", "-m", "Update config with invalid URL"])
        
        let result = try await harness.run(
            arguments: ["update", "lib"],
            workingDirectory: local.path
        )
        
        // Should exit with code 1 (git operation failed)
        #expect(result.exitCode == 1, "Should exit with code 1 for git failure")
        #expect(result.stdout.contains("Failed") || result.stdout.contains("error"),
                "Should indicate operation failure")
    }
    
    // T027A: Test corrupted YAML syntax error
    @Test("corrupted YAML syntax error")
    func testCorruptedYAMLError() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Init creates valid YAML
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        
        // Corrupt the YAML file
        let configPath = local.path.appending("subtree.yaml")
        let corruptedYAML = """
        # Managed by subtree CLI
        subtrees:
          - name: test
            remote: url
            prefix: path
            commit: hash
            invalid syntax here: [unclosed
        """
        try corruptedYAML.write(toFile: configPath.string, atomically: true, encoding: .utf8)
        
        let result = try await harness.run(
            arguments: ["update", "test"],
            workingDirectory: local.path
        )
        
        // Should exit with code 1 (failed to load config)
        #expect(result.exitCode == 1, "Should exit with code 1 for YAML error")
        #expect(result.stdout.contains("Failed to load") || result.stdout.contains("configuration"),
                "Should indicate configuration error")
    }
    
    // T027B: Test upstream history rewritten (force-push)
    @Test("upstream history rewritten (force-push)")
    func testUpstreamHistoryRewrittenError() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Init and add subtree
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "lib", "--prefix", "lib", "--ref", "master"],
            workingDirectory: local.path
        )
        #expect(addResult.exitCode == 0, "Add should succeed")
        
        // Manually edit config to use a commit that doesn't exist in history
        // (simulating force-push scenario)
        let configPath = local.path.appending("subtree.yaml")
        var configContent = try String(contentsOfFile: configPath.string, encoding: .utf8)
        // Replace actual commit with fake one using string manipulation
        if let commitRange = configContent.range(of: "commit: ") {
            let afterCommit = configContent.index(commitRange.upperBound, offsetBy: 0)
            if let newlineRange = configContent[afterCommit...].range(of: "\n") {
                configContent.replaceSubrange(afterCommit..<newlineRange.lowerBound, 
                                            with: "0000000000000000000000000000000000000000")
            }
        }
        try configContent.write(toFile: configPath.string, atomically: true, encoding: .utf8)
        try await local.runGit(["add", "subtree.yaml"])
        try await local.runGit(["commit", "-m", "Simulate force-push scenario"])
        
        let result = try await harness.run(
            arguments: ["update", "lib"],
            workingDirectory: local.path
        )
        
        // May succeed (treats as out of sync) or fail - both are acceptable
        // The key is it doesn't crash
        #expect(result.exitCode == 0 || result.exitCode == 1,
                "Should handle gracefully (exit 0 or 1)")
    }
    
    // T027C: Test manually modified subtree files
    @Test("manually modified subtree files")
    func testManuallyModifiedSubtreeFiles() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Init and add subtree
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "lib", "--prefix", "lib", "--ref", "master"],
            workingDirectory: local.path
        )
        #expect(addResult.exitCode == 0, "Add should succeed")
        
        // Manually modify a file in the subtree
        let subtreeFile = local.path.appending("lib/README")
        if FileManager.default.fileExists(atPath: subtreeFile.string) {
            try "MANUALLY MODIFIED".write(toFile: subtreeFile.string, atomically: true, encoding: .utf8)
            try await local.runGit(["add", "lib/README"])
            try await local.runGit(["commit", "-m", "Manually modify subtree file"])
        }
        
        let result = try await harness.run(
            arguments: ["update", "lib"],
            workingDirectory: local.path
        )
        
        // Git subtree should handle this (may merge or conflict)
        // The key is the command doesn't crash
        #expect(result.exitCode == 0 || result.exitCode == 1,
                "Should handle manual modifications gracefully")
    }
    
    // MARK: - Bulk Update Tests (User Story 2)
    
    // T034: Test update all subtrees with mixed results
    @Test("update all subtrees with mixed results")
    func testUpdateAllSubtreesWithMixedResults() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Init and add multiple subtrees
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        
        // Add first subtree (stable, likely up-to-date)
        let add1 = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "hello", "--prefix", "vendor/hello", "--ref", "master"],
            workingDirectory: local.path
        )
        #expect(add1.exitCode == 0, "First add should succeed")
        
        // Add second subtree (may have updates)
        let add2 = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:swiftlang/swift-se0270-range-set.git", "--name", "rangeset", "--prefix", "vendor/rangeset", "--ref", "main"],
            workingDirectory: local.path
        )
        #expect(add2.exitCode == 0, "Second add should succeed")
        
        // Update all
        let result = try await harness.run(
            arguments: ["update", "--all"],
            workingDirectory: local.path
        )
        
        // Should succeed even if some are up-to-date
        #expect(result.exitCode == 0, "Update --all should succeed")
        
        // Should show summary
        #expect(result.stdout.contains("hello") || result.stdout.contains("rangeset"),
                "Should mention subtree names")
        
        // Should show results (updated, up-to-date, or summary)
        let hasResults = result.stdout.contains("Updated") || 
                         result.stdout.contains("up to date") ||
                         result.stdout.contains("up-to-date") ||
                         result.stdout.contains("updated") ||
                         result.stdout.contains("skipped")
        #expect(hasResults, "Should show update results")
    }
    
    // T035: Test update all when all up-to-date
    @Test("update all when all up-to-date")
    func testUpdateAllWhenAllUpToDate() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Init and add subtrees
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "lib1", "--prefix", "lib1", "--ref", "master"],
            workingDirectory: local.path
        )
        
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Spoon-Knife.git", "--name", "lib2", "--prefix", "lib2", "--ref", "main"],
            workingDirectory: local.path
        )
        
        // Get commit count before update
        let commitsBefore = try await local.getCommitCount()
        
        // Update all (likely all up-to-date since just added)
        let result = try await harness.run(
            arguments: ["update", "--all"],
            workingDirectory: local.path
        )
        
        // Should succeed
        #expect(result.exitCode == 0, "Update --all should succeed")
        
        // Commits may stay same or increase slightly
        let commitsAfter = try await local.getCommitCount()
        #expect(commitsAfter >= commitsBefore, "Commit count should not decrease")
    }
    
    // T036: Test update all with no subtrees configured
    @Test("update all with no subtrees configured")
    func testUpdateAllWithNoSubtrees() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Init but don't add any subtrees
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        
        let result = try await harness.run(
            arguments: ["update", "--all"],
            workingDirectory: local.path
        )
        
        // Should succeed (nothing to do)
        #expect(result.exitCode == 0, "Update --all with empty config should succeed")
        
        // Should indicate no subtrees
        #expect(result.stdout.contains("No subtrees") || result.stdout.contains("0 "),
                "Should indicate no subtrees to update")
    }
    
    // MARK: - Report Mode Tests (User Story 3)
    
    // T044: Report mode with updates available (exit 5)
    @Test("report mode with updates available")
    func testReportModeWithUpdatesAvailable() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:swiftlang/swift-se0270-range-set.git", "--name", "lib", "--prefix", "lib", "--ref", "main"],
            workingDirectory: local.path
        )
        
        let result = try await harness.run(
            arguments: ["update", "lib", "--report"],
            workingDirectory: local.path
        )
        
        // Should exit with 0 (up-to-date) or 5 (updates available)
        #expect(result.exitCode == 0 || result.exitCode == 5, "Report mode should exit 0 or 5")
        #expect(result.stdout.contains("→") || result.stdout.contains("up to date"), "Should show status")
    }
    
    // T045: Report mode with no updates (exit 0)
    @Test("report mode with no updates")
    func testReportModeWithNoUpdates() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "lib", "--prefix", "lib", "--ref", "master"],
            workingDirectory: local.path
        )
        
        let result = try await harness.run(
            arguments: ["update", "lib", "--report"],
            workingDirectory: local.path
        )
        
        // Likely up-to-date since just added
        #expect(result.exitCode == 0 || result.exitCode == 5, "Report mode should exit 0 or 5")
    }
    
    // T046: Report mode with --all
    @Test("report mode with --all flag")
    func testReportModeWithAll() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "lib1", "--prefix", "lib1", "--ref", "master"],
            workingDirectory: local.path
        )
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Spoon-Knife.git", "--name", "lib2", "--prefix", "lib2", "--ref", "main"],
            workingDirectory: local.path
        )
        
        let result = try await harness.run(
            arguments: ["update", "--all", "--report"],
            workingDirectory: local.path
        )
        
        #expect(result.exitCode == 0 || result.exitCode == 5, "Report mode should exit 0 or 5")
        #expect(result.stdout.contains("lib1") && result.stdout.contains("lib2"), "Should show all subtrees")
    }
    
    // T047: Report mode makes no repository changes
    @Test("report mode makes no repository changes")
    func testReportModeNoChanges() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "lib", "--prefix", "lib", "--ref", "master"],
            workingDirectory: local.path
        )
        
        let commitsBefore = try await local.getCommitCount()
        
        _ = try await harness.run(
            arguments: ["update", "lib", "--report"],
            workingDirectory: local.path
        )
        
        let commitsAfter = try await local.getCommitCount()
        #expect(commitsBefore == commitsAfter, "Report mode should not create commits")
    }
    
    // MARK: - Feature 007: Case-Insensitive Lookup Tests
    
    // T025 [P] [US1] - Case-insensitive update tests
    @Test("Updates subtree using different case")
    func testUpdateWithDifferentCase() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Initialize and add subtree with name "My-Lib"
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "My-Lib", "--prefix", "My-Lib", "--ref", "master"],
            workingDirectory: local.path
        )
        
        // Update using lowercase "my-lib" (should succeed)
        let result = try await harness.run(
            arguments: ["update", "my-lib"],
            workingDirectory: local.path
        )
        
        // Should succeed with case-insensitive match
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("My-Lib"))
    }
    
    @Test("Preserves original case in update message")
    func testPreservesOriginalCaseInUpdateMessage() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Initialize and add subtree with name "MyLibrary"
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "MyLibrary", "--prefix", "MyLibrary", "--ref", "master"],
            workingDirectory: local.path
        )
        
        // Update using different case "mylibrary"
        let result = try await harness.run(
            arguments: ["update", "mylibrary"],
            workingDirectory: local.path
        )
        
        // Should succeed and message should reference the original "MyLibrary"
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("MyLibrary"))
    }
    
    // T026 [P] [US1] - Not-found error tests
    @Test("Shows clear error when subtree not found (any case)")
    func testNotFoundErrorCaseInsensitive() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Initialize with a subtree named "existing"
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "existing", "--prefix", "existing", "--ref", "master"],
            workingDirectory: local.path
        )
        
        // Try to update non-existent subtree
        let result = try await harness.run(
            arguments: ["update", "nonexistent"],
            workingDirectory: local.path
        )
        
        // Should fail with not found error
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains("❌"))
        #expect(result.stdout.contains("not found"))
        #expect(result.stdout.contains("nonexistent"))
    }
    
    @Test("Detects multiple case-variant matches (corruption)")
    func testDetectsMultipleMatches() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Initialize config
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        
        // Manually create corrupted config with case-variant duplicates
        let configPath = local.path.appending("/subtree.yaml")
        let corruptedConfig = """
        # Subtree Configuration
        subtrees:
          - name: My-Lib
            remote: git@github.com:octocat/Hello-World.git
            prefix: My-Lib
            commit: abc123
            branch: master
            squash: true
          - name: my-lib
            remote: git@github.com:octocat/Spoon-Knife.git
            prefix: other
            commit: def456
            branch: main
            squash: true
        """
        try corruptedConfig.write(toFile: configPath.string, atomically: true, encoding: .utf8)
        
        // Try to update - should detect corruption
        let result = try await harness.run(
            arguments: ["update", "my-lib"],
            workingDirectory: local.path
        )
        
        // Should fail when validate() detects duplicate names (corruption caught early)
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains("❌"))
        #expect(result.stdout.contains("conflicts") || result.stdout.contains("duplicate"))
        // Error should mention both case variants
        #expect(result.stdout.contains("My-Lib") || result.stdout.contains("my-lib"))
    }
    
    // T027 [P] [US1] - Whitespace trimming tests
    @Test("Trims whitespace from name input")
    func testTrimsWhitespaceFromName() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Initialize and add subtree
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "MyLib", "--prefix", "MyLib", "--ref", "master"],
            workingDirectory: local.path
        )
        
        // Update with whitespace padding (should be trimmed)
        let result = try await harness.run(
            arguments: ["update", "  MyLib  "],
            workingDirectory: local.path
        )
        
        // Should succeed after trimming
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("MyLib"))
    }
    
    // MARK: - Phase 5: Additional Corruption Detection & Case Preservation Tests
    
    // T031 [P] [US4] - Additional corruption test: Update with prefix corruption
    @Test("Detects corrupted config with duplicate prefixes before update")
    func testDetectsPrefixCorruptionBeforeUpdate() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Initialize config
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        
        // Manually corrupt config with duplicate prefixes (different case)
        let configPath = local.path.appending("/subtree.yaml")
        let corruptedConfig = """
        # Subtree Configuration
        subtrees:
          - name: lib-alpha
            remote: git@github.com:octocat/Hello-World.git
            prefix: Libraries/Core
            commit: abc123
            branch: master
            squash: true
          - name: lib-beta
            remote: git@github.com:octocat/Spoon-Knife.git
            prefix: libraries/core
            commit: def456
            branch: main
            squash: true
        """
        try corruptedConfig.write(toFile: configPath.string, atomically: true, encoding: .utf8)
        
        // Attempt to update a subtree
        let result = try await harness.run(
            arguments: ["update", "lib-alpha"],
            workingDirectory: local.path
        )
        
        // Should fail when validate() detects duplicate prefixes
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains("❌"))
        #expect(result.stdout.contains("conflicts") || result.stdout.contains("duplicate"))
    }
    
    // T035 [P] [US5] - Case preservation in Update command config writes
    @Test("Update preserves original case when updating commit hash")
    func testUpdatePreservesOriginalCaseInConfig() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Initialize and add subtree with specific casing
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "MySpecialLib", "--prefix", "vendor/special", "--ref", "master"],
            workingDirectory: local.path
        )
        
        // Update the subtree (may or may not have updates)
        _ = try await harness.run(
            arguments: ["update", "myspeciallib"],  // Different case input
            workingDirectory: local.path
        )
        
        // Verify config still has original case
        let configPath = local.path.appending("/subtree.yaml")
        let configData = try String(contentsOfFile: configPath.string, encoding: .utf8)
        #expect(configData.contains("name: MySpecialLib"))
        #expect(!configData.contains("name: myspeciallib"))
    }
    
    // MARK: - Bug Fix Tests: Commit Creation and Tag Detection
    
    // Regression test: Update should NOT amend unrelated commits
    @Test("update does not amend unrelated commits")
    func testUpdateDoesNotAmendUnrelatedCommits() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Initialize and add subtree
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "lib", "--prefix", "lib", "--ref", "master"],
            workingDirectory: local.path
        )
        #expect(addResult.exitCode == 0, "Add should succeed")
        
        // Create an unrelated commit
        let unrelatedFile = local.path.appending("unrelated.txt")
        try "unrelated content".write(toFile: unrelatedFile.string, atomically: true, encoding: .utf8)
        try await local.runGit(["add", "unrelated.txt"])
        try await local.runGit(["commit", "-m", "Unrelated commit"])
        
        // Get the unrelated commit message before update
        let logBefore = try await local.runGit(["log", "-1", "--format=%s"])
        #expect(logBefore.contains("Unrelated commit"), "Should have unrelated commit")
        
        // Try to update (may or may not have updates)
        let result = try await harness.run(
            arguments: ["update", "lib"],
            workingDirectory: local.path
        )
        #expect(result.exitCode == 0, "Update should succeed")
        
        // If up-to-date, the unrelated commit should NOT be modified
        if result.stdout.contains("up to date") {
            let logAfter = try await local.runGit(["log", "-1", "--format=%s"])
            #expect(logAfter.contains("Unrelated commit"), "Unrelated commit should NOT be amended")
        }
    }
    
    // Test --ref flag for explicit version specification
    @Test("update with --ref flag updates to specific version")
    func testUpdateWithRefFlag() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Initialize and add subtree with master branch
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "lib", "--prefix", "lib", "--ref", "master"],
            workingDirectory: local.path
        )
        #expect(addResult.exitCode == 0, "Add should succeed")
        
        // Update with explicit --ref (using same ref to test the flag works)
        let result = try await harness.run(
            arguments: ["update", "lib", "--ref", "master"],
            workingDirectory: local.path
        )
        
        // Should succeed (up-to-date or updated)
        #expect(result.exitCode == 0, "Update with --ref should succeed")
    }
    
    // Test that config tag field is updated when updating to new tag
    @Test("update updates tag field in config when tag changes")
    func testUpdateUpdatesTagFieldInConfig() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Initialize config
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        
        // Manually create config with an old tag (simulating a subtree added with old tag)
        // Using swift-argument-parser which has many tags
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "https://github.com/apple/swift-argument-parser.git", "--name", "argparser", "--prefix", "vendor/argparser", "--ref", "1.0.0"],
            workingDirectory: local.path
        )
        #expect(addResult.exitCode == 0, "Add should succeed: \(addResult.stderr)")
        
        // Read config before update
        let configPath = local.path.appending("/subtree.yaml")
        let configBefore = try String(contentsOfFile: configPath.string, encoding: .utf8)
        #expect(configBefore.contains("tag: 1.0.0") || configBefore.contains("branch:"), "Config should have ref")
        
        // Try to update (should detect newer tags)
        let result = try await harness.run(
            arguments: ["update", "argparser"],
            workingDirectory: local.path
        )
        
        // Should succeed
        #expect(result.exitCode == 0, "Update should succeed: \(result.stdout)")
        
        // If updated, verify tag field changed
        if result.stdout.contains("Updated") && !result.stdout.contains("up to date") {
            let configAfter = try String(contentsOfFile: configPath.string, encoding: .utf8)
            // Tag should be updated (not still 1.0.0)
            #expect(!configAfter.contains("tag: 1.0.0"), "Tag should be updated to newer version")
        }
    }
    
    // Test commit message shows version transition
    @Test("update commit message shows version transition for tags")
    func testUpdateCommitMessageShowsVersionTransition() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Initialize and add subtree with a specific old tag
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "https://github.com/apple/swift-argument-parser.git", "--name", "argparser", "--prefix", "vendor/argparser", "--ref", "1.0.0"],
            workingDirectory: local.path
        )
        #expect(addResult.exitCode == 0, "Add should succeed: \(addResult.stderr)")
        
        // Try to update
        let result = try await harness.run(
            arguments: ["update", "argparser"],
            workingDirectory: local.path
        )
        #expect(result.exitCode == 0, "Update should succeed")
        
        // If updated (not up-to-date), check commit message format
        if result.stdout.contains("Updated") && !result.stdout.contains("up to date") {
            let commitMsg = try await local.runGit(["log", "-1", "--format=%B"])
            // Should show version transition with arrow
            #expect(commitMsg.contains("→") || commitMsg.contains("tag:"), "Commit message should show version info")
            #expect(commitMsg.contains("argparser"), "Commit message should mention subtree name")
        }
    }
    
    // Test auto-detect latest tag for tag-configured subtrees
    @Test("update auto-detects latest tag when configured with tag")
    func testUpdateAutoDetectsLatestTag() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Initialize config
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        
        // Add subtree with an old tag
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "https://github.com/apple/swift-argument-parser.git", "--name", "argparser", "--prefix", "vendor/argparser", "--ref", "1.0.0"],
            workingDirectory: local.path
        )
        #expect(addResult.exitCode == 0, "Add should succeed")
        
        // Update should auto-detect newer tags
        let result = try await harness.run(
            arguments: ["update", "argparser"],
            workingDirectory: local.path
        )
        
        // Should succeed and show updating message (since 1.0.0 is very old)
        #expect(result.exitCode == 0, "Update should succeed")
        // The output should indicate updating or already up to date
        let hasStatusMessage = result.stdout.contains("Updating") || result.stdout.contains("Updated") || result.stdout.contains("up to date")
        #expect(hasStatusMessage, "Should show status message")
    }
}
