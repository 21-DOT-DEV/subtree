import Foundation
import Subprocess
#if canImport(System)
import System
#else
import SystemPackage
#endif

/// Result of running a subprocess command
public struct CommandResult {
    public let exitStatus: Int
    public let stdout: String
    public let stderr: String
    
    public var isSuccess: Bool { exitStatus == 0 }
}

/// Helper utilities for running subprocess commands in tests
public enum SubprocessHelpers {
    
    /// Run a command and capture its output
    public static func run(
        _ executable: Subprocess.Executable,
        arguments: [String] = [],
        workingDirectory: URL? = nil
    ) async throws -> CommandResult {
        
        let workingDir = workingDirectory.map { FilePath($0.path) }
        
        let result = try await Subprocess.run(
            executable,
            arguments: .init(arguments),
            workingDirectory: workingDir,
            output: .string(limit: 65536),
            error: .string(limit: 65536)
        )
        
        let exitCode: Int
        if case .exited(let code) = result.terminationStatus {
            exitCode = Int(code)
        } else {
            exitCode = -1 // Non-zero for any other termination
        }
        
        return CommandResult(
            exitStatus: exitCode,
            stdout: result.standardOutput ?? "",
            stderr: result.standardError ?? ""
        )
    }
    
    /// Run the subtree CLI with given arguments
    public static func runSubtreeCLI(
        arguments: [String] = [],
        workingDirectory: URL? = nil
    ) async throws -> CommandResult {
        // Use the built executable directly instead of 'swift run'
        // This avoids Package.swift lookup issues in test directories
        let executablePath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build")
            .appendingPathComponent("arm64-apple-macosx")
            .appendingPathComponent("debug")
            .appendingPathComponent("subtree")
        
        return try await run(
            .path(FilePath(executablePath.path)),
            arguments: arguments,
            workingDirectory: workingDirectory
        )
    }
}
