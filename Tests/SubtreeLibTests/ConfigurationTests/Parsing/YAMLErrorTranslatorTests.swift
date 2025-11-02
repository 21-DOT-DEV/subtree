import Testing
import Foundation
import Yams
@testable import SubtreeLib

@Suite("YAMLErrorTranslator Tests")
struct YAMLErrorTranslatorTests {
    
    @Test("Translate YAML error to ConfigurationError")
    func translateYAMLError() throws {
        // Create a simple YAML parse error
        struct TestError: Error {}
        let testError = TestError()
        
        let result = YAMLErrorTranslator.translate(error: testError)
        
        // Should return a ConfigurationError with yamlSyntaxError case
        if case .yamlSyntaxError = result {
            // Success - error was translated
        } else {
            #expect(Bool(false), "Expected yamlSyntaxError case")
        }
    }
    
    @Test("Pass through ConfigurationError unchanged")
    func passThroughConfigurationError() throws {
        let originalError = ConfigurationError.emptyFile
        
        let result = YAMLErrorTranslator.translate(error: originalError)
        
        // Should be the same error
        if case .emptyFile = result {
            // Success
        } else {
            #expect(Bool(false), "Expected emptyFile error")
        }
    }
    
    @Test("Provide user-friendly message for YAML syntax errors")
    func userFriendlyMessage() throws {
        struct YAMLSyntaxError: Error, CustomStringConvertible {
            var description: String { "Scanner error at line 5" }
        }
        
        let result = YAMLErrorTranslator.translate(error: YAMLSyntaxError())
        
        // Should contain user-friendly guidance
        #expect(result.description.contains("YAML") || result.description.contains("syntax"))
    }
}
