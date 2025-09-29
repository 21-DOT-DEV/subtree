import Testing
import Foundation
@testable import Subtree

struct CommitMessageBuilderTests {
    
    @Test("build add message for branch")
    func testBuildAddMessageForBranch() {
        let state = CommitMessageBuilder.SubtreeState(
            name: "example-lib",
            remote: "https://github.com/example/lib.git",
            prefix: "Vendor/lib",
            ref: "main",
            commit: "abc1234567890abcdef1234567890abcdef123456",
            refType: .branch
        )
        
        let message = CommitMessageBuilder.buildMessage(
            operation: .add,
            currentState: state
        )
        
        #expect(message.contains("Add subtree example-lib"))
        #expect(message.contains("- Added from branch: main (commit: abc12345)"))
        #expect(message.contains("- From: https://github.com/example/lib.git"))
        #expect(message.contains("- In: Vendor/lib"))
    }
    
    @Test("build add message for tag")
    func testBuildAddMessageForTag() {
        let state = CommitMessageBuilder.SubtreeState(
            name: "example-lib",
            remote: "https://github.com/example/lib.git",
            prefix: "Vendor/lib",
            ref: "v1.2.0",
            commit: "def4567890abcdef1234567890abcdef12345678",
            refType: .tag
        )
        
        let message = CommitMessageBuilder.buildMessage(
            operation: .add,
            currentState: state
        )
        
        #expect(message.contains("Add subtree example-lib"))
        #expect(message.contains("- Added from tag: v1.2.0 (commit: def45678)"))
        #expect(message.contains("- From: https://github.com/example/lib.git"))
        #expect(message.contains("- In: Vendor/lib"))
    }
    
    @Test("build update message with tag transition")
    func testBuildUpdateMessageWithTagTransition() {
        let previousState = CommitMessageBuilder.SubtreeState(
            name: "example-lib",
            remote: "https://github.com/example/lib.git",
            prefix: "Vendor/lib",
            ref: "v1.2.0",
            commit: "abc1234567890abcdef1234567890abcdef123456",
            refType: .tag
        )
        
        let currentState = CommitMessageBuilder.SubtreeState(
            name: "example-lib",
            remote: "https://github.com/example/lib.git",
            prefix: "Vendor/lib",
            ref: "v1.3.0",
            commit: "def4567890abcdef1234567890abcdef12345678",
            refType: .tag
        )
        
        let message = CommitMessageBuilder.buildMessage(
            operation: .update,
            currentState: currentState,
            previousState: previousState
        )
        
        #expect(message.contains("Update subtree example-lib (v1.2.0 -> v1.3.0)"))
        #expect(message.contains("- Updated to tag: v1.3.0 (commit: def45678)"))
        #expect(message.contains("- From: https://github.com/example/lib.git"))
        #expect(message.contains("- In: Vendor/lib"))
    }
    
    @Test("build update message for branch with same ref")
    func testBuildUpdateMessageForBranchSameRef() {
        let previousState = CommitMessageBuilder.SubtreeState(
            name: "example-lib",
            remote: "https://github.com/example/lib.git",
            prefix: "Vendor/lib",
            ref: "main",
            commit: "abc1234567890abcdef1234567890abcdef123456",
            refType: .branch
        )
        
        let currentState = CommitMessageBuilder.SubtreeState(
            name: "example-lib",
            remote: "https://github.com/example/lib.git",
            prefix: "Vendor/lib",
            ref: "main",
            commit: "def4567890abcdef1234567890abcdef12345678",
            refType: .branch
        )
        
        let message = CommitMessageBuilder.buildMessage(
            operation: .update,
            currentState: currentState,
            previousState: previousState
        )
        
        #expect(message.contains("Update subtree example-lib"))
        #expect(message.contains("- Updated to commit: def45678"))
        #expect(message.contains("- Previous commit: abc12345"))
        #expect(message.contains("- From: https://github.com/example/lib.git"))
        #expect(message.contains("- In: Vendor/lib"))
    }
    
    @Test("build remove message")
    func testBuildRemoveMessage() {
        let state = CommitMessageBuilder.SubtreeState(
            name: "example-lib",
            remote: "https://github.com/example/lib.git",
            prefix: "Vendor/lib",
            ref: "v1.2.0",
            commit: "abc1234567890abcdef1234567890abcdef123456",
            refType: .tag
        )
        
        let message = CommitMessageBuilder.buildMessage(
            operation: .remove,
            currentState: state
        )
        
        #expect(message.contains("Remove subtree example-lib"))
        #expect(message.contains("- Last commit: abc12345"))
        #expect(message.contains("- From: https://github.com/example/lib.git"))
        #expect(message.contains("- In: Vendor/lib"))
    }
    
    @Test("determine ref type")
    func testDetermineRefType() {
        // Test commit SHA - use a real git commit SHA format
        let commitSHA = "abcdef1234567890abcdef1234567890abcdef12"
        #expect(commitSHA.count == 40)  // Verify length
        #expect(CommitMessageBuilder.determineRefType(commitSHA) == .commit)
        
        // Test version tags
        #expect(CommitMessageBuilder.determineRefType("v1.2.0") == .tag)
        #expect(CommitMessageBuilder.determineRefType("v2.0.0-beta.1") == .tag)
        
        // Test semantic version
        #expect(CommitMessageBuilder.determineRefType("1.2.3") == .tag)
        #expect(CommitMessageBuilder.determineRefType("2.0.0-alpha") == .tag)
        
        // Test branches
        #expect(CommitMessageBuilder.determineRefType("main") == .branch)
        #expect(CommitMessageBuilder.determineRefType("develop") == .branch)
        #expect(CommitMessageBuilder.determineRefType("feature/awesome") == .branch)
    }
}
