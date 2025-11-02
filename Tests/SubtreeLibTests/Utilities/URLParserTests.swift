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
