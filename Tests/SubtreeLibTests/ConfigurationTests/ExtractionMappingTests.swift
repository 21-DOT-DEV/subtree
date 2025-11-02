import Testing
import Foundation
@testable import SubtreeLib
import Yams

@Suite("ExtractionMapping Tests")
struct ExtractionMappingTests {
    
    // T006: Test for ExtractionMapping init
    @Test("ExtractionMapping initializes with from and to")
    func testExtractionMappingInit() {
        let mapping = ExtractionMapping(from: "src/**/*.h", to: "include/")
        #expect(mapping.from == "src/**/*.h")
        #expect(mapping.to == "include/")
        #expect(mapping.exclude == nil)
    }
    
    // T007: Test for Codable conformance (encode/decode)
    @Test("ExtractionMapping encodes to and decodes from Data")
    func testExtractionMappingCodable() throws {
        let original = ExtractionMapping(
            from: "docs/**/*.md",
            to: "project-docs/",
            exclude: ["docs/internal/**"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ExtractionMapping.self, from: data)
        
        #expect(decoded == original)
        #expect(decoded.from == "docs/**/*.md")
        #expect(decoded.to == "project-docs/")
        #expect(decoded.exclude == ["docs/internal/**"])
    }
    
    // T008: Test for Equatable conformance
    @Test("ExtractionMapping compares equal when fields match")
    func testExtractionMappingEquatable() {
        let mapping1 = ExtractionMapping(from: "src/**/*.c", to: "Sources/")
        let mapping2 = ExtractionMapping(from: "src/**/*.c", to: "Sources/")
        let mapping3 = ExtractionMapping(from: "src/**/*.h", to: "Sources/")
        
        #expect(mapping1 == mapping2)
        #expect(mapping1 != mapping3)
    }
    
    // T009: Test for optional exclude field
    @Test("ExtractionMapping handles optional exclude field")
    func testExtractionMappingOptionalExclude() {
        // Without exclude
        let withoutExclude = ExtractionMapping(from: "*.txt", to: "docs/")
        #expect(withoutExclude.exclude == nil)
        
        // With exclude
        let withExclude = ExtractionMapping(
            from: "*.txt",
            to: "docs/",
            exclude: ["test.txt", "*.tmp"]
        )
        #expect(withExclude.exclude == ["test.txt", "*.tmp"])
        
        // With empty exclude array
        let withEmptyExclude = ExtractionMapping(
            from: "*.txt",
            to: "docs/",
            exclude: []
        )
        #expect(withEmptyExclude.exclude == [])
    }
    
    // T010: Test for YAML serialization
    @Test("ExtractionMapping serializes to YAML correctly")
    func testExtractionMappingYAMLSerialization() throws {
        let mapping = ExtractionMapping(
            from: "src/**/*.{h,c}",
            to: "Sources/lib/",
            exclude: ["src/**/test*/**", "src/bench*.c"]
        )
        
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(mapping)
        
        #expect(yaml.contains("from: src/**/*.{h,c}"))
        #expect(yaml.contains("to: Sources/lib/"))
        #expect(yaml.contains("exclude:"))
        #expect(yaml.contains("- src/**/test*/**"))
        #expect(yaml.contains("- src/bench*.c"))
    }
    
    // T011: Test for YAML deserialization
    @Test("ExtractionMapping deserializes from YAML correctly")
    func testExtractionMappingYAMLDeserialization() throws {
        let yaml = """
        from: "docs/**/*.md"
        to: "project-docs/"
        exclude:
          - "docs/internal/**"
          - "docs/draft*.md"
        """
        
        let decoder = YAMLDecoder()
        let mapping = try decoder.decode(ExtractionMapping.self, from: yaml)
        
        #expect(mapping.from == "docs/**/*.md")
        #expect(mapping.to == "project-docs/")
        #expect(mapping.exclude == ["docs/internal/**", "docs/draft*.md"])
    }
    
    // Additional: Test YAML without exclude field
    @Test("ExtractionMapping deserializes from YAML without exclude field")
    func testExtractionMappingYAMLWithoutExclude() throws {
        let yaml = """
        from: "templates/**"
        to: ".templates/"
        """
        
        let decoder = YAMLDecoder()
        let mapping = try decoder.decode(ExtractionMapping.self, from: yaml)
        
        #expect(mapping.from == "templates/**")
        #expect(mapping.to == ".templates/")
        #expect(mapping.exclude == nil)
    }
}
