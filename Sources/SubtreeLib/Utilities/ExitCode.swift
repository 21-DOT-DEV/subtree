/// Exit codes for the subtree CLI
///
/// These codes follow Unix conventions:
/// - 0: Success
/// - 1-2: General errors and misuse
/// - 3+: Application-specific errors
public enum ExitCode: Int32 {
    /// Successful execution
    case success = 0
    
    /// General error (catch-all for unexpected failures)
    case generalError = 1
    
    /// Command misuse (invalid arguments, wrong usage)
    case misuse = 2
    
    /// Configuration error (invalid or missing subtree.yaml)
    case configError = 3
    
    /// Git operation error (git command failed)
    case gitError = 4
}
