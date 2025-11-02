import Testing
import Foundation
@testable import SubtreeLib

@Suite("TypeValidator Tests")
struct TypeValidatorTests {
    
    @Test("Validate name is non-empty (FR-005)")
    func validateNameNonEmpty() throws {
        let validator = TypeValidator()
        
        // Empty name should fail
        let entryWithEmptyName = SubtreeEntry(
            name: "",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678"
        )
        let errors = validator.validate(entryWithEmptyName, index: 0)
        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.field == "name" })
        
        // Non-empty name should pass
        let entryWithName = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678"
        )
        let noErrors = validator.validate(entryWithName, index: 0)
        #expect(noErrors.filter { $0.field == "name" }.isEmpty)
    }
    
    @Test("Validate tag/branch non-empty when present (FR-009)")
    func validateTagBranchNonEmpty() throws {
        let validator = TypeValidator()
        
        // Empty tag should fail
        let entryWithEmptyTag = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678",
            tag: ""
        )
        let tagErrors = validator.validate(entryWithEmptyTag, index: 0)
        #expect(tagErrors.contains { $0.field == "tag" })
        
        // Empty branch should fail
        let entryWithEmptyBranch = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678",
            branch: ""
        )
        let branchErrors = validator.validate(entryWithEmptyBranch, index: 0)
        #expect(branchErrors.contains { $0.field == "branch" })
    }
    
    @Test("Validate squash is boolean (FR-010)")
    func validateSquashBoolean() throws {
        // This is validated by Swift's type system
        // The model only accepts Bool?, so invalid types won't compile
        let validator = TypeValidator()
        
        let entry = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678",
            squash: true
        )
        let errors = validator.validate(entry, index: 0)
        // Should not have squash-related type errors
        #expect(errors.filter { $0.field == "squash" }.isEmpty)
    }
    
    @Test("Validate extracts is non-empty array when present (FR-011)")
    func validateExtractsNonEmpty() throws {
        let validator = TypeValidator()
        
        // Empty extracts array should fail
        let entryWithEmptyExtracts = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678",
            extracts: []
        )
        let errors = validator.validate(entryWithEmptyExtracts, index: 0)
        #expect(errors.contains { $0.field == "extracts" })
        
        // Non-empty extracts should pass
        let pattern = ExtractPattern(from: "*.h", to: "Sources/")
        let entryWithExtracts = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678",
            extracts: [pattern]
        )
        let noErrors = validator.validate(entryWithExtracts, index: 0)
        #expect(noErrors.filter { $0.field == "extracts" }.isEmpty)
    }
}
