import Foundation

/// Errors that can occur during glob pattern parsing or matching
public enum GlobMatcherError: Error, Equatable {
    case emptyPattern
    case unclosedBracket(String)
    case unclosedBrace(String)
    case invalidRange(String)
    case emptyCharacterClass(String)
}

/// Matches file paths against glob patterns
///
/// Supports standard glob syntax:
/// - `*` - matches any characters except directory separator (single level)
/// - `**` - matches any characters including directory separator (recursive)
/// - `?` - matches exactly one character
/// - `[abc]` - matches any character in the set
/// - `[a-z]` - matches any character in the range
/// - `{a,b,c}` - brace expansion (matches any of the alternatives)
///
/// Pattern matching is case-sensitive and operates on path strings only (no filesystem access).
public struct GlobMatcher {
    private let pattern: String
    private let components: [PatternComponent]

    /// Initialize a glob matcher with a pattern
    ///
    /// - Parameter pattern: Glob pattern to match against
    /// - Throws: `GlobMatcherError` if pattern is invalid
    public init(pattern: String) throws {
        guard !pattern.isEmpty else {
            throw GlobMatcherError.emptyPattern
        }

        self.pattern = pattern
        self.components = try Self.parse(pattern: pattern)
    }

    /// Check if a path matches the glob pattern
    ///
    /// - Parameter path: File path to test (relative path)
    /// - Returns: `true` if path matches pattern, `false` otherwise
    public func matches(_ path: String) -> Bool {
        // Normalize trailing slash in both pattern and path (but preserve leading ones)
        let normalizedPath = path.hasSuffix("/") ? String(path.dropLast()) : path
        let normalizedPattern = pattern.hasSuffix("/") ? String(pattern.dropLast()) : pattern

        // Split into segments, preserving empty segments from leading slashes
        var pathSegments = normalizedPath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        var patternSegments = normalizedPattern.split(separator: "/", omittingEmptySubsequences: false).map(String.init)

        // Remove trailing empty segments (from normalized trailing slashes)
        while pathSegments.last?.isEmpty == true {
            pathSegments.removeLast()
        }
        while patternSegments.last?.isEmpty == true {
            patternSegments.removeLast()
        }

        return matchSegments(patternSegments, against: pathSegments)
    }

    // MARK: - Private Implementation

    private enum PatternComponent {
        case literal(String)
        case wildcard
        case globstar
        case singleChar
        case characterClass(Set<Character>)
        case braceExpansion([String])
    }

    /// Parse glob pattern into components
    private static func parse(pattern: String) throws -> [PatternComponent] {
        var components: [PatternComponent] = []
        var currentLiteral = ""
        var i = pattern.startIndex

        func addLiteral() {
            if !currentLiteral.isEmpty {
                components.append(.literal(currentLiteral))
                currentLiteral = ""
            }
        }

        while i < pattern.endIndex {
            let char = pattern[i]

            switch char {
            case "*":
                // Check for globstar (**)
                let nextIndex = pattern.index(after: i)
                if nextIndex < pattern.endIndex && pattern[nextIndex] == "*" {
                    addLiteral()
                    components.append(.globstar)
                    i = pattern.index(after: nextIndex)
                    continue
                } else {
                    addLiteral()
                    components.append(.wildcard)
                }

            case "?":
                addLiteral()
                components.append(.singleChar)

            case "[":
                addLiteral()
                let (charClass, endIndex) = try parseCharacterClass(pattern, startingAt: i)
                components.append(.characterClass(charClass))
                i = endIndex
                i = pattern.index(after: i)
                continue

            case "{":
                addLiteral()
                let (alternatives, endIndex) = try parseBraceExpansion(pattern, startingAt: i)
                components.append(.braceExpansion(alternatives))
                i = endIndex
                i = pattern.index(after: i)
                continue

            default:
                currentLiteral.append(char)
            }

            i = pattern.index(after: i)
        }

        addLiteral()
        return components
    }

    /// Parse character class [abc] or [a-z]
    private static func parseCharacterClass(_ pattern: String, startingAt start: String.Index) throws -> (Set<Character>, String.Index) {
        var chars = Set<Character>()
        var i = pattern.index(after: start) // Skip '['
        var foundClosing = false

        while i < pattern.endIndex {
            let char = pattern[i]

            if char == "]" {
                foundClosing = true
                break
            }

            // Check for range (a-z)
            let nextIndex = pattern.index(after: i)
            if nextIndex < pattern.endIndex && pattern[nextIndex] == "-" {
                let rangeEndIndex = pattern.index(after: nextIndex)
                if rangeEndIndex < pattern.endIndex {
                    let endChar = pattern[rangeEndIndex]
                    if endChar != "]" {
                        // Valid range - use Unicode scalars
                        guard let startScalar = char.unicodeScalars.first,
                              let endScalar = endChar.unicodeScalars.first else {
                            throw GlobMatcherError.invalidRange(String(pattern[start...rangeEndIndex]))
                        }
                        guard startScalar <= endScalar else {
                            throw GlobMatcherError.invalidRange(String(pattern[start...rangeEndIndex]))
                        }
                        for scalar in startScalar.value...endScalar.value {
                            if let unicodeScalar = UnicodeScalar(scalar) {
                                chars.insert(Character(unicodeScalar))
                            }
                        }
                        i = pattern.index(after: rangeEndIndex)
                        continue
                    }
                }
            }

            chars.insert(char)
            i = pattern.index(after: i)
        }

        guard foundClosing else {
            throw GlobMatcherError.unclosedBracket(String(pattern[start...]))
        }

        guard !chars.isEmpty else {
            throw GlobMatcherError.emptyCharacterClass(String(pattern[start...i]))
        }

        return (chars, i)
    }

    /// Parse brace expansion {a,b,c}
    private static func parseBraceExpansion(_ pattern: String, startingAt start: String.Index) throws -> ([String], String.Index) {
        var alternatives: [String] = []
        var current = ""
        var i = pattern.index(after: start) // Skip '{'
        var foundClosing = false

        while i < pattern.endIndex {
            let char = pattern[i]

            if char == "}" {
                alternatives.append(current)
                foundClosing = true
                break
            } else if char == "," {
                alternatives.append(current)
                current = ""
            } else {
                current.append(char)
            }

            i = pattern.index(after: i)
        }

        guard foundClosing else {
            throw GlobMatcherError.unclosedBrace(String(pattern[start...]))
        }

        return (alternatives, i)
    }

    /// Match pattern segments against path segments
    private func matchSegments(_ patternSegments: [String], against pathSegments: [String]) -> Bool {
        return matchSegmentsRecursive(patternSegments, 0, pathSegments, 0)
    }

    private func matchSegmentsRecursive(_ patternSegments: [String], _ patternIndex: Int, _ pathSegments: [String], _ pathIndex: Int) -> Bool {
        // Both exhausted - success
        if patternIndex >= patternSegments.count && pathIndex >= pathSegments.count {
            return true
        }

        // Pattern exhausted but path remains - failure
        if patternIndex >= patternSegments.count {
            return false
        }

        let patternSegment = patternSegments[patternIndex]

        // Check for globstar (**)
        if patternSegment == "**" {
            // Try matching zero or more path segments
            // First try skipping the globstar (matches zero segments)
            if matchSegmentsRecursive(patternSegments, patternIndex + 1, pathSegments, pathIndex) {
                return true
            }
            // Then try matching one or more segments
            for i in pathIndex..<pathSegments.count {
                if matchSegmentsRecursive(patternSegments, patternIndex + 1, pathSegments, i + 1) {
                    return true
                }
            }
            return false
        }

        // For other patterns, we need a path segment to match
        guard pathIndex < pathSegments.count else {
            return false
        }

        let pathSegment = pathSegments[pathIndex]

        if matchSingleSegment(pattern: patternSegment, against: pathSegment) {
            return matchSegmentsRecursive(patternSegments, patternIndex + 1, pathSegments, pathIndex + 1)
        } else {
            return false
        }
    }

    /// Match a single pattern segment against a path segment
    private func matchSingleSegment(pattern: String, against pathSegment: String) -> Bool {
        // Try to parse the pattern segment for special characters
        do {
            let components = try Self.parse(pattern: pattern)
            return matchComponentsAgainstString(components, against: pathSegment)
        } catch {
            // If parsing fails, treat as literal
            return pattern == pathSegment
        }
    }

    /// Match parsed components against a single string (not a path)
    private func matchComponentsAgainstString(_ components: [PatternComponent], against str: String) -> Bool {
        return matchComponentsStringRecursive(components, 0, str, str.startIndex)
    }

    private func matchComponentsStringRecursive(_ components: [PatternComponent], _ compIndex: Int, _ str: String, _ strIndex: String.Index) -> Bool {
        // Both exhausted - success
        if compIndex >= components.count && strIndex >= str.endIndex {
            return true
        }

        // Components exhausted but string remains - failure
        if compIndex >= components.count {
            return false
        }

        // String exhausted but components remain
        if strIndex >= str.endIndex {
            // Only wildcards can match empty
            let component = components[compIndex]
            if case .wildcard = component {
                return matchComponentsStringRecursive(components, compIndex + 1, str, strIndex)
            }
            return false
        }

        let component = components[compIndex]

        switch component {
        case .literal(let lit):
            let endIndex = str.index(strIndex, offsetBy: lit.count, limitedBy: str.endIndex) ?? str.endIndex
            let substring = String(str[strIndex..<endIndex])
            if substring == lit {
                return matchComponentsStringRecursive(components, compIndex + 1, str, endIndex)
            }
            return false

        case .wildcard:
            // Wildcard: try matching 0 or more characters
            // Try from longest to shortest for greedy matching
            for i in stride(from: str.count - str.distance(from: str.startIndex, to: strIndex), through: 0, by: -1) {
                let nextIndex = str.index(strIndex, offsetBy: i, limitedBy: str.endIndex) ?? str.endIndex
                if matchComponentsStringRecursive(components, compIndex + 1, str, nextIndex) {
                    return true
                }
            }
            return false

        case .globstar:
            // Globstar shouldn't appear in a single segment pattern
            return false

        case .singleChar:
            let nextIndex = str.index(after: strIndex)
            return matchComponentsStringRecursive(components, compIndex + 1, str, nextIndex)

        case .characterClass(let chars):
            let char = str[strIndex]
            if chars.contains(char) {
                let nextIndex = str.index(after: strIndex)
                return matchComponentsStringRecursive(components, compIndex + 1, str, nextIndex)
            }
            return false

        case .braceExpansion(let alternatives):
            // Try each alternative as a prefix, then continue matching remaining components
            for alternative in alternatives {
                // Check if the string starts with this alternative
                let altEndIndex = str.index(strIndex, offsetBy: alternative.count, limitedBy: str.endIndex)
                if let endIdx = altEndIndex {
                    let substring = String(str[strIndex..<endIdx])
                    if substring == alternative {
                        // Alternative matched, continue with remaining components
                        if matchComponentsStringRecursive(components, compIndex + 1, str, endIdx) {
                            return true
                        }
                    }
                }
            }
            return false
        }
    }
}
