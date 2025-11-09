import Testing
import Foundation
@testable import SubtreeLib

@Suite("GlobPatternValidator Tests")
struct GlobPatternValidatorTests {
    
    @Test("Validate simple glob patterns are valid (US3)")
    func validateSimplePatterns() throws {
        let validator = GlobPatternValidator()
        
        // Simple wildcards should pass
        #expect(validator.isValid("*.h"))
        #expect(validator.isValid("include/*.h"))
        #expect(validator.isValid("src/*.c"))
        #expect(validator.isValid("test?.txt"))
    }
    
    @Test("Validate globstar (**) pattern (US3, FR-019)")
    func validateGlobstarPattern() throws {
        let validator = GlobPatternValidator()
        
        // Globstar (recursive match) should pass
        #expect(validator.isValid("src/**/*.h"))
        #expect(validator.isValid("**/test.c"))
        #expect(validator.isValid("lib/**"))
    }
    
    @Test("Validate brace expansion ({...}) pattern (US3, FR-019)")
    func validateBraceExpansion() throws {
        let validator = GlobPatternValidator()
        
        // Brace expansion should pass
        #expect(validator.isValid("src/**/*.{h,c}"))
        #expect(validator.isValid("*.{jpg,png,gif}"))
        #expect(validator.isValid("{src,include}/**/*.h"))
        
        // Nested braces
        #expect(validator.isValid("**/*.{h,{c,cpp}}"))
    }
    
    @Test("Validate character classes ([...]) pattern (US3, FR-019)")
    func validateCharacterClasses() throws {
        let validator = GlobPatternValidator()
        
        // Character classes should pass
        #expect(validator.isValid("file[0-9].txt"))
        #expect(validator.isValid("test[abc].h"))
        #expect(validator.isValid("[A-Z]*.c"))
        #expect(validator.isValid("file[!0-9].txt")) // Negation
    }
    
    @Test("Reject unclosed brace pattern (US3)")
    func rejectUnclosedBrace() throws {
        let validator = GlobPatternValidator()
        
        // Unclosed braces should fail
        #expect(!validator.isValid("src/**/*.{h,c"))
        #expect(!validator.isValid("*.{jpg,png"))
        #expect(!validator.isValid("{src,include/**/*.h"))
    }
    
    @Test("Reject unclosed bracket pattern (US3)")
    func rejectUnclosedBracket() throws {
        let validator = GlobPatternValidator()
        
        // Unclosed brackets should fail
        #expect(!validator.isValid("file[0-9.txt"))
        #expect(!validator.isValid("test[abc.h"))
        #expect(!validator.isValid("[A-Z*.c"))
    }
    
    @Test("Complex real-world patterns are valid")
    func validateComplexPatterns() throws {
        let validator = GlobPatternValidator()
        
        // Real-world examples from spec
        #expect(validator.isValid("include/*.h"))
        #expect(validator.isValid("src/**/*.{h,c}"))
        #expect(validator.isValid("src/**/bench*/**"))
        #expect(validator.isValid("src/**/test*/**"))
        #expect(validator.isValid("src/precompute_*.c"))
    }
    
    @Test("Validate pattern returns error message for invalid patterns")
    func validatePatternErrorMessages() throws {
        let validator = GlobPatternValidator()
        
        let result1 = validator.validate("src/**/*.{h,c")
        #expect(result1.isValid == false)
        #expect(result1.errorMessage?.contains("brace") ?? false)
        
        let result2 = validator.validate("file[0-9.txt")
        #expect(result2.isValid == false)
        #expect(result2.errorMessage?.contains("bracket") ?? false)
    }
}
