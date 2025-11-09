import Testing
import Foundation
@testable import SubtreeLib

@Suite("ExtractPattern Model Tests")
struct ExtractPatternTests {
    
    @Test("Parse extract pattern with from and to (FR-018)")
    func parseRequiredFields() throws {
        let pattern = ExtractPattern(
            from: "include/*.h",
            to: "Sources/lib/include/"
        )
        #expect(pattern.from == "include/*.h")
        #expect(pattern.exclude == nil)
    }
    
    @Test("Parse extract pattern with exclude array (FR-004)")
    func parseWithExclusions() throws {
        let pattern = ExtractPattern(
            from: "src/**/*.{h,c}",
            to: "Sources/lib/src/",
            exclude: ["src/**/test*", "src/**/bench*"]
        )
        #expect(pattern.exclude?.count == 2)
    }
    
    @Test("Parse extract pattern with complex glob (FR-019)")
    func parseComplexGlobPattern() throws {
        let pattern = ExtractPattern(
            from: "src/**/*.{h,c}",
            to: "Sources/lib/"
        )
        #expect(pattern.from.contains("**"))
        #expect(pattern.from.contains("{h,c}"))
    }
    
    @Test("ExtractPattern is Codable")
    func patternIsCodable() throws {
        let original = ExtractPattern(
            from: "include/*.h",
            to: "Sources/lib/include/",
            exclude: ["test*", "bench*"]
        )
        
        // Encode
        let encoded = try JSONEncoder().encode(original)
        
        // Decode
        let decoded = try JSONDecoder().decode(ExtractPattern.self, from: encoded)
        
        // Verify round-trip preserves data
        #expect(decoded.from == original.from)
        #expect(decoded.to == original.to)
        #expect(decoded.exclude == original.exclude)
    }
}
