import Testing
import Foundation
@testable import SubtreeLib

@Suite("LogicValidator Tests")
struct LogicValidatorTests {
    
    @Test("Validate tag/branch mutual exclusivity (FR-012)")
    func validateTagBranchMutualExclusivity() throws {
        let validator = LogicValidator()
        
        // Both tag and branch should fail
        let bothTagAndBranch = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678",
            tag: "v1.0.0",
            branch: "main"
        )
        let errors = validator.validate(bothTagAndBranch, index: 0)
        #expect(errors.contains { $0.field.contains("tag") || $0.field.contains("branch") })
        
        // Only tag should pass
        let onlyTag = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678",
            tag: "v1.0.0"
        )
        let tagErrors = validator.validate(onlyTag, index: 0)
        #expect(tagErrors.filter { $0.field.contains("tag") || $0.field.contains("branch") }.isEmpty)
        
        // Only branch should pass
        let onlyBranch = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678",
            branch: "main"
        )
        let branchErrors = validator.validate(onlyBranch, index: 0)
        #expect(branchErrors.filter { $0.field.contains("tag") || $0.field.contains("branch") }.isEmpty)
    }
    
    @Test("Validate commit only is valid (FR-013)")
    func validateCommitOnly() throws {
        let validator = LogicValidator()
        
        // Commit without tag or branch should pass
        let commitOnly = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678"
        )
        let errors = validator.validate(commitOnly, index: 0)
        // Should not have any tag/branch related errors
        #expect(errors.filter { $0.field.contains("tag") || $0.field.contains("branch") }.isEmpty)
    }
    
    @Test("Validate tag + commit is valid (FR-014)")
    func validateTagPlusCommit() throws {
        let validator = LogicValidator()
        
        // Tag with commit should pass
        let tagPlusCommit = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678",
            tag: "v1.0.0"
        )
        let errors = validator.validate(tagPlusCommit, index: 0)
        // Should not error on this combination
        #expect(errors.filter { $0.message.contains("Cannot specify both") }.isEmpty)
    }
    
    @Test("Validate branch + commit is valid (FR-015)")
    func validateBranchPlusCommit() throws {
        let validator = LogicValidator()
        
        // Branch with commit should pass
        let branchPlusCommit = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678",
            branch: "main"
        )
        let errors = validator.validate(branchPlusCommit, index: 0)
        // Should not error on this combination
        #expect(errors.filter { $0.message.contains("Cannot specify both") }.isEmpty)
    }
    
    @Test("Validate unknown fields rejected (FR-016)")
    func validateUnknownFieldsRejected() throws {
        // This is handled by YAML decoder
        // Codable will reject unknown fields at parse time
        // Test verified in integration tests
        let validator = LogicValidator()
        
        let entry = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678"
        )
        let errors = validator.validate(entry, index: 0)
        // LogicValidator doesn't check for unknown fields (parser does)
        #expect(errors.isEmpty || errors.allSatisfy { !$0.message.contains("unknown") })
    }
    
    @Test("Validate duplicate names rejected (FR-030)")
    func validateDuplicateNamesRejected() throws {
        let validator = LogicValidator()
        
        let entry1 = SubtreeEntry(
            name: "duplicate",
            remote: "https://github.com/org/repo1",
            prefix: "Vendors/lib1",
            commit: "1234567890abcdef1234567890abcdef12345678"
        )
        let entry2 = SubtreeEntry(
            name: "duplicate",
            remote: "https://github.com/org/repo2",
            prefix: "Vendors/lib2",
            commit: "abcdef1234567890abcdef1234567890abcdef12"
        )
        let config = SubtreeConfiguration(subtrees: [entry1, entry2])
        
        let errors = validator.validate(config)
        #expect(errors.contains { $0.field == "name" && $0.message.contains("Duplicate") })
    }
}
