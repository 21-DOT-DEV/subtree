import Foundation
import Testing
@testable import SubtreeLib

/// Tests for BraceExpander utility (011-brace-expansion)
///
/// Test organization follows user stories from spec.md:
/// - US1: Basic brace expansion ({a,b}, {a,b/c})
/// - US2: Multiple brace groups (cartesian product)
/// - US3: Pass-through for invalid patterns
/// - US4: Error on empty alternatives
@Suite("BraceExpander Tests")
struct BraceExpanderTests {
    
    // MARK: - Phase 2: Foundational Tests (T004)
    
    @Test("Detects single brace group with comma")
    func detectsSingleBraceGroup() throws {
        // A valid brace group has: opening {, at least one comma, closing }
        let result = try BraceExpander.expand("{a,b}")
        #expect(result.count == 2, "Should detect brace group and expand to 2 patterns")
    }
    
    @Test("Detects brace group in middle of pattern")
    func detectsBraceGroupInMiddle() throws {
        let result = try BraceExpander.expand("prefix{a,b}suffix")
        #expect(result.count == 2, "Should detect brace group even with prefix/suffix")
    }
    
    @Test("Detects multiple brace groups")
    func detectsMultipleBraceGroups() throws {
        let result = try BraceExpander.expand("{a,b}{1,2}")
        #expect(result.count == 4, "Should detect both brace groups (2 × 2 = 4)")
    }
    
    @Test("No brace group when no braces")
    func noBraceGroupWhenNoBraces() throws {
        let result = try BraceExpander.expand("plain.txt")
        #expect(result == ["plain.txt"], "Should return original when no braces")
    }
    
    @Test("No brace group when no comma inside braces")
    func noBraceGroupWhenNoComma() throws {
        let result = try BraceExpander.expand("{single}")
        #expect(result == ["{single}"], "Should treat as literal when no comma")
    }
    
    // MARK: - US1: Basic Brace Expansion Tests (T008-T010)
    
    // T008: Basic expansion tests
    @Test("Basic expansion {a,b} returns two alternatives")
    func basicExpansionTwoAlternatives() throws {
        let result = try BraceExpander.expand("{a,b}")
        #expect(result == ["a", "b"], "Should expand to exact alternatives")
    }
    
    @Test("Basic expansion {a,b,c} returns three alternatives")
    func basicExpansionThreeAlternatives() throws {
        let result = try BraceExpander.expand("{a,b,c}")
        #expect(result == ["a", "b", "c"], "Should expand to all alternatives")
    }
    
    @Test("Basic expansion preserves order")
    func basicExpansionPreservesOrder() throws {
        let result = try BraceExpander.expand("{z,a,m}")
        #expect(result == ["z", "a", "m"], "Should preserve original order")
    }
    
    // T009: Embedded path separator tests
    @Test("Embedded path separator {a,b/c} expands correctly")
    func embeddedPathSeparator() throws {
        let result = try BraceExpander.expand("{a,b/c}")
        #expect(result == ["a", "b/c"], "Should support path separators inside braces")
    }
    
    @Test("Embedded deep path {a,b/c/d} expands correctly")
    func embeddedDeepPath() throws {
        let result = try BraceExpander.expand("{a,b/c/d}")
        #expect(result == ["a", "b/c/d"], "Should support deep paths inside braces")
    }
    
    @Test("Real-world pattern Sources/{A,B/C}.swift")
    func realWorldEmbeddedPath() throws {
        let result = try BraceExpander.expand("Sources/{A,B/C}.swift")
        #expect(result == ["Sources/A.swift", "Sources/B/C.swift"], "Should handle real-world embedded paths")
    }
    
    // T010: Patterns with prefix/suffix tests
    @Test("Pattern with prefix and suffix")
    func patternWithPrefixAndSuffix() throws {
        let result = try BraceExpander.expand("prefix{a,b}suffix")
        #expect(result == ["prefixasuffix", "prefixbsuffix"], "Should preserve prefix and suffix")
    }
    
    @Test("File extension pattern *.{h,c}")
    func fileExtensionPattern() throws {
        let result = try BraceExpander.expand("*.{h,c}")
        #expect(result == ["*.h", "*.c"], "Should expand file extension patterns")
    }
    
    @Test("Directory pattern {src,test}/*.swift")
    func directoryPattern() throws {
        let result = try BraceExpander.expand("{src,test}/*.swift")
        #expect(result == ["src/*.swift", "test/*.swift"], "Should expand directory patterns")
    }
    
    @Test("Complex real-world pattern")
    func complexRealWorldPattern() throws {
        let result = try BraceExpander.expand("Sources/Crypto/Util/{PrettyBytes,SecureBytes}.swift")
        #expect(result == [
            "Sources/Crypto/Util/PrettyBytes.swift",
            "Sources/Crypto/Util/SecureBytes.swift"
        ], "Should handle complex real-world patterns")
    }
    
    // MARK: - US2: Multiple Brace Groups Tests (T014-T015)
    
    // T014: Two brace groups cartesian product
    @Test("Two brace groups {a,b}{1,2} produces 4 patterns")
    func twoBraceGroupsCartesian() throws {
        let result = try BraceExpander.expand("{a,b}{1,2}")
        #expect(result == ["a1", "a2", "b1", "b2"], "Should produce cartesian product")
    }
    
    @Test("Two brace groups with prefix/suffix")
    func twoBraceGroupsWithContext() throws {
        let result = try BraceExpander.expand("pre{a,b}mid{1,2}post")
        #expect(result == ["preamid1post", "preamid2post", "prebmid1post", "prebmid2post"])
    }
    
    @Test("Two brace groups in path pattern")
    func twoBraceGroupsPath() throws {
        let result = try BraceExpander.expand("{Sources,Tests}/{Foo,Bar}.swift")
        #expect(result == [
            "Sources/Foo.swift",
            "Sources/Bar.swift",
            "Tests/Foo.swift",
            "Tests/Bar.swift"
        ], "Should expand directory × filename")
    }
    
    @Test("Mixed sizes {a,b,c}{1,2} produces 6 patterns")
    func mixedSizeBraceGroups() throws {
        let result = try BraceExpander.expand("{a,b,c}{1,2}")
        #expect(result.count == 6, "Should produce 3 × 2 = 6 patterns")
        #expect(result == ["a1", "a2", "b1", "b2", "c1", "c2"])
    }
    
    // T015: Three brace groups (8 patterns)
    @Test("Three brace groups {x,y}{a,b}{1,2} produces 8 patterns")
    func threeBraceGroupsCartesian() throws {
        let result = try BraceExpander.expand("{x,y}{a,b}{1,2}")
        #expect(result.count == 8, "Should produce 2 × 2 × 2 = 8 patterns")
        #expect(result == ["xa1", "xa2", "xb1", "xb2", "ya1", "ya2", "yb1", "yb2"])
    }
    
    @Test("Three brace groups in real-world pattern")
    func threeBraceGroupsRealWorld() throws {
        let result = try BraceExpander.expand("{src,test}/{foo,bar}.{h,c}")
        #expect(result.count == 8, "Should produce 2 × 2 × 2 = 8 patterns")
    }
    
    @Test("Multiple groups with embedded path separator")
    func multipleGroupsWithEmbeddedPath() throws {
        let result = try BraceExpander.expand("{A,B/C}{1,2}")
        #expect(result == ["A1", "A2", "B/C1", "B/C2"], "Should handle embedded paths in multi-group")
    }
    
    // MARK: - US3: Pass-Through Tests (T020-T023)
    
    // T020: No-comma pass-through tests
    @Test("Single alternative {a} passes through unchanged")
    func singleAlternativePassThrough() throws {
        let result = try BraceExpander.expand("{a}")
        #expect(result == ["{a}"], "No comma means no expansion")
    }
    
    @Test("Single alternative with path {foo/bar} passes through")
    func singleAlternativeWithPath() throws {
        let result = try BraceExpander.expand("{foo/bar}")
        #expect(result == ["{foo/bar}"], "No comma means no expansion even with path")
    }
    
    @Test("Single alternative in context pre{x}post passes through")
    func singleAlternativeInContext() throws {
        let result = try BraceExpander.expand("pre{x}post")
        #expect(result == ["pre{x}post"], "No comma means literal braces preserved")
    }
    
    // T021: Empty braces pass-through tests
    @Test("Empty braces {} passes through unchanged")
    func emptyBracesPassThrough() throws {
        let result = try BraceExpander.expand("{}")
        #expect(result == ["{}"], "Empty braces treated as literal")
    }
    
    @Test("Empty braces in context pre{}post passes through")
    func emptyBracesInContext() throws {
        let result = try BraceExpander.expand("pre{}post")
        #expect(result == ["pre{}post"], "Empty braces preserved in context")
    }
    
    // T022: Unclosed braces pass-through tests
    @Test("Unclosed brace {a,b passes through unchanged")
    func unclosedBracePassThrough() throws {
        let result = try BraceExpander.expand("{a,b")
        #expect(result == ["{a,b"], "Unclosed brace treated as literal")
    }
    
    @Test("Unclosed brace in context pre{a,b passes through")
    func unclosedBraceInContext() throws {
        let result = try BraceExpander.expand("pre{a,b")
        #expect(result == ["pre{a,b"], "Unclosed brace preserved in context")
    }
    
    @Test("Only closing brace passes through")
    func onlyClosingBrace() throws {
        let result = try BraceExpander.expand("a,b}")
        #expect(result == ["a,b}"], "Only closing brace treated as literal")
    }
    
    // T023: No-braces pass-through tests
    @Test("Plain text without braces passes through")
    func plainTextPassThrough() throws {
        let result = try BraceExpander.expand("plain.txt")
        #expect(result == ["plain.txt"], "No braces means no change")
    }
    
    @Test("Path without braces passes through")
    func pathWithoutBraces() throws {
        let result = try BraceExpander.expand("Sources/Foo/Bar.swift")
        #expect(result == ["Sources/Foo/Bar.swift"], "Path without braces unchanged")
    }
    
    @Test("Glob pattern without braces passes through")
    func globWithoutBraces() throws {
        let result = try BraceExpander.expand("**/*.swift")
        #expect(result == ["**/*.swift"], "Glob wildcards preserved")
    }
    
    @Test("Empty string passes through")
    func emptyStringPassThrough() throws {
        let result = try BraceExpander.expand("")
        #expect(result == [""], "Empty string returns empty string in array")
    }
    
    // MARK: - US4: Empty Alternative Error Tests (T027-T029)
    
    // T027: Trailing empty alternative error tests
    @Test("Trailing empty alternative {a,} throws error")
    func trailingEmptyAlternativeThrows() throws {
        #expect(throws: BraceExpanderError.emptyAlternative("{a,}")) {
            try BraceExpander.expand("{a,}")
        }
    }
    
    @Test("Trailing empty alternative in context throws error")
    func trailingEmptyInContextThrows() throws {
        #expect(throws: BraceExpanderError.emptyAlternative("pre{a,}post")) {
            try BraceExpander.expand("pre{a,}post")
        }
    }
    
    @Test("Trailing empty with multiple alternatives {a,b,} throws")
    func trailingEmptyMultipleThrows() throws {
        #expect(throws: BraceExpanderError.emptyAlternative("{a,b,}")) {
            try BraceExpander.expand("{a,b,}")
        }
    }
    
    // T028: Leading empty alternative error tests
    @Test("Leading empty alternative {,b} throws error")
    func leadingEmptyAlternativeThrows() throws {
        #expect(throws: BraceExpanderError.emptyAlternative("{,b}")) {
            try BraceExpander.expand("{,b}")
        }
    }
    
    @Test("Leading empty alternative in context throws error")
    func leadingEmptyInContextThrows() throws {
        #expect(throws: BraceExpanderError.emptyAlternative("pre{,b}post")) {
            try BraceExpander.expand("pre{,b}post")
        }
    }
    
    @Test("Leading empty with multiple alternatives {,a,b} throws")
    func leadingEmptyMultipleThrows() throws {
        #expect(throws: BraceExpanderError.emptyAlternative("{,a,b}")) {
            try BraceExpander.expand("{,a,b}")
        }
    }
    
    // T029: Middle empty alternative error tests
    @Test("Middle empty alternative {a,,b} throws error")
    func middleEmptyAlternativeThrows() throws {
        #expect(throws: BraceExpanderError.emptyAlternative("{a,,b}")) {
            try BraceExpander.expand("{a,,b}")
        }
    }
    
    @Test("Middle empty alternative in context throws error")
    func middleEmptyInContextThrows() throws {
        #expect(throws: BraceExpanderError.emptyAlternative("pre{a,,b}post")) {
            try BraceExpander.expand("pre{a,,b}post")
        }
    }
    
    @Test("Multiple middle empties {a,,,b} throws error")
    func multipleMiddleEmptiesThrows() throws {
        #expect(throws: BraceExpanderError.emptyAlternative("{a,,,b}")) {
            try BraceExpander.expand("{a,,,b}")
        }
    }
    
    @Test("Empty alternative in second brace group throws")
    func emptyInSecondGroupThrows() throws {
        #expect(throws: BraceExpanderError.emptyAlternative("{a,b}{c,}")) {
            try BraceExpander.expand("{a,b}{c,}")
        }
    }
    
    // MARK: - Performance Tests (T046)
    
    @Test("Expansion completes in <10ms for 3 brace groups (NFR-001)")
    func performanceThreeBraceGroups() throws {
        // Pattern with 3 brace groups: 2 × 2 × 2 = 8 patterns
        let pattern = "{src,test}/{foo,bar}/{a,b}.swift"
        
        let start = Date()
        let result = try BraceExpander.expand(pattern)
        let elapsed = Date().timeIntervalSince(start)
        
        // Verify correctness
        #expect(result.count == 8, "Should produce 8 patterns from 2×2×2")
        
        // Verify performance (NFR-001: <10ms)
        #expect(elapsed < 0.010, "Should complete in <10ms, took \(elapsed * 1000)ms")
    }
    
    @Test("Expansion handles 10 alternatives per group efficiently")
    func performanceTenAlternatives() throws {
        // Pattern with 10 alternatives (within typical usage)
        let pattern = "{a,b,c,d,e,f,g,h,i,j}{1,2,3}"
        
        let start = Date()
        let result = try BraceExpander.expand(pattern)
        let elapsed = Date().timeIntervalSince(start)
        
        // Verify correctness
        #expect(result.count == 30, "Should produce 10 × 3 = 30 patterns")
        
        // Verify performance
        #expect(elapsed < 0.010, "Should complete in <10ms, took \(elapsed * 1000)ms")
    }
}
