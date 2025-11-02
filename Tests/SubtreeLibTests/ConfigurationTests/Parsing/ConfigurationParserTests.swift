import Testing
import Foundation
@testable import SubtreeLib

@Suite("ConfigurationParser Tests")
struct ConfigurationParserTests {
    
    @Test("Parse valid YAML with subtrees (FR-025)")
    func parseValidYAML() throws {
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
    
    @Test("Parse empty subtrees array (FR-031)")
    func parseEmptyArray() throws {
        let yaml = """
        subtrees: []
        """
        
        let config = try ConfigurationParser.parse(yaml: yaml)
        #expect(config.subtrees.isEmpty)
    }
    
    @Test("Handle missing file (FR-027)")
    func handleMissingFile() throws {
        #expect(throws: (any Error).self) {
            let _ = try ConfigurationParser.parseFile(at: "/nonexistent/path.yaml")
        }
    }
    
    @Test("Handle malformed YAML (FR-026)")
    func handleMalformedYAML() throws {
        let badYAML = """
        subtrees:
          - name: "unclosed quote
        """
        
        #expect(throws: (any Error).self) {
            let _ = try ConfigurationParser.parse(yaml: badYAML)
        }
    }
    
    @Test("Handle empty file (FR-028)")
    func handleEmptyFile() throws {
        let emptyYAML = ""
        
        #expect(throws: (any Error).self) {
            let _ = try ConfigurationParser.parse(yaml: emptyYAML)
        }
    }
}
