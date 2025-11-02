import Testing
@testable import SubtreeLib

@Suite("ValidationError Tests")
struct ValidationErrorTests {
    
    @Test("Create validation error with all fields (FR-020, FR-021, FR-022)")
    func createWithAllFields() throws {
        let error = ValidationError(
            entry: "test-lib",
            field: "commit",
            message: "Invalid commit hash format",
            suggestion: "Use 40-character SHA-1 hash"
        )
        #expect(error.entry == "test-lib")
        #expect(error.suggestion != nil)
    }
    
    @Test("Create validation error without suggestion")
    func createWithoutSuggestion() throws {
        let error = ValidationError(
            entry: "test-lib",
            field: "commit",
            message: "Invalid commit hash format"
        )
        #expect(error.suggestion == nil)
    }
    
    @Test("Error entry identification (FR-020)")
    func entryIdentification() throws {
        let error = ValidationError(
            entry: "my-lib",
            field: "remote",
            message: "Invalid URL"
        )
        #expect(error.entry == "my-lib")
    }
    
    @Test("Error field identification (FR-021)")
    func fieldIdentification() throws {
        let error = ValidationError(
            entry: "my-lib",
            field: "prefix",
            message: "Unsafe path"
        )
        #expect(error.field == "prefix")
    }
    
    @Test("Error message clarity (FR-022)")
    func messageClarity() throws {
        let error = ValidationError(
            entry: "my-lib",
            field: "commit",
            message: "Invalid commit hash format: expected 40 hex characters, got 38"
        )
        #expect(error.message.contains("expected"))
        #expect(error.message.contains("got"))
    }
    
    @Test("Error suggestion guidance (FR-023)")
    func suggestionGuidance() throws {
        let error = ValidationError(
            entry: "my-lib",
            field: "commit",
            message: "Invalid commit hash",
            suggestion: "Verify the commit hash is a complete SHA-1 hash (40 characters)"
        )
        #expect(error.suggestion != nil)
    }
}
