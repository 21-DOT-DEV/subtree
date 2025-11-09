import Testing
@testable import SubtreeLib

@Suite("String Extensions Tests")
struct StringExtensionsTests {
    
    // MARK: - normalized() Tests
    
    @Test("Trims leading whitespace")
    func testTrimsLeadingWhitespace() {
        #expect("  Hello".normalized() == "Hello")
        #expect("\tHello".normalized() == "Hello")
        #expect("\n\nHello".normalized() == "Hello")
    }
    
    @Test("Trims trailing whitespace")
    func testTrimsTrailingWhitespace() {
        #expect("Hello  ".normalized() == "Hello")
        #expect("Hello\t".normalized() == "Hello")
        #expect("Hello\n\n".normalized() == "Hello")
    }
    
    @Test("Trims both leading and trailing whitespace")
    func testTrimsBothWhitespace() {
        #expect("  Hello  ".normalized() == "Hello")
        #expect("\tHello\t".normalized() == "Hello")
        #expect("\n  Hello  \n".normalized() == "Hello")
    }
    
    @Test("Preserves internal whitespace")
    func testPreservesInternalWhitespace() {
        #expect("  Hello World  ".normalized() == "Hello World")
        #expect("  My Awesome Library  ".normalized() == "My Awesome Library")
    }
    
    @Test("Handles empty string")
    func testHandlesEmptyString() {
        #expect("".normalized() == "")
    }
    
    @Test("Handles whitespace-only string")
    func testHandlesWhitespaceOnlyString() {
        #expect("   ".normalized() == "")
        #expect("\t\n".normalized() == "")
    }
    
    @Test("Handles string without whitespace")
    func testHandlesNoWhitespace() {
        #expect("Hello".normalized() == "Hello")
        #expect("My-Library".normalized() == "My-Library")
    }
    
    @Test("Handles mixed whitespace types")
    func testHandlesMixedWhitespace() {
        #expect(" \t\nHello\n\t ".normalized() == "Hello")
    }
    
    // MARK: - matchesCaseInsensitive() Tests
    
    @Test("Matches identical strings")
    func testMatchesIdenticalStrings() {
        #expect("Hello".matchesCaseInsensitive("Hello") == true)
        #expect("test".matchesCaseInsensitive("test") == true)
    }
    
    @Test("Matches different cases")
    func testMatchesDifferentCases() {
        #expect("Hello".matchesCaseInsensitive("hello") == true)
        #expect("HELLO".matchesCaseInsensitive("hello") == true)
        #expect("HeLLo".matchesCaseInsensitive("hello") == true)
    }
    
    @Test("Matches mixed case variations")
    func testMatchesMixedCaseVariations() {
        #expect("Hello-World".matchesCaseInsensitive("hello-world") == true)
        #expect("My-Library".matchesCaseInsensitive("MY-LIBRARY") == true)
        #expect("VendorLib".matchesCaseInsensitive("vendorlib") == true)
    }
    
    @Test("Does not match different strings")
    func testDoesNotMatchDifferentStrings() {
        #expect("Hello".matchesCaseInsensitive("World") == false)
        #expect("test".matchesCaseInsensitive("testing") == false)
        #expect("lib".matchesCaseInsensitive("library") == false)
    }
    
    @Test("Handles empty strings")
    func testHandlesEmptyStringsInMatch() {
        #expect("".matchesCaseInsensitive("") == true)
        #expect("Hello".matchesCaseInsensitive("") == false)
        #expect("".matchesCaseInsensitive("Hello") == false)
    }
    
    @Test("Handles special characters")
    func testHandlesSpecialCharacters() {
        #expect("Test-Lib_v2.0".matchesCaseInsensitive("test-lib_v2.0") == true)
        #expect("My@Library!".matchesCaseInsensitive("my@library!") == true)
    }
    
    @Test("Handles whitespace in matching")
    func testHandlesWhitespaceInMatching() {
        #expect("Hello World".matchesCaseInsensitive("hello world") == true)
        #expect("Hello World".matchesCaseInsensitive("HELLO WORLD") == true)
    }
    
    @Test("Unicode case-folding works correctly")
    func testUnicodeCaseFolding() {
        // Swift's lowercased() correctly handles Unicode case-folding
        #expect("Café".matchesCaseInsensitive("Café") == true)
        // Swift correctly recognizes é and É as case variants (better than byte-for-byte)
        #expect("café".matchesCaseInsensitive("Café") == true)
        #expect("CAFÉ".matchesCaseInsensitive("café") == true)
    }
    
    @Test("Numbers are case-insensitive (no case to change)")
    func testNumbersAreCaseInsensitive() {
        #expect("lib123".matchesCaseInsensitive("LIB123") == true)
        #expect("v2.0".matchesCaseInsensitive("V2.0") == true)
    }
    
    // MARK: - Combined Usage Tests
    
    @Test("normalized() then matchesCaseInsensitive()")
    func testNormalizedThenMatch() {
        let input1 = "  Hello-World  ".normalized()
        let input2 = "  HELLO-WORLD  ".normalized()
        #expect(input1.matchesCaseInsensitive(input2) == true)
    }
    
    @Test("Whitespace differences after normalization")
    func testWhitespaceDifferencesAfterNormalization() {
        #expect("  test  ".normalized() == "test")
        #expect("\ttest\t".normalized() == "test")
        #expect("  test  ".normalized().matchesCaseInsensitive("\ttest\t".normalized()) == true)
    }
}
