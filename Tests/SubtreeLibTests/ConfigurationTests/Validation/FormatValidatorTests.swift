import Testing
import Foundation
@testable import SubtreeLib

@Suite("FormatValidator Tests")
struct FormatValidatorTests {
    
    @Test("Validate remote URL format (FR-006)")
    func validateRemoteURLFormat() throws {
        let validator = FormatValidator()
        
        // Valid URLs should pass
        let validHTTPS = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678"
        )
        let httpsErrors = validator.validate(validHTTPS, index: 0)
        #expect(httpsErrors.filter { $0.field == "remote" }.isEmpty)
        
        let validSSH = SubtreeEntry(
            name: "test",
            remote: "git@github.com:org/repo.git",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678"
        )
        let sshErrors = validator.validate(validSSH, index: 0)
        #expect(sshErrors.filter { $0.field == "remote" }.isEmpty)
        
        // Invalid URL should fail
        let invalidURL = SubtreeEntry(
            name: "test",
            remote: "ftp://invalid.com/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678"
        )
        let errors = validator.validate(invalidURL, index: 0)
        #expect(errors.contains { $0.field == "remote" })
    }
    
    @Test("Validate prefix path safety (FR-007)")
    func validatePrefixPathSafety() throws {
        let validator = FormatValidator()
        
        // Valid relative path should pass
        let validPath = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678"
        )
        let noErrors = validator.validate(validPath, index: 0)
        #expect(noErrors.filter { $0.field == "prefix" }.isEmpty)
        
        // Absolute path should fail
        let absolutePath = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "/usr/local/lib",
            commit: "1234567890abcdef1234567890abcdef12345678"
        )
        let absErrors = validator.validate(absolutePath, index: 0)
        #expect(absErrors.contains { $0.field == "prefix" })
        
        // Path with .. should fail
        let unsafePath = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "../outside/repo",
            commit: "1234567890abcdef1234567890abcdef12345678"
        )
        let unsafeErrors = validator.validate(unsafePath, index: 0)
        #expect(unsafeErrors.contains { $0.field == "prefix" })
    }
    
    @Test("Validate commit hash format (FR-008)")
    func validateCommitHashFormat() throws {
        let validator = FormatValidator()
        
        // Valid 40-char hex should pass
        let validCommit = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "1234567890abcdef1234567890abcdef12345678"
        )
        let noErrors = validator.validate(validCommit, index: 0)
        #expect(noErrors.filter { $0.field == "commit" }.isEmpty)
        
        // Short commit should fail
        let shortCommit = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "short123"
        )
        let shortErrors = validator.validate(shortCommit, index: 0)
        #expect(shortErrors.contains { $0.field == "commit" })
        
        // Non-hex characters should fail
        let invalidChars = SubtreeEntry(
            name: "test",
            remote: "https://github.com/org/repo",
            prefix: "Vendors/test",
            commit: "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
        )
        let charErrors = validator.validate(invalidChars, index: 0)
        #expect(charErrors.contains { $0.field == "commit" })
    }
}
