import Testing
@testable import SubtreeLib

/// Tests for NameSanitizer utility
@Suite("NameSanitizer Tests")
struct NameSanitizerTests {
    
    // T015 - Test invalid char replacement
    @Test("Replace invalid characters (/, :, \\, *, ?, \", <, >, |)")
    func testInvalidCharReplacement() {
        #expect(NameSanitizer.sanitize("repo/name") == "repo-name")
        #expect(NameSanitizer.sanitize("repo:name") == "repo-name")
        #expect(NameSanitizer.sanitize("repo\\name") == "repo-name")
        #expect(NameSanitizer.sanitize("repo*name") == "repo-name")
        #expect(NameSanitizer.sanitize("repo?name") == "repo-name")
        #expect(NameSanitizer.sanitize("repo\"name") == "repo-name")
        #expect(NameSanitizer.sanitize("repo<name") == "repo-name")
        #expect(NameSanitizer.sanitize("repo>name") == "repo-name")
        #expect(NameSanitizer.sanitize("repo|name") == "repo-name")
    }
    
    // T016 - Test alphanumeric/hyphen/underscore preservation
    @Test("Preserve alphanumeric, hyphen, and underscore")
    func testValidCharPreservation() {
        #expect(NameSanitizer.sanitize("abc123") == "abc123")
        #expect(NameSanitizer.sanitize("ABC123") == "ABC123")
        #expect(NameSanitizer.sanitize("repo-name") == "repo-name")
        #expect(NameSanitizer.sanitize("repo_name") == "repo_name")
        #expect(NameSanitizer.sanitize("My-Repo_123") == "My-Repo_123")
    }
    
    // T017 - Test whitespace replacement
    @Test("Replace whitespace with hyphens")
    func testWhitespaceReplacement() {
        #expect(NameSanitizer.sanitize("repo name") == "repo-name")
        #expect(NameSanitizer.sanitize("repo\tname") == "repo-name")
        #expect(NameSanitizer.sanitize("repo\nname") == "repo-name")
        #expect(NameSanitizer.sanitize("repo  name") == "repo-name") // Multiple spaces -> single hyphen
    }
}
