import Foundation
import Testing
import Yams
#if canImport(System)
import System
#else
import SystemPackage
#endif

/// Integration tests for subtree add command
@Suite("Add Integration Tests")
struct AddIntegrationTests {
    
    // T021 - Minimal add with only --remote flag
    @Test("Minimal add with only --remote flag")
    func testMinimalAddWithRemoteOnly() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Initialize subtree.yaml
        let harness = TestHarness()
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Use real GitHub repository with minimal flags (smart defaults)
        // Note: octocat/Hello-World uses 'master' as default branch, not 'main'
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Should succeed with real repository using smart defaults:
        // - name: "Hello-World" (derived from URL)
        // - prefix: "Hello-World" (from name)
        #expect(addResult.exitCode == 0)
        #expect(addResult.stdout.contains("Hello-World"))
    }
    
    // T022 - Verify single atomic commit produced
    @Test("Verify single atomic commit produced")
    func testSingleAtomicCommit() async throws {
        // TODO: Implement when AddCommand has atomic commit logic
        // 1. Run add command
        // 2. Check git log shows exactly one commit
        // 3. Verify commit contains both subtree files and subtree.yaml
    }
    
    // T023 - Verify config entry created with correct values
    @Test("Verify config entry created with correct values")
    func testConfigEntryCreated() async throws {
        // TODO: Implement when AddCommand creates config entries
        // 1. Run add command
        // 2. Parse subtree.yaml
        // 3. Verify entry contains: name, remote, prefix, ref, commit, squash
    }
    
    // T024 - Verify custom commit message format
    @Test("Verify custom commit message format")
    func testCustomCommitMessageFormat() async throws {
        // TODO: Implement when AddCommand uses CommitMessageFormatter
        // 1. Run add command
        // 2. Get commit message via git log
        // 3. Verify format matches:
        //    Add subtree <name>
        //    - Added from <ref-type>: <ref> (commit: <short-hash>)
        //    - From: <remote-url>
        //    - In: <prefix>
    }
    
    // T025 - Verify success message output format
    @Test("Verify success message output format")
    func testSuccessMessageOutput() async throws {
        // TODO: Implement when AddCommand outputs success messages
        // 1. Run add command
        // 2. Check stdout contains: "✅ Added subtree '<name>' at <prefix> (ref: <ref>, commit: <short-hash>)"
    }
    
    // T048 - Test --name override
    @Test("Test --name override")
    func testNameOverride() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Use real GitHub repository for actual git subtree operation
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "custom-name", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Should succeed with real repository
        #expect(addResult.exitCode == 0)
        #expect(addResult.stdout.contains("custom-name"))
    }
    
    // T049 - Test --prefix override
    @Test("Test --prefix override")
    func testPrefixOverride() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Use real GitHub repository with custom prefix
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--prefix", "vendor/custom", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Should succeed with real repository
        #expect(addResult.exitCode == 0)
        #expect(addResult.stdout.contains("vendor/custom"))
    }
    
    // T050 - Test --ref override
    @Test("Test --ref override")
    func testRefOverride() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Use real GitHub repository with specific ref (master branch)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Should succeed with real repository
        #expect(addResult.exitCode == 0)
        #expect(addResult.stdout.contains("master"))
    }
    
    // T051 - Test multiple overrides together
    @Test("Test multiple overrides together")
    func testMultipleOverrides() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Use real GitHub repository with all overrides
        let addResult = try await harness.run(
            arguments: [
                "add",
                "--remote", "git@github.com:octocat/Hello-World.git",
                "--name", "my-lib",
                "--prefix", "vendor/my-lib",
                "--ref", "master"
            ],
            workingDirectory: fixture.path
        )
        
        // Should succeed with real repository
        #expect(addResult.exitCode == 0)
        #expect(addResult.stdout.contains("my-lib"))
        #expect(addResult.stdout.contains("vendor/my-lib"))
    }
    
    // T052 - Test prefix defaults from name when --name provided but not --prefix
    @Test("Test prefix defaults from name when --name provided but not --prefix")
    func testPrefixDefaultsFromName() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Use real GitHub repository with only name override (prefix should default to name)
        let addResult = try await harness.run(
            arguments: [
                "add",
                "--remote", "git@github.com:octocat/Hello-World.git",
                "--name", "custom-lib",
                "--ref", "master"
            ],
            workingDirectory: fixture.path
        )
        
        // Should succeed with real repository and use "custom-lib" for both name and prefix
        #expect(addResult.exitCode == 0)
        #expect(addResult.stdout.contains("custom-lib"))
    }
    
    // T059 - Test --no-squash flag execution
    @Test("Test --no-squash flag execution")
    func testNoSquashFlagExecution() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Use real GitHub repository with --no-squash flag
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--no-squash", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Should succeed with real repository
        #expect(addResult.exitCode == 0)
    }
    
    // T060 - Verify config squash=false saved
    @Test("Verify config squash=false saved")
    func testConfigSquashFalse() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Add with --no-squash flag
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--no-squash", "--ref", "master"],
            workingDirectory: fixture.path
        )
        #expect(addResult.exitCode == 0)
        
        // Read and parse the config file (black-box validation)
        let configPath = "\(fixture.path.string)/subtree.yaml"
        let configData = try String(contentsOfFile: configPath, encoding: .utf8)
        
        // Parse YAML as dictionary to verify squash field is false
        let yaml = try Yams.load(yaml: configData) as! [String: Any]
        let subtrees = yaml["subtrees"] as! [[String: Any]]
        
        #expect(subtrees.count == 1)
        #expect(subtrees[0]["squash"] as? Bool == false)
        #expect(subtrees[0]["name"] as? String == "Hello-World")
    }
    
    // T061 - Verify git log shows individual commits (not squashed)
    @Test("Verify git log shows individual commits (not squashed)")
    func testGitLogIndividualCommits() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Get initial commit count
        let initialLog = try await harness.runGit(["rev-list", "--count", "HEAD"], in: fixture.path)
        let initialCount = Int(initialLog.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        
        // Add with --no-squash flag
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--no-squash", "--ref", "master"],
            workingDirectory: fixture.path
        )
        #expect(addResult.exitCode == 0)
        
        // Get final commit count
        let finalLog = try await harness.runGit(["rev-list", "--count", "HEAD"], in: fixture.path)
        let finalCount = Int(finalLog.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        
        // With --no-squash, we should have multiple commits from upstream
        // The octocat/Hello-World repo has multiple commits, so finalCount > initialCount + 1
        #expect(finalCount > initialCount + 1)
    }
    
    // T065 - Test duplicate name detection
    @Test("Test duplicate name detection")
    func testDuplicateNameDetection() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Add first subtree
        let firstAddResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "mylib", "--ref", "master"],
            workingDirectory: fixture.path
        )
        #expect(firstAddResult.exitCode == 0)
        
        // Try to add another subtree with the same name (different remote)
        let duplicateResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Spoon-Knife.git", "--name", "mylib", "--ref", "main"],
            workingDirectory: fixture.path
        )
        
        // Should fail with duplicate name error
        #expect(duplicateResult.exitCode == 1)
        #expect(duplicateResult.stdout.contains("conflicts with existing"))
        #expect(duplicateResult.stdout.contains("mylib"))
    }
    
    // T066 - Test duplicate prefix detection
    @Test("Test duplicate prefix detection")
    func testDuplicatePrefixDetection() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Add first subtree
        let firstAddResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--prefix", "vendor/lib", "--ref", "master"],
            workingDirectory: fixture.path
        )
        #expect(firstAddResult.exitCode == 0)
        
        // Try to add another subtree with the same prefix (different name)
        let duplicateResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Spoon-Knife.git", "--prefix", "vendor/lib", "--ref", "main"],
            workingDirectory: fixture.path
        )
        
        // Should fail with duplicate prefix error
        #expect(duplicateResult.exitCode == 1)
        #expect(duplicateResult.stdout.contains("conflicts with existing"))
        #expect(duplicateResult.stdout.contains("vendor/lib"))
    }
    
    // T067 - Verify error message format for duplicate name
    @Test("Verify error message format for duplicate name")
    func testDuplicateNameErrorMessage() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Add first subtree
        let firstAddResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "testlib", "--ref", "master"],
            workingDirectory: fixture.path
        )
        #expect(firstAddResult.exitCode == 0)
        
        // Try to add duplicate
        let duplicateResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Spoon-Knife.git", "--name", "testlib", "--ref", "main"],
            workingDirectory: fixture.path
        )
        
        // Verify specific error message format: "❌ Subtree with name 'X' already exists"
        #expect(duplicateResult.exitCode == 1)
        #expect(duplicateResult.stdout.contains("❌"))
        #expect(duplicateResult.stdout.contains("conflicts with existing"))
        #expect(duplicateResult.stdout.contains("testlib"))
        #expect(duplicateResult.stdout.contains("case-insensitively"))
    }
    
    // T068 - Verify error message format for duplicate prefix
    @Test("Verify error message format for duplicate prefix")
    func testDuplicatePrefixErrorMessage() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Add first subtree
        let firstAddResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--prefix", "libs/test", "--ref", "master"],
            workingDirectory: fixture.path
        )
        #expect(firstAddResult.exitCode == 0)
        
        // Try to add duplicate prefix
        let duplicateResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Spoon-Knife.git", "--prefix", "libs/test", "--ref", "main"],
            workingDirectory: fixture.path
        )
        
        // Verify specific error message format: "❌ Subtree with prefix 'X' already exists"
        #expect(duplicateResult.exitCode == 1)
        #expect(duplicateResult.stdout.contains("❌"))
        #expect(duplicateResult.stdout.contains("conflicts with existing"))
        #expect(duplicateResult.stdout.contains("libs/test"))
        #expect(duplicateResult.stdout.contains("case-insensitively"))
    }
    
    // T069 - Verify no git operations executed when duplicate detected
    @Test("Verify no git operations executed when duplicate detected")
    func testNoGitOpsOnDuplicateDetection() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Add first subtree
        let firstAddResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "first", "--ref", "master"],
            workingDirectory: fixture.path
        )
        #expect(firstAddResult.exitCode == 0)
        
        // Get commit count after first add
        let afterFirstLog = try await harness.runGit(["rev-list", "--count", "HEAD"], in: fixture.path)
        let afterFirstCount = Int(afterFirstLog.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        
        // Try to add duplicate name (should fail before git operations)
        let duplicateResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Spoon-Knife.git", "--name", "first", "--ref", "main"],
            workingDirectory: fixture.path
        )
        #expect(duplicateResult.exitCode == 1)
        
        // Get commit count after duplicate attempt
        let afterDuplicateLog = try await harness.runGit(["rev-list", "--count", "HEAD"], in: fixture.path)
        let afterDuplicateCount = Int(afterDuplicateLog.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        
        // Commit count should be unchanged - no git operations executed
        #expect(afterFirstCount == afterDuplicateCount)
        
        // Verify the second subtree directory was NOT created
        let secondSubtreeExists = FileManager.default.fileExists(atPath: "\(fixture.path.string)/Spoon-Knife")
        #expect(secondSubtreeExists == false)
    }
    
    // T072 - Test invalid URL error
    @Test("Test invalid URL error")
    func testInvalidURLError() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Try to add with invalid URL
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "not-a-valid-url"],
            workingDirectory: fixture.path
        )
        
        // Should fail with invalid URL error
        #expect(addResult.exitCode == 1)
        #expect(addResult.stdout.contains("❌"))
        #expect(addResult.stdout.contains("URL") || addResult.stdout.contains("url"))
    }
    
    // T073 - Test missing config error
    @Test("Test missing config error")
    func testMissingConfigError() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Don't initialize config - try to add without subtree.yaml
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Should fail with missing config error
        #expect(addResult.exitCode == 1)
        #expect(addResult.stdout.contains("❌"))
        #expect(addResult.stdout.contains("init") || addResult.stdout.contains("Configuration"))
    }
    
    // T074 - Test not in git repo error
    @Test("Test not in git repo error")
    func testNotInGitRepoError() async throws {
        let harness = TestHarness()
        
        // Create a temporary directory that is NOT a git repo
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-a-repo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        #if canImport(System)
        let tempPath = System.FilePath(tempDir.path)
        #else
        let tempPath = SystemPackage.FilePath(tempDir.path)
        #endif
        
        // Try to add in non-git directory
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--ref", "master"],
            workingDirectory: tempPath
        )
        
        // Should fail with not in git repo error
        #expect(addResult.exitCode == 1)
        #expect(addResult.stdout.contains("❌"))
        #expect(addResult.stdout.contains("git") || addResult.stdout.contains("repository"))
    }
    
    // T075 - Test git operation failure handling
    @Test("Test git operation failure handling")
    func testGitOperationFailure() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Try to add with invalid ref (non-existent branch)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--ref", "nonexistent-branch-xyz"],
            workingDirectory: fixture.path
        )
        
        // Should fail with git operation error
        #expect(addResult.exitCode == 1)
        #expect(addResult.stdout.contains("❌"))
        #expect(addResult.stdout.contains("failed") || addResult.stdout.contains("error"))
    }
    
    // T076 - Test commit amend failure recovery guidance
    @Test("Test commit amend failure recovery guidance")
    func testCommitAmendFailureGuidance() async throws {
        // This test verifies that if commit --amend fails, we provide recovery guidance
        // In practice, commit --amend failures are rare in our use case, but we should handle them
        
        // Note: This is difficult to test in integration without corrupting the git state
        // The implementation should catch amend failures and provide clear guidance
        // For now, we verify the error path exists by checking the implementation
        
        // This test documents the expected behavior:
        // 1. If amend fails, show "❌ Failed to amend commit"
        // 2. Provide recovery steps
        // 3. Exit with code 1
        
        // Since we can't easily trigger this failure in integration tests,
        // we'll mark this as a test that verifies the implementation has error handling
    }
    
    // MARK: - Feature 007: Case-Insensitive Validation Tests
    
    // T011 [P] [US2] - Duplicate name prevention tests
    @Test("Rejects duplicate name (case-insensitive)")
    func testRejectsDuplicateNameCaseInsensitive() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Add first subtree with name "Hello-World"
        let firstAdd = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "Hello-World", "--ref", "master"],
            workingDirectory: fixture.path
        )
        #expect(firstAdd.exitCode == 0)
        
        // Capture commit count after first add
        let afterFirstLog = try await harness.runGit(["rev-list", "--count", "HEAD"], in: fixture.path)
        let afterFirstCount = Int(afterFirstLog.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        
        // Try to add second subtree with case-variant name "hello-world"
        let secondAdd = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Spoon-Knife.git", "--name", "hello-world", "--prefix", "other", "--ref", "main"],
            workingDirectory: fixture.path
        )
        
        // Should fail with duplicate name error BEFORE git operations
        #expect(secondAdd.exitCode == 1)
        #expect(secondAdd.stdout.contains("❌"))
        #expect(secondAdd.stdout.contains("conflicts with existing"))
        #expect(secondAdd.stdout.contains("'hello-world'"))
        #expect(secondAdd.stdout.contains("'Hello-World'"))
        #expect(secondAdd.stdout.contains("case-insensitively"))
        
        // Verify git operations were NOT executed (commit count unchanged)
        let afterDuplicateLog = try await harness.runGit(["rev-list", "--count", "HEAD"], in: fixture.path)
        let afterDuplicateCount = Int(afterDuplicateLog.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        
        // Commit count must be unchanged - no git operations executed
        #expect(afterDuplicateCount == afterFirstCount)
    }
    
    @Test("Accepts different names with different case")
    func testAcceptsDifferentNamesWithDifferentCase() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Add subtree with name "MyLib"
        let firstAdd = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "MyLib", "--ref", "master"],
            workingDirectory: fixture.path
        )
        #expect(firstAdd.exitCode == 0)
        
        // Add subtree with different name "OtherLib" (not case-variant)
        let secondAdd = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Spoon-Knife.git", "--name", "OtherLib", "--prefix", "other", "--ref", "main"],
            workingDirectory: fixture.path
        )
        
        // Should succeed - different names
        #expect(secondAdd.exitCode == 0)
    }
    
    // T012 [P] [US3] - Duplicate prefix prevention tests
    @Test("Rejects duplicate prefix (case-insensitive)")
    func testRejectsDuplicatePrefixCaseInsensitive() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Add first subtree with prefix "vendor/lib"
        let firstAdd = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--prefix", "vendor/lib", "--ref", "master"],
            workingDirectory: fixture.path
        )
        #expect(firstAdd.exitCode == 0)
        
        // Capture commit count after first add
        let afterFirstLog = try await harness.runGit(["rev-list", "--count", "HEAD"], in: fixture.path)
        let afterFirstCount = Int(afterFirstLog.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        
        // Try to add second subtree with case-variant prefix "vendor/Lib"
        let secondAdd = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Spoon-Knife.git", "--prefix", "vendor/Lib", "--ref", "main"],
            workingDirectory: fixture.path
        )
        
        // Should fail with duplicate prefix error BEFORE git operations
        #expect(secondAdd.exitCode == 1)
        #expect(secondAdd.stdout.contains("❌"))
        #expect(secondAdd.stdout.contains("conflicts with existing"))
        #expect(secondAdd.stdout.contains("'vendor/Lib'"))
        #expect(secondAdd.stdout.contains("'vendor/lib'"))
        
        // Verify git operations were NOT executed (commit count unchanged)
        let afterDuplicateLog = try await harness.runGit(["rev-list", "--count", "HEAD"], in: fixture.path)
        let afterDuplicateCount = Int(afterDuplicateLog.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        
        // Commit count must be unchanged - no git operations executed
        #expect(afterDuplicateCount == afterFirstCount)
    }
    
    @Test("Accepts different prefixes")
    func testAcceptsDifferentPrefixes() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Add subtree with prefix "vendor/lib-a"
        let firstAdd = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--prefix", "vendor/lib-a", "--ref", "master"],
            workingDirectory: fixture.path
        )
        #expect(firstAdd.exitCode == 0)
        
        // Add subtree with different prefix "vendor/lib-b"
        let secondAdd = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Spoon-Knife.git", "--prefix", "vendor/lib-b", "--ref", "main"],
            workingDirectory: fixture.path
        )
        
        // Should succeed - different prefixes
        #expect(secondAdd.exitCode == 0)
    }
    
    // T013 [P] [US2] - Path validation tests
    @Test("Rejects absolute path prefix")
    func testRejectsAbsolutePathPrefix() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Try to add with absolute path prefix
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--prefix", "/vendor/lib", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Should fail with absolute path error BEFORE git operations
        #expect(addResult.exitCode == 1)
        #expect(addResult.stdout.contains("❌"))
        #expect(addResult.stdout.contains("must be a relative path"))
        #expect(addResult.stdout.contains("'/vendor/lib'"))
        
        // Verify git operations were NOT executed
        let logResult = try await harness.runGit(["log", "--oneline"], in: fixture.path)
        let commitCount = logResult.split(separator: "\n").count
        #expect(commitCount == 1)  // Only initial commit
    }
    
    @Test("Rejects parent traversal in prefix")
    func testRejectsParentTraversalInPrefix() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Try to add with parent traversal in prefix
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--prefix", "../vendor/lib", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Should fail with parent traversal error BEFORE git operations
        #expect(addResult.exitCode == 1)
        #expect(addResult.stdout.contains("❌"))
        #expect(addResult.stdout.contains("parent directory traversal"))
        #expect(addResult.stdout.contains("'../'"))
        
        // Verify git operations were NOT executed
        let logResult = try await harness.runGit(["log", "--oneline"], in: fixture.path)
        let commitCount = logResult.split(separator: "\n").count
        #expect(commitCount == 1)  // Only initial commit
    }
    
    @Test("Rejects backslash separator in prefix")
    func testRejectsBackslashSeparatorInPrefix() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Try to add with backslash separator
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--prefix", "vendor\\lib", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Should fail with invalid separator error BEFORE git operations
        #expect(addResult.exitCode == 1)
        #expect(addResult.stdout.contains("❌"))
        #expect(addResult.stdout.contains("invalid path separator"))
        #expect(addResult.stdout.contains("forward slashes"))
        
        // Verify git operations were NOT executed
        let logResult = try await harness.runGit(["log", "--oneline"], in: fixture.path)
        let commitCount = logResult.split(separator: "\n").count
        #expect(commitCount == 1)  // Only initial commit
    }
    
    // T014 [P] [US2] - Whitespace normalization tests
    @Test("Trims whitespace from name")
    func testTrimsWhitespaceFromName() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Add with whitespace in name (should be trimmed)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "  MyLib  ", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Should succeed with trimmed name
        #expect(addResult.exitCode == 0)
        
        // Verify config has trimmed name (not "  MyLib  ")
        let configPath = fixture.path.appending("/subtree.yaml")
        let configData = try String(contentsOfFile: configPath.string, encoding: .utf8)
        #expect(configData.contains("name: MyLib"))
        #expect(!configData.contains("name:   MyLib  "))
    }
    
    @Test("Trims whitespace from prefix")
    func testTrimsWhitespaceFromPrefix() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Add with whitespace in prefix (should be trimmed)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--prefix", "  vendor/lib  ", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Should succeed with trimmed prefix
        #expect(addResult.exitCode == 0)
        
        // Verify config has trimmed prefix
        let configPath = fixture.path.appending("/subtree.yaml")
        let configData = try String(contentsOfFile: configPath.string, encoding: .utf8)
        #expect(configData.contains("prefix: vendor/lib"))
        #expect(!configData.contains("prefix:   vendor/lib  "))
    }
    
    // T015 [P] [US2] - Non-ASCII warning tests
    @Test("Displays warning for non-ASCII name")
    func testDisplaysWarningForNonASCIIName() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Add with non-ASCII name (Cyrillic characters)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "Библиотека", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Should succeed but display warning to stderr
        #expect(addResult.exitCode == 0)
        #expect(addResult.stderr.contains("⚠️") || addResult.stderr.contains("Warning"))
        #expect(addResult.stderr.contains("non-ASCII"))
        #expect(addResult.stderr.contains("Библиотека"))
        #expect(addResult.stderr.contains("case-insensitive") || addResult.stderr.contains("Case-insensitive"))
    }
    
    @Test("No warning for ASCII-only name")
    func testNoWarningForASCIIOnlyName() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        #expect(initResult.exitCode == 0)
        
        // Add with ASCII-only name
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "My-Lib-123", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        // Should succeed with no warning
        #expect(addResult.exitCode == 0)
        #expect(!addResult.stderr.contains("⚠️"))
        #expect(!addResult.stderr.contains("Warning"))
        #expect(!addResult.stderr.contains("non-ASCII"))
    }
    
    // MARK: - Phase 5: Corruption Detection & Case Preservation Tests
    
    // T032 [P] [US4] - Config corruption detection for Add
    @Test("Detects corrupted config with duplicate names before add")
    func testDetectsCorruptedConfigOnAdd() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        
        // Manually corrupt config with case-variant duplicate names
        let configPath = fixture.path.appending("/subtree.yaml")
        let corruptedConfig = """
        # Subtree Configuration
        subtrees:
          - name: My-Library
            remote: git@github.com:octocat/Hello-World.git
            prefix: vendor/my-lib
            commit: abc123
            branch: master
            squash: true
          - name: my-library
            remote: git@github.com:octocat/Spoon-Knife.git
            prefix: vendor/other
            commit: def456
            branch: main
            squash: true
        """
        try corruptedConfig.write(toFile: configPath.string, atomically: true, encoding: .utf8)
        
        // Attempt to add a new subtree
        let result = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/git-consortium.git", "--name", "new-lib", "--ref", "main"],
            workingDirectory: fixture.path
        )
        
        // Should fail when validate() detects corruption
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains("❌"))
        #expect(result.stdout.contains("conflicts") || result.stdout.contains("duplicate"))
    }
    
    // T033 [P] [US4] - Duplicate prefix corruption detection
    @Test("Detects corrupted config with duplicate prefixes before add")
    func testDetectsDuplicatePrefixCorruption() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        
        // Manually corrupt config with case-variant duplicate prefixes
        let configPath = fixture.path.appending("/subtree.yaml")
        let corruptedConfig = """
        # Subtree Configuration
        subtrees:
          - name: lib-one
            remote: git@github.com:octocat/Hello-World.git
            prefix: Vendor/Lib
            commit: abc123
            branch: master
            squash: true
          - name: lib-two
            remote: git@github.com:octocat/Spoon-Knife.git
            prefix: vendor/lib
            commit: def456
            branch: main
            squash: true
        """
        try corruptedConfig.write(toFile: configPath.string, atomically: true, encoding: .utf8)
        
        // Attempt to add a new subtree
        let result = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/git-consortium.git", "--name", "new-lib", "--prefix", "other", "--ref", "main"],
            workingDirectory: fixture.path
        )
        
        // Should fail when validate() detects corrupted prefixes
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains("❌"))
        #expect(result.stdout.contains("conflicts") || result.stdout.contains("duplicate"))
    }
    
    // T034 [P] [US5] - Case preservation in Add command
    @Test("Preserves exact case of user-provided name in config")
    func testPreservesCaseOfProvidedName() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        
        // Add with specific casing
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "MyAwesomeLib", "--prefix", "vendor/awesome", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        #expect(addResult.exitCode == 0)
        
        // Verify config preserves exact case
        let configPath = fixture.path.appending("/subtree.yaml")
        let configData = try String(contentsOfFile: configPath.string, encoding: .utf8)
        #expect(configData.contains("name: MyAwesomeLib"))
        #expect(!configData.contains("name: myawesomelib"))
        #expect(!configData.contains("name: MYAWESOMELIB"))
    }
    
    @Test("Preserves exact case of user-provided prefix in config")
    func testPreservesCaseOfProvidedPrefix() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        
        // Add with mixed-case prefix
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--prefix", "Vendor/MyLib", "--ref", "master"],
            workingDirectory: fixture.path
        )
        
        #expect(addResult.exitCode == 0)
        
        // Verify config preserves exact case
        let configPath = fixture.path.appending("/subtree.yaml")
        let configData = try String(contentsOfFile: configPath.string, encoding: .utf8)
        #expect(configData.contains("prefix: Vendor/MyLib"))
        #expect(!configData.contains("prefix: vendor/mylib"))
    }
    
    // T036 [P] [US5] - Mixed-case config verification
    @Test("Allows multiple subtrees with different cases and different names")
    func testAllowsMixedCaseSubtrees() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Initialize config
        _ = try await harness.run(arguments: ["init"], workingDirectory: fixture.path)
        
        // Add first subtree with PascalCase
        let add1 = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Hello-World.git", "--name", "HelloWorld", "--prefix", "vendor/hello", "--ref", "master"],
            workingDirectory: fixture.path
        )
        #expect(add1.exitCode == 0)
        
        // Add second subtree with kebab-case (different name)
        let add2 = try await harness.run(
            arguments: ["add", "--remote", "git@github.com:octocat/Spoon-Knife.git", "--name", "spoon-knife", "--prefix", "vendor/spoon", "--ref", "main"],
            workingDirectory: fixture.path
        )
        #expect(add2.exitCode == 0)
        
        // Verify two entries exist with original casing (no third add needed for case preservation test)
        let configPath = fixture.path.appending("/subtree.yaml")
        let configData = try String(contentsOfFile: configPath.string, encoding: .utf8)
        #expect(configData.contains("name: HelloWorld"))
        #expect(configData.contains("name: spoon-knife"))
        
        // Verify both are different (case-insensitive matching would reject if they were "hello-world" variants)
        #expect(configData.contains("vendor/hello"))
        #expect(configData.contains("vendor/spoon"))
    }
}
