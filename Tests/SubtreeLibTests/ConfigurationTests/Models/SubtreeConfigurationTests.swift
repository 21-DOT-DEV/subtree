import Testing
import Foundation
@testable import SubtreeLib

@Suite("SubtreeConfiguration Model Tests")
struct SubtreeConfigurationTests {
    
    @Test("Parse valid configuration with subtrees array")
    func parseValidConfiguration() throws {
        let config = SubtreeConfiguration(subtrees: [])
        #expect(config.subtrees.isEmpty)
    }
    
    @Test("Parse configuration with empty subtrees array (FR-031)")
    func parseEmptySubtreesArray() throws {
        // Empty array should be valid per FR-031
        let config = SubtreeConfiguration(subtrees: [])
        #expect(config.subtrees.isEmpty)
    }
    
    @Test("Parse configuration with multiple subtrees")
    func parseMultipleSubtrees() throws {
        let entry1 = SubtreeEntry(
            name: "lib1",
            remote: "https://github.com/org/repo1",
            prefix: "Vendors/lib1",
            commit: "1234567890abcdef1234567890abcdef12345678"
        )
        let entry2 = SubtreeEntry(
            name: "lib2",
            remote: "https://github.com/org/repo2",
            prefix: "Vendors/lib2",
            commit: "abcdef1234567890abcdef1234567890abcdef12"
        )
        let config = SubtreeConfiguration(subtrees: [entry1, entry2])
        #expect(config.subtrees.count == 2)
    }
    
    @Test("Configuration is Codable")
    func configurationIsCodable() throws {
        let entry = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678",
            tag: "v1.0.0"
        )
        let original = SubtreeConfiguration(subtrees: [entry])
        
        // Encode
        let encoded = try JSONEncoder().encode(original)
        
        // Decode
        let decoded = try JSONDecoder().decode(SubtreeConfiguration.self, from: encoded)
        
        // Verify round-trip preserves data
        #expect(decoded.subtrees.count == original.subtrees.count)
        #expect(decoded.subtrees.first?.name == original.subtrees.first?.name)
        #expect(decoded.subtrees.first?.tag == original.subtrees.first?.tag)
    }
}
