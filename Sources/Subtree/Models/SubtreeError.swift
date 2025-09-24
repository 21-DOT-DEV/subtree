import Foundation

/// Custom error for proper exit codes
public enum SubtreeError: Error, CustomStringConvertible {
    case invalidUsage(String)
    case gitFailure(String)  
    case generalError(String)
    case configNotFound(String)
    case updatesAvailable(String)
    
    public var description: String {
        switch self {
        case .invalidUsage(let message):
            return "Error: \(message)"
        case .gitFailure(let message):
            return "Error: \(message)"
        case .generalError(let message):
            return "Error: \(message)"
        case .configNotFound(let message):
            return "Error: \(message)"
        case .updatesAvailable(let message):
            return "\(message)"  // Don't prefix with "Error:" for info messages
        }
    }
}

extension SubtreeError: LocalizedError {
    public var errorDescription: String? { description }
}

extension SubtreeError {
    public var exitCode: Int32 {
        switch self {
        case .invalidUsage:
            return 2
        case .gitFailure:
            return 3
        case .generalError:
            return 1
        case .configNotFound:
            return 4
        case .updatesAvailable:
            return 5
        }
    }
}
