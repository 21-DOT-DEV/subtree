import Testing
import Foundation

struct GitValidationTests {
    
    @Test("git subtree command exists and works")
    func testGitSubtreeCommandExists() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        let result = try await SubprocessHelpers.run(
            .name("git"),
            arguments: ["subtree"],
            workingDirectory: fixture.repoRoot
        )
        
        // Git subtree without arguments shows usage and exits with 129
        #expect(result.exitStatus == 129)
        
        // Should contain subtree help text
        #expect(result.stdout.contains("usage: git subtree"))
    }
    
    @Test("git version compatibility check")
    func testGitVersionCompatibility() async throws {
        let result = try await SubprocessHelpers.run(
            .name("git"),
            arguments: ["--version"]
        )
        
        // Should exit successfully
        #expect(result.exitStatus == 0)
        
        // Should return version information
        #expect(result.stdout.contains("git version"))
        
        // Extract version and check if it's reasonably recent (2.0+)
        let versionLine = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(versionLine.starts(with: "git version"))
        
        // Basic version format validation
        let components = versionLine.components(separatedBy: " ")
        #expect(components.count >= 3)
        
        if components.count >= 3 {
            let versionString = components[2]
            let versionParts = versionString.components(separatedBy: ".")
            if let majorVersion = versionParts.first, let major = Int(majorVersion) {
                // Git 2.0+ should support subtree
                #expect(major >= 2, "Git version \(majorVersion) may not support subtree operations")
            }
        }
    }
    
    @Test("git command error reporting")
    func testGitCommandErrorReporting() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Test with an invalid git subtree command
        let result = try await SubprocessHelpers.run(
            .name("git"),
            arguments: ["subtree", "invalid-command"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should exit with non-zero code
        #expect(result.exitStatus != 0)
        
        // Should have error message
        #expect(!result.stderr.isEmpty || !result.stdout.isEmpty)
        
        // Error message should be informative
        let errorOutput = result.stderr.isEmpty ? result.stdout : result.stderr
        #expect(errorOutput.contains("usage") || errorOutput.contains("invalid") || errorOutput.contains("unknown"))
    }
    
    @Test("git subtree basic functionality in git repo")
    func testGitSubtreeBasicFunctionality() async throws {
        let fixture = try await RepoFixture.create()
        defer { try? fixture.cleanup() }
        
        // Test that git subtree works in a real git repo
        // This is a dry-run test - we're not actually adding a subtree
        let result = try await SubprocessHelpers.run(
            .name("git"),
            arguments: ["subtree"],
            workingDirectory: fixture.repoRoot
        )
        
        // Should show usage when no arguments provided
        #expect(result.exitStatus == 129)
        
        // Should contain add command in usage
        #expect(result.stdout.contains("add"))
    }
}
