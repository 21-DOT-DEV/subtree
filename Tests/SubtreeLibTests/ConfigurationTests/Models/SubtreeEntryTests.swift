import Testing
import Foundation
@testable import SubtreeLib
import Yams

@Suite("SubtreeEntry Model Tests")
struct SubtreeEntryTests {
    
    @Test("Parse subtree entry with required fields only")
    func parseRequiredFieldsOnly() throws {
        let entry = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678"
        )
        #expect(entry.name == "test")
        #expect(entry.tag == nil)
        #expect(entry.branch == nil)
    }
    
    @Test("Parse subtree entry with tag (FR-003)")
    func parseWithTag() throws {
        let entry = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678",
            tag: "v1.0.0"
        )
        #expect(entry.tag == "v1.0.0")
    }
    
    @Test("Parse subtree entry with branch (FR-003)")
    func parseWithBranch() throws {
        let entry = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678",
            branch: "main"
        )
        #expect(entry.branch == "main")
    }
    
    @Test("Parse subtree entry with squash flag (FR-003)")
    func parseWithSquash() throws {
        let entry = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678",
            squash: true
        )
        #expect(entry.squash == true)
    }
    
    @Test("SubtreeEntry is Codable")
    func entryIsCodable() throws {
        let original = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678",
            tag: "v1.0.0",
            squash: true
        )
        
        // Encode
        let encoded = try JSONEncoder().encode(original)
        
        // Decode
        let decoded = try JSONDecoder().decode(SubtreeEntry.self, from: encoded)
        
        // Verify round-trip preserves data
        #expect(decoded.name == original.name)
        #expect(decoded.remote == original.remote)
        #expect(decoded.prefix == original.prefix)
        #expect(decoded.commit == original.commit)
        #expect(decoded.tag == original.tag)
        #expect(decoded.branch == original.branch)
        #expect(decoded.squash == original.squash)
    }
    
    // T014: Test for SubtreeEntry with extractions array
    @Test("SubtreeEntry decodes with extractions array")
    func testSubtreeEntryWithExtractions() throws {
        let yaml = """
        name: my-lib
        remote: https://github.com/example/lib
        prefix: vendor/my-lib
        commit: abc1234567890abcdef1234567890abcdef1234
        extractions:
          - from: "docs/**/*.md"
            to: "project-docs/"
        """
        
        let decoder = YAMLDecoder()
        let entry = try decoder.decode(SubtreeEntry.self, from: yaml)
        
        #expect(entry.extractions?.count == 1)
        #expect(entry.extractions?[0].from == "docs/**/*.md")
        #expect(entry.extractions?[0].to == "project-docs/")
    }
    
    // T015: Test for SubtreeEntry backward compatibility
    @Test("SubtreeEntry backward compatibility - missing extractions field")
    func testSubtreeEntryBackwardCompatibility() throws {
        let yaml = """
        name: my-lib
        remote: https://github.com/example/lib
        prefix: vendor/my-lib
        commit: abc1234567890abcdef1234567890abcdef1234
        """
        
        let decoder = YAMLDecoder()
        let entry = try decoder.decode(SubtreeEntry.self, from: yaml)
        
        #expect(entry.extractions == nil)
        #expect(entry.name == "my-lib")
    }
    
    // T016: Test for SubtreeEntry with empty extractions array
    @Test("SubtreeEntry with empty extractions array")
    func testSubtreeEntryEmptyExtractions() throws {
        let yaml = """
        name: my-lib
        remote: https://github.com/example/lib
        prefix: vendor/my-lib
        commit: abc1234567890abcdef1234567890abcdef1234
        extractions: []
        """
        
        let decoder = YAMLDecoder()
        let entry = try decoder.decode(SubtreeEntry.self, from: yaml)
        
        #expect(entry.extractions != nil)
        #expect(entry.extractions?.isEmpty == true)
    }
    
    // T017: Test for SubtreeEntry with multiple extraction mappings
    @Test("SubtreeEntry with multiple extraction mappings")
    func testSubtreeEntryMultipleExtractions() throws {
        let yaml = """
        name: secp256k1
        remote: https://github.com/bitcoin-core/secp256k1
        prefix: vendor/secp256k1
        commit: def4567890abcdef1234567890abcdef12345678
        extractions:
          - from: "src/**/*.{h,c}"
            to: "Sources/libsecp256k1/src/"
            exclude:
              - "src/**/test*/**"
              - "src/**/bench*/**"
          - from: "include/**/*.h"
            to: "Sources/libsecp256k1/include/"
        """
        
        let decoder = YAMLDecoder()
        let entry = try decoder.decode(SubtreeEntry.self, from: yaml)
        
        #expect(entry.extractions?.count == 2)
        #expect(entry.extractions?[0].from == "src/**/*.{h,c}")
        #expect(entry.extractions?[0].to == "Sources/libsecp256k1/src/")
        #expect(entry.extractions?[0].exclude?.count == 2)
        #expect(entry.extractions?[1].from == "include/**/*.h")
        #expect(entry.extractions?[1].to == "Sources/libsecp256k1/include/")
    }
}
