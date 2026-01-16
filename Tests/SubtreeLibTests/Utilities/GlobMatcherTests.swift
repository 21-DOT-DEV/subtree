import Foundation
import Testing

@testable import SubtreeLib

@Suite("GlobMatcher Tests")
struct GlobMatcherTests {

    // MARK: - T022: Single-level wildcard matching (*.txt)

    @Test("Single wildcard matches file with extension")
    func testSingleWildcardBasic() throws {
        let matcher = try GlobMatcher(pattern: "*.txt")
        #expect(matcher.matches("file.txt") == true)
        #expect(matcher.matches("document.txt") == true)
        #expect(matcher.matches("readme.txt") == true)
    }

    @Test("Single wildcard does not match subdirectories")
    func testSingleWildcardNoSubdirs() throws {
        let matcher = try GlobMatcher(pattern: "*.txt")
        #expect(matcher.matches("dir/file.txt") == false)
        #expect(matcher.matches("a/b/c.txt") == false)
    }

    @Test("Single wildcard does not match wrong extension")
    func testSingleWildcardWrongExtension() throws {
        let matcher = try GlobMatcher(pattern: "*.txt")
        #expect(matcher.matches("file.md") == false)
        #expect(matcher.matches("document.pdf") == false)
    }

    @Test("Wildcard in middle of pattern")
    func testWildcardMiddle() throws {
        let matcher = try GlobMatcher(pattern: "test-*.log")
        #expect(matcher.matches("test-debug.log") == true)
        #expect(matcher.matches("test-error.log") == true)
        #expect(matcher.matches("test.log") == false)
        #expect(matcher.matches("production-test.log") == false)
    }

    // MARK: - T023: Globstar matching (**/*.md, docs/**/*.txt)

    @Test("Globstar matches files in any subdirectory")
    func testGlobstarBasic() throws {
        let matcher = try GlobMatcher(pattern: "**/*.md")
        #expect(matcher.matches("README.md") == true)
        #expect(matcher.matches("docs/guide.md") == true)
        #expect(matcher.matches("docs/api/reference.md") == true)
        #expect(matcher.matches("a/b/c/deep.md") == true)
    }

    @Test("Globstar with prefix")
    func testGlobstarWithPrefix() throws {
        let matcher = try GlobMatcher(pattern: "docs/**/*.txt")
        #expect(matcher.matches("docs/readme.txt") == true)
        #expect(matcher.matches("docs/api/guide.txt") == true)
        #expect(matcher.matches("docs/a/b/c/file.txt") == true)
        #expect(matcher.matches("other/file.txt") == false)
        #expect(matcher.matches("readme.txt") == false)
    }

    @Test("Globstar at end of pattern")
    func testGlobstarAtEnd() throws {
        let matcher = try GlobMatcher(pattern: "src/**")
        #expect(matcher.matches("src/main.c") == true)
        #expect(matcher.matches("src/lib/util.c") == true)
        #expect(matcher.matches("src/a/b/c/deep.h") == true)
        #expect(matcher.matches("other/file.c") == false)
    }

    @Test("Multiple directory levels with globstar")
    func testGlobstarDeepNesting() throws {
        let matcher = try GlobMatcher(pattern: "**/test/**/*.c")
        #expect(matcher.matches("test/unit.c") == true)
        #expect(matcher.matches("src/test/integration.c") == true)
        #expect(matcher.matches("lib/module/test/bench/speed.c") == true)
    }

    // MARK: - T024: Character class matching ([abc], *.{h,c})

    @Test("Character class matches single character")
    func testCharacterClassBasic() throws {
        let matcher = try GlobMatcher(pattern: "file[123].txt")
        #expect(matcher.matches("file1.txt") == true)
        #expect(matcher.matches("file2.txt") == true)
        #expect(matcher.matches("file3.txt") == true)
        #expect(matcher.matches("file4.txt") == false)
        #expect(matcher.matches("filea.txt") == false)
    }

    @Test("Character class with ranges")
    func testCharacterClassRange() throws {
        let matcher = try GlobMatcher(pattern: "chapter[0-9].md")
        #expect(matcher.matches("chapter0.md") == true)
        #expect(matcher.matches("chapter5.md") == true)
        #expect(matcher.matches("chapter9.md") == true)
        #expect(matcher.matches("chaptera.md") == false)
    }

    @Test("Brace expansion for extensions")
    func testBraceExpansion() throws {
        let matcher = try GlobMatcher(pattern: "*.{h,c}")
        #expect(matcher.matches("main.c") == true)
        #expect(matcher.matches("util.h") == true)
        #expect(matcher.matches("test.cpp") == false)
        #expect(matcher.matches("readme.md") == false)
    }

    @Test("Brace expansion with multiple options")
    func testBraceExpansionMultiple() throws {
        let matcher = try GlobMatcher(pattern: "src/**/*.{h,c,cpp}")
        #expect(matcher.matches("src/main.c") == true)
        #expect(matcher.matches("src/lib/util.h") == true)
        #expect(matcher.matches("src/test/runner.cpp") == true)
        #expect(matcher.matches("src/doc/readme.md") == false)
    }

    @Test("Brace expansion as prefix with wildcard suffix")
    func testBraceExpansionPrefixWithWildcard() throws {
        // Regression test: brace expansion followed by more pattern components
        // Previously, braces only worked at end of segment (e.g., *.{h,c})
        let matcher = try GlobMatcher(pattern: "{ppc,sparc}cap*")
        #expect(matcher.matches("ppccap.c") == true)
        #expect(matcher.matches("sparccap.c") == true)
        #expect(matcher.matches("ppccap") == true)
        #expect(matcher.matches("sparccap_test.c") == true)
        #expect(matcher.matches("armcap.c") == false)
        // Note: sparcv9cap.c does NOT match because v9 is between sparc and cap
        #expect(matcher.matches("sparcv9cap.c") == false)
    }

    @Test("Brace expansion with globstar prefix")
    func testBraceExpansionWithGlobstar() throws {
        // Regression test: globstar + brace expansion in path segment
        let matcher = try GlobMatcher(pattern: "**/{ppc,sparc}cap*")
        #expect(matcher.matches("crypto/ppccap.c") == true)
        #expect(matcher.matches("crypto/sparccap.c") == true)
        #expect(matcher.matches("lib/arch/ppccap_asm.s") == true)
    }

    @Test("Brace expansion with inner wildcard for flexible matching")
    func testBraceExpansionWithInnerWildcard() throws {
        // Pattern for matching files like sparcv9cap.c where there's content between prefix and suffix
        let matcher = try GlobMatcher(pattern: "{ppc,sparc}*cap*")
        #expect(matcher.matches("sparcv9cap.c") == true)
        #expect(matcher.matches("ppccap.c") == true)
        #expect(matcher.matches("sparccap.c") == true)
        #expect(matcher.matches("ppc64cap_test.c") == true)
    }

    // MARK: - T025: Single char wildcard (?)

    @Test("Question mark matches single character")
    func testSingleCharWildcard() throws {
        let matcher = try GlobMatcher(pattern: "file?.txt")
        #expect(matcher.matches("file1.txt") == true)
        #expect(matcher.matches("filea.txt") == true)
        #expect(matcher.matches("file.txt") == false)
        #expect(matcher.matches("file12.txt") == false)
    }

    @Test("Multiple question marks")
    func testMultipleSingleCharWildcards() throws {
        let matcher = try GlobMatcher(pattern: "test-???.log")
        #expect(matcher.matches("test-abc.log") == true)
        #expect(matcher.matches("test-123.log") == true)
        #expect(matcher.matches("test-ab.log") == false)
        #expect(matcher.matches("test-abcd.log") == false)
    }

    // MARK: - T026: Literal path matching

    @Test("Exact literal path matches")
    func testLiteralPath() throws {
        let matcher = try GlobMatcher(pattern: "docs/README.md")
        #expect(matcher.matches("docs/README.md") == true)
        #expect(matcher.matches("docs/readme.md") == false)  // Case-sensitive
        #expect(matcher.matches("DOCS/README.md") == false)
        #expect(matcher.matches("docs/README.txt") == false)
    }

    @Test("Literal path with multiple directories")
    func testLiteralPathMultipleDir() throws {
        let matcher = try GlobMatcher(pattern: "src/lib/util/string.c")
        #expect(matcher.matches("src/lib/util/string.c") == true)
        #expect(matcher.matches("src/lib/util/string.h") == false)
        #expect(matcher.matches("src/lib/string.c") == false)
    }

    // MARK: - T027: Directory separator handling

    @Test("Forward slash as directory separator")
    func testForwardSlash() throws {
        let matcher = try GlobMatcher(pattern: "src/*/main.c")
        #expect(matcher.matches("src/app/main.c") == true)
        #expect(matcher.matches("src/lib/main.c") == true)
        #expect(matcher.matches("src/main.c") == false)
        #expect(matcher.matches("src/a/b/main.c") == false)
    }

    @Test("Trailing slash in pattern")
    func testTrailingSlash() throws {
        let matcher = try GlobMatcher(pattern: "docs/")
        #expect(matcher.matches("docs/") == true)
        #expect(matcher.matches("docs") == true)  // Should match directory
    }

    @Test("Leading slash is not supported (relative paths only)")
    func testLeadingSlashNotSupported() throws {
        // Patterns should be relative, leading slash treated as literal character
        let matcher = try GlobMatcher(pattern: "/src/*.c")
        #expect(matcher.matches("src/main.c") == false)
        #expect(matcher.matches("/src/main.c") == true)
    }

    // MARK: - T028: Edge cases (empty path, root path, deep nesting)

    @Test("Empty pattern does not match anything")
    func testEmptyPatternError() throws {
        #expect(throws: Error.self) {
            try GlobMatcher(pattern: "")
        }
    }

    @Test("Pattern with only wildcard")
    func testOnlyWildcard() throws {
        let matcher = try GlobMatcher(pattern: "*")
        #expect(matcher.matches("file.txt") == true)
        #expect(matcher.matches("README") == true)
        #expect(matcher.matches("dir/file.txt") == false)
    }

    @Test("Pattern with only globstar")
    func testOnlyGlobstar() throws {
        let matcher = try GlobMatcher(pattern: "**")
        #expect(matcher.matches("file.txt") == true)
        #expect(matcher.matches("dir/file.txt") == true)
        #expect(matcher.matches("a/b/c/deep.txt") == true)
    }

    @Test("Deeply nested path matching")
    func testDeepNesting() throws {
        let matcher = try GlobMatcher(pattern: "a/**/z/*.txt")
        #expect(matcher.matches("a/z/file.txt") == true)
        #expect(matcher.matches("a/b/z/file.txt") == true)
        #expect(matcher.matches("a/b/c/d/e/f/z/file.txt") == true)
        #expect(matcher.matches("a/b/c/file.txt") == false)
    }

    @Test("Very long path names")
    func testVeryLongPath() throws {
        let longDir = String(repeating: "subdir/", count: 50)
        let matcher = try GlobMatcher(pattern: "**/*.txt")
        #expect(matcher.matches(longDir + "file.txt") == true)
    }

    // MARK: - T029: Invalid patterns (unclosed brackets, invalid syntax)

    @Test("Unclosed character class throws error")
    func testUnclosedBracket() throws {
        #expect(throws: Error.self) {
            try GlobMatcher(pattern: "file[abc.txt")
        }
    }

    @Test("Unclosed brace expansion throws error")
    func testUnclosedBrace() throws {
        #expect(throws: Error.self) {
            try GlobMatcher(pattern: "*.{h,c")
        }
    }

    @Test("Invalid character range throws error")
    func testInvalidRange() throws {
        #expect(throws: Error.self) {
            try GlobMatcher(pattern: "file[z-a].txt")
        }
    }

    @Test("Empty character class throws error")
    func testEmptyCharacterClass() throws {
        #expect(throws: Error.self) {
            try GlobMatcher(pattern: "file[].txt")
        }
    }

    // MARK: - T030: Symlink handling (follow symlinks, copy target)

    @Test("Pattern matches work regardless of symlink status")
    func testSymlinkPatternMatching() throws {
        // GlobMatcher only does pattern matching, not filesystem operations
        // Symlink handling is done during file copying, not pattern matching
        let matcher = try GlobMatcher(pattern: "src/**/*.c")

        // Both regular files and symlinks should match if they meet the pattern
        #expect(matcher.matches("src/main.c") == true)
        #expect(matcher.matches("src/lib/util.c") == true)

        // Pattern matching doesn't care about file type, only path structure
    }

    @Test("Symlink note - filesystem operations separate from pattern matching")
    func testSymlinkNote() throws {
        // This test documents that GlobMatcher is pure pattern matching
        // Actual symlink following (copying target content) happens in file extraction logic
        // GlobMatcher just needs to match path strings correctly

        let matcher = try GlobMatcher(pattern: "**/*.txt")
        #expect(matcher.matches("docs/link-to-file.txt") == true)
        #expect(matcher.matches("real-file.txt") == true)
    }
}
