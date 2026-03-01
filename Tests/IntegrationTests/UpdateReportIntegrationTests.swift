import Testing
import Foundation
#if canImport(System)
import System
#else
import SystemPackage
#endif

@Suite("Update Report & JSON Integration Tests")
final class UpdateReportIntegrationTests {

    let harness = TestHarness()

    // MARK: - Helpers

    /// Create a local repository with multiple tagged commits to serve as a remote.
    private func createRemoteWithTags(tags: [String]) async throws -> GitRepositoryFixture {
        let remote = try await GitRepositoryFixture()

        for (index, tag) in tags.enumerated() {
            let filePath = remote.path.appending("file\(index).txt")
            try "content for \(tag)".write(toFile: filePath.string, atomically: true, encoding: .utf8)
            try await remote.runGit(["add", "."])
            try await remote.runGit(["commit", "-m", "Commit for \(tag)"])
            try await remote.runGit(["tag", tag])
        }

        return remote
    }

    /// Write a subtree.yaml config with a single entry.
    private func writeConfig(
        in repoPath: FilePath,
        name: String,
        remote: String,
        prefix: String,
        commit: String,
        tag: String? = nil,
        branch: String? = nil
    ) throws {
        var yaml = """
        # Subtree Configuration
        subtrees:
          - name: \(name)
            remote: \(remote)
            prefix: \(prefix)
            commit: \(commit)
        """
        if let tag = tag {
            yaml += "\n    tag: \(tag)"
        }
        if let branch = branch {
            yaml += "\n    branch: \(branch)"
        }
        yaml += "\n    squash: true\n"

        let configPath = repoPath.appending("subtree.yaml")
        try yaml.write(toFile: configPath.string, atomically: true, encoding: .utf8)
    }

    // MARK: - Report Mode Tag Detection (Bug Fix Tests)

    @Test("report mode detects newer tag on remote (tag-based subtree)")
    func testReportDetectsNewerTag() async throws {
        let remote = try await createRemoteWithTags(tags: ["v1.0.0", "v2.0.0"])
        defer { try? remote.tearDown() }

        let v1Commit = try await remote.runGit(["rev-parse", "v1.0.0"])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)

        try writeConfig(
            in: local.path,
            name: "mylib",
            remote: remote.path.string,
            prefix: "vendor/mylib",
            commit: v1Commit,
            tag: "v1.0.0"
        )
        try await local.runGit(["add", "subtree.yaml"])
        try await local.runGit(["commit", "-m", "Add subtree config"])

        let result = try await harness.run(
            arguments: ["update", "mylib", "--report"],
            workingDirectory: local.path
        )

        #expect(result.exitCode == 5, "Should exit 5 when updates available, got \(result.exitCode): \(result.stdout)")
        #expect(result.stdout.contains("v1.0.0") && result.stdout.contains("v2.0.0"),
                "Should show tag transition: \(result.stdout)")
    }

    @Test("report mode shows up-to-date for latest tag (tag-based subtree)")
    func testReportUpToDateForLatestTag() async throws {
        let remote = try await createRemoteWithTags(tags: ["v1.0.0", "v2.0.0"])
        defer { try? remote.tearDown() }

        let v2Commit = try await remote.runGit(["rev-parse", "v2.0.0"])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)

        try writeConfig(
            in: local.path,
            name: "mylib",
            remote: remote.path.string,
            prefix: "vendor/mylib",
            commit: v2Commit,
            tag: "v2.0.0"
        )
        try await local.runGit(["add", "subtree.yaml"])
        try await local.runGit(["commit", "-m", "Add subtree config"])

        let result = try await harness.run(
            arguments: ["update", "mylib", "--report"],
            workingDirectory: local.path
        )

        #expect(result.exitCode == 0, "Should exit 0 when up to date, got \(result.exitCode): \(result.stdout)")
        #expect(result.stdout.contains("up to date"), "Should indicate up to date: \(result.stdout)")
    }

    // MARK: - JSON Output Tests

    @Test("--json flag outputs valid JSON array with tag-based entry")
    func testJsonOutputIsValidJSON() async throws {
        let remote = try await createRemoteWithTags(tags: ["v1.0.0", "v2.0.0"])
        defer { try? remote.tearDown() }

        let v1Commit = try await remote.runGit(["rev-parse", "v1.0.0"])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)

        try writeConfig(
            in: local.path,
            name: "mylib",
            remote: remote.path.string,
            prefix: "vendor/mylib",
            commit: v1Commit,
            tag: "v1.0.0"
        )
        try await local.runGit(["add", "subtree.yaml"])
        try await local.runGit(["commit", "-m", "Add subtree config"])

        let result = try await harness.run(
            arguments: ["update", "mylib", "--json"],
            workingDirectory: local.path
        )

        let jsonData = Data(result.stdout.utf8)
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

        #expect(parsed.count == 1, "Should have one entry")
        #expect(parsed[0]["name"] as? String == "mylib")
        #expect(parsed[0]["status"] as? String == "behind")
        #expect(parsed[0]["current_tag"] as? String == "v1.0.0")
        #expect(parsed[0]["latest_tag"] as? String == "v2.0.0")
        #expect(parsed[0]["remote"] as? String == remote.path.string)
    }

    @Test("--json suppresses human-readable emoji output")
    func testJsonSuppressesEmojiOutput() async throws {
        let remote = try await createRemoteWithTags(tags: ["v1.0.0"])
        defer { try? remote.tearDown() }

        let v1Commit = try await remote.runGit(["rev-parse", "v1.0.0"])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)

        try writeConfig(
            in: local.path,
            name: "mylib",
            remote: remote.path.string,
            prefix: "vendor/mylib",
            commit: v1Commit,
            tag: "v1.0.0"
        )
        try await local.runGit(["add", "subtree.yaml"])
        try await local.runGit(["commit", "-m", "Add subtree config"])

        let result = try await harness.run(
            arguments: ["update", "mylib", "--json"],
            workingDirectory: local.path
        )

        // Should NOT contain emoji markers
        #expect(!result.stdout.contains("📦"))
        #expect(!result.stdout.contains("✅"))
        #expect(!result.stdout.contains("⚠️"))
        // Should be parseable JSON
        #expect(result.stdout.contains("["))
        #expect(result.stdout.contains("]"))
    }

    @Test("--json includes error entries for unreachable remotes")
    func testJsonIncludesErrorEntries() async throws {
        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)

        try writeConfig(
            in: local.path,
            name: "badlib",
            remote: "/nonexistent/path/to/repo.git",
            prefix: "vendor/badlib",
            commit: "0000000000000000000000000000000000000000",
            tag: "v1.0.0"
        )
        try await local.runGit(["add", "subtree.yaml"])
        try await local.runGit(["commit", "-m", "Add subtree config"])

        let result = try await harness.run(
            arguments: ["update", "badlib", "--json"],
            workingDirectory: local.path
        )

        let jsonData = Data(result.stdout.utf8)
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

        #expect(parsed.count == 1)
        #expect(parsed[0]["status"] as? String == "error")
        #expect(parsed[0]["error"] != nil, "Should include error message")
    }

    @Test("--json with --all reports multiple entries")
    func testJsonWithAllReportsMultipleEntries() async throws {
        let remote1 = try await createRemoteWithTags(tags: ["v1.0.0", "v2.0.0"])
        defer { try? remote1.tearDown() }
        let remote2 = try await createRemoteWithTags(tags: ["v3.0.0"])
        defer { try? remote2.tearDown() }

        let v1Commit = try await remote1.runGit(["rev-parse", "v1.0.0"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let v3Commit = try await remote2.runGit(["rev-parse", "v3.0.0"])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)

        let yaml = """
        # Subtree Configuration
        subtrees:
          - name: lib-a
            remote: \(remote1.path.string)
            prefix: vendor/lib-a
            commit: \(v1Commit)
            tag: v1.0.0
            squash: true
          - name: lib-b
            remote: \(remote2.path.string)
            prefix: vendor/lib-b
            commit: \(v3Commit)
            tag: v3.0.0
            squash: true
        """
        let configPath = local.path.appending("subtree.yaml")
        try yaml.write(toFile: configPath.string, atomically: true, encoding: .utf8)
        try await local.runGit(["add", "subtree.yaml"])
        try await local.runGit(["commit", "-m", "Add subtree config"])

        let result = try await harness.run(
            arguments: ["update", "--all", "--json"],
            workingDirectory: local.path
        )

        let jsonData = Data(result.stdout.utf8)
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

        #expect(parsed.count == 2, "Should have two entries")
        let names = parsed.compactMap { $0["name"] as? String }
        #expect(names.contains("lib-a"))
        #expect(names.contains("lib-b"))

        // lib-a should be "behind" (v1.0.0 vs v2.0.0)
        let libA = parsed.first { ($0["name"] as? String) == "lib-a" }
        #expect(libA?["status"] as? String == "behind")

        // lib-b should be "up_to_date" (v3.0.0 is latest)
        let libB = parsed.first { ($0["name"] as? String) == "lib-b" }
        #expect(libB?["status"] as? String == "up_to_date")
    }

    @Test("--json implies --report (no repository modification)")
    func testJsonImpliesReport() async throws {
        let remote = try await createRemoteWithTags(tags: ["v1.0.0", "v2.0.0"])
        defer { try? remote.tearDown() }

        let v1Commit = try await remote.runGit(["rev-parse", "v1.0.0"])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)

        try writeConfig(
            in: local.path,
            name: "mylib",
            remote: remote.path.string,
            prefix: "vendor/mylib",
            commit: v1Commit,
            tag: "v1.0.0"
        )
        try await local.runGit(["add", "subtree.yaml"])
        try await local.runGit(["commit", "-m", "Add subtree config"])

        let commitsBefore = try await local.getCommitCount()

        // Use --json WITHOUT --report -- should still enter report mode
        let result = try await harness.run(
            arguments: ["update", "mylib", "--json"],
            workingDirectory: local.path
        )

        let commitsAfter = try await local.getCommitCount()
        #expect(commitsBefore == commitsAfter, "JSON mode should not create commits")

        // Should produce JSON output
        #expect(result.stdout.contains("["))
    }

    @Test("branch-based report shows commit hashes in JSON")
    func testBranchBasedReportJSON() async throws {
        // Create remote with commits on a branch (no tags)
        let remote = try await GitRepositoryFixture()
        defer { try? remote.tearDown() }

        // Remote already has initial commit; get its hash
        let initialCommit = try await remote.runGit(["rev-parse", "HEAD"])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Add another commit to make the "local" stale
        let filePath = remote.path.appending("new_file.txt")
        try "new content".write(toFile: filePath.string, atomically: true, encoding: .utf8)
        try await remote.runGit(["add", "."])
        try await remote.runGit(["commit", "-m", "Second commit"])

        // Determine the default branch name used by git init
        let branchName = try await remote.runGit(["rev-parse", "--abbrev-ref", "HEAD"])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let local = try await GitRepositoryFixture()
        defer { try? local.tearDown() }
        _ = try await harness.run(arguments: ["init"], workingDirectory: local.path)

        try writeConfig(
            in: local.path,
            name: "branchlib",
            remote: remote.path.string,
            prefix: "vendor/branchlib",
            commit: initialCommit,
            branch: branchName
        )
        try await local.runGit(["add", "subtree.yaml"])
        try await local.runGit(["commit", "-m", "Add subtree config"])

        let result = try await harness.run(
            arguments: ["update", "branchlib", "--json"],
            workingDirectory: local.path
        )

        let jsonData = Data(result.stdout.utf8)
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

        #expect(parsed.count == 1)
        #expect(parsed[0]["status"] as? String == "behind")
        #expect(parsed[0]["branch"] as? String == branchName)
        #expect(parsed[0]["current_commit"] != nil, "Should include current_commit for branch-based")
        // Tag fields should be absent or null for branch-based entries
        let currentTag = parsed[0]["current_tag"]
        #expect(currentTag == nil || currentTag is NSNull, "current_tag should be absent/null for branch-based")
        let latestTag = parsed[0]["latest_tag"]
        #expect(latestTag == nil || latestTag is NSNull, "latest_tag should be absent/null for branch-based")
    }
}
