import Foundation
import Testing
import Subprocess
import Yams
#if canImport(System)
import System
#else
import SystemPackage
#endif

/// Integration tests for the gitlink-stripping feature (Policy C: detect-and-warn by default,
/// strip on opt-in via `--strip-gitlinks` or `stripGitlinks: true` in subtree.yaml).
///
/// These tests construct a local "upstream" repository whose tree contains an unmapped
/// submodule gitlink (mode 160000) — mimicking the real-world swift-openssl/SPI scenario
/// where upstream's `.gitmodules`-bound submodules are dropped on extraction but the
/// gitlink entries remain in the tree.
@Suite("Strip Gitlinks Integration Tests")
struct StripGitlinksIntegrationTests {
    
    // MARK: - Helpers
    
    /// Run a git command in a directory and return stdout. Throws on non-zero exit.
    @discardableResult
    private func runGit(_ arguments: [String], in dir: FilePath) async throws -> String {
        let result = try await Subprocess.run(
            .name("git"),
            arguments: .init(arguments),
            workingDirectory: dir,
            output: .string(limit: 16384),
            error: .string(limit: 16384)
        )
        guard case .exited(0) = result.terminationStatus else {
            let stderr = result.standardError ?? ""
            throw TestError.gitCommandFailed(arguments.joined(separator: " "), stderr)
        }
        return result.standardOutput ?? ""
    }
    
    /// Create a local upstream repo containing one regular file plus a fake submodule
    /// gitlink (mode 160000) at `lib/sub`. Returns the absolute path.
    ///
    /// The gitlink is injected via `git update-index --add --cacheinfo` with a dummy SHA;
    /// no real submodule is required. This reproduces the exact tree shape that
    /// real upstreams (e.g., OpenSSL, with `cloudflare-quiche`, `krb5`, etc.) produce.
    private func createUpstreamWithGitlink() async throws -> FilePath {
        let upstream = FilePath("/tmp/subtree-strip-gitlinks-upstream-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: upstream.string, withIntermediateDirectories: true)
        
        try await runGit(["init", "-b", "main"], in: upstream)
        try await runGit(["config", "user.name", "Test User"], in: upstream)
        try await runGit(["config", "user.email", "test@example.com"], in: upstream)
        try await runGit(["config", "commit.gpgsign", "false"], in: upstream)
        
        // Add a real file so the tree is not empty
        let helloPath = upstream.appending("hello.txt")
        try "upstream content\n".write(toFile: helloPath.string, atomically: true, encoding: .utf8)
        try await runGit(["add", "hello.txt"], in: upstream)
        
        // Inject a fake gitlink. The dummy SHA is never resolved — git only validates format.
        let dummyCommitSha = "0000000000000000000000000000000000000001"
        try await runGit(
            ["update-index", "--add", "--cacheinfo", "160000,\(dummyCommitSha),lib/sub"],
            in: upstream
        )
        
        try await runGit(["commit", "-m", "Initial upstream tree with submodule gitlink"], in: upstream)
        
        return upstream
    }
    
    /// Get the file mode (e.g., "100644", "160000") for a path in the index, or nil if absent.
    private func indexMode(of path: String, in dir: FilePath) async throws -> String? {
        let output = try await runGit(["ls-files", "-s", "--", path], in: dir)
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Format: "<mode> <hash> <stage>\t<path>"
        let firstField = trimmed.split(separator: " ", maxSplits: 1).first.map(String.init)
        return firstField
    }
    
    // MARK: - Tests
    
    /// Policy C default: when `--strip-gitlinks` is NOT passed and the entry has no
    /// `stripGitlinks: true`, the CLI must emit a warning AND leave the gitlink in the index.
    /// The user retains full control; no silent data loss.
    @Test("Without --strip-gitlinks: gitlink remains in index and warning is emitted")
    func warnsButDoesNotStripByDefault() async throws {
        let upstream = try await createUpstreamWithGitlink()
        defer { try? FileManager.default.removeItem(atPath: upstream.string) }
        
        let consumer = try await GitRepositoryFixture()
        defer { try? consumer.tearDown() }
        
        let harness = TestHarness()
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: consumer.path)
        #expect(initResult.exitCode == 0)
        
        let addResult = try await harness.run(
            arguments: ["add", "--remote", "file://\(upstream.string)", "--name", "fake", "--ref", "main"],
            workingDirectory: consumer.path
        )
        #expect(addResult.exitCode == 0)
        
        // Warning must mention the gitlink and tell the user how to opt in.
        #expect(addResult.stdout.contains("upstream submodule gitlink"))
        #expect(addResult.stdout.contains("--strip-gitlinks"))
        
        // Gitlink must still be present in the consumer's index — Policy C is non-destructive.
        let mode = try await indexMode(of: "fake/lib/sub", in: consumer.path)
        #expect(mode == "160000", "Expected gitlink to remain in index without opt-in; got mode=\(mode ?? "nil")")
        
        // subtree.yaml must NOT have stripGitlinks set (no implicit opt-in).
        let configPath = consumer.path.appending("subtree.yaml")
        let configContent = try String(contentsOfFile: configPath.string, encoding: .utf8)
        #expect(!configContent.contains("stripGitlinks"))
    }
    
    /// With `--strip-gitlinks` on `add`: the gitlink is removed from the index, the
    /// removal is folded into the atomic add commit, and `stripGitlinks: true` is
    /// persisted to subtree.yaml so subsequent updates auto-strip.
    @Test("With --strip-gitlinks: gitlink removed and config persisted")
    func stripsAndPersistsWhenOptedIn() async throws {
        let upstream = try await createUpstreamWithGitlink()
        defer { try? FileManager.default.removeItem(atPath: upstream.string) }
        
        let consumer = try await GitRepositoryFixture()
        defer { try? consumer.tearDown() }
        
        let harness = TestHarness()
        let initResult = try await harness.run(arguments: ["init"], workingDirectory: consumer.path)
        #expect(initResult.exitCode == 0)
        
        let addResult = try await harness.run(
            arguments: [
                "add",
                "--remote", "file://\(upstream.string)",
                "--name", "fake",
                "--ref", "main",
                "--strip-gitlinks"
            ],
            workingDirectory: consumer.path
        )
        #expect(addResult.exitCode == 0, "add failed: \(addResult.stderr)")
        
        // Stripped indicator must be in stdout.
        #expect(addResult.stdout.contains("Stripped 1 upstream submodule gitlink"))
        
        // Gitlink must be ABSENT from the consumer's index.
        let mode = try await indexMode(of: "fake/lib/sub", in: consumer.path)
        #expect(mode == nil, "Expected gitlink stripped; still present with mode=\(mode ?? "nil")")
        
        // Removal must be part of the atomic add commit (no separate "strip gitlinks" commit).
        // The HEAD commit (the amended merge commit) must show subtree.yaml as added,
        // and its tree must not contain fake/lib/sub. If a separate strip commit had been
        // created, HEAD's name-status would show only the deletion of fake/lib/sub, not
        // the subtree.yaml addition.
        let headStatus = try await runGit(["show", "--name-status", "--format=", "HEAD"], in: consumer.path)
        #expect(headStatus.contains("subtree.yaml"),
                "Expected HEAD commit to include subtree.yaml; got:\n\(headStatus)")
        let headTree = try await runGit(["ls-tree", "-r", "HEAD"], in: consumer.path)
        #expect(!headTree.contains("fake/lib/sub"),
                "Expected gitlink absent from HEAD tree; got:\n\(headTree)")
        
        // subtree.yaml must persist `stripGitlinks: true` so future `update` runs auto-strip.
        let configPath = consumer.path.appending("subtree.yaml")
        let configContent = try String(contentsOfFile: configPath.string, encoding: .utf8)
        #expect(configContent.contains("stripGitlinks: true"),
                "Expected stripGitlinks: true in subtree.yaml; got:\n\(configContent)")
    }
}
