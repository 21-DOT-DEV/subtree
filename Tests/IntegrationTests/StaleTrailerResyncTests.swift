import Testing
import Foundation
#if canImport(System)
import System
#else
import SystemPackage
#endif

@Suite("Stale Trailer Resync Tests")
final class StaleTrailerResyncTests {
    
    let harness = TestHarness()
    
    /// Helper: get the file:// URL for a fixture's path
    private func fileURL(for fixture: GitRepositoryFixture) -> String {
        "file://\(fixture.path.string)"
    }
    
    /// Helper: create an upstream repo with an initial commit and tag
    private func createUpstreamRepo(tag: String) async throws -> GitRepositoryFixture {
        let upstream = try await GitRepositoryFixture()
        
        let srcDir = upstream.path.appending("src")
        try FileManager.default.createDirectory(atPath: srcDir.string, withIntermediateDirectories: true)
        try "int main() { return 0; }\n".write(
            toFile: srcDir.appending("main.c").string, atomically: true, encoding: .utf8
        )
        try await upstream.runGit(["add", "."])
        try await upstream.runGit(["commit", "-m", "Add source files"])
        try await upstream.runGit(["tag", tag])
        
        return upstream
    }
    
    /// Helper: add new content to upstream and tag it
    private func addUpstreamUpdate(repo: GitRepositoryFixture, tag: String, content: String = "// updated\n") async throws {
        try content.write(
            toFile: repo.path.appending("src/main.c").string, atomically: true, encoding: .utf8
        )
        try await repo.runGit(["add", "."])
        try await repo.runGit(["commit", "-m", "Update for \(tag)"])
        try await repo.runGit(["tag", tag])
    }
    
    /// Helper: get the full commit hash for a tag in a repo
    private func getTagCommit(repo: GitRepositoryFixture, tag: String) async throws -> String {
        let output = try await repo.runGit(["rev-parse", tag])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Stale Trailer Tests (GitHub Squash Merge Scenario)
    
    @Test("update succeeds when trailer has stale split hash from squash merge")
    func testUpdateWithStaleTrailer() async throws {
        // Setup: upstream with v1.0, v2.0, and v3.0
        let upstream = try await createUpstreamRepo(tag: "v1.0")
        defer { try? upstream.tearDown() }
        
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Init and add subtree at v1.0
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", fileURL(for: upstream), "--name", "lib",
                        "--prefix", "Vendor/lib", "--ref", "v1.0"],
            workingDirectory: local.path
        )
        #expect(addResult.exitCode == 0, "Add should succeed: \(addResult.stderr)")
        
        // Update to v2.0 normally (this creates proper trailers)
        try await addUpstreamUpdate(repo: upstream, tag: "v2.0", content: "// v2\n")
        let update1 = try await harness.run(
            arguments: ["update", "lib"],
            workingDirectory: local.path
        )
        #expect(update1.exitCode == 0, "First update should succeed: \(update1.stdout)\(update1.stderr)")
        
        // Simulate GitHub squash merge: replace the update commit with one that has NO trailers
        // This is what happens when GitHub squash-merges a multi-commit subtree PR
        try await local.runGit(["commit", "--allow-empty", "-m",
            "chore(deps): update subtree lib to v2.0 (#123)\n\nThis squash merge lost the trailers."])
        
        // Now the most recent trailer still points to v1.0's split hash,
        // but subtree.yaml says the commit is v2.0.
        // Add v3.0 upstream
        try await addUpstreamUpdate(repo: upstream, tag: "v3.0", content: "// v3\n")
        
        // Update to v3.0 — should detect stale trailer and create resync before pulling
        let update2 = try await harness.run(
            arguments: ["update", "lib"],
            workingDirectory: local.path
        )
        
        #expect(update2.exitCode == 0,
                "Update should succeed after stale trailer resync: \(update2.stdout)\(update2.stderr)")
        #expect(update2.stdout.contains("Updated lib"),
                "Should show updated message: \(update2.stdout)")
        
        // Verify the content was actually updated
        let content = try String(contentsOfFile: local.path.appending("Vendor/lib/src/main.c").string)
        #expect(content.contains("v3"), "Content should be from v3.0")
    }
    
    @Test("update succeeds when no trailer exists at all")
    func testUpdateWithMissingTrailer() async throws {
        // Setup: upstream with v1.0
        let upstream = try await createUpstreamRepo(tag: "v1.0")
        defer { try? upstream.tearDown() }
        
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Manually place subtree content (without git subtree add, so no trailers)
        let v1Commit = try await getTagCommit(repo: upstream, tag: "v1.0")
        let vendorDir = local.path.appending("Vendor/lib/src")
        try FileManager.default.createDirectory(atPath: vendorDir.string, withIntermediateDirectories: true)
        try "int main() { return 0; }\n".write(
            toFile: vendorDir.appending("main.c").string, atomically: true, encoding: .utf8
        )
        
        // Create subtree.yaml manually with correct config
        let configContent = """
        subtrees:
          - name: lib
            remote: \(fileURL(for: upstream))
            prefix: Vendor/lib
            commit: \(v1Commit)
            tag: v1.0
            squash: true
        """
        try configContent.write(
            toFile: local.path.appending("subtree.yaml").string, atomically: true, encoding: .utf8
        )
        
        try await local.runGit(["add", "."])
        try await local.runGit(["commit", "-m", "manual subtree setup (no trailers)"])
        
        // Now there are zero git-subtree-dir trailers in the history,
        // but subtree.yaml exists with the correct commit hash and Vendor/lib has content
        
        // Add v2.0 upstream
        try await addUpstreamUpdate(repo: upstream, tag: "v2.0", content: "// v2\n")
        
        // Update — should detect missing trailer and create resync from config
        let updateResult = try await harness.run(
            arguments: ["update", "lib"],
            workingDirectory: local.path
        )
        
        #expect(updateResult.exitCode == 0,
                "Update should succeed with missing trailer resync: \(updateResult.stdout)\(updateResult.stderr)")
        #expect(updateResult.stdout.contains("Updated lib"),
                "Should show updated message: \(updateResult.stdout)")
    }
    
    @Test("resync commit is created with correct hash from config when trailer is stale")
    func testResyncCommitUsesConfigHash() async throws {
        let upstream = try await createUpstreamRepo(tag: "v1.0")
        defer { try? upstream.tearDown() }
        
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Init and add subtree at v1.0
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", fileURL(for: upstream), "--name", "lib",
                        "--prefix", "Vendor/lib", "--ref", "v1.0"],
            workingDirectory: local.path
        )
        
        // Update to v2.0 normally
        try await addUpstreamUpdate(repo: upstream, tag: "v2.0", content: "// v2\n")
        _ = try await harness.run(arguments: ["update", "lib"], workingDirectory: local.path)
        let v2Commit = try await getTagCommit(repo: upstream, tag: "v2.0")
        
        // Simulate squash merge losing trailers
        try await local.runGit(["commit", "--allow-empty", "-m",
            "squash merge that lost trailers"])
        
        // Add v3.0 upstream and update
        try await addUpstreamUpdate(repo: upstream, tag: "v3.0", content: "// v3\n")
        let updateResult = try await harness.run(
            arguments: ["update", "lib"], workingDirectory: local.path
        )
        #expect(updateResult.exitCode == 0, "Update should succeed: \(updateResult.stdout)\(updateResult.stderr)")
        
        // Check that the resync commit used the v2.0 hash (from config), not v1.0 (from stale trailer)
        let log = try await local.runGit(["log", "--all", "--format=%B", "--grep=git-subtree-split: \(v2Commit)"])
        #expect(log.contains("git-subtree-split: \(v2Commit)"),
                "Resync should use config commit hash (\(v2Commit)), not stale trailer")
        #expect(log.contains("git-subtree-dir: Vendor/lib"),
                "Resync should have correct prefix")
    }
    
    @Test("normal update does not create unnecessary resync when trailer matches config")
    func testNoResyncWhenTrailerMatchesConfig() async throws {
        let upstream = try await createUpstreamRepo(tag: "v1.0")
        defer { try? upstream.tearDown() }
        
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Init and add subtree
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", fileURL(for: upstream), "--name", "lib",
                        "--prefix", "Vendor/lib", "--ref", "v1.0"],
            workingDirectory: local.path
        )
        
        // Record HEAD before update
        let headBefore = try await local.runGit(["rev-parse", "HEAD"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add v2.0 and update — trailer should match config, no resync needed
        try await addUpstreamUpdate(repo: upstream, tag: "v2.0", content: "// v2\n")
        let updateResult = try await harness.run(
            arguments: ["update", "lib"], workingDirectory: local.path
        )
        #expect(updateResult.exitCode == 0)
        
        // Count first-parent commits between old HEAD and new HEAD
        // --first-parent excludes squash parent commits from the count
        // Normal update (no resync): 1 (the merge/amend commit)
        // With unnecessary resync: 2 (resync + merge/amend commit)
        let countOutput = try await local.runGit(
            ["rev-list", "--first-parent", "--count", "\(headBefore)..HEAD"]
        )
        let newCommitCount = Int(countOutput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        #expect(newCommitCount == 1,
                "Normal update should create exactly 1 first-parent commit (no resync), got \(newCommitCount)")
    }
    
    @Test("update detects stale trailer even when correct trailer exists on another branch")
    func testStaleTrailerNotMaskedByOtherBranch() async throws {
        // This reproduces the exact CI failure: a previous workflow run pushed a branch
        // with the correct resync trailer, but the current branch (from main) still has
        // the stale trailer. findSubtreeSplitInfo must only search HEAD, not --all.
        
        let upstream = try await createUpstreamRepo(tag: "v1.0")
        defer { try? upstream.tearDown() }
        
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Init and add subtree at v1.0
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", fileURL(for: upstream), "--name", "lib",
                        "--prefix", "Vendor/lib", "--ref", "v1.0"],
            workingDirectory: local.path
        )
        #expect(addResult.exitCode == 0, "Add should succeed: \(addResult.stderr)")
        
        // Update to v2.0 normally (creates proper trailers)
        try await addUpstreamUpdate(repo: upstream, tag: "v2.0", content: "// v2\n")
        let update1 = try await harness.run(
            arguments: ["update", "lib"],
            workingDirectory: local.path
        )
        #expect(update1.exitCode == 0, "First update should succeed: \(update1.stdout)\(update1.stderr)")
        let v2Commit = try await getTagCommit(repo: upstream, tag: "v2.0")
        
        // Simulate GitHub squash merge: replace update commit with one that has NO trailers
        try await local.runGit(["commit", "--allow-empty", "-m",
            "chore(deps): update subtree lib to v2.0 (#123)\n\nSquash merge lost trailers."])
        
        // Create a side branch that has the CORRECT trailer (simulates a previous CI run)
        try await local.runGit(["checkout", "-b", "other-branch"])
        try await local.runGit(["commit", "--allow-empty", "-m",
            "Squashed 'Vendor/lib/' content from commit \(String(v2Commit.prefix(8)))\n\ngit-subtree-dir: Vendor/lib\ngit-subtree-split: \(v2Commit)"])
        
        // Go back to main — this branch has the stale v1.0 trailer
        try await local.runGit(["checkout", "-"])
        
        // Add v3.0 upstream
        try await addUpstreamUpdate(repo: upstream, tag: "v3.0", content: "// v3\n")
        
        // Update — must detect stale trailer on HEAD despite correct trailer on other-branch
        let update2 = try await harness.run(
            arguments: ["update", "lib"],
            workingDirectory: local.path
        )
        
        #expect(update2.exitCode == 0,
                "Update should succeed (resync from HEAD, ignoring other branch): \(update2.stdout)\(update2.stderr)")
        #expect(update2.stdout.contains("Updated lib"),
                "Should show updated message: \(update2.stdout)")
        
        // Verify content was actually updated to v3
        let content = try String(contentsOfFile: local.path.appending("Vendor/lib/src/main.c").string)
        #expect(content.contains("v3"), "Content should be from v3.0")
    }
}
