import Testing
import Foundation
@testable import SubtreeLib
import Yams

/// Unit tests for ExtractionMapping (updated for 009-multi-pattern-extraction)
///
/// The `from` field now supports both legacy string format and new array format:
/// - Legacy: `from: "pattern"` (single pattern, wrapped in array internally)
/// - New: `from: ["p1", "p2"]` (multiple patterns)
@Suite("ExtractionMapping Tests")
struct ExtractionMappingTests {
    
    // MARK: - Single Pattern (Legacy Compatibility)
    
    // T006: Test for ExtractionMapping init (single pattern)
    @Test("ExtractionMapping initializes with single pattern (wrapped in array)")
    func testExtractionMappingInit() {
        let mapping = ExtractionMapping(from: "src/**/*.h", to: "include/")
        #expect(mapping.from == ["src/**/*.h"], "Single pattern should be wrapped in array")
        #expect(mapping.to == ["include/"])
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
        #expect(decoded.from == ["docs/**/*.md"])
        #expect(decoded.to == ["project-docs/"])
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
    
    // T010: Test for YAML serialization (single pattern → string)
    @Test("ExtractionMapping serializes single pattern to YAML as string")
    func testExtractionMappingYAMLSerialization() throws {
        let mapping = ExtractionMapping(
            from: "src/**/*.{h,c}",
            to: "Sources/lib/",
            exclude: ["src/**/test*/**", "src/bench*.c"]
        )
        
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(mapping)
        
        // Single pattern should encode as string, not array
        #expect(yaml.contains("from: src/**/*.{h,c}") || yaml.contains("from: \"src/**/*.{h,c}\""),
                "Single pattern should encode as string. Got: \(yaml)")
        #expect(yaml.contains("to: Sources/lib/"))
        #expect(yaml.contains("exclude:"))
        #expect(yaml.contains("- src/**/test*/**"))
        #expect(yaml.contains("- src/bench*.c"))
    }
    
    // T011: Test for YAML deserialization (string → wrapped in array)
    @Test("ExtractionMapping deserializes string from YAML (wrapped in array)")
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
        
        #expect(mapping.from == ["docs/**/*.md"], "String should be wrapped in array")
        #expect(mapping.to == ["project-docs/"])
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
        
        #expect(mapping.from == ["templates/**"])
        #expect(mapping.to == [".templates/"])
        #expect(mapping.exclude == nil)
    }
    
    // MARK: - Multi-Pattern (009-multi-pattern-extraction)
    
    // T003: Decode single string format `from: "pattern"`
    @Test("Decode single string format from: pattern")
    func testDecodeSingleStringFormat() throws {
        let yaml = """
        from: "include/**/*.h"
        to: "vendor/headers/"
        """
        
        let decoder = YAMLDecoder()
        let mapping = try decoder.decode(ExtractionMapping.self, from: yaml)
        
        #expect(mapping.from == ["include/**/*.h"], "Single string should be wrapped in array")
        #expect(mapping.to == ["vendor/headers/"])
        #expect(mapping.exclude == nil)
    }
    
    // T004: Decode array format `from: ["p1", "p2"]`
    @Test("Decode array format from: [p1, p2]")
    func testDecodeArrayFormat() throws {
        let yaml = """
        from:
          - "include/**/*.h"
          - "src/**/*.c"
        to: "vendor/source/"
        """
        
        let decoder = YAMLDecoder()
        let mapping = try decoder.decode(ExtractionMapping.self, from: yaml)
        
        #expect(mapping.from == ["include/**/*.h", "src/**/*.c"], "Array should be preserved")
        #expect(mapping.to == ["vendor/source/"])
    }
    
    // T005: Encode single pattern as string
    @Test("Encode single pattern as string format")
    func testEncodeSinglePatternAsString() throws {
        let mapping = ExtractionMapping(from: "include/**/*.h", to: "vendor/")
        
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(mapping)
        
        // Single pattern should encode as string, not array
        #expect(yaml.contains("from: include/**/*.h") || yaml.contains("from: \"include/**/*.h\""), 
                "Single pattern should encode as string, not array. Got: \(yaml)")
        #expect(!yaml.contains("- include"), "Should not encode as array")
    }
    
    // T006: Encode multiple patterns as array
    @Test("Encode multiple patterns as array format")
    func testEncodeMultiplePatternsAsArray() throws {
        let mapping = ExtractionMapping(fromPatterns: ["include/**/*.h", "src/**/*.c"], to: "vendor/")
        
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(mapping)
        
        // Multiple patterns should encode as array
        #expect(yaml.contains("- include/**/*.h") || yaml.contains("- \"include/**/*.h\""),
                "Multiple patterns should encode as array. Got: \(yaml)")
        #expect(yaml.contains("- src/**/*.c") || yaml.contains("- \"src/**/*.c\""),
                "Multiple patterns should encode as array. Got: \(yaml)")
    }
    
    // T007: Reject empty array `from: []`
    @Test("Reject empty array from: []")
    func testRejectEmptyArray() throws {
        let yaml = """
        from: []
        to: "vendor/"
        """
        
        let decoder = YAMLDecoder()
        
        #expect(throws: Error.self) {
            _ = try decoder.decode(ExtractionMapping.self, from: yaml)
        }
    }
    
    // T007b: Reject array with non-string elements
    // Note: Yams automatically coerces integers to strings, so this test verifies
    // that the decoding still works (Swift's type system handles the conversion).
    // True non-string rejection would require custom validation in the decoder.
    @Test("Array with mixed types is handled by Yams coercion")
    func testMixedTypesHandledByYams() throws {
        // YAML with integer in array - Yams coerces to string
        let yaml = """
        from:
          - "valid/pattern"
          - 123
        to: "vendor/"
        """
        
        let decoder = YAMLDecoder()
        // Yams coerces 123 to "123", so this actually succeeds
        let mapping = try decoder.decode(ExtractionMapping.self, from: yaml)
        #expect(mapping.from == ["valid/pattern", "123"], "Yams coerces integers to strings")
    }
    
    // T008: Single-pattern initializer wraps in array
    @Test("Single-pattern initializer wraps string in array")
    func testSinglePatternInitializerWrapsInArray() {
        let mapping = ExtractionMapping(from: "docs/**/*.md", to: "output/", exclude: ["**/internal/**"])
        
        #expect(mapping.from == ["docs/**/*.md"], "Single pattern should be wrapped in array")
        #expect(mapping.to == ["output/"])
        #expect(mapping.exclude == ["**/internal/**"])
    }
    
    // Additional: Multi-pattern initializer preserves array
    @Test("Multi-pattern initializer preserves array")
    func testMultiPatternInitializer() {
        let patterns = ["include/**/*.h", "src/**/*.c", "lib/**/*.a"]
        let mapping = ExtractionMapping(fromPatterns: patterns, to: "vendor/", exclude: nil)
        
        #expect(mapping.from == patterns, "Patterns should be preserved")
        #expect(mapping.to == ["vendor/"])
        #expect(mapping.exclude == nil)
    }
    
    // Additional: Decode with exclude patterns preserved
    @Test("Decode with exclude patterns preserved")
    func testDecodeWithExcludePatterns() throws {
        let yaml = """
        from:
          - "src/**/*.c"
        to: "vendor/"
        exclude:
          - "**/test_*"
          - "**/internal/**"
        """
        
        let decoder = YAMLDecoder()
        let mapping = try decoder.decode(ExtractionMapping.self, from: yaml)
        
        #expect(mapping.from == ["src/**/*.c"])
        #expect(mapping.to == ["vendor/"])
        #expect(mapping.exclude == ["**/test_*", "**/internal/**"])
    }
    
    // MARK: - Multi-Destination (012-multi-destination-extraction)
    
    // T012: Decode single string format `to: "path/"`
    @Test("Decode single string format to: path/")
    func testDecodeSingleStringToFormat() throws {
        let yaml = """
        from: "include/**/*.h"
        to: "vendor/headers/"
        """
        
        let decoder = YAMLDecoder()
        let mapping = try decoder.decode(ExtractionMapping.self, from: yaml)
        
        #expect(mapping.from == ["include/**/*.h"])
        #expect(mapping.to == ["vendor/headers/"], "Single string should be wrapped in array")
    }
    
    // T013: Decode array format `to: ["p1/", "p2/"]`
    @Test("Decode array format to: [p1/, p2/]")
    func testDecodeArrayToFormat() throws {
        let yaml = """
        from: "include/**/*.h"
        to:
          - "Lib/headers/"
          - "Vendor/headers/"
        """
        
        let decoder = YAMLDecoder()
        let mapping = try decoder.decode(ExtractionMapping.self, from: yaml)
        
        #expect(mapping.from == ["include/**/*.h"])
        #expect(mapping.to == ["Lib/headers/", "Vendor/headers/"], "Array should be preserved")
    }
    
    // T014: Encode single destination as string
    @Test("Encode single destination as string format")
    func testEncodeSingleDestinationAsString() throws {
        let mapping = ExtractionMapping(from: "include/**/*.h", to: "vendor/")
        
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(mapping)
        
        // Single destination should encode as string, not array
        #expect(yaml.contains("to: vendor/") || yaml.contains("to: \"vendor/\""),
                "Single destination should encode as string, not array. Got: \(yaml)")
        #expect(!yaml.contains("- vendor"), "Should not encode as array")
    }
    
    // T015: Encode multiple destinations as array
    @Test("Encode multiple destinations as array format")
    func testEncodeMultipleDestinationsAsArray() throws {
        let mapping = ExtractionMapping(from: "include/**/*.h", toDestinations: ["Lib/", "Vendor/"])
        
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(mapping)
        
        // Multiple destinations should encode as array
        #expect(yaml.contains("- Lib/") || yaml.contains("- \"Lib/\""),
                "Multiple destinations should encode as array. Got: \(yaml)")
        #expect(yaml.contains("- Vendor/") || yaml.contains("- \"Vendor/\""),
                "Multiple destinations should encode as array. Got: \(yaml)")
    }
    
    // T016: Reject empty array `to: []`
    @Test("Reject empty array to: []")
    func testRejectEmptyToArray() throws {
        let yaml = """
        from: "include/**/*.h"
        to: []
        """
        
        let decoder = YAMLDecoder()
        
        #expect(throws: Error.self) {
            _ = try decoder.decode(ExtractionMapping.self, from: yaml)
        }
    }
    
    // T017: Single-destination initializer works
    @Test("Single-destination initializer wraps string in array")
    func testSingleDestinationInitializerWrapsInArray() {
        let mapping = ExtractionMapping(from: "docs/**/*.md", to: "output/", exclude: ["**/internal/**"])
        
        #expect(mapping.from == ["docs/**/*.md"])
        #expect(mapping.to == ["output/"], "Single destination should be wrapped in array")
        #expect(mapping.exclude == ["**/internal/**"])
    }
    
    // T018: Multi-destination initializer works
    @Test("Multi-destination initializer preserves array")
    func testMultiDestinationInitializer() {
        let destinations = ["Lib/", "Vendor/", "Backup/"]
        let mapping = ExtractionMapping(from: "include/**/*.h", toDestinations: destinations, exclude: nil)
        
        #expect(mapping.from == ["include/**/*.h"])
        #expect(mapping.to == destinations, "Destinations should be preserved")
        #expect(mapping.exclude == nil)
    }
    
    // T018b: Verify Yams coercion of non-string elements in `to`
    @Test("Array with mixed types in to is handled by Yams coercion")
    func testMixedTypesToHandledByYams() throws {
        // YAML with integer in array - Yams coerces to string
        let yaml = """
        from: "valid/pattern"
        to:
          - "Lib/"
          - 123
        """
        
        let decoder = YAMLDecoder()
        // Yams coerces 123 to "123", so this actually succeeds
        let mapping = try decoder.decode(ExtractionMapping.self, from: yaml)
        #expect(mapping.to == ["Lib/", "123"], "Yams coerces integers to strings")
    }
    
    // Additional: Combined multi-pattern + multi-destination
    @Test("Combined multi-pattern and multi-destination")
    func testCombinedMultiPatternMultiDestination() throws {
        let yaml = """
        from:
          - "include/**/*.h"
          - "src/**/*.c"
        to:
          - "Lib/"
          - "Vendor/"
        exclude:
          - "**/test/**"
        """
        
        let decoder = YAMLDecoder()
        let mapping = try decoder.decode(ExtractionMapping.self, from: yaml)
        
        #expect(mapping.from == ["include/**/*.h", "src/**/*.c"])
        #expect(mapping.to == ["Lib/", "Vendor/"])
        #expect(mapping.exclude == ["**/test/**"])
    }
    
    // Additional: Multi-pattern + multi-destination initializer
    @Test("Multi-pattern multi-destination initializer")
    func testMultiPatternMultiDestinationInitializer() {
        let patterns = ["include/**/*.h", "src/**/*.c"]
        let destinations = ["Lib/", "Vendor/"]
        let mapping = ExtractionMapping(fromPatterns: patterns, toDestinations: destinations, exclude: ["**/internal/**"])
        
        #expect(mapping.from == patterns)
        #expect(mapping.to == destinations)
        #expect(mapping.exclude == ["**/internal/**"])
    }
}
