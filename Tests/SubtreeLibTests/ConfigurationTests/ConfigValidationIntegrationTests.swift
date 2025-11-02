import Testing
import Foundation
@testable import SubtreeLib

@Suite("Configuration Validation Integration Tests")
struct ConfigValidationIntegrationTests {
    
    // MARK: - User Story 1: Valid Configuration Loading
    
    @Test("Parse valid minimal config (US1)")
    func parseValidMinimalConfig() throws {
        let yaml = """
        subtrees:
          - name: test
            remote: https://github.com/org/repo
            prefix: Vendors/test
            commit: 1234567890abcdef1234567890abcdef12345678
        """
        
        let config = try ConfigurationParser.parse(yaml: yaml)
        #expect(config.subtrees.count == 1)
        #expect(config.subtrees.first?.name == "test")
    }
    
    @Test("Parse valid config with optional fields (US1)")
    func parseValidConfigWithOptionalFields() throws {
        let yaml = """
        subtrees:
          - name: secp256k1
            remote: https://github.com/bitcoin-core/secp256k1
            prefix: Vendors/secp256k1
            commit: bf4f0bc877e4d6771e48611cc9e66ab9db576bac
            tag: v0.7.0
            squash: true
        """
        
        let config = try ConfigurationParser.parse(yaml: yaml)
        #expect(config.subtrees.count == 1)
        #expect(config.subtrees.first?.tag == "v0.7.0")
        #expect(config.subtrees.first?.squash == true)
    }
    
    @Test("Parse valid config with multiple subtrees (US1)")
    func parseValidConfigWithMultipleSubtrees() throws {
        let yaml = """
        subtrees:
          - name: lib1
            remote: https://github.com/org/repo1
            prefix: Vendors/lib1
            commit: 1234567890abcdef1234567890abcdef12345678
          - name: lib2
            remote: https://github.com/org/repo2
            prefix: Vendors/lib2
            commit: abcdef1234567890abcdef1234567890abcdef12
        """
        
        let config = try ConfigurationParser.parse(yaml: yaml)
        #expect(config.subtrees.count == 2)
        #expect(config.subtrees[0].name == "lib1")
        #expect(config.subtrees[1].name == "lib2")
    }
    
    @Test("Parse empty subtrees array (US1, FR-031)")
    func parseEmptySubtreesArray() throws {
        let yaml = """
        subtrees: []
        """
        
        let config = try ConfigurationParser.parse(yaml: yaml)
        #expect(config.subtrees.isEmpty)
    }
    
    // MARK: - User Story 2: Error Validation
    
    @Test("Invalid commit format produces clear error (US2)")
    func invalidCommitFormatError() throws {
        let yaml = """
        subtrees:
          - name: bad
            remote: https://github.com/org/repo
            prefix: Vendors/bad
            commit: short123
        """
        
        // Should parse but validation should catch invalid commit
        let config = try ConfigurationParser.parse(yaml: yaml)
        let validator = ConfigurationValidator()
        let errors = validator.validate(config)
        
        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.field == "commit" })
        #expect(errors.contains { $0.message.contains("40") })
    }
    
    @Test("Tag and branch conflict produces clear error (US2)")
    func tagBranchConflictError() throws {
        let yaml = """
        subtrees:
          - name: conflict
            remote: https://github.com/org/repo
            prefix: Vendors/conflict
            commit: 1234567890abcdef1234567890abcdef12345678
            tag: v1.0.0
            branch: main
        """
        
        let config = try ConfigurationParser.parse(yaml: yaml)
        let validator = ConfigurationValidator()
        let errors = validator.validate(config)
        
        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.message.contains("both") || $0.message.contains("Cannot specify") })
    }
    
    @Test("Invalid remote URL produces clear error (US2)")
    func invalidRemoteURLError() throws {
        let yaml = """
        subtrees:
          - name: bad-remote
            remote: ftp://invalid.com/repo
            prefix: Vendors/bad
            commit: 1234567890abcdef1234567890abcdef12345678
        """
        
        let config = try ConfigurationParser.parse(yaml: yaml)
        let validator = ConfigurationValidator()
        let errors = validator.validate(config)
        
        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.field == "remote" })
    }
    
    @Test("Unsafe path produces clear error (US2)")
    func unsafePathError() throws {
        let yaml = """
        subtrees:
          - name: unsafe
            remote: https://github.com/org/repo
            prefix: ../outside/repo
            commit: 1234567890abcdef1234567890abcdef12345678
        """
        
        let config = try ConfigurationParser.parse(yaml: yaml)
        let validator = ConfigurationValidator()
        let errors = validator.validate(config)
        
        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.field == "prefix" })
        #expect(errors.contains { $0.message.contains("..") || $0.message.contains("unsafe") })
    }
    
    @Test("Duplicate names produce clear error (US2, FR-030)")
    func duplicateNamesError() throws {
        let yaml = """
        subtrees:
          - name: lib
            remote: https://github.com/org/repo1
            prefix: Vendors/lib1
            commit: 1234567890abcdef1234567890abcdef12345678
          - name: lib
            remote: https://github.com/org/repo2
            prefix: Vendors/lib2
            commit: abcdef1234567890abcdef1234567890abcdef12
        """
        
        let config = try ConfigurationParser.parse(yaml: yaml)
        let validator = ConfigurationValidator()
        let errors = validator.validate(config)
        
        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.field == "name" && $0.message.contains("Duplicate") })
    }
    
    @Test("Multiple errors collected together (US2, FR-024)")
    func multipleErrorsCollected() throws {
        let yaml = """
        subtrees:
          - name: bad1
            remote: ftp://bad.com
            prefix: ../unsafe
            commit: short
          - name: bad1
            remote: https://github.com/org/repo
            prefix: Vendors/dup
            commit: 1234567890abcdef1234567890abcdef12345678
        """
        
        let config = try ConfigurationParser.parse(yaml: yaml)
        let validator = ConfigurationValidator()
        let errors = validator.validate(config)
        
        // Should collect multiple errors: bad remote, unsafe path, short commit, duplicate name
        #expect(errors.count >= 3)
    }
    
    @Test("YAML syntax error is user-friendly (US2, FR-026)")
    func yamlSyntaxErrorUserFriendly() throws {
        let badYAML = """
        subtrees:
          - name: "unclosed quote
        """
        
        #expect(throws: ConfigurationError.self) {
            let _ = try ConfigurationParser.parse(yaml: badYAML)
        }
    }
    
    // MARK: - User Stories 3+4: Extract Pattern Validation
    
    @Test("Valid extract patterns parse successfully (US3)")
    func validExtractPatterns() throws {
        let yaml = """
        subtrees:
          - name: lib
            remote: https://github.com/org/repo
            prefix: Vendors/lib
            commit: 1234567890abcdef1234567890abcdef12345678
            extracts:
              - from: include/*.h
                to: Sources/lib/include/
              - from: src/**/*.{h,c}
                to: Sources/lib/src/
                exclude:
                  - src/**/test*
                  - src/**/bench*
        """
        
        let config = try ConfigurationParser.parse(yaml: yaml)
        #expect(config.subtrees.count == 1)
        #expect(config.subtrees.first?.extracts?.count == 2)
    }
    
    @Test("Invalid glob pattern produces error (US3)")
    func invalidGlobPatternError() throws {
        let yaml = """
        subtrees:
          - name: bad-glob
            remote: https://github.com/org/repo
            prefix: Vendors/bad
            commit: 1234567890abcdef1234567890abcdef12345678
            extracts:
              - from: "src/**/*.{h,c"
                to: Sources/lib/
        """
        
        let config = try ConfigurationParser.parse(yaml: yaml)
        let validator = ConfigurationValidator()
        let errors = validator.validate(config)
        
        // Should detect invalid glob pattern
        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.field.contains("from") && $0.message.contains("glob") })
    }
}
