import Testing
@testable import SubtreeLib

/// Tests for URLParser utility
@Suite("URLParser Tests")
struct URLParserTests {
    
    // T009 - Test https URL parsing
    @Test("Parse https URL (https://github.com/user/repo.git → 'repo')")
    func testHttpsURLParsing() throws {
        let url = "https://github.com/user/repo.git"
        let name = try URLParser.extractName(from: url)
        #expect(name == "repo")
    }
    
    // T010 - Test git@ URL parsing
    @Test("Parse git@ URL (git@github.com:user/repo.git → 'repo')")
    func testGitURLParsing() throws {
        let url = "git@github.com:user/repo.git"
        let name = try URLParser.extractName(from: url)
        #expect(name == "repo")
    }
    
    // T011 - Test .git extension removal
    @Test("Remove .git extension")
    func testGitExtensionRemoval() throws {
        let urlWithGit = "https://github.com/user/myproject.git"
        let urlWithoutGit = "https://github.com/user/myproject"
        
        let name1 = try URLParser.extractName(from: urlWithGit)
        let name2 = try URLParser.extractName(from: urlWithoutGit)
        
        #expect(name1 == "myproject")
        #expect(name2 == "myproject")
    }
    
    // T012 - Test invalid URL throws error
    @Test("Invalid URL throws error")
    func testInvalidURLThrowsError() {
        #expect(throws: URLParseError.self) {
            _ = try URLParser.extractName(from: "invalid-url")
        }
        
        #expect(throws: URLParseError.self) {
            _ = try URLParser.extractName(from: "")
        }
    }
    
    // T013 - Test file:// URL parsing
    @Test("Parse file:// URL")
    func testFileURLParsing() throws {
        let url = "file:///local/path/myrepo.git"
        let name = try URLParser.extractName(from: url)
        #expect(name == "myrepo")
    }
    
    // MARK: - compareURL Tests
    
    @Test("compareURL with GitHub HTTPS URL")
    func testCompareURLGitHubHTTPS() {
        let url = URLParser.compareURL(
            remote: "https://github.com/bitcoin-core/secp256k1",
            oldRef: "v0.3.1",
            newRef: "v0.4.0"
        )
        #expect(url == "https://github.com/bitcoin-core/secp256k1/compare/v0.3.1...v0.4.0")
    }
    
    @Test("compareURL with GitHub HTTPS URL with .git suffix")
    func testCompareURLGitHubHTTPSWithGitSuffix() {
        let url = URLParser.compareURL(
            remote: "https://github.com/apple/swift-crypto.git",
            oldRef: "3.10.0",
            newRef: "4.0.0"
        )
        #expect(url == "https://github.com/apple/swift-crypto/compare/3.10.0...4.0.0")
    }
    
    @Test("compareURL with GitHub SSH URL")
    func testCompareURLGitHubSSH() {
        let url = URLParser.compareURL(
            remote: "git@github.com:user/repo.git",
            oldRef: "v1.0.0",
            newRef: "v2.0.0"
        )
        #expect(url == "https://github.com/user/repo/compare/v1.0.0...v2.0.0")
    }
    
    @Test("compareURL returns nil for non-GitHub URLs")
    func testCompareURLNonGitHub() {
        // GitLab
        #expect(URLParser.compareURL(
            remote: "https://gitlab.com/user/repo.git",
            oldRef: "v1.0.0",
            newRef: "v2.0.0"
        ) == nil)
        
        // Bitbucket
        #expect(URLParser.compareURL(
            remote: "https://bitbucket.org/user/repo.git",
            oldRef: "v1.0.0",
            newRef: "v2.0.0"
        ) == nil)
        
        // file://
        #expect(URLParser.compareURL(
            remote: "file:///local/path/repo.git",
            oldRef: "v1.0.0",
            newRef: "v2.0.0"
        ) == nil)
    }
    
    @Test("compareURL with full commit hashes for branch-based entries")
    func testCompareURLWithCommitHashes() {
        let url = URLParser.compareURL(
            remote: "https://github.com/user/repo",
            oldRef: "abc123def456abc123def456abc123def456abc1",
            newRef: "def456abc123def456abc123def456abc123def4"
        )
        #expect(url == "https://github.com/user/repo/compare/abc123def456abc123def456abc123def456abc1...def456abc123def456abc123def456abc123def4")
    }
    
    // T014 - Verify parsing works for standard formats
    @Test("Parse standard formats (GitHub, GitLab, Bitbucket)")
    func testStandardFormats() throws {
        // GitHub https
        let gh1 = try URLParser.extractName(from: "https://github.com/21-DOT-DEV/subtree.git")
        #expect(gh1 == "subtree")
        
        // GitHub git@
        let gh2 = try URLParser.extractName(from: "git@github.com:21-DOT-DEV/subtree.git")
        #expect(gh2 == "subtree")
        
        // GitLab https
        let gl1 = try URLParser.extractName(from: "https://gitlab.com/user/project.git")
        #expect(gl1 == "project")
        
        // GitLab git@
        let gl2 = try URLParser.extractName(from: "git@gitlab.com:user/project.git")
        #expect(gl2 == "project")
        
        // Bitbucket https
        let bb1 = try URLParser.extractName(from: "https://bitbucket.org/user/repo.git")
        #expect(bb1 == "repo")
        
        // Bitbucket git@
        let bb2 = try URLParser.extractName(from: "git@bitbucket.org:user/repo.git")
        #expect(bb2 == "repo")
    }
}
