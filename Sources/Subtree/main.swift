import Foundation
import ArgumentParser

do {
    var command = try SubtreeCLI.parseAsRoot()
    try command.run()
} catch let error as SubtreeError {
    FileHandle.standardError.write("\(error.description)\n".data(using: .utf8) ?? Data())
    exit(error.exitCode)
} catch {
    SubtreeCLI.exit(withError: error)
}
