import Testing
@testable import SubtreeLib

@Suite("PathValidator Tests")
struct PathValidatorTests {
    
    // MARK: - Valid Paths
    
    @Test("Validates simple relative path")
    func testSimpleRelativePath() throws {
        try PathValidator.validate("vendor/lib")
        // No error thrown = success
    }
    
    @Test("Validates nested relative path")
    func testNestedRelativePath() throws {
        try PathValidator.validate("vendor/third-party/lib")
        // No error thrown = success
    }
    
    @Test("Validates path with spaces")
    func testPathWithSpaces() throws {
        try PathValidator.validate("vendor/my lib")
        try PathValidator.validate("vendor/my awesome library")
        // No error thrown = success
    }
    
    @Test("Validates path with hyphens and underscores")
    func testPathWithSpecialChars() throws {
        try PathValidator.validate("vendor-libs/my_lib")
        try PathValidator.validate("third-party/awesome-lib_v2")
        // No error thrown = success
    }
    
    @Test("Validates single directory name")
    func testSingleDirectory() throws {
        try PathValidator.validate("vendor")
        try PathValidator.validate("lib")
        // No error thrown = success
    }
    
    // MARK: - Absolute Path Rejection
    
    @Test("Rejects absolute path with leading slash")
    func testRejectsAbsolutePath() {
        #expect(throws: SubtreeValidationError.self) {
            try PathValidator.validate("/vendor/lib")
        }
    }
    
    @Test("Rejects root path")
    func testRejectsRootPath() {
        #expect(throws: SubtreeValidationError.self) {
            try PathValidator.validate("/")
        }
    }
    
    @Test("Rejects absolute Unix path")
    func testRejectsAbsoluteUnixPath() {
        #expect(throws: SubtreeValidationError.self) {
            try PathValidator.validate("/usr/local/lib")
        }
    }
    
    @Test("Absolute path error has correct type")
    func testAbsolutePathErrorType() {
        do {
            try PathValidator.validate("/absolute/path")
            Issue.record("Expected ValidationError to be thrown")
        } catch let error as SubtreeValidationError {
            if case .absolutePath = error {
                // Success - correct error type
            } else {
                Issue.record("Wrong ValidationError case: \(error)")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Parent Traversal Rejection
    
    @Test("Rejects parent traversal at start")
    func testRejectsParentTraversalAtStart() {
        #expect(throws: SubtreeValidationError.self) {
            try PathValidator.validate("../vendor/lib")
        }
    }
    
    @Test("Rejects parent traversal in middle")
    func testRejectsParentTraversalInMiddle() {
        #expect(throws: SubtreeValidationError.self) {
            try PathValidator.validate("vendor/../lib")
        }
    }
    
    @Test("Rejects parent traversal at end")
    func testRejectsParentTraversalAtEnd() {
        #expect(throws: SubtreeValidationError.self) {
            try PathValidator.validate("vendor/lib/..")
        }
    }
    
    @Test("Rejects multiple parent traversals")
    func testRejectsMultipleParentTraversals() {
        #expect(throws: SubtreeValidationError.self) {
            try PathValidator.validate("../../escape/path")
        }
    }
    
    @Test("Parent traversal error has correct type")
    func testParentTraversalErrorType() {
        do {
            try PathValidator.validate("../escape")
            Issue.record("Expected ValidationError to be thrown")
        } catch let error as SubtreeValidationError {
            if case .parentTraversal = error {
                // Success - correct error type
            } else {
                Issue.record("Wrong ValidationError case: \(error)")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Backslash Rejection
    
    @Test("Rejects single backslash")
    func testRejectsSingleBackslash() {
        #expect(throws: SubtreeValidationError.self) {
            try PathValidator.validate("vendor\\lib")
        }
    }
    
    @Test("Rejects multiple backslashes")
    func testRejectsMultipleBackslashes() {
        #expect(throws: SubtreeValidationError.self) {
            try PathValidator.validate("vendor\\third-party\\lib")
        }
    }
    
    @Test("Rejects mixed slashes")
    func testRejectsMixedSlashes() {
        #expect(throws: SubtreeValidationError.self) {
            try PathValidator.validate("vendor/lib\\subdir")
        }
    }
    
    @Test("Invalid separator error has correct type")
    func testInvalidSeparatorErrorType() {
        do {
            try PathValidator.validate("path\\with\\backslash")
            Issue.record("Expected ValidationError to be thrown")
        } catch let error as SubtreeValidationError {
            if case .invalidSeparator = error {
                // Success - correct error type
            } else {
                Issue.record("Wrong ValidationError case: \(error)")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Validates path with dots (not parent traversal)")
    func testPathWithDots() throws {
        try PathValidator.validate("vendor/lib.v2")
        try PathValidator.validate("vendor/my.awesome.lib")
        // No error thrown = success
    }
    
    @Test("Rejects path ending with slash and two dots")
    func testRejectsTrailingParentTraversal() {
        #expect(throws: SubtreeValidationError.self) {
            try PathValidator.validate("vendor/..")
        }
    }
    
    @Test("Validates empty directory names are handled by filesystem")
    func testEmptyPath() throws {
        // Empty path is technically valid (current directory)
        // Let filesystem handle validation of empty paths
        try PathValidator.validate("")
    }
}
