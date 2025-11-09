import Testing
import Foundation
#if canImport(System)
import System
#else
import SystemPackage
#endif

/// Integration tests for GitRepositoryFixture
///
/// These tests verify that the git repository fixture works correctly:
/// - Creates unique temporary directories
/// - Initializes git repositories
/// - Creates initial commits
/// - Allows CLI execution in the repository
/// - Cleans up completely
@Suite("Git Fixture Tests")
struct GitFixtureTests {
    
    @Test("Temp directory created with unique path")
    func testUniqueTempDirectory() async throws {
        let fixture1 = try await GitRepositoryFixture()
        defer { try? fixture1.tearDown() }
        
        let fixture2 = try await GitRepositoryFixture()
        defer { try? fixture2.tearDown() }
        
        // Paths should be different (UUID-based)
        #expect(fixture1.path != fixture2.path)
        
        // Both should exist
        #expect(FileManager.default.fileExists(atPath: fixture1.path.string))
        #expect(FileManager.default.fileExists(atPath: fixture2.path.string))
        
        // Paths should contain UUID pattern (be unique)
        #expect(fixture1.path.string.contains("/tmp/subtree-test-"))
        #expect(fixture2.path.string.contains("/tmp/subtree-test-"))
    }
    
    @Test("Git init executed successfully")
    func testGitInitialized() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // .git directory should exist
        let gitDir = fixture.path.appending(".git")
        #expect(FileManager.default.fileExists(atPath: gitDir.string))
        
        // Git rev-parse should work
        let output = try await fixture.runGit(["rev-parse", "--git-dir"])
        #expect(output.contains(".git"))
        
        // Should have git config
        let userName = try await fixture.runGit(["config", "user.name"])
        #expect(userName.trimmingCharacters(in: .whitespacesAndNewlines) == "Test User")
    }
    
    @Test("Initial commit created")
    func testInitialCommit() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        // Should have at least 1 commit
        let commitCount = try await fixture.getCommitCount()
        #expect(commitCount == 1)
        
        // Should have README.md
        #expect(fixture.fileExists("README.md"))
        
        // Commit message should be "Initial commit"
        let log = try await fixture.runGit(["log", "--oneline"])
        #expect(log.contains("Initial commit"))
        
        // Should have current commit SHA
        let sha = try await fixture.getCurrentCommit()
        #expect(!sha.isEmpty)
        #expect(sha.count >= 7) // Short SHA is at least 7 chars
    }
    
    @Test("Subtree CLI can be executed in git repo")
    func testCLIInGitRepo() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Run subtree --help in the git repository
        let result = try await harness.run(
            arguments: ["--help"],
            workingDirectory: fixture.path
        )
        
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("USAGE"))
        
        // Verify we're in a git repository using TestHarness helper
        let isGitRepo = await harness.isGitRepository(fixture.path)
        #expect(isGitRepo == true)
    }
    
    @Test("Cleanup removes temp directory completely")
    func testCleanup() async throws {
        let fixture = try await GitRepositoryFixture()
        let tempPath = fixture.path
        
        // Directory should exist
        #expect(FileManager.default.fileExists(atPath: tempPath.string))
        
        // Clean up
        try fixture.tearDown()
        
        // Directory should be gone
        #expect(!FileManager.default.fileExists(atPath: tempPath.string))
    }
    
    @Test("Multiple fixtures can coexist")
    func testMultipleFixtures() async throws {
        let fixture1 = try await GitRepositoryFixture()
        let fixture2 = try await GitRepositoryFixture()
        let fixture3 = try await GitRepositoryFixture()
        
        defer {
            try? fixture1.tearDown()
            try? fixture2.tearDown()
            try? fixture3.tearDown()
        }
        
        // All should have independent git repos
        let count1 = try await fixture1.getCommitCount()
        let count2 = try await fixture2.getCommitCount()
        let count3 = try await fixture3.getCommitCount()
        
        #expect(count1 == 1)
        #expect(count2 == 1)
        #expect(count3 == 1)
        
        // All paths should be different
        #expect(fixture1.path != fixture2.path)
        #expect(fixture2.path != fixture3.path)
        #expect(fixture1.path != fixture3.path)
    }
    
    @Test("Git state verification helpers work")
    func testGitHelpers() async throws {
        let fixture = try await GitRepositoryFixture()
        defer { try? fixture.tearDown() }
        
        let harness = TestHarness()
        
        // Verify commit exists
        let hasCommit = try await harness.verifyCommitExists(
            withMessage: "Initial commit",
            in: fixture.path
        )
        #expect(hasCommit == true)
        
        // Get git config
        let userName = try await harness.getGitConfig("user.name", in: fixture.path)
        #expect(userName == "Test User")
        
        let userEmail = try await harness.getGitConfig("user.email", in: fixture.path)
        #expect(userEmail == "test@example.com")
        
        // Verify it's a git repository
        let isRepo = await harness.isGitRepository(fixture.path)
        #expect(isRepo == true)
    }
}
