import Testing
import Foundation
@testable import SubtreeLib

/// Tests for tag-prefix filtering used when selecting the "latest" remote tag.
///
/// Background: `GitOperations.lsRemoteTags` returns tags sorted by a
/// semver-ish comparator that falls back to plain string compare for
/// non-numeric parts. Repos with historical/label tags (e.g., OpenSSL's
/// `rsaref`, `SSLeay_*`) therefore sort ahead of the actual releases
/// (`openssl-3.6.2`), causing spurious update PRs. These tests lock in
/// prefix-aware filtering that scopes candidates to the same naming
/// scheme as the currently-configured tag.
@Suite("GitOperations Tag Filter Tests")
struct GitOperationsTagFilterTests {
    
    // MARK: - nonNumericPrefix
    
    @Test("nonNumericPrefix extracts the leading non-digit prefix of a tag")
    func nonNumericPrefixBasic() {
        #expect(GitOperations.nonNumericPrefix(of: "openssl-3.6.2") == "openssl-")
        #expect(GitOperations.nonNumericPrefix(of: "tor-0.4.8.21") == "tor-")
        #expect(GitOperations.nonNumericPrefix(of: "v1.2.3") == "v")
        #expect(GitOperations.nonNumericPrefix(of: "V1.2.3") == "V")
        #expect(GitOperations.nonNumericPrefix(of: "1.2.3") == "")
        #expect(GitOperations.nonNumericPrefix(of: "") == "")
    }
    
    @Test("nonNumericPrefix returns full tag when no digit is present")
    func nonNumericPrefixNoDigits() {
        #expect(GitOperations.nonNumericPrefix(of: "rsaref") == "rsaref")
        #expect(GitOperations.nonNumericPrefix(of: "main") == "main")
        #expect(GitOperations.nonNumericPrefix(of: "stable") == "stable")
    }
    
    @Test("nonNumericPrefix handles mixed-case and underscore separators")
    func nonNumericPrefixMixedFormats() {
        #expect(GitOperations.nonNumericPrefix(of: "OpenSSL_1_1_1w") == "OpenSSL_")
        #expect(GitOperations.nonNumericPrefix(of: "release-2.1.12-stable") == "release-")
        #expect(GitOperations.nonNumericPrefix(of: "SSLeay_0_9_0") == "SSLeay_")
    }
    
    @Test("nonNumericPrefix treats only ASCII 0-9 as digits")
    func nonNumericPrefixOnlyASCIIDigits() {
        // Ensure we don't accidentally match non-ASCII digit-like characters.
        #expect(GitOperations.nonNumericPrefix(of: "v\u{0660}1.2.3") == "v\u{0660}") // Arabic-Indic digit 0
    }
    
    // MARK: - latestTag(from:matchingPrefixOf:)
    
    @Test("latestTag picks the first tag sharing the configured tag's prefix")
    func latestTagPrefersMatchingPrefix() {
        // Pre-sorted as lsRemoteTags would return (latest-first under compareSemver).
        let tags: [(tag: String, commit: String)] = [
            ("rsaref", "aaa"),                 // would sort first under old logic ('r' > 'o')
            ("openssl-3.7.0-beta1", "bbb"),
            ("openssl-3.6.2", "ccc"),
        ]
        let result = GitOperations.latestTag(from: tags, matchingPrefixOf: "openssl-3.6.2")
        #expect(result?.tag == "openssl-3.7.0-beta1")
        #expect(result?.commit == "bbb")
    }
    
    @Test("latestTag regression: OpenSSL tag set does not select rsaref")
    func latestTagOpenSSLRegression() {
        // Reproduces the real-world tag set from openssl/openssl that caused
        // the spurious "update to rsaref" PR in swift-openssl.
        // Pre-sorted by compareSemver (simulating lsRemoteTags output).
        let tags: [(tag: String, commit: String)] = [
            ("rsaref", "000"),                 // 'r' > 'o' → would sort first
            ("openssl-3.7.0-beta1", "001"),
            ("openssl-3.6.2", "002"),
            ("openssl-3.6.1", "003"),
            ("openssl-3.5.0", "004"),
            ("OpenSSL_1_1_1w", "005"),         // 'O' < 'o'
            ("SSLeay_0_9_0", "006"),
            ("BEN_FIPS_TEST_6", "007"),
        ]
        let result = GitOperations.latestTag(from: tags, matchingPrefixOf: "openssl-3.6.2")
        #expect(result?.tag == "openssl-3.7.0-beta1")
        #expect(result?.tag != "rsaref")
    }
    
    @Test("latestTag returns nil when no tag matches the configured prefix")
    func latestTagReturnsNilOnPrefixRebrand() {
        // Simulates an upstream rename: user has foo-* configured but remote
        // only publishes bar-* now. Surfacing nil lets the caller raise a
        // clear error instead of silently picking an unrelated tag.
        let tags: [(tag: String, commit: String)] = [
            ("bar-2.0.0", "aaa"),
            ("bar-1.0.0", "bbb"),
        ]
        let result = GitOperations.latestTag(from: tags, matchingPrefixOf: "foo-1.0.0")
        #expect(result == nil)
    }
    
    @Test("latestTag returns nil on empty tag list")
    func latestTagReturnsNilOnEmptyList() {
        let tags: [(tag: String, commit: String)] = []
        let result = GitOperations.latestTag(from: tags, matchingPrefixOf: "openssl-3.6.2")
        #expect(result == nil)
    }
    
    @Test("latestTag preserves tor-style prefix isolation")
    func latestTagTorStyle() {
        let tags: [(tag: String, commit: String)] = [
            ("tor-0.4.9.0", "new"),
            ("tor-0.4.8.21", "cur"),
            ("tor-0.4.8.20", "old"),
        ]
        let result = GitOperations.latestTag(from: tags, matchingPrefixOf: "tor-0.4.8.21")
        #expect(result?.tag == "tor-0.4.9.0")
    }
    
    @Test("latestTag uses strict prefix equality, not hasPrefix")
    func latestTagStrictPrefixEquality() {
        // Configured tag has empty non-numeric prefix (pure-numeric scheme).
        // Tags like "rsaref" have full-string non-numeric prefix and must NOT
        // match just because "rsaref".hasPrefix("") is true.
        let tags: [(tag: String, commit: String)] = [
            ("rsaref", "junk"),
            ("2.0.0", "new"),
            ("1.2.3", "cur"),
        ]
        let result = GitOperations.latestTag(from: tags, matchingPrefixOf: "1.2.3")
        #expect(result?.tag == "2.0.0")
    }
    
    @Test("latestTag distinguishes case-sensitive prefixes")
    func latestTagCaseSensitivePrefix() {
        // openssl/openssl historically mixed `OpenSSL_*` and `openssl-*`
        // schemes. A user who configured the lowercase scheme must not be
        // migrated to the uppercase one automatically.
        let tags: [(tag: String, commit: String)] = [
            ("OpenSSL_3_9_9", "upper"),
            ("openssl-3.7.0", "lower-new"),
            ("openssl-3.6.2", "lower-cur"),
        ]
        let result = GitOperations.latestTag(from: tags, matchingPrefixOf: "openssl-3.6.2")
        #expect(result?.tag == "openssl-3.7.0")
    }
}
