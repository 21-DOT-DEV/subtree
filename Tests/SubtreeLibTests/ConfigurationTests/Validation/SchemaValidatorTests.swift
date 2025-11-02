import Testing
import Foundation
@testable import SubtreeLib

@Suite("SchemaValidator Tests")
struct SchemaValidatorTests {
    
    @Test("Validate configuration with subtrees array (FR-001)")
    func validateSubtreesArrayPresent() throws {
        let config = SubtreeConfiguration(subtrees: [])
        let validator = SchemaValidator()
        let errors = validator.validate(config)
        
        // Should pass - subtrees array is present
        #expect(errors.isEmpty)
    }
    
    @Test("Validate empty subtrees array is valid (FR-031)")
    func validateEmptySubtreesArray() throws {
        let config = SubtreeConfiguration(subtrees: [])
        let validator = SchemaValidator()
        let errors = validator.validate(config)
        
        // Empty array should be valid per FR-031
        #expect(errors.isEmpty)
    }
    
    @Test("Validate configuration with subtree entries")
    func validateWithSubtreeEntries() throws {
        let entry = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678"
        )
        let config = SubtreeConfiguration(subtrees: [entry])
        let validator = SchemaValidator()
        let errors = validator.validate(config)
        
        // Should pass validation
        #expect(errors.isEmpty)
    }
}
