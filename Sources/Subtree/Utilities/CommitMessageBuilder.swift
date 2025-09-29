import Foundation

/// Builds enhanced commit messages for subtree operations
struct CommitMessageBuilder {
    
    enum Operation {
        case add
        case update  
        case remove
    }
    
    struct SubtreeState {
        let name: String
        let remote: String
        let prefix: String
        let ref: String  // branch, tag, or commit
        let commit: String?  // resolved commit SHA
        let refType: RefType
        
        enum RefType {
            case branch
            case tag
            case commit
        }
    }
    
    /// Build enhanced commit message for subtree operations
    static func buildMessage(
        operation: Operation,
        currentState: SubtreeState,
        previousState: SubtreeState? = nil
    ) -> String {
        
        switch operation {
        case .add:
            return buildAddMessage(currentState: currentState)
        case .update:
            return buildUpdateMessage(currentState: currentState, previousState: previousState)
        case .remove:
            return buildRemoveMessage(previousState: previousState ?? currentState)
        }
    }
    
    private static func buildAddMessage(currentState: SubtreeState) -> String {
        var message = "Add subtree \(currentState.name)"
        
        // Add the structured details
        switch currentState.refType {
        case .tag:
            let commitInfo = currentState.commit.map { " (commit: \(String($0.prefix(8))))" } ?? ""
            message += "\n- Added from tag: \(currentState.ref)\(commitInfo)"
        case .branch:
            let commitInfo = currentState.commit.map { " (commit: \(String($0.prefix(8))))" } ?? ""
            message += "\n- Added from branch: \(currentState.ref)\(commitInfo)"
        case .commit:
            message += "\n- Added from commit: \(String(currentState.ref.prefix(8)))"
        }
        
        message += "\n- From: \(currentState.remote)"
        message += "\n- In: \(currentState.prefix)"
        
        return message
    }
    
    private static func buildUpdateMessage(
        currentState: SubtreeState,
        previousState: SubtreeState?
    ) -> String {
        var message: String
        
        // Handle tag transitions with special title format
        if let prev = previousState,
           currentState.refType == .tag && prev.refType == .tag {
            message = "Update subtree \(currentState.name) (\(prev.ref) -> \(currentState.ref))"
        } else {
            message = "Update subtree \(currentState.name)"
        }
        
        // Add structured update details
        if let prev = previousState {
            message += buildUpdateTransitionInfo(from: prev, to: currentState)
        } else {
            // No previous state available - show current state
            switch currentState.refType {
            case .tag:
                let commitInfo = currentState.commit.map { " (commit: \(String($0.prefix(8))))" } ?? ""
                message += "\n- Updated to tag: \(currentState.ref)\(commitInfo)"
            case .branch:
                let commitInfo = currentState.commit.map { " (commit: \(String($0.prefix(8))))" } ?? ""
                message += "\n- Updated to branch: \(currentState.ref)\(commitInfo)"
            case .commit:
                message += "\n- Updated to commit: \(String(currentState.ref.prefix(8)))"
            }
        }
        
        message += "\n- From: \(currentState.remote)"
        message += "\n- In: \(currentState.prefix)"
        
        return message
    }
    
    private static func buildRemoveMessage(previousState: SubtreeState) -> String {
        var message = "Remove subtree \(previousState.name)"
        
        // Add last commit info
        if let commit = previousState.commit {
            message += "\n- Last commit: \(String(commit.prefix(8)))"
        }
        
        message += "\n- From: \(previousState.remote)"
        message += "\n- In: \(previousState.prefix)"
        
        return message
    }
    
    private static func buildUpdateTransitionInfo(
        from previousState: SubtreeState,
        to currentState: SubtreeState
    ) -> String {
        var info = ""
        
        // Show the update details based on type
        switch (previousState.refType, currentState.refType) {
        case (.tag, .tag):
            let commitInfo = currentState.commit.map { " (commit: \(String($0.prefix(8))))" } ?? ""
            info += "\n- Updated to tag: \(currentState.ref)\(commitInfo)"
            
        case (.branch, .branch) where previousState.ref == currentState.ref:
            // Same branch, different commits
            info += "\n- Updated to commit: \(currentState.commit.map { String($0.prefix(8)) } ?? "unknown")"
            if let prevCommit = previousState.commit {
                info += "\n- Previous commit: \(String(prevCommit.prefix(8)))"
            }
            
        case (.branch, .branch):
            // Different branches
            let commitInfo = currentState.commit.map { " (commit: \(String($0.prefix(8))))" } ?? ""
            info += "\n- Updated to branch: \(currentState.ref)\(commitInfo)"
            if let prevCommit = previousState.commit {
                info += "\n- Previous commit: \(String(prevCommit.prefix(8)))"
            }
            
        case (.commit, .commit):
            info += "\n- Updated to commit: \(String(currentState.ref.prefix(8)))"
            info += "\n- Previous commit: \(String(previousState.ref.prefix(8)))"
            
        default:
            // Mixed types (e.g., branch to tag, tag to branch)
            switch currentState.refType {
            case .tag:
                let commitInfo = currentState.commit.map { " (commit: \(String($0.prefix(8))))" } ?? ""
                info += "\n- Updated to tag: \(currentState.ref)\(commitInfo)"
            case .branch:
                let commitInfo = currentState.commit.map { " (commit: \(String($0.prefix(8))))" } ?? ""
                info += "\n- Updated to branch: \(currentState.ref)\(commitInfo)"
            case .commit:
                info += "\n- Updated to commit: \(String(currentState.ref.prefix(8)))"
            }
            
            if let prevCommit = previousState.commit {
                info += "\n- Previous commit: \(String(prevCommit.prefix(8)))"
            }
        }
        
        return info
    }
    
    private static func formatRef(_ state: SubtreeState) -> String {
        switch state.refType {
        case .tag:
            return "tag \(state.ref)"
        case .branch:
            return "branch \(state.ref)"
        case .commit:
            return "commit \(String(state.ref.prefix(8)))"
        }
    }
    
    /// Determine ref type from git ref string
    static func determineRefType(_ ref: String) -> SubtreeState.RefType {
        // Check if it looks like a commit SHA (40 hex characters)
        if ref.count == 40 {
            let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
            if ref.unicodeScalars.allSatisfy({ hexCharacters.contains($0) }) {
                return .commit
            }
        }
        
        // Check if it starts with 'v' followed by numbers (common tag pattern)
        if ref.hasPrefix("v") && ref.dropFirst().first?.isNumber == true {
            return .tag
        }
        
        // Check for semantic version pattern (e.g., "1.2.3", "2.0.0-beta")
        let semverPattern = #"^\d+\.\d+\.\d+.*$"#
        if ref.range(of: semverPattern, options: .regularExpression) != nil {
            return .tag
        }
        
        // Default to branch
        return .branch
    }
}

extension Character {
    var isHexDigit: Bool {
        return self.isNumber || ("a"..."f").contains(self.lowercased())
    }
}
