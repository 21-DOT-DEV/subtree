import Testing
@testable import SubtreeLib

@Suite("SubtreeConfiguration Validation Tests")
struct SubtreeConfigurationValidationTests {
    
    // MARK: - findSubtree() Tests
    
    @Test("Finds subtree by exact name match")
    func testFindsExactMatch() throws {
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "Hello-World", remote: "https://example.com", prefix: "vendor/lib", commit: "abc123")
        ])
        
        let found = try config.findSubtree(name: "Hello-World")
        #expect(found != nil)
        #expect(found?.name == "Hello-World")
    }
    
    @Test("Finds subtree by case-insensitive match")
    func testFindsCaseInsensitiveMatch() throws {
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "Hello-World", remote: "https://example.com", prefix: "vendor/lib", commit: "abc123")
        ])
        
        let found1 = try config.findSubtree(name: "hello-world")
        #expect(found1 != nil)
        #expect(found1?.name == "Hello-World")  // Original case preserved
        
        let found2 = try config.findSubtree(name: "HELLO-WORLD")
        #expect(found2 != nil)
        #expect(found2?.name == "Hello-World")
    }
    
    @Test("Returns nil when subtree not found")
    func testReturnsNilWhenNotFound() throws {
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "exists", remote: "https://example.com", prefix: "vendor/lib", commit: "abc123")
        ])
        
        let found = try config.findSubtree(name: "nonexistent")
        #expect(found == nil)
    }
    
    @Test("Throws when multiple case-variant matches found")
    func testThrowsOnMultipleMatches() {
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "Hello-World", remote: "https://example.com", prefix: "vendor/a", commit: "abc123"),
            SubtreeEntry(name: "hello-world", remote: "https://example.com", prefix: "vendor/b", commit: "def456")
        ])
        
        #expect(throws: SubtreeValidationError.self) {
            _ = try config.findSubtree(name: "hello-world")
        }
    }
    
    @Test("Multiple matches error contains all found names")
    func testMultipleMatchesErrorDetails() {
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "Lib", remote: "https://example.com", prefix: "vendor/a", commit: "abc123"),
            SubtreeEntry(name: "lib", remote: "https://example.com", prefix: "vendor/b", commit: "def456"),
            SubtreeEntry(name: "LIB", remote: "https://example.com", prefix: "vendor/c", commit: "ghi789")
        ])
        
        do {
            _ = try config.findSubtree(name: "lib")
            Issue.record("Expected ValidationError to be thrown")
        } catch let error as SubtreeValidationError {
            if case .multipleMatches(let searchName, let found) = error {
                #expect(searchName == "lib")
                #expect(found.count == 3)
                #expect(found.contains("Lib"))
                #expect(found.contains("lib"))
                #expect(found.contains("LIB"))
            } else {
                Issue.record("Wrong ValidationError case: \(error)")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }
    
    // MARK: - validate() Tests
    
    @Test("Validates empty config")
    func testValidatesEmptyConfig() throws {
        let config = SubtreeConfiguration(subtrees: [])
        try config.validate()
        // No error thrown = success
    }
    
    @Test("Validates config with one subtree")
    func testValidatesSingleSubtree() throws {
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "lib", remote: "https://example.com", prefix: "vendor/lib", commit: "abc123")
        ])
        try config.validate()
        // No error thrown = success
    }
    
    @Test("Validates config with multiple unique subtrees")
    func testValidatesMultipleUniqueSubtrees() throws {
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "lib-a", remote: "https://example.com", prefix: "vendor/a", commit: "abc123"),
            SubtreeEntry(name: "lib-b", remote: "https://example.com", prefix: "vendor/b", commit: "def456"),
            SubtreeEntry(name: "lib-c", remote: "https://example.com", prefix: "vendor/c", commit: "ghi789")
        ])
        try config.validate()
        // No error thrown = success
    }
    
    @Test("Throws on duplicate names (case-insensitive)")
    func testThrowsOnDuplicateNames() {
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "Hello-World", remote: "https://example.com", prefix: "vendor/a", commit: "abc123"),
            SubtreeEntry(name: "hello-world", remote: "https://example.com", prefix: "vendor/b", commit: "def456")
        ])
        
        #expect(throws: SubtreeValidationError.self) {
            try config.validate()
        }
    }
    
    @Test("Throws on duplicate prefixes (case-insensitive)")
    func testThrowsOnDuplicatePrefixes() {
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "lib-a", remote: "https://example.com", prefix: "vendor/lib", commit: "abc123"),
            SubtreeEntry(name: "lib-b", remote: "https://example.com", prefix: "vendor/Lib", commit: "def456")
        ])
        
        #expect(throws: SubtreeValidationError.self) {
            try config.validate()
        }
    }
    
    @Test("Duplicate name error has correct type")
    func testDuplicateNameErrorType() {
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "Test", remote: "https://example.com", prefix: "vendor/a", commit: "abc123"),
            SubtreeEntry(name: "test", remote: "https://example.com", prefix: "vendor/b", commit: "def456")
        ])
        
        do {
            try config.validate()
            Issue.record("Expected ValidationError to be thrown")
        } catch let error as SubtreeValidationError {
            if case .duplicateName = error {
                // Success - correct error type
            } else {
                Issue.record("Wrong ValidationError case: \(error)")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }
    
    @Test("Duplicate prefix error has correct type")
    func testDuplicatePrefixErrorType() {
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "lib-a", remote: "https://example.com", prefix: "deps/ui", commit: "abc123"),
            SubtreeEntry(name: "lib-b", remote: "https://example.com", prefix: "DEPS/UI", commit: "def456")
        ])
        
        do {
            try config.validate()
            Issue.record("Expected ValidationError to be thrown")
        } catch let error as SubtreeValidationError {
            if case .duplicatePrefix = error {
                // Success - correct error type
            } else {
                Issue.record("Wrong ValidationError case: \(error)")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Validates names with different cases but different prefixes")
    func testDifferentCaseDifferentPrefixes() throws {
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "Lib", remote: "https://example.com", prefix: "vendor/a", commit: "abc123"),
            SubtreeEntry(name: "lib", remote: "https://example.com", prefix: "vendor/b", commit: "def456")
        ])
        
        // This should fail validation (duplicate names)
        #expect(throws: SubtreeValidationError.self) {
            try config.validate()
        }
    }
    
    @Test("Validates same names with different cases as duplicates")
    func testSameNamesDifferentCasesAreDuplicates() {
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "MyLib", remote: "https://example.com", prefix: "vendor/a", commit: "abc123"),
            SubtreeEntry(name: "mylib", remote: "https://example.com", prefix: "vendor/b", commit: "def456"),
            SubtreeEntry(name: "MYLIB", remote: "https://example.com", prefix: "vendor/c", commit: "ghi789")
        ])
        
        #expect(throws: SubtreeValidationError.self) {
            try config.validate()
        }
    }
    
    @Test("Validates names with special characters")
    func testNamesWithSpecialCharacters() throws {
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "lib-v2.0", remote: "https://example.com", prefix: "vendor/a", commit: "abc123"),
            SubtreeEntry(name: "my_lib", remote: "https://example.com", prefix: "vendor/b", commit: "def456"),
            SubtreeEntry(name: "test.lib", remote: "https://example.com", prefix: "vendor/c", commit: "ghi789")
        ])
        
        try config.validate()
        // No error thrown = success
    }
    
    @Test("Validates prefixes with spaces")
    func testPrefixesWithSpaces() throws {
        let config = SubtreeConfiguration(subtrees: [
            SubtreeEntry(name: "lib-a", remote: "https://example.com", prefix: "vendor/my lib", commit: "abc123"),
            SubtreeEntry(name: "lib-b", remote: "https://example.com", prefix: "vendor/another lib", commit: "def456")
        ])
        
        try config.validate()
        // No error thrown = success (spaces are allowed)
    }
}
