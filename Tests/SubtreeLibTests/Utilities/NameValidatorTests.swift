import Testing
@testable import SubtreeLib

@Suite("NameValidator Tests")
struct NameValidatorTests {
    
    // MARK: - ASCII Detection
    
    @Test("Detects pure ASCII names")
    func testDetectsPureASCII() {
        #expect(NameValidator.containsNonASCII("Hello-World") == false)
        #expect(NameValidator.containsNonASCII("my-lib") == false)
        #expect(NameValidator.containsNonASCII("VendorLib123") == false)
        #expect(NameValidator.containsNonASCII("test_lib-v2.0") == false)
    }
    
    @Test("Detects non-ASCII characters")
    func testDetectsNonASCII() {
        #expect(NameValidator.containsNonASCII("Café") == true)
        #expect(NameValidator.containsNonASCII("Библиотека") == true)
        #expect(NameValidator.containsNonASCII("日本語") == true)
        #expect(NameValidator.containsNonASCII("München") == true)
    }
    
    @Test("Detects mixed ASCII and non-ASCII")
    func testDetectsMixedASCII() {
        #expect(NameValidator.containsNonASCII("My-Café") == true)
        #expect(NameValidator.containsNonASCII("lib-日本語") == true)
        #expect(NameValidator.containsNonASCII("München-Library") == true)
    }
    
    @Test("Handles empty string")
    func testHandlesEmptyString() {
        #expect(NameValidator.containsNonASCII("") == false)
    }
    
    @Test("Handles special ASCII characters")
    func testHandlesSpecialASCIIChars() {
        #expect(NameValidator.containsNonASCII("lib-!@#$%") == false)
        #expect(NameValidator.containsNonASCII("test_123()") == false)
        #expect(NameValidator.containsNonASCII("my.lib+plus") == false)
    }
    
    // MARK: - Warning Message Format
    
    @Test("Warning message contains name")
    func testWarningContainsName() {
        let warning = NameValidator.nonASCIIWarning(for: "Café")
        #expect(warning.contains("'Café'"))
    }
    
    @Test("Warning message has emoji prefix")
    func testWarningHasEmojiPrefix() {
        let warning = NameValidator.nonASCIIWarning(for: "Библиотека")
        #expect(warning.contains("⚠️") || warning.contains("Warning"))
    }
    
    @Test("Warning message explains limitation")
    func testWarningExplainsLimitation() {
        let warning = NameValidator.nonASCIIWarning(for: "日本語")
        #expect(warning.contains("non-ASCII"))
        #expect(warning.contains("Case-insensitive"))
        #expect(warning.contains("ASCII"))
    }
    
    @Test("Warning message is informational not error")
    func testWarningIsInformational() {
        let warning = NameValidator.nonASCIIWarning(for: "München")
        #expect(warning.contains("Warning") || warning.contains("⚠️"))
        #expect(!warning.contains("Error") && !warning.contains("❌"))
    }
    
    // MARK: - Edge Cases
    
    @Test("Handles ASCII emojis (single byte)")
    func testHandlesASCIIEmojis() {
        // Traditional ASCII "emojis" like :) are ASCII
        #expect(NameValidator.containsNonASCII("lib:)") == false)
        #expect(NameValidator.containsNonASCII("test<3") == false)
    }
    
    @Test("Detects Unicode emojis (multi-byte)")
    func testDetectsUnicodeEmojis() {
        // Real emojis are non-ASCII
        #expect(NameValidator.containsNonASCII("lib😀") == true)
        #expect(NameValidator.containsNonASCII("test🎉") == true)
    }
    
    @Test("Handles accented characters")
    func testHandlesAccentedChars() {
        #expect(NameValidator.containsNonASCII("naïve") == true)
        #expect(NameValidator.containsNonASCII("résumé") == true)
        #expect(NameValidator.containsNonASCII("señor") == true)
    }
    
    @Test("Handles extended ASCII (above 127)")
    func testHandlesExtendedASCII() {
        // Characters above ASCII 127 should be detected as non-ASCII
        let extendedChar = String(UnicodeScalar(200)!)
        #expect(NameValidator.containsNonASCII(extendedChar) == true)
    }
}
