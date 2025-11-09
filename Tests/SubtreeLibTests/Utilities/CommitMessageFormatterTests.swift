import Testing
@testable import SubtreeLib

/// Tests for CommitMessageFormatter utility
@Suite("CommitMessageFormatter Tests")
struct CommitMessageFormatterTests {
    
    // T018 - Test message format structure
    @Test("Format commit message structure")
    func testMessageFormatStructure() {
        let message = CommitMessageFormatter.format(
            name: "secp256k1",
            ref: "v0.7.0",
            refType: "tag",
            commit: "bf4f0bc8ae9b488c5dbbadb24f3566ead2f3fc97",
            remote: "https://github.com/bitcoin-core/secp256k1",
            prefix: "Vendors/secp256k1"
        )
        
        // Expected format:
        // Add subtree secp256k1
        // - Added from tag: v0.7.0 (commit: bf4f0bc8)
        // - From: https://github.com/bitcoin-core/secp256k1
        // - In: Vendors/secp256k1
        
        #expect(message.contains("Add subtree secp256k1"))
        #expect(message.contains("- Added from tag: v0.7.0 (commit: bf4f0bc8)"))
        #expect(message.contains("- From: https://github.com/bitcoin-core/secp256k1"))
        #expect(message.contains("- In: Vendors/secp256k1"))
    }
    
    // T019 - Test ref-type derivation (tag vs branch)
    @Test("Derive ref-type with regex ^v?\\d+\\.\\d+(\\.\\d+)?")
    func testRefTypeDerivation() {
        // Tags with 'v' prefix
        #expect(CommitMessageFormatter.deriveRefType(from: "v1.0.0") == "tag")
        #expect(CommitMessageFormatter.deriveRefType(from: "v0.7.0") == "tag")
        #expect(CommitMessageFormatter.deriveRefType(from: "v2.1") == "tag")
        
        // Tags without 'v' prefix
        #expect(CommitMessageFormatter.deriveRefType(from: "1.0.0") == "tag")
        #expect(CommitMessageFormatter.deriveRefType(from: "0.7.0") == "tag")
        #expect(CommitMessageFormatter.deriveRefType(from: "2.1") == "tag")
        
        // Branches
        #expect(CommitMessageFormatter.deriveRefType(from: "main") == "branch")
        #expect(CommitMessageFormatter.deriveRefType(from: "develop") == "branch")
        #expect(CommitMessageFormatter.deriveRefType(from: "feature/xyz") == "branch")
        #expect(CommitMessageFormatter.deriveRefType(from: "bugfix/123") == "branch")
    }
    
    // T020 - Test short-hash extraction
    @Test("Extract short-hash (first 8 chars)")
    func testShortHashExtraction() {
        let fullHash = "bf4f0bc8ae9b488c5dbbadb24f3566ead2f3fc97"
        let shortHash = CommitMessageFormatter.shortHash(from: fullHash)
        
        #expect(shortHash == "bf4f0bc8")
        #expect(shortHash.count == 8)
    }
}
