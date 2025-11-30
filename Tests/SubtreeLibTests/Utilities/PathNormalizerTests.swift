import Testing
import Foundation
@testable import SubtreeLib

/// Unit tests for PathNormalizer (012-multi-destination-extraction)
///
/// PathNormalizer handles destination path normalization and deduplication:
/// - Removes trailing slashes: `Lib/` → `Lib`
/// - Removes leading `./`: `./Lib` → `Lib`
/// - Deduplicates equivalent paths while preserving order and original form
@Suite("PathNormalizer Tests")
struct PathNormalizerTests {
    
    // MARK: - T004: Normalize removes trailing slash
    
    @Test("Normalize removes single trailing slash")
    func testNormalizeRemovesTrailingSlash() {
        #expect(PathNormalizer.normalize("Lib/") == "Lib")
        #expect(PathNormalizer.normalize("vendor/headers/") == "vendor/headers")
    }
    
    @Test("Normalize removes multiple trailing slashes")
    func testNormalizeRemovesMultipleTrailingSlashes() {
        #expect(PathNormalizer.normalize("Lib//") == "Lib")
        #expect(PathNormalizer.normalize("path///") == "path")
    }
    
    @Test("Normalize preserves path without trailing slash")
    func testNormalizePreservesPathWithoutTrailingSlash() {
        #expect(PathNormalizer.normalize("Lib") == "Lib")
        #expect(PathNormalizer.normalize("vendor/headers") == "vendor/headers")
    }
    
    // MARK: - T005: Normalize removes leading `./`
    
    @Test("Normalize removes single leading ./")
    func testNormalizeRemovesLeadingDotSlash() {
        #expect(PathNormalizer.normalize("./Lib") == "Lib")
        #expect(PathNormalizer.normalize("./vendor/headers") == "vendor/headers")
    }
    
    @Test("Normalize removes multiple leading ./")
    func testNormalizeRemovesMultipleLeadingDotSlash() {
        #expect(PathNormalizer.normalize("././Lib") == "Lib")
        #expect(PathNormalizer.normalize("./././path") == "path")
    }
    
    @Test("Normalize preserves path without leading ./")
    func testNormalizePreservesPathWithoutLeadingDotSlash() {
        #expect(PathNormalizer.normalize("Lib") == "Lib")
        #expect(PathNormalizer.normalize("vendor/headers") == "vendor/headers")
    }
    
    // MARK: - T006: Normalize handles combined `./path/`
    
    @Test("Normalize handles combined leading ./ and trailing /")
    func testNormalizeHandlesCombined() {
        #expect(PathNormalizer.normalize("./Lib/") == "Lib")
        #expect(PathNormalizer.normalize("./vendor/headers/") == "vendor/headers")
        #expect(PathNormalizer.normalize("././path//") == "path")
    }
    
    @Test("Normalize handles edge cases")
    func testNormalizeEdgeCases() {
        // Single dot should remain (current directory)
        #expect(PathNormalizer.normalize(".") == ".")
        // Root slash should remain
        #expect(PathNormalizer.normalize("/") == "/")
        // Empty string edge case
        #expect(PathNormalizer.normalize("") == "")
    }
    
    // MARK: - T007: Deduplicate removes equivalent paths
    
    @Test("Deduplicate removes paths that normalize to same value")
    func testDeduplicateRemovesEquivalentPaths() {
        let paths = ["Lib", "Lib/", "./Lib", "./Lib/"]
        let result = PathNormalizer.deduplicate(paths)
        #expect(result.count == 1)
    }
    
    @Test("Deduplicate keeps distinct paths")
    func testDeduplicateKeepsDistinctPaths() {
        let paths = ["Lib", "Vendor", "Headers"]
        let result = PathNormalizer.deduplicate(paths)
        #expect(result == ["Lib", "Vendor", "Headers"])
    }
    
    @Test("Deduplicate handles mixed equivalent and distinct")
    func testDeduplicateMixedPaths() {
        let paths = ["Lib/", "Vendor", "./Lib", "Vendor/", "Headers"]
        let result = PathNormalizer.deduplicate(paths)
        #expect(result.count == 3)
        // Should contain one form of Lib, Vendor, Headers
    }
    
    // MARK: - T008: Deduplicate preserves order and original form
    
    @Test("Deduplicate preserves original form (first occurrence)")
    func testDeduplicatePreservesOriginalForm() {
        // First occurrence "Lib/" should be kept, not "Lib" or "./Lib"
        let paths = ["Lib/", "Lib", "./Lib"]
        let result = PathNormalizer.deduplicate(paths)
        #expect(result == ["Lib/"])
    }
    
    @Test("Deduplicate preserves input order")
    func testDeduplicatePreservesOrder() {
        let paths = ["Vendor", "Lib", "Headers"]
        let result = PathNormalizer.deduplicate(paths)
        #expect(result == ["Vendor", "Lib", "Headers"])
    }
    
    @Test("Deduplicate handles empty array")
    func testDeduplicateEmptyArray() {
        let result = PathNormalizer.deduplicate([])
        #expect(result.isEmpty)
    }
    
    @Test("Deduplicate handles single element")
    func testDeduplicateSingleElement() {
        let result = PathNormalizer.deduplicate(["Lib/"])
        #expect(result == ["Lib/"])
    }
}
