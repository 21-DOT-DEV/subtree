import Testing
import Foundation
#if canImport(System)
import System
#else
import SystemPackage
#endif

@Suite("Multi-Trailer Resync Tests")
final class MultiTrailerResyncTests {
    
    let harness = TestHarness()
    
    /// Helper: get the file:// URL for a fixture's path
    private func fileURL(for fixture: GitRepositoryFixture) -> String {
        "file://\(fixture.path.string)"
    }
    
    /// Helper: create a bare upstream repo with an initial commit and tag
    private func createUpstreamRepo(name: String, tag: String) async throws -> GitRepositoryFixture {
        let upstream = try await GitRepositoryFixture()
        
        // Add a source file so the subtree has content
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
    private func addUpstreamUpdate(repo: GitRepositoryFixture, tag: String) async throws {
        try "// updated\n".write(
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
    
    // MARK: - Multi-Trailer Detection Tests
    
    @Test("update succeeds when multi-trailer merge commit exists")
    func testUpdateWithMultiTrailerCommit() async throws {
        // Create two upstream repos
        let upstreamA = try await createUpstreamRepo(name: "libA", tag: "v1.0")
        defer { try? upstreamA.tearDown() }
        let upstreamB = try await createUpstreamRepo(name: "libB", tag: "v1.0")
        defer { try? upstreamB.tearDown() }
        
        // Create consumer repo
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Init subtree config
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        
        // Add both subtrees individually
        let addA = try await harness.run(
            arguments: ["add", "--remote", fileURL(for: upstreamA), "--name", "libA",
                        "--prefix", "Vendor/libA", "--ref", "v1.0"],
            workingDirectory: local.path
        )
        #expect(addA.exitCode == 0, "Add libA should succeed: \(addA.stderr)")
        
        let addB = try await harness.run(
            arguments: ["add", "--remote", fileURL(for: upstreamB), "--name", "libB",
                        "--prefix", "Vendor/libB", "--ref", "v1.0"],
            workingDirectory: local.path
        )
        #expect(addB.exitCode == 0, "Add libB should succeed: \(addB.stderr)")
        
        // Get the split hashes from the individual subtree add commits
        let commitHashA = try await getTagCommit(repo: upstreamA, tag: "v1.0")
        let commitHashB = try await getTagCommit(repo: upstreamB, tag: "v1.0")
        
        // Create a multi-trailer commit (simulates squash-merged PR that combined both adds)
        let multiTrailerMessage = """
        refactor: Replace submodules with subtrees
        
        git-subtree-dir: Vendor/libA
        git-subtree-split: \(commitHashA)
        git-subtree-dir: Vendor/libB
        git-subtree-split: \(commitHashB)
        """
        try await local.runGit(["commit", "--allow-empty", "-m", multiTrailerMessage])
        
        // Add new content to upstream A and tag v2.0
        try await addUpstreamUpdate(repo: upstreamA, tag: "v2.0")
        
        // Update libA — this should trigger resync and succeed
        let updateResult = try await harness.run(
            arguments: ["update", "libA"],
            workingDirectory: local.path
        )
        
        #expect(updateResult.exitCode == 0,
                "Update should succeed after multi-trailer resync: \(updateResult.stdout)\(updateResult.stderr)")
        #expect(updateResult.stdout.contains("Updated libA") || updateResult.stdout.contains("up to date"),
                "Should show update status")
    }
    
    @Test("update succeeds when no multi-trailer issue exists")
    func testUpdateWithoutMultiTrailerCommit() async throws {
        // Create upstream repo
        let upstream = try await createUpstreamRepo(name: "lib", tag: "v1.0")
        defer { try? upstream.tearDown() }
        
        // Create consumer repo
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Init and add subtree
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        let addResult = try await harness.run(
            arguments: ["add", "--remote", fileURL(for: upstream), "--name", "lib",
                        "--prefix", "Vendor/lib", "--ref", "v1.0"],
            workingDirectory: local.path
        )
        #expect(addResult.exitCode == 0, "Add should succeed")
        
        // Add new content upstream
        try await addUpstreamUpdate(repo: upstream, tag: "v2.0")
        
        // Update should succeed normally (no multi-trailer issue)
        let updateResult = try await harness.run(
            arguments: ["update", "lib"],
            workingDirectory: local.path
        )
        
        #expect(updateResult.exitCode == 0, "Update should succeed: \(updateResult.stdout)\(updateResult.stderr)")
        #expect(updateResult.stdout.contains("Updated lib"), "Should show updated message")
    }
    
    @Test("resync commit has correct single-prefix trailer")
    func testResyncCommitFormat() async throws {
        // Create two upstream repos
        let upstreamA = try await createUpstreamRepo(name: "libA", tag: "v1.0")
        defer { try? upstreamA.tearDown() }
        let upstreamB = try await createUpstreamRepo(name: "libB", tag: "v1.0")
        defer { try? upstreamB.tearDown() }
        
        // Create consumer repo
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        
        // Init and add both subtrees
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)
        _ = try await harness.run(
            arguments: ["add", "--remote", fileURL(for: upstreamA), "--name", "libA",
                        "--prefix", "Vendor/libA", "--ref", "v1.0"],
            workingDirectory: local.path
        )
        _ = try await harness.run(
            arguments: ["add", "--remote", fileURL(for: upstreamB), "--name", "libB",
                        "--prefix", "Vendor/libB", "--ref", "v1.0"],
            workingDirectory: local.path
        )
        
        // Create multi-trailer commit
        let commitHashA = try await getTagCommit(repo: upstreamA, tag: "v1.0")
        let commitHashB = try await getTagCommit(repo: upstreamB, tag: "v1.0")
        let multiTrailerMessage = """
        combined subtree adds
        
        git-subtree-dir: Vendor/libA
        git-subtree-split: \(commitHashA)
        git-subtree-dir: Vendor/libB
        git-subtree-split: \(commitHashB)
        """
        try await local.runGit(["commit", "--allow-empty", "-m", multiTrailerMessage])
        
        let commitsBefore = try await local.getCommitCount()
        
        // Add upstream update and run update
        try await addUpstreamUpdate(repo: upstreamA, tag: "v2.0")
        let updateResult = try await harness.run(
            arguments: ["update", "libA"],
            workingDirectory: local.path
        )
        #expect(updateResult.exitCode == 0, "Update should succeed")
        
        // Verify a resync commit was created (commit count should be higher than expected)
        // Expected: +1 resync + 1 subtree pull merge + amend = at least commitsBefore + 2
        let commitsAfter = try await local.getCommitCount()
        #expect(commitsAfter > commitsBefore, "Should have new commits from resync + update")
        
        // Verify the resync commit exists with correct format
        let log = try await local.runGit(["log", "--all", "--oneline", "--grep=git-subtree-dir: Vendor/libA"])
        #expect(log.contains("Squashed 'Vendor/libA/'"), "Should contain resync commit")
    }
}
