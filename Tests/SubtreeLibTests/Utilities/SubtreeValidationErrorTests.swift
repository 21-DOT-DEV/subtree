import Testing
@testable import SubtreeLib

@Suite("SubtreeValidationError Tests")
struct SubtreeValidationErrorTests {
    
    // MARK: - Duplicate Name Error
    
    @Test("Duplicate name error has correct message")
    func testDuplicateNameErrorMessage() {
        let error = SubtreeValidationError.duplicateName(attempted: "hello-world", existing: "Hello-World")
        let description = error.errorDescription
        
        #expect(description != nil)
        #expect(description!.contains("conflicts with existing"))
        #expect(description!.contains("'hello-world'"))
        #expect(description!.contains("'Hello-World'"))
        #expect(description!.contains("case-insensitively"))
    }
    
    @Test("Duplicate name error has user error exit code")
    func testDuplicateNameExitCode() {
        let error = SubtreeValidationError.duplicateName(attempted: "test", existing: "Test")
        #expect(error.exitCode == 1)
    }
    
    @Test("Duplicate name error includes fix guidance")
    func testDuplicateNameGuidance() {
        let error = SubtreeValidationError.duplicateName(attempted: "lib", existing: "Lib")
        let description = error.errorDescription!
        
        #expect(description.contains("To fix:"))
        #expect(description.contains("--name"))
    }
    
    // MARK: - Duplicate Prefix Error
    
    @Test("Duplicate prefix error has correct message")
    func testDuplicatePrefixErrorMessage() {
        let error = SubtreeValidationError.duplicatePrefix(attempted: "vendor/Lib", existing: "vendor/lib")
        let description = error.errorDescription
        
        #expect(description != nil)
        #expect(description!.contains("conflicts with existing"))
        #expect(description!.contains("'vendor/Lib'"))
        #expect(description!.contains("'vendor/lib'"))
        #expect(description!.contains("case-insensitively"))
    }
    
    @Test("Duplicate prefix error has user error exit code")
    func testDuplicatePrefixExitCode() {
        let error = SubtreeValidationError.duplicatePrefix(attempted: "test/path", existing: "Test/Path")
        #expect(error.exitCode == 1)
    }
    
    @Test("Duplicate prefix error includes fix guidance")
    func testDuplicatePrefixGuidance() {
        let error = SubtreeValidationError.duplicatePrefix(attempted: "deps/ui", existing: "DEPS/UI")
        let description = error.errorDescription!
        
        #expect(description.contains("To fix:"))
        #expect(description.contains("--prefix"))
    }
    
    // MARK: - Multiple Matches Error
    
    @Test("Multiple matches error has correct message")
    func testMultipleMatchesErrorMessage() {
        let error = SubtreeValidationError.multipleMatches(name: "hello-world", found: ["Hello-World", "hello-world"])
        let description = error.errorDescription
        
        #expect(description != nil)
        #expect(description!.contains("Multiple subtrees match"))
        #expect(description!.contains("'hello-world'"))
        #expect(description!.contains("'Hello-World'"))
        #expect(description!.contains("manual config corruption"))
    }
    
    @Test("Multiple matches error has corruption exit code")
    func testMultipleMatchesExitCode() {
        let error = SubtreeValidationError.multipleMatches(name: "test", found: ["Test", "test"])
        #expect(error.exitCode == 2)
    }
    
    @Test("Multiple matches error references lint command")
    func testMultipleMatchesReferencesLint() {
        let error = SubtreeValidationError.multipleMatches(name: "lib", found: ["Lib", "lib", "LIB"])
        let description = error.errorDescription!
        
        #expect(description.contains("subtree lint"))
        #expect(description.contains("To fix:"))
    }
    
    // MARK: - Absolute Path Error
    
    @Test("Absolute path error has correct message")
    func testAbsolutePathErrorMessage() {
        let error = SubtreeValidationError.absolutePath("/vendor/lib")
        let description = error.errorDescription
        
        #expect(description != nil)
        #expect(description!.contains("must be a relative path"))
        #expect(description!.contains("'/vendor/lib'"))
        #expect(description!.contains("starting with '/'"))
    }
    
    @Test("Absolute path error has user error exit code")
    func testAbsolutePathExitCode() {
        let error = SubtreeValidationError.absolutePath("/some/path")
        #expect(error.exitCode == 1)
    }
    
    @Test("Absolute path error includes fix guidance")
    func testAbsolutePathGuidance() {
        let error = SubtreeValidationError.absolutePath("/vendor/lib")
        let description = error.errorDescription!
        
        #expect(description.contains("To fix:"))
        #expect(description.contains("vendor/lib"))
    }
    
    // MARK: - Parent Traversal Error
    
    @Test("Parent traversal error has correct message")
    func testParentTraversalErrorMessage() {
        let error = SubtreeValidationError.parentTraversal("../vendor/lib")
        let description = error.errorDescription
        
        #expect(description != nil)
        #expect(description!.contains("parent directory traversal"))
        #expect(description!.contains("'../'"))
        #expect(description!.contains("security reasons"))
    }
    
    @Test("Parent traversal error has user error exit code")
    func testParentTraversalExitCode() {
        let error = SubtreeValidationError.parentTraversal("../../escape")
        #expect(error.exitCode == 1)
    }
    
    @Test("Parent traversal error includes fix guidance")
    func testParentTraversalGuidance() {
        let error = SubtreeValidationError.parentTraversal("../sibling/path")
        let description = error.errorDescription!
        
        #expect(description.contains("To fix:"))
        #expect(description.contains("repository root"))
    }
    
    // MARK: - Invalid Separator Error
    
    @Test("Invalid separator error has correct message")
    func testInvalidSeparatorErrorMessage() {
        let error = SubtreeValidationError.invalidSeparator("vendor\\lib")
        let description = error.errorDescription
        
        #expect(description != nil)
        #expect(description!.contains("invalid path separator"))
        #expect(description!.contains("forward slashes"))
        #expect(description!.contains("cross-platform"))
    }
    
    @Test("Invalid separator error has user error exit code")
    func testInvalidSeparatorExitCode() {
        let error = SubtreeValidationError.invalidSeparator("path\\with\\backslashes")
        #expect(error.exitCode == 1)
    }
    
    @Test("Invalid separator error suggests replacement")
    func testInvalidSeparatorSuggestsReplacement() {
        let error = SubtreeValidationError.invalidSeparator("vendor\\lib")
        let description = error.errorDescription!
        
        #expect(description.contains("To fix:"))
        #expect(description.contains("vendor/lib"))
    }
    
    // MARK: - Subtree Not Found Error
    
    @Test("Subtree not found error has correct message")
    func testSubtreeNotFoundErrorMessage() {
        let error = SubtreeValidationError.subtreeNotFound("nonexistent")
        let description = error.errorDescription
        
        #expect(description != nil)
        #expect(description!.contains("not found"))
        #expect(description!.contains("'nonexistent'"))
    }
    
    @Test("Subtree not found error has user error exit code")
    func testSubtreeNotFoundExitCode() {
        let error = SubtreeValidationError.subtreeNotFound("missing")
        #expect(error.exitCode == 1)
    }
    
    // MARK: - Error Message Formatting
    
    @Test("All errors use emoji prefix")
    func testAllErrorsHaveEmojiPrefix() {
        let errors: [SubtreeValidationError] = [
            .duplicateName(attempted: "a", existing: "A"),
            .duplicatePrefix(attempted: "a", existing: "A"),
            .multipleMatches(name: "a", found: ["A", "a"]),
            .absolutePath("/path"),
            .parentTraversal("../path"),
            .invalidSeparator("path\\sep"),
            .subtreeNotFound("name")
        ]
        
        for error in errors {
            let description = error.errorDescription!
            #expect(description.contains("❌") || description.contains("Error:"))
        }
    }
}
