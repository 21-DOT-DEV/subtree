import Testing
import Foundation
@testable import Subtree

struct RemoteURLParserTests {
    
    @Test("infer name from HTTPS URLs")
    func testInferNameFromHTTPSURLs() throws {
        let testCases = [
            ("https://github.com/user/repo.git", "repo"),
            ("https://github.com/user/awesome-lib.git", "awesome-lib"),
            ("https://github.com/org/my-project", "my-project"),
            ("https://gitlab.com/user/utils.git", "utils"),
            ("http://bitbucket.org/team/tool", "tool")
        ]
        
        for (url, expected) in testCases {
            let result = try RemoteURLParser.inferNameFromRemote(url)
            #expect(result == expected, "URL: \(url) should infer name: \(expected), got: \(result)")
        }
    }
    
    @Test("infer name from SSH URLs")
    func testInferNameFromSSHURLs() throws {
        let testCases = [
            ("git@github.com:user/repo.git", "repo"),
            ("git@gitlab.com:org/awesome-tool.git", "awesome-tool"),
            ("ssh://git@bitbucket.org/user/project.git", "project")
        ]
        
        for (url, expected) in testCases {
            let result = try RemoteURLParser.inferNameFromRemote(url)
            #expect(result == expected, "URL: \(url) should infer name: \(expected), got: \(result)")
        }
    }
    
    @Test("infer name handles complex repository names")
    func testInferNameHandlesComplexNames() throws {
        let testCases = [
            ("https://github.com/user/my-awesome-lib.git", "my-awesome-lib"),
            ("https://github.com/user/lib_with_underscores.git", "lib_with_underscores"),
            ("https://github.com/user/lib123.git", "lib123"),
            ("https://github.com/user/CamelCaseLib.git", "CamelCaseLib")
        ]
        
        for (url, expected) in testCases {
            let result = try RemoteURLParser.inferNameFromRemote(url)
            #expect(result == expected, "URL: \(url) should infer name: \(expected), got: \(result)")
        }
    }
    
    @Test("infer name fails for truly invalid URLs")
    func testInferNameFailsForTrulyInvalidURLs() {
        let invalidURLs = [
            "", // Empty string
            "https://github.com/user/" // Ends with slash, no repo name
        ]
        
        for url in invalidURLs {
            #expect(throws: SubtreeError.self) {
                _ = try RemoteURLParser.inferNameFromRemote(url)
            }
        }
    }
    
    @Test("infer name removes .git suffix")
    func testInferNameRemovesGitSuffix() throws {
        let result = try RemoteURLParser.inferNameFromRemote("https://github.com/user/repo.git")
        #expect(result == "repo")
        
        // Should also work without .git suffix
        let result2 = try RemoteURLParser.inferNameFromRemote("https://github.com/user/repo")
        #expect(result2 == "repo")
    }
    
    @Test("infer prefix from name")
    func testInferPrefixFromName() {
        let testCases = [
            ("repo", "Vendor/repo"),
            ("awesome-lib", "Vendor/awesome-lib"),
            ("my_tool", "Vendor/my_tool"),
            ("lib123", "Vendor/lib123")
        ]
        
        for (name, expectedPrefix) in testCases {
            let result = RemoteURLParser.inferPrefixFromName(name)
            #expect(result == expectedPrefix, "Name: \(name) should infer prefix: \(expectedPrefix), got: \(result)")
        }
    }
    
    @Test("infer name validates character set")
    func testInferNameValidatesCharacterSet() {
        // Valid characters should work
        let validNames = [
            "https://github.com/user/valid-name.git",
            "https://github.com/user/valid_name.git",
            "https://github.com/user/valid123.git"
        ]
        
        for url in validNames {
            #expect(throws: Never.self) {
                _ = try RemoteURLParser.inferNameFromRemote(url)
            }
        }
        
        // Invalid characters should fail
        let invalidURLs = [
            "https://github.com/user/invalid name.git",
            "https://github.com/user/invalid@name.git",
            "https://github.com/user/invalid#name.git"
        ]
        
        for url in invalidURLs {
            #expect(throws: SubtreeError.self) {
                _ = try RemoteURLParser.inferNameFromRemote(url)
            }
        }
    }
    
    @Test("infer name handles edge cases")
    func testInferNameHandlesEdgeCases() throws {
        // Single character names
        let result1 = try RemoteURLParser.inferNameFromRemote("https://github.com/user/a.git")
        #expect(result1 == "a")
        
        // Names with only numbers
        let result2 = try RemoteURLParser.inferNameFromRemote("https://github.com/user/123.git")
        #expect(result2 == "123")
        
        // Names with mixed case
        let result3 = try RemoteURLParser.inferNameFromRemote("https://github.com/user/MyAwesomeLib.git")
        #expect(result3 == "MyAwesomeLib")
    }
    
    @Test("infer name works with different hosts")
    func testInferNameWorksWithDifferentHosts() throws {
        let testCases = [
            ("https://gitlab.com/user/project.git", "project"),
            ("https://bitbucket.org/user/tool.git", "tool"),
            ("https://codeberg.org/user/app.git", "app"),
            ("https://git.example.com/user/lib.git", "lib")
        ]
        
        for (url, expected) in testCases {
            let result = try RemoteURLParser.inferNameFromRemote(url)
            #expect(result == expected, "URL: \(url) should infer name: \(expected), got: \(result)")
        }
    }
}
